local chat = require("fm.chat")
local config = require("fm.config")

local M = {
  ---@type integer|nil
  win = nil,
  ---@type integer|nil
  buf = nil,
  ---@type integer|nil
  input_win = nil,
  ---@type integer|nil
  input_buf = nil,
  ---@type integer[]
  autocmds = {},
}

local NS = vim.api.nvim_create_namespace("fm.nvim")

local function hl_setup()
  local function ensure(name, link)
    if vim.fn.hlexists(name) == 0 then
      vim.api.nvim_set_hl(0, name, { link = link })
    end
  end
  ensure("FmUser", "DiagnosticInfo")
  ensure("FmAssistant", "Normal")
  ensure("FmSystem", "Comment")
  ensure("FmError", "DiagnosticError")
  ensure("FmPrompt", "Title")
end

---@param value number
---@param total integer
---@return integer
local function resolve_size(value, total)
  if value > 0 and value <= 1 then
    return math.max(1, math.floor(total * value))
  end
  return math.max(1, math.floor(value))
end

---@return { row: integer, col: integer, width: integer, height: integer, input_height: integer }
local function layout()
  local cfg = config.get().window
  local width = resolve_size(cfg.width, vim.o.columns)
  local height = resolve_size(cfg.height, vim.o.lines - vim.o.cmdheight)
  local input_height = math.max(1, cfg.input_height or 3)
  local chat_height = math.max(3, height - input_height - 1)

  local row, col
  if cfg.relative == "cursor" then
    -- Hover-style: anchor near the cursor.
    local win_row = vim.fn.winline()
    local win_col = vim.fn.wincol()
    row = math.min(win_row, math.max(0, vim.o.lines - height - 2))
    col = math.min(math.max(0, win_col - 1), math.max(0, vim.o.columns - width))
  else
    row = math.floor((vim.o.lines - height) / 2) - 1
    col = math.floor((vim.o.columns - width) / 2)
    row = math.max(0, row)
    col = math.max(0, col)
  end

  return {
    row = row,
    col = col,
    width = width,
    height = height,
    chat_height = chat_height,
    input_height = input_height,
  }
end

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

function M.is_open()
  return valid_win(M.win) and valid_buf(M.buf)
end

local function clear_autocmds()
  for _, id in ipairs(M.autocmds) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  M.autocmds = {}
end

function M.close()
  clear_autocmds()
  if valid_win(M.input_win) then
    pcall(vim.api.nvim_win_close, M.input_win, true)
  end
  if valid_win(M.win) then
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  if valid_buf(M.input_buf) then
    pcall(vim.api.nvim_buf_delete, M.input_buf, { force = true })
  end
  if valid_buf(M.buf) then
    pcall(vim.api.nvim_buf_delete, M.buf, { force = true })
  end
  M.win, M.buf, M.input_win, M.input_buf = nil, nil, nil, nil
end

---@param lines string[]
---@return string[]
local function wrap_soft(lines)
  -- Keep raw lines; Neovim wraps with wrap=true.
  return lines
end

function M.render()
  if not M.is_open() then
    return
  end

  local lines = {}
  local marks = {}

  if #chat.messages == 0 then
    lines = {
      "Talk to Apple Foundation Models via `fm`.",
      "",
      "Type a prompt below and press Enter to send.",
      "Visual selection can be attached with :FmAskSelection",
      "",
      "q  close   <C-l> clear   <C-c> stop",
    }
    marks[#marks + 1] = { 0, #lines - 1, "FmSystem" }
  else
    for _, msg in ipairs(chat.messages) do
      local label
      local hl
      if msg.role == "user" then
        label, hl = "You", "FmUser"
      elseif msg.role == "assistant" then
        label, hl = "fm", "FmAssistant"
      elseif msg.role == "error" then
        label, hl = "error", "FmError"
      else
        label, hl = msg.role, "FmSystem"
      end

      local start = #lines
      lines[#lines + 1] = ("── %s ──"):format(label)
      for _, line in ipairs(vim.split(msg.content, "\n", { plain = true })) do
        lines[#lines + 1] = line
      end
      if msg.content == "" and msg.role == "assistant" and chat.is_busy() then
        lines[#lines + 1] = "…"
      end
      lines[#lines + 1] = ""
      marks[#marks + 1] = { start, start, hl }
    end
  end

  lines = wrap_soft(lines)
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(M.buf, NS, 0, -1)
  -- Each mark is { first_row, last_row, hl_group }, rows 0-indexed and inclusive.
  for _, m in ipairs(marks) do
    for row = m[1], m[2] do
      vim.api.nvim_buf_set_extmark(M.buf, NS, row, 0, { line_hl_group = m[3] })
    end
  end

  -- Keep the latest reply visible.
  local last = math.max(0, #lines - 1)
  pcall(vim.api.nvim_win_set_cursor, M.win, { last + 1, 0 })
end

local function map_buf(buf, mode, lhs, rhs, desc)
  if not lhs or lhs == false or lhs == "" then
    return
  end
  vim.keymap.set(mode, lhs, rhs, {
    buffer = buf,
    silent = true,
    noremap = true,
    desc = desc,
  })
end

---@param on_send fun(text: string)
local function bind_keys(on_send)
  local keys = config.get().keymaps

  map_buf(M.buf, "n", keys.close, function()
    M.close()
  end, "Close fm window")
  map_buf(M.input_buf, "n", keys.close, function()
    M.close()
  end, "Close fm window")
  map_buf(M.input_buf, "i", "<Esc>", function()
    vim.cmd("stopinsert")
    M.close()
  end, "Close fm window")

  map_buf(M.buf, "n", keys.clear, function()
    chat.clear()
    M.render()
  end, "Clear fm conversation")
  map_buf(M.input_buf, "n", keys.clear, function()
    chat.clear()
    M.render()
  end, "Clear fm conversation")
  map_buf(M.input_buf, "i", keys.clear, function()
    chat.clear()
    M.render()
  end, "Clear fm conversation")

  map_buf(M.buf, "n", keys.stop, function()
    chat.stop()
    M.render()
  end, "Stop fm generation")
  map_buf(M.input_buf, "n", keys.stop, function()
    chat.stop()
    M.render()
  end, "Stop fm generation")
  map_buf(M.input_buf, "i", keys.stop, function()
    chat.stop()
    M.render()
  end, "Stop fm generation")

  local function send()
    local lines = vim.api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
    local text = vim.trim(table.concat(lines, "\n"))
    vim.api.nvim_buf_set_lines(M.input_buf, 0, -1, false, { "" })
    if text ~= "" then
      on_send(text)
    end
  end

  map_buf(M.input_buf, "n", keys.send, send, "Send prompt to fm")
  map_buf(M.input_buf, "i", keys.send, function()
    -- In insert mode, <CR> alone would insert a newline; we send instead.
    -- Use <C-j> / configured key. Default is <CR>.
    vim.cmd("stopinsert")
    send()
    vim.cmd("startinsert")
  end, "Send prompt to fm")

  -- Allow a literal newline with Shift-Enter / Ctrl-Enter style.
  map_buf(M.input_buf, "i", "<C-Enter>", "<CR>", "Insert newline")
  map_buf(M.input_buf, "i", "<S-CR>", "<CR>", "Insert newline")
end

---@param on_send fun(text: string)
function M.open(on_send)
  if M.is_open() then
    vim.api.nvim_set_current_win(M.input_win)
    vim.cmd("startinsert")
    return
  end

  hl_setup()
  local cfg = config.get().window
  local geo = layout()

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[M.buf].buftype = "nofile"
  vim.bo[M.buf].bufhidden = "wipe"
  vim.bo[M.buf].swapfile = false
  vim.bo[M.buf].filetype = "markdown"
  vim.bo[M.buf].modifiable = false
  vim.bo[M.buf].textwidth = 0

  M.win = vim.api.nvim_open_win(M.buf, false, {
    relative = cfg.relative == "cursor" and "cursor" or "editor",
    row = cfg.relative == "cursor" and 1 or geo.row,
    col = cfg.relative == "cursor" and 0 or geo.col,
    width = geo.width,
    height = geo.chat_height,
    style = "minimal",
    border = cfg.border,
    title = cfg.title,
    title_pos = cfg.title_pos,
    zindex = cfg.zindex,
  })
  vim.wo[M.win].wrap = true
  vim.wo[M.win].linebreak = true
  vim.wo[M.win].cursorline = false
  vim.wo[M.win].number = false
  vim.wo[M.win].relativenumber = false
  vim.wo[M.win].signcolumn = "no"

  M.input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[M.input_buf].buftype = "nofile"
  vim.bo[M.input_buf].bufhidden = "wipe"
  vim.bo[M.input_buf].swapfile = false
  vim.bo[M.input_buf].filetype = "fm-prompt"

  -- Place the prompt float just below the chat float (borders sit outside height).
  local input_row = (cfg.relative == "cursor") and (geo.chat_height + 2)
    or (geo.row + geo.chat_height + 2)

  M.input_win = vim.api.nvim_open_win(M.input_buf, true, {
    relative = cfg.relative == "cursor" and "cursor" or "editor",
    row = input_row,
    col = cfg.relative == "cursor" and 0 or geo.col,
    width = geo.width,
    height = geo.input_height,
    style = "minimal",
    border = cfg.border,
    title = " prompt ",
    title_pos = "left",
    zindex = cfg.zindex + 1,
  })
  vim.wo[M.input_win].wrap = true
  vim.wo[M.input_win].number = false
  vim.wo[M.input_win].relativenumber = false
  vim.wo[M.input_win].signcolumn = "no"

  bind_keys(on_send)
  M.render()

  M.autocmds[#M.autocmds + 1] = vim.api.nvim_create_autocmd({ "WinClosed" }, {
    callback = function(args)
      local closed = tonumber(args.match)
      if closed == M.win or closed == M.input_win then
        M.close()
      end
    end,
  })

  vim.api.nvim_set_current_win(M.input_win)
  vim.cmd("startinsert")
end

function M.toggle(on_send)
  if M.is_open() then
    M.close()
  else
    M.open(on_send)
  end
end

---One-shot hover float near the cursor (LSP-style).
---@param title string
---@param body string
function M.hover(title, body)
  hl_setup()
  local width = math.min(80, math.max(40, math.floor(vim.o.columns * 0.5)))
  local lines = vim.split(body, "\n", { plain = true })
  if #lines == 0 then
    lines = { "" }
  end
  local height = math.min(20, math.max(3, #lines))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = config.get().window.border,
    title = " " .. title .. " ",
    title_pos = "center",
    zindex = 60,
    focusable = true,
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local group = vim.api.nvim_create_augroup("fm.nvim.hover", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
    group = group,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })

  return win, buf
end

return M

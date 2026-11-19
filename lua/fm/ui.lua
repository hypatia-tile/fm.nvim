local M = {
  ---@type integer|nil
  prompt_win = nil,
  ---@type integer|nil
  result_win = nil,
  ---@type integer|nil
  result_buf = nil,
  ---Called once when the result window closes.
  ---@type fun()|nil
  on_result_close = nil,
}

local function valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function scratch_buf(filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = filetype
  return buf
end

---@param buf integer
---@param close fun()
local function map_close(buf, close)
  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, close, { buffer = buf, silent = true, nowait = true, desc = "Close fm window" })
  end
end

---Centred float geometry.
---@param width integer
---@param height integer
local function centred(width, height)
  return {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  }
end

local function float_width()
  return math.max(20, math.min(100, math.floor(vim.o.columns * 0.6)))
end

---@return boolean
function M.prompt_is_open()
  return valid_win(M.prompt_win)
end

function M.close_prompt()
  if valid_win(M.prompt_win) then
    vim.api.nvim_win_close(M.prompt_win, true)
  end
  M.prompt_win = nil
end

---Open a prompt window. <CR> sends; q or <Esc> in Normal mode cancels.
---@param on_submit fun(prompt: string)
function M.open_prompt(on_submit)
  M.close_prompt()
  local buf = scratch_buf("fm-prompt")
  local opts = centred(float_width(), 3)
  opts.title = " fm prompt "
  opts.title_pos = "center"
  M.prompt_win = vim.api.nvim_open_win(buf, true, opts)
  vim.wo[M.prompt_win].wrap = true

  local function submit()
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
    vim.cmd("stopinsert")
    M.close_prompt()
    if text ~= "" then
      on_submit(text)
    end
  end
  vim.keymap.set({ "n", "i" }, "<CR>", submit, { buffer = buf, silent = true, desc = "Send prompt to fm" })
  map_close(buf, M.close_prompt)

  vim.cmd("startinsert")
end

function M.close_result()
  local cb, win = M.on_result_close, M.result_win
  -- Clear first: closing fires WinClosed, which must not close again.
  M.on_result_close, M.result_win, M.result_buf = nil, nil, nil
  if valid_win(win) then
    vim.api.nvim_win_close(win, true)
  end
  if cb then
    cb()
  end
end

---Number of screen rows `lines` take when wrapped at `width`.
---@param lines string[]
---@param width integer
local function wrapped_height(lines, width)
  local rows = 0
  for _, line in ipairs(lines) do
    rows = rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
  end
  return rows
end

---Show `lines` in the result window, opening it or replacing its contents.
---@param lines string[]
---@param opts { title?: string, on_close?: fun() }|nil
function M.show_result(lines, opts)
  opts = opts or {}
  local width = float_width()
  local max_height = math.max(3, math.floor(vim.o.lines * 0.6))
  local height = math.min(max_height, math.max(1, wrapped_height(lines, width)))
  local win_opts = centred(width, height)
  win_opts.title = opts.title or " fm "
  win_opts.title_pos = "center"

  if valid_win(M.result_win) then
    vim.api.nvim_win_set_config(M.result_win, win_opts)
  else
    M.result_buf = scratch_buf("markdown")
    M.result_win = vim.api.nvim_open_win(M.result_buf, true, win_opts)
    vim.wo[M.result_win].wrap = true
    vim.wo[M.result_win].linebreak = true
    map_close(M.result_buf, M.close_result)
    local win = M.result_win
    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = tostring(win),
      once = true,
      callback = function()
        if M.result_win == win then
          -- Closed some other way (:q, <C-w>c): still run the callback.
          M.close_result()
        end
      end,
    })
  end
  M.on_result_close = opts.on_close

  vim.bo[M.result_buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.result_buf, 0, -1, false, lines)
  vim.bo[M.result_buf].modifiable = false
end

return M

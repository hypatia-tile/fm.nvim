local chat = require("fm.chat")
local config = require("fm.config")
local ui = require("fm.ui")

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "fm.nvim" })
end

local ask

---Called when a prompt is sent from the chat window's input.
---@param text string
local function on_send(text)
  ask(text, {})
end

---@param prompt string
---@param opts { text?: string }|nil
ask = function(prompt, opts)
  opts = opts or {}

  local started = chat.ask(prompt, {
    text = opts.text,
    on_start = function()
      if ui.is_open() then
        ui.render()
      else
        ui.open(on_send)
      end
    end,
    on_delta = function()
      if ui.is_open() then
        ui.render()
      end
    end,
    on_done = function()
      if ui.is_open() then
        ui.render()
      end
    end,
    on_error = function(err)
      notify(err, vim.log.levels.ERROR)
      if ui.is_open() then
        ui.render()
      end
    end,
  })

  return started
end

---@param opts FmConfig|nil
function M.setup(opts)
  config.setup(opts)
  local keys = config.get().keymaps

  if keys.toggle and keys.toggle ~= false then
    vim.keymap.set({ "n", "v" }, keys.toggle, function()
      M.toggle()
    end, { desc = "Toggle fm hover chat", silent = true })
  end

  if keys.ask_selection and keys.ask_selection ~= false then
    vim.keymap.set("v", keys.ask_selection, function()
      M.ask_selection()
    end, { desc = "Ask fm about selection", silent = true })
  end
end

function M.toggle()
  ui.toggle(on_send)
end

function M.open()
  ui.open(on_send)
end

function M.close()
  ui.close()
end

---@param prompt string|nil
function M.ask(prompt)
  if not prompt or vim.trim(prompt) == "" then
    M.open()
    return
  end
  ask(prompt, {})
end

---Collect text for a line range (1-indexed, inclusive).
---@param buf integer
---@param line1 integer
---@param line2 integer
---@return string
local function lines_text(buf, line1, line2)
  local lines = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
  return table.concat(lines, "\n")
end

---Ask about the current visual selection (or a line range / current line).
---@param prompt string|nil Extra instruction for the selection
---@param range { line1: integer, line2: integer }|nil Optional command range
function M.ask_selection(prompt, range)
  local mode = vim.fn.mode()
  local text

  if mode == "v" or mode == "V" or mode == "\22" then
    local from, to = vim.fn.getpos("v"), vim.fn.getpos(".")
    if vim.fn.exists("*getregion") == 1 then
      text = table.concat(vim.fn.getregion(from, to, { type = mode }), "\n")
    else
      -- Neovim 0.9 has no getregion(). The '< and '> marks still hold the
      -- previous selection while in Visual mode, so use the live ends of the
      -- current one, whole lines.
      text = lines_text(0, math.min(from[2], to[2]), math.max(from[2], to[2]))
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  elseif range and range.line1 and range.line2 and range.line2 >= range.line1 then
    text = lines_text(0, range.line1, range.line2)
  else
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    if start_pos[2] > 0 and end_pos[2] >= start_pos[2] then
      text = lines_text(0, start_pos[2], end_pos[2])
    else
      text = vim.api.nvim_get_current_line()
    end
  end

  text = vim.trim(text or "")
  if text == "" then
    notify("No selection to send", vim.log.levels.WARN)
    return
  end

  local instruction = prompt
  if not instruction or vim.trim(instruction) == "" then
    instruction = "Explain or improve the following code. Be concise."
  end

  ask(instruction, { text = text })
end

function M.clear()
  chat.clear()
  if ui.is_open() then
    ui.render()
  end
end

function M.stop()
  chat.stop()
  if ui.is_open() then
    ui.render()
  end
end

return M

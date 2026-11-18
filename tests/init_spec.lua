-- Run with:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile tests/init_spec.lua"

local function assert_true(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

vim.cmd("runtime plugin/fm.lua")

local transcript_dir = vim.fn.tempname()
require("fm").setup({
  cmd = "true",
  transcript_dir = transcript_dir,
  keymaps = { toggle = false, ask_selection = false },
})

local chat = require("fm.chat")

-- Capture what the commands send instead of starting fm.
local sent = {}
local real_ask = chat.ask
chat.ask = function(prompt, opts)
  table.insert(sent, { prompt = prompt, text = opts and opts.text })
  return true
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three", "four" })

-- No range: use the last '< '> selection, not the cursor line.
vim.api.nvim_buf_set_mark(0, "<", 2, 0, {})
vim.api.nvim_buf_set_mark(0, ">", 3, 0, {})
vim.api.nvim_win_set_cursor(0, { 4, 0 })
vim.cmd("FmAskSelection")
assert_true(sent[1] and sent[1].text == "two\nthree", "no range uses last selection: " .. vim.inspect(sent[1]))

-- Explicit range wins over the marks.
vim.cmd("1,1FmAskSelection summarise")
assert_true(sent[2] and sent[2].text == "one", "range is used: " .. vim.inspect(sent[2]))
assert_true(sent[2].prompt == "summarise", "instruction is passed")

chat.ask = real_ask

-- The transcript is deleted when Neovim exits.
local path = chat.transcript_file()
vim.fn.writefile({ "{}" }, path)
assert_true(vim.fn.filereadable(path) == 1, "transcript exists")
vim.api.nvim_exec_autocmds("VimLeavePre", {})
assert_true(vim.fn.filereadable(path) == 0, "transcript deleted on VimLeavePre")

-- clear() without a transcript does not create the directory.
local fresh = vim.fn.tempname()
require("fm.config").options.transcript_dir = fresh
chat.clear()
assert_true(vim.fn.isdirectory(fresh) == 0, "clear() does not create the transcript dir")

print("init_spec: ok")
vim.cmd("qa!")

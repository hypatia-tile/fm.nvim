-- Run with: make test
-- Drives :Fm against a fake fm, so it runs anywhere.

local function assert_true(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

vim.cmd("runtime plugin/fm.lua")

-- Fake fm. The last argument is the prompt:
--   "fail"  -> coloured error on stderr, exit 1
--   "stdin" -> read stdin to EOF first (hangs if stdin is left open)
--   "slow"  -> sleep, then write a marker file
--   other   -> print the arguments it got
local marker = vim.fn.tempname()
local fake = vim.fn.tempname()
vim.fn.writefile({
  "#!/bin/sh",
  'for a; do last=$a; done',
  'case "$last" in',
  "  fail) printf '\\033[31mError: boom\\033[0m\\n' >&2; exit 1 ;;",
  "  stdin) cat >/dev/null; echo 'read stdin' ;;",
  "  slow) sleep 1; echo done > " .. marker .. "; echo slow ;;",
  '  *) echo "args: $*" ;;',
  "esac",
}, fake)
vim.fn.system({ "chmod", "+x", fake })

require("fm").setup({ cmd = fake })
local ui = require("fm.ui")

local function result_lines()
  return vim.api.nvim_buf_get_lines(ui.result_buf, 0, -1, false)
end

local function result_title()
  local title = vim.api.nvim_win_get_config(ui.result_win).title
  return type(title) == "table" and title[1][1] or title
end

local function wait_for_title(title)
  vim.wait(3000, function()
    return ui.result_win ~= nil and result_title() == title
  end, 20)
  assert_true(ui.result_win ~= nil and result_title() == title, "title " .. title .. ", got " .. vim.inspect(ui.result_win and result_title()))
end

-- 1. :Fm opens the prompt window; <CR> sends and shows the answer.
vim.cmd("Fm")
assert_true(ui.prompt_win and vim.api.nvim_get_current_win() == ui.prompt_win, "prompt window is focused")
vim.cmd("stopinsert")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello there" })
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert_true(ui.prompt_win == nil, "prompt window closes on send")
assert_true(result_title() == " fm (thinking) ", "thinking title while waiting")
wait_for_title(" fm ")
local lines = result_lines()
assert_true(lines[1] == "> hello there", "prompt shown as header: " .. vim.inspect(lines))
assert_true(lines[3] == "args: respond --no-stream -- hello there", "answer shown: " .. vim.inspect(lines))
assert_true(vim.api.nvim_get_current_win() == ui.result_win, "result window is focused")

-- 2. q closes the result window.
vim.api.nvim_feedkeys("q", "x", false)
assert_true(ui.result_win == nil, "q closes the result window")

-- 3. q in the prompt window cancels without sending.
vim.cmd("Fm")
vim.cmd("stopinsert")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "never sent" })
vim.api.nvim_feedkeys("q", "x", false)
assert_true(ui.prompt_win == nil and ui.result_win == nil, "q cancels the prompt")

-- 4. Errors are shown with colour codes removed.
vim.cmd("Fm fail")
wait_for_title(" fm: error ")
assert_true(result_lines()[3] == "Error: boom", "error text without ANSI: " .. vim.inspect(result_lines()))
ui.close_result()

-- 5. stdin is closed, so an fm that reads stdin does not hang.
vim.cmd("Fm stdin")
wait_for_title(" fm ")
assert_true(result_lines()[3] == "read stdin", "stdin reader finished")
ui.close_result()

-- 6. Closing the window while fm runs cancels it.
vim.cmd("Fm slow")
assert_true(result_title() == " fm (thinking) ", "slow request is running")
vim.api.nvim_feedkeys("q", "x", false)
vim.wait(1500)
assert_true(ui.result_win == nil, "no window reopens after cancel")
assert_true(vim.fn.filereadable(marker) == 0, "fm was killed before finishing")

-- 7. A new request replaces one still running.
vim.cmd("Fm slow")
vim.cmd("Fm second")
wait_for_title(" fm ")
vim.wait(1500)
assert_true(result_lines()[1] == "> second", "the newer request's answer stays: " .. vim.inspect(result_lines()))
assert_true(vim.fn.filereadable(marker) == 0, "the older request was killed")
ui.close_result()

-- 8. A missing fm is reported in the window.
require("fm").setup({ cmd = "fm-does-not-exist" })
vim.cmd("Fm hi")
assert_true(result_title() == " fm: error ", "missing fm shows an error")
assert_true(result_lines()[3]:find("not found in PATH", 1, true), "missing fm message: " .. vim.inspect(result_lines()))
ui.close_result()

print("fm_spec: ok")
vim.cmd("qa!")

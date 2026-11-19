-- Run with: make test

local function assert_true(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

vim.g.mapleader = " "
local fm = require("fm")
local ui = require("fm.ui")

-- Default: <leader>tf toggles the prompt window; <leader>f stays free.
fm.setup({})
local map = vim.fn.maparg("<leader>tf", "n", false, true)
assert_true(map.desc == "Toggle fm prompt window", "default toggle map: " .. vim.inspect(map))
for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
  assert_true(not vim.startswith(m.lhs, " f"), "nothing mapped under <leader>f: " .. m.lhs)
end

vim.api.nvim_feedkeys(vim.keycode("<leader>tf"), "x", false)
assert_true(ui.prompt_is_open(), "toggle opens the prompt window")
vim.cmd("stopinsert")
fm.toggle()
assert_true(not ui.prompt_is_open(), "toggle closes the prompt window")

-- Custom key.
vim.keymap.del("n", "<leader>tf")
fm.setup({ keymaps = { toggle = "<leader>xx" } })
assert_true(vim.fn.maparg("<leader>xx", "n") ~= "", "custom toggle map")
assert_true(vim.fn.maparg("<leader>tf", "n") == "", "default not mapped when overridden")

-- Disabled.
vim.keymap.del("n", "<leader>xx")
fm.setup({ keymaps = { toggle = false } })
assert_true(vim.fn.maparg("<leader>tf", "n") == "", "no map when toggle = false")

print("keymap_spec: ok")
vim.cmd("qa!")

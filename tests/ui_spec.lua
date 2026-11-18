-- Run with:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile tests/ui_spec.lua"

local function assert_true(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

-- Fake `fm` that streams a reply then exits 0.
local fake = vim.fn.tempname()
vim.fn.writefile({
  "#!/bin/sh",
  "printf 'Hello '",
  "printf 'from fm\\n'",
  "exit 0",
}, fake)
vim.fn.system({ "chmod", "+x", fake })

require("fm").setup({
  cmd = fake,
  instructions = "test",
  keymaps = {
    toggle = false,
    ask_selection = false,
  },
  window = {
    width = 40,
    height = 12,
    relative = "editor",
    input_height = 2,
  },
})

local fm = require("fm")
local ui = require("fm.ui")
local chat = require("fm.chat")

fm.open()
assert_true(ui.is_open(), "hover window should open")

local done = false
chat.ask("ping", {
  on_done = function(assistant, code)
    assert_true(code == 0, "exit code")
    assert_true(assistant.content:find("Hello"), "streamed content")
    done = true
  end,
  on_error = function(err)
    error("unexpected error: " .. err)
  end,
})

vim.wait(2000, function()
  return done
end, 20)

assert_true(done, "job should finish")
assert_true(ui.is_open(), "window still open after reply")
ui.render()

fm.clear()
assert_true(#chat.messages == 0, "cleared")

fm.close()
assert_true(not ui.is_open(), "window closed")

print("ui_spec: ok")
vim.cmd("qa!")

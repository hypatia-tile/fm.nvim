-- Run with: make test

local function assert_eq(actual, expected, msg)
  if not vim.deep_equal(actual, expected) then
    error(("%s: expected %s, got %s"):format(msg or "assertion failed", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local cli = require("fm.cli")

require("fm").setup({})
assert_eq(cli.build_args("hello"), { "fm", "respond", "--no-stream", "--", "hello" }, "default args")

require("fm").setup({ cmd = "/usr/bin/fm", instructions = "be brief" })
assert_eq(
  cli.build_args("-v hi"),
  { "/usr/bin/fm", "respond", "--no-stream", "--instructions", "be brief", "--", "-v hi" },
  "instructions, and a prompt starting with - stays the prompt"
)

print("cli_spec: ok")
vim.cmd("qa!")

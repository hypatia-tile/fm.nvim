-- Run with:
--   nvim --headless -u NONE \
--     -c "set rtp+=." \
--     -c "luafile tests/cli_spec.lua"

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. (": expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function assert_has(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return
    end
  end
  error("missing value in list: " .. vim.inspect(value) .. "\nlist=" .. vim.inspect(list), 2)
end

require("fm").setup({
  cmd = "fm",
  model = "system",
  instructions = "be brief",
  stream = true,
  greedy = true,
  use_case = "general",
})

local cli = require("fm.cli")
local args = cli.build_respond_args("hello", {
  resume = "/tmp/a.json",
  save_transcript = "/tmp/b.json",
  text = "context",
})

assert_eq(args[1], "fm")
assert_eq(args[2], "respond")
assert_has(args, "--model")
assert_has(args, "system")
assert_has(args, "--instructions")
assert_has(args, "be brief")
assert_has(args, "--text")
assert_has(args, "context")
assert_has(args, "--resume")
assert_has(args, "/tmp/a.json")
assert_has(args, "--save-transcript")
assert_has(args, "/tmp/b.json")
assert_has(args, "--stream")
assert_has(args, "--greedy")
assert_has(args, "--use-case")
assert_has(args, "general")
assert_eq(args[#args], "hello")

require("fm").setup({ stream = false, instructions = nil, greedy = false, use_case = nil })
args = cli.build_respond_args("hi", {})
assert_has(args, "--no-stream")
assert_eq(args[#args], "hi")

print("cli_spec: ok")
vim.cmd("qa!")

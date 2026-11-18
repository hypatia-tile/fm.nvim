-- Run with:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile tests/chat_spec.lua"

local function assert_true(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

-- Fake `fm` that prints a chunk, then keeps running until killed or done.
local fake = vim.fn.tempname()
vim.fn.writefile({
  "#!/bin/sh",
  "printf 'partial '",
  "sleep 0.3",
  "printf 'done\\n'",
  "exit 0",
}, fake)
vim.fn.system({ "chmod", "+x", fake })

require("fm").setup({
  cmd = fake,
  transcript_dir = vim.fn.tempname(),
  keymaps = { toggle = false, ask_selection = false },
})

local chat = require("fm.chat")

-- 1. Stopping a reply is not reported as an error.
local errors = {}
local function on_error(err)
  table.insert(errors, err)
end

assert_true(chat.ask("one", { on_error = on_error }), "first ask starts")
vim.wait(100)
chat.stop()
vim.wait(300) -- let the killed job's exit callback run

assert_true(#errors == 0, "stop must not call on_error: " .. vim.inspect(errors))
for _, msg in ipairs(chat.messages) do
  assert_true(msg.role ~= "error", "stop must not add an error message: " .. vim.inspect(chat.messages))
end

-- 2. A stopped job's late exit does not clobber the next request.
chat.clear()
assert_true(chat.ask("two", { on_error = on_error }), "second ask starts")
chat.stop()
local done_code
assert_true(chat.ask("three", {
  on_error = on_error,
  on_done = function(_, code)
    done_code = code
  end,
}), "third ask starts right after stop")
local third_job = chat.job_id

vim.wait(100) -- the stopped job's exit is processed here
assert_true(chat.is_busy(), "new request must still be busy")
assert_true(chat.job_id == third_job, "new request's job id must be kept")
assert_true(not chat.ask("four", { on_error = on_error }), "a concurrent request must be refused")

vim.wait(2000, function()
  return done_code ~= nil
end, 20)
assert_true(done_code == 0, "third request finishes normally")
assert_true(not chat.is_busy(), "not busy after finishing")
assert_true(#errors == 1 and errors[1]:find("already generating"), "only the refusal is an error: " .. vim.inspect(errors))

-- 3. clear() during a reply leaves the cleared conversation empty.
assert_true(chat.ask("five", {}), "fifth ask starts")
vim.wait(100)
chat.clear()
vim.wait(300)
assert_true(#chat.messages == 0, "cleared conversation stays empty: " .. vim.inspect(chat.messages))

print("chat_spec: ok")
vim.cmd("qa!")

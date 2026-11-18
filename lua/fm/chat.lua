local cli = require("fm.cli")
local config = require("fm.config")

---@class FmMessage
---@field role "user"|"assistant"|"system"|"error"
---@field content string

local M = {
  ---@type FmMessage[]
  messages = {},
  ---@type integer|nil
  job_id = nil,
  ---Token of the request in flight. Callbacks from any other request are stale.
  ---@type table|nil
  current = nil,
  ---@type string|nil
  transcript_path = nil,
  ---@type boolean
  busy = false,
}

local function ensure_transcript_dir()
  local dir = config.get().transcript_dir
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

---@return string
function M.transcript_file()
  if M.transcript_path then
    return M.transcript_path
  end
  local dir = ensure_transcript_dir()
  M.transcript_path = dir .. "/session-" .. tostring(vim.fn.getpid()) .. ".json"
  return M.transcript_path
end

function M.clear()
  M.stop()
  M.messages = {}
  local path = M.transcript_path or M.transcript_file()
  if path and vim.fn.filereadable(path) == 1 then
    pcall(vim.fn.delete, path)
  end
  M.transcript_path = nil
end

---@return boolean
function M.is_busy()
  return M.busy
end

function M.stop()
  -- Drop the token first so the killed job's exit (code 143) is ignored.
  M.current = nil
  if M.job_id then
    pcall(vim.fn.jobstop, M.job_id)
    M.job_id = nil
  end
  M.busy = false
end

---@param role FmMessage["role"]
---@param content string
---@return FmMessage
local function push(role, content)
  local msg = { role = role, content = content }
  table.insert(M.messages, msg)
  return msg
end

---@param msg FmMessage
---@param chunk string
local function append_content(msg, chunk)
  msg.content = msg.content .. chunk
end

---@class FmAskOpts
---@field text string|nil Extra context (--text)
---@field instructions string|nil Override instructions
---@field on_start fun(user: FmMessage, assistant: FmMessage)|nil
---@field on_delta fun(assistant: FmMessage, chunk: string)|nil
---@field on_done fun(assistant: FmMessage, code: integer)|nil
---@field on_error fun(err: string)|nil

---@param prompt string
---@param opts FmAskOpts|nil
---@return boolean started
function M.ask(prompt, opts)
  opts = opts or {}
  prompt = vim.trim(prompt or "")
  if prompt == "" then
    if opts.on_error then
      opts.on_error("Empty prompt")
    end
    return false
  end

  if M.busy then
    if opts.on_error then
      opts.on_error("fm is already generating a response")
    end
    return false
  end

  local ok, msg = cli.executable_ok()
  if not ok then
    if opts.on_error then
      opts.on_error(msg)
    end
    return false
  end

  local user = push("user", prompt)
  local assistant = push("assistant", "")

  local transcript = M.transcript_file()
  local resume = nil
  if vim.fn.filereadable(transcript) == 1 then
    resume = transcript
  end

  local req = {}
  M.current = req
  M.busy = true
  if opts.on_start then
    opts.on_start(user, assistant)
  end

  local stderr = {}

  local job_ok, job_or_err = pcall(cli.respond, prompt, {
    resume = resume,
    save_transcript = transcript,
    instructions = opts.instructions,
    text = opts.text,
  }, {
    on_stdout = function(chunk)
      vim.schedule(function()
        if M.current ~= req then
          return
        end
        append_content(assistant, chunk)
        if opts.on_delta then
          opts.on_delta(assistant, chunk)
        end
      end)
    end,
    on_stderr = function(chunk)
      if M.current ~= req then
        return
      end
      table.insert(stderr, chunk)
    end,
    on_exit = function(code, _)
      vim.schedule(function()
        if M.current ~= req then
          -- Stopped, cleared, or superseded: leave the newer state alone.
          return
        end
        M.current = nil
        M.job_id = nil
        M.busy = false
        if code ~= 0 then
          local err = vim.trim(table.concat(stderr, ""))
          if err == "" then
            err = ("fm exited with code %d"):format(code)
          end
          if assistant.content == "" then
            assistant.role = "error"
            assistant.content = err
          else
            push("error", err)
          end
          if opts.on_error then
            opts.on_error(err)
          end
        end
        if opts.on_done then
          opts.on_done(assistant, code)
        end
      end)
    end,
  })

  if not job_ok then
    M.current = nil
    M.busy = false
    assistant.role = "error"
    assistant.content = tostring(job_or_err)
    if opts.on_error then
      opts.on_error(tostring(job_or_err))
    end
    return false
  end

  M.job_id = job_or_err
  return true
end

return M

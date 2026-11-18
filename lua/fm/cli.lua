local config = require("fm.config")

local M = {}

---Turn Neovim jobstart stdout/stderr chunks into continuous text deltas.
---@param data string[]
---@param emit fun(chunk: string)
local function emit_chunks(data, emit)
  if not data or not emit then
    return
  end
  for i, piece in ipairs(data) do
    local is_last = i == #data
    -- jobstart appends an empty string sentinel at the end of each callback.
    if not (is_last and piece == "") then
      emit(piece .. (is_last and "" or "\n"))
    end
  end
end

---@param prompt string
---@param opts { resume?: string, save_transcript?: string, instructions?: string, text?: string }|nil
---@return string[]
function M.build_respond_args(prompt, opts)
  opts = opts or {}
  local cfg = config.get()
  local args = { cfg.cmd, "respond" }

  if cfg.model and cfg.model ~= "" then
    vim.list_extend(args, { "--model", cfg.model })
  end

  local instructions = opts.instructions or cfg.instructions
  if instructions and instructions ~= "" then
    vim.list_extend(args, { "--instructions", instructions })
  end

  if opts.text and opts.text ~= "" then
    vim.list_extend(args, { "--text", opts.text })
  end

  if opts.resume and opts.resume ~= "" then
    vim.list_extend(args, { "--resume", opts.resume })
  end

  if opts.save_transcript and opts.save_transcript ~= "" then
    vim.list_extend(args, { "--save-transcript", opts.save_transcript })
  end

  if cfg.stream then
    table.insert(args, "--stream")
  else
    table.insert(args, "--no-stream")
  end

  if cfg.greedy then
    table.insert(args, "--greedy")
  end

  if cfg.verbose then
    table.insert(args, "--verbose")
  end

  if cfg.use_case and cfg.use_case ~= "" then
    vim.list_extend(args, { "--use-case", cfg.use_case })
  end

  if cfg.guardrails and cfg.guardrails ~= "" then
    vim.list_extend(args, { "--guardrails", cfg.guardrails })
  end

  table.insert(args, prompt)
  return args
end

---@class FmJobCallbacks
---@field on_stdout fun(chunk: string)|nil
---@field on_stderr fun(chunk: string)|nil
---@field on_exit fun(code: integer, signal: integer)|nil

---@param args string[]
---@param callbacks FmJobCallbacks
---@return integer job_id
function M.start(args, callbacks)
  callbacks = callbacks or {}
  local cfg = config.get()

  ---@type table
  local opts = {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      emit_chunks(data, callbacks.on_stdout)
    end,
    on_stderr = function(_, data)
      emit_chunks(data, callbacks.on_stderr)
    end,
    on_exit = function(_, code, signal)
      if callbacks.on_exit then
        callbacks.on_exit(code, signal)
      end
    end,
  }

  if cfg.timeout and cfg.timeout > 0 then
    opts.timeout = cfg.timeout
  end

  local job_id = vim.fn.jobstart(args, opts)
  if job_id <= 0 then
    error(("fm.nvim: failed to start job for %q"):format(table.concat(args, " ")))
  end
  return job_id
end

---@param prompt string
---@param opts table|nil
---@param callbacks FmJobCallbacks
---@return integer job_id
function M.respond(prompt, opts, callbacks)
  return M.start(M.build_respond_args(prompt, opts or {}), callbacks)
end

---@return boolean ok
---@return string message
function M.executable_ok()
  local cfg = config.get()
  if vim.fn.executable(cfg.cmd) == 1 then
    return true, cfg.cmd
  end
  return false,
    ("`%s` not found in PATH (requires macOS 27+ with Apple Intelligence)"):format(cfg.cmd)
end

return M

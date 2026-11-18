local config = require("fm.config")

local M = {}

---Arguments for a one-off `fm respond` call.
---@param prompt string
---@return string[]
function M.build_args(prompt)
  local cfg = config.get()
  local args = { cfg.cmd, "respond", "--no-stream" }
  if cfg.instructions and cfg.instructions ~= "" then
    vim.list_extend(args, { "--instructions", cfg.instructions })
  end
  -- End of options, so a prompt starting with "-" is not read as a flag.
  table.insert(args, "--")
  table.insert(args, prompt)
  return args
end

---@param s string
---@return string
local function strip_ansi(s)
  return (s:gsub("\27%[[%d;]*m", ""))
end

---Run `fm respond` once. `on_done` runs on the main loop.
---@param prompt string
---@param on_done fun(ok: boolean, text: string)
---@return vim.SystemObj|nil job nil when fm could not be started
function M.run(prompt, on_done)
  local cfg = config.get()
  if vim.fn.executable(cfg.cmd) ~= 1 then
    on_done(false, ("`%s` not found in PATH (requires macOS 27+ with Apple Intelligence)"):format(cfg.cmd))
    return nil
  end

  -- vim.system() leaves stdin closed by default. fm reads its prompt from
  -- stdin when stdin is not a TTY, so an open pipe would make it wait.
  local ok, job = pcall(vim.system, M.build_args(prompt), { text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 then
        on_done(true, vim.trim(res.stdout or ""))
      else
        local err = vim.trim(strip_ansi(res.stderr or ""))
        if err == "" then
          err = ("fm exited with code %d"):format(res.code)
        end
        on_done(false, err)
      end
    end)
  end)
  if not ok then
    on_done(false, tostring(job))
    return nil
  end
  return job
end

return M

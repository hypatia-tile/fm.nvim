local cli = require("fm.cli")
local config = require("fm.config")

local M = {}

function M.check()
  vim.health.start("fm.nvim")

  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.error("Neovim 0.9+ is required")
  end

  local ok, msg = cli.executable_ok()
  if ok then
    vim.health.ok("Found fm executable: " .. msg)
  else
    vim.health.warn(msg, {
      "Install / enable Apple Intelligence on macOS 27+",
      "Agree to the license with: sudo fm license",
      "Or set require('fm').setup({ cmd = '/usr/bin/fm' })",
    })
  end

  local cfg = config.get()
  vim.health.info(("model=%s stream=%s"):format(cfg.model, tostring(cfg.stream)))

  local dir = cfg.transcript_dir
  if vim.fn.isdirectory(dir) == 1 or vim.fn.mkdir(dir, "p") == 1 then
    vim.health.ok("Transcript directory: " .. dir)
  else
    vim.health.warn("Cannot create transcript directory: " .. dir)
  end
end

return M

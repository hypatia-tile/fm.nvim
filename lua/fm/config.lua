---@class FmConfig
---@field cmd string Path or name of the fm executable
---@field instructions string|nil Instructions passed with --instructions
---@field keymaps { toggle: string|false } Global keymaps; false disables one

local M = {}

---@type FmConfig
M.defaults = {
  cmd = "fm",
  instructions = nil,
  keymaps = {
    toggle = "<leader>tf",
  },
}

---@type FmConfig
M.options = vim.deepcopy(M.defaults)

---@param opts FmConfig|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

---@return FmConfig
function M.get()
  return M.options
end

return M

---@class FmWindowConfig
---@field width number Width as a fraction of editor columns (0–1) or absolute columns
---@field height number Height as a fraction of editor lines (0–1) or absolute lines
---@field border string|string[] Border style
---@field title string Window title
---@field title_pos string Title position: "left"|"center"|"right"
---@field input_height integer Lines reserved for the prompt input
---@field relative string "editor"|"win"|"cursor"
---@field zindex integer

---@class FmKeymapsConfig
---@field toggle string|false
---@field send string|false
---@field close string|false
---@field clear string|false
---@field stop string|false
---@field ask_selection string|false

---@class FmConfig
---@field cmd string Path or name of the fm executable
---@field model string Model name: "system" or "pcc"
---@field instructions string|nil System instructions passed with -i
---@field stream boolean Stream tokens as they are generated
---@field greedy boolean Use greedy sampling
---@field verbose boolean Pass --verbose to fm
---@field use_case string|nil "general" or "content-tagging"
---@field guardrails string|nil "default" or "permissive-content-transformations"
---@field transcript_dir string Directory for session transcript files
---@field timeout integer Job timeout in milliseconds (0 = no timeout)
---@field window FmWindowConfig
---@field keymaps FmKeymapsConfig
---@field highlights table<string, string>

local M = {}

---@type FmConfig
M.defaults = {
  cmd = "fm",
  model = "system",
  instructions = "You are a helpful coding assistant inside Neovim. Be concise and practical.",
  stream = true,
  greedy = false,
  verbose = false,
  use_case = nil,
  guardrails = nil,
  transcript_dir = vim.fn.stdpath("cache") .. "/fm.nvim",
  timeout = 0,
  window = {
    width = 0.6,
    height = 0.5,
    border = "rounded",
    title = " fm ",
    title_pos = "center",
    input_height = 3,
    relative = "editor",
    zindex = 50,
  },
  keymaps = {
    toggle = "<leader>fm",
    send = "<CR>",
    close = "q",
    clear = "<C-l>",
    stop = "<C-c>",
    ask_selection = "<leader>fa",
  },
  highlights = {
    user = "FmUser",
    assistant = "FmAssistant",
    system = "FmSystem",
    border = "FloatBorder",
    title = "FloatTitle",
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

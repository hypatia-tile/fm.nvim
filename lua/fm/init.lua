local cli = require("fm.cli")
local config = require("fm.config")
local ui = require("fm.ui")

local M = {}

---The request in flight: `{ job = vim.SystemObj|nil }`. Results from any
---other request are stale and dropped.
---@type table|nil
local current = nil

local function cancel()
  local req = current
  current = nil
  if req and req.job then
    pcall(req.job.kill, req.job, 15)
  end
end

---@param opts FmConfig|nil
function M.setup(opts)
  config.setup(opts)
end

---@param prompt string
---@return string[]
local function prompt_header(prompt)
  local lines = {}
  for _, line in ipairs(vim.split(prompt, "\n", { plain = true })) do
    table.insert(lines, "> " .. line)
  end
  table.insert(lines, "")
  return lines
end

---Send `prompt` to fm once and show the answer in a floating window.
---A new request replaces one still running.
---@param prompt string|nil
function M.ask(prompt)
  prompt = vim.trim(prompt or "")
  if prompt == "" then
    vim.notify("fm.nvim: empty prompt", vim.log.levels.WARN)
    return
  end

  cancel()
  local req = {}
  current = req

  local header = prompt_header(prompt)
  ui.show_result(vim.list_extend(vim.deepcopy(header), { "…" }), {
    title = " fm (thinking) ",
    -- Closing the window while fm is still working cancels it.
    on_close = function()
      if current == req then
        cancel()
      end
    end,
  })

  req.job = cli.run(prompt, function(ok, text)
    if current ~= req then
      return
    end
    current = nil
    local body = vim.split(text, "\n", { plain = true })
    ui.show_result(vim.list_extend(vim.deepcopy(header), body), {
      title = ok and " fm " or " fm: error ",
    })
  end)
end

---Open the prompt window; the prompt is sent with <CR>.
function M.prompt()
  ui.open_prompt(M.ask)
end

return M

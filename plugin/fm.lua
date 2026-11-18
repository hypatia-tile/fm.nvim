if vim.g.loaded_fm_nvim then
  return
end
vim.g.loaded_fm_nvim = true

local function with_fm(fn)
  return function(opts)
    local ok, fm = pcall(require, "fm")
    if not ok then
      vim.notify("fm.nvim: " .. tostring(fm), vim.log.levels.ERROR)
      return
    end
    fn(fm, opts)
  end
end

vim.api.nvim_create_user_command(
  "Fm",
  with_fm(function(fm, opts)
    if opts.args and opts.args ~= "" then
      fm.ask(opts.args)
    else
      fm.toggle()
    end
  end),
  {
    nargs = "*",
    desc = "Toggle fm hover chat, or ask with :Fm {prompt}",
  }
)

vim.api.nvim_create_user_command(
  "FmAsk",
  with_fm(function(fm, opts)
    fm.ask(opts.args)
  end),
  {
    nargs = "+",
    desc = "Ask fm a prompt in the hover window",
  }
)

vim.api.nvim_create_user_command(
  "FmAskSelection",
  with_fm(function(fm, opts)
    fm.ask_selection(opts.args, { line1 = opts.line1, line2 = opts.line2 })
  end),
  {
    nargs = "*",
    range = true,
    desc = "Ask fm about the visual selection (or last selection)",
  }
)

vim.api.nvim_create_user_command(
  "FmClear",
  with_fm(function(fm)
    fm.clear()
  end),
  { desc = "Clear the fm conversation and transcript" }
)

vim.api.nvim_create_user_command(
  "FmStop",
  with_fm(function(fm)
    fm.stop()
  end),
  { desc = "Stop the current fm generation" }
)

vim.api.nvim_create_user_command(
  "FmClose",
  with_fm(function(fm)
    fm.close()
  end),
  { desc = "Close the fm hover window" }
)

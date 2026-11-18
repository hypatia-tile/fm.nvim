if vim.g.loaded_fm_nvim then
  return
end
vim.g.loaded_fm_nvim = true

vim.api.nvim_create_user_command("Fm", function(opts)
  local fm = require("fm")
  if opts.args ~= "" then
    fm.ask(opts.args)
  else
    fm.prompt()
  end
end, {
  nargs = "*",
  desc = "Open the fm prompt window, or ask directly with :Fm {prompt}",
})

if vim.fn.has("nvim-0.12") == 0 then
  error("nvim-new requires Neovim 0.12.0 or newer")
end

vim.loader.enable()

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.tmux_navigator_no_mappings = 1

require("config.options")
require("config.rust")
require("config.pack")
require("config.lsp")
require("config.keymaps")

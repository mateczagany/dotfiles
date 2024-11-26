-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>pv", ":Ex<cr>")

-- Move lines in visual mode, auto-indent
vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv")

-- Keep sreen centered
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Use this to not replace register when pasting in visual mode
vim.keymap.set("x", "<leader>p", '"_dP')

-- Same with delete
vim.keymap.set("n", "<leader>d", '"_d')
vim.keymap.set("v", "<leader>d", '"_d')

-- Use this to yank into OS clipboard
vim.keymap.set("n", "<leader>y", '"+y')
vim.keymap.set("v", "<leader>y", '"+y')
vim.keymap.set("n", "<leader>Y", '"+Y')

vim.keymap.set("n", "Q", "<nop>")

-- Buffer movements
vim.keymap.set("n", "<leader>bb", ":bprevious<cr>")
vim.keymap.set("n", "<leader>bn", ":bnext<cr>")

-- Git
vim.keymap.set("n", "<leader>gs", vim.cmd.Git)

-- Disable LazyVim binding
vim.keymap.del("n", "<leader>l")

-- FZF
local fzf = require("fzf-lua")
fzf.setup({})
-- Find
vim.keymap.set('n', '<leader>ff', fzf.files, {})
vim.keymap.set('n', '<leader>fb', fzf.buffers, {})
vim.keymap.set('n', '<leader>fh', fzf.oldfiles, {})
vim.keymap.set('n', '<leader>fq', fzf.quickfix, {})
vim.keymap.set('n', '<leader>ft', fzf.live_grep_native, {})
vim.keymap.set('n', '<leader>a', fzf.live_grep_native, {})
vim.keymap.set('n', '<leader>?', fzf.commands, {})
vim.keymap.set('n', '<leader>fg', fzf.git_files, {})
vim.keymap.set('n', '<leader>fc', fzf.git_commits, {})
-- LSP
vim.keymap.set('n', 'gr', fzf.lsp_references, {})
vim.keymap.set('n', 'gi', fzf.lsp_implementations, {})
vim.keymap.set('n', '<leader>la', fzf.lsp_code_actions, {})
vim.keymap.set('n', '<leader>ls', fzf.lsp_live_workspace_symbols, {})

local zen = require("zen-mode")
vim.keymap.set('n', '<leader>z', zen.toggle, {})

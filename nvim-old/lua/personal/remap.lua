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
vim.keymap.set("x", "<leader>p", "\"_dP")

-- Same with delete
vim.keymap.set("n", "<leader>d", "\"_d")
vim.keymap.set("v", "<leader>d", "\"_d")

-- Use this to yank into OS clipboard
vim.keymap.set("n", "<leader>y", "\"+y")
vim.keymap.set("v", "<leader>y", "\"+y")
vim.keymap.set("n", "<leader>Y", "\"+Y")

vim.keymap.set("n", "Q", "<nop>")

-- Buffer movements
vim.keymap.set("n", "<leader>bb", ":bprevious<cr>")
vim.keymap.set("n", "<leader>bn", ":bnext<cr>")

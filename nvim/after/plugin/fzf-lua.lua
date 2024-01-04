local fzf = require("fzf-lua")
fzf.setup({})

-- Find

vim.keymap.set('n', '<leader>ff', fzf.files, {})
vim.keymap.set('n', '<leader>fb', fzf.buffers, {})
vim.keymap.set('n', '<leader>fh', fzf.oldfiles, {})
vim.keymap.set('n', '<leader>fq', fzf.quickfix, {})
vim.keymap.set('n', '<leader>ft', fzf.grep_visual, {})
vim.keymap.set('n', '<leader>a', fzf.grep_visual, {})
vim.keymap.set('n', '<leader>?', fzf.commands, {})
vim.keymap.set('n', '<leader>fg', fzf.git_files, {})
vim.keymap.set('n', '<leader>fc', fzf.git_commits, {})

-- LSP

vim.keymap.set('n', 'gr', fzf.lsp_references, {})
vim.keymap.set('n', 'gi', fzf.lsp_implementations, {})
vim.keymap.set('n', '<leader>la', fzf.lsp_code_actions, {})
vim.keymap.set('n', '<leader>ls', fzf.lsp_live_workspace_symbols, {})

require('neotest').setup {
    adapters = {
        require('rustaceanvim.neotest')
    }
}


vim.keymap.set('n', '<leader>tt', '<cmd>lua require("neotest").run.run(vim.fn.expand("%"))<cr>')
vim.keymap.set('n', '<leader>tr', '<cmd>Neotest output<cr>')

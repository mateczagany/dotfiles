return {
    "neovim/nvim-lspconfig",
    opts = {
        servers = {
            ['*'] = {
                keys = {
                    { "K", "<cmd>lua vim.lsp.buf.hover()<cr>" },
                    { "gd", "<cmd>lua vim.lsp.buf.definition()<cr>" },
                    { "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>" },
                    { "gi", "<cmd>lua vim.lsp.buf.implementation()<cr>" },
                    { "go", "<cmd>lua vim.lsp.buf.type_definition()<cr>" },
                    { "gr", "<cmd>lua vim.lsp.buf.references()<cr>" },
                    { "gs", "<cmd>lua vim.lsp.buf.signature_help()<cr>" },
                    { "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>" },
                    { "<leader>lf", "<cmd>lua vim.lsp.buf.format({async = true},)<cr>" },
                    { "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>" },
                    { "gl", "<cmd>lua vim.diagnostic.open_float()<cr>" },
                    { "<leader>lk", "<cmd>lua vim.diagnostic.goto_prev()<cr>" },
                    { "<leader>lj", "<cmd>lua vim.diagnostic.goto_next()<cr>" }
                }
            }
        }
    }
}

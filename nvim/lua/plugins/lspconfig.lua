return {
    "neovim/nvim-lspconfig",
    opts = function()
        local keys = require("lazyvim.plugins.lsp.keymaps").get()

        keys[#keys + 1] = { "K", "<cmd>lua vim.lsp.buf.hover()<cr>" }
        keys[#keys + 1] = { "gd", "<cmd>lua vim.lsp.buf.definition()<cr>" }
        keys[#keys + 1] = { "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>" }
        keys[#keys + 1] = { "gi", "<cmd>lua vim.lsp.buf.implementation()<cr>" }
        keys[#keys + 1] = { "go", "<cmd>lua vim.lsp.buf.type_definition()<cr>" }
        keys[#keys + 1] = { "gr", "<cmd>lua vim.lsp.buf.references()<cr>" }
        keys[#keys + 1] = { "gs", "<cmd>lua vim.lsp.buf.signature_help()<cr>" }
        keys[#keys + 1] = { "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>" }
        keys[#keys + 1] = { "<leader>lf", "<cmd>lua vim.lsp.buf.format({async = true})<cr>" }
        keys[#keys + 1] = { "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>" }

        keys[#keys + 1] = { "gl", "<cmd>lua vim.diagnostic.open_float()<cr>" }
        keys[#keys + 1] = { "<leader>lk", "<cmd>lua vim.diagnostic.goto_prev()<cr>" }
        keys[#keys + 1] = { "<leader>lj", "<cmd>lua vim.diagnostic.goto_next()<cr>" }
    end,
}

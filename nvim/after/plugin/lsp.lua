local lsp = require('lsp-zero')

local lsp_attach = function(client, bufnr)
    local opts = { buffer = bufnr }

    vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
    vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
    vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
    -- vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
    vim.keymap.set('n', 'go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
    -- vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
    -- vim.keymap.set('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
    vim.keymap.set('n', '<leader>lr', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
    vim.keymap.set('n', '<leader>lf', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
    -- vim.keymap.set('n', '<leader>la', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)

    vim.keymap.set('n', 'gl', '<cmd>lua vim.diagnostic.open_float()<cr>', opts)
    vim.keymap.set('n', '<leader>lk', '<cmd>lua vim.diagnostic.goto_prev()<cr>', opts)
    vim.keymap.set('n', '<leader>lj', '<cmd>lua vim.diagnostic.goto_next()<cr>', opts)
end


lsp.extend_lspconfig({
    capabilities = require('cmp_nvim_lsp').default_capabilities(),
    lsp_attach = lsp_attach,
    float_border = 'rounded',
    sign_text = true,
})

require('mason').setup({})
require('mason-lspconfig').setup {
    ensure_installed = vim.tbl_keys({
        rust_analyzer = {},
        gopls = {},
        pyright = {},
        lua_ls = {
            Lua = {
                workspace = { checkThirdParty = false },
                telemetry = { enable = false },
            },
        },
        jdtls = {}
    }),
    handlers = {
        -- this first function is the "default handler"
        -- it applies to every language server without a "custom handler"
        function(server_name)
            require('lspconfig')[server_name].setup({})
        end,

        -- this is the "custom handler" for `lua_ls`
        lua_ls = function()
            require('lspconfig').lua_ls.setup({
                on_init = function(client)
                    lsp.nvim_lua_settings(client, {})
                end,
            })
        end,

        jdtls = lsp.noop
    },
}

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    pattern = { "*.java" },
    callback = function()
        local _, _ = pcall(vim.lsp.codelens.refresh)
    end,
})

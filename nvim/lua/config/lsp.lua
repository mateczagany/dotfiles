local lsp_group = vim.api.nvim_create_augroup("NvimNewLsp", { clear = true })

vim.diagnostic.config({
  severity_sort = true,
  float = { border = "rounded" },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))

    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
    end

    map("K", vim.lsp.buf.hover, "Hover")
    map("gd", vim.lsp.buf.definition, "Goto Definition")
    map("gD", vim.lsp.buf.declaration, "Goto Declaration")
    map("go", vim.lsp.buf.type_definition, "Goto Type Definition")
    map("gs", vim.lsp.buf.signature_help, "Signature Help")
    map("gl", vim.diagnostic.open_float, "Line Diagnostics")
    map("<leader>lr", vim.lsp.buf.rename, "Rename")
    map("<leader>lf", function()
      vim.lsp.buf.format({ async = true })
    end, "Format")
    map("<leader>la", vim.lsp.buf.code_action, "Code Action")
    map("<leader>lk", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, "Prev Diagnostic")
    map("<leader>lj", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, "Next Diagnostic")

    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})

if vim.fn.executable("helm_ls") == 1 then
  vim.lsp.enable("helm_ls")
else
  vim.api.nvim_create_autocmd("FileType", {
    group = lsp_group,
    pattern = { "helm", "yaml.helm-values" },
    once = true,
    callback = function()
      vim.notify(
        "helm_ls not found in PATH.\nhttps://github.com/mrjosh/helm-ls",
        vim.log.levels.WARN,
        { title = "nvim-lspconfig" }
      )
    end,
  })
end

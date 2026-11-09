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
    map("gh", vim.diagnostic.open_float, "Line Diagnostics")
    map("<leader>lr", vim.lsp.buf.rename, "Rename")
    map("<leader>lf", function()
      local ok, conform = pcall(require, "conform")
      if ok then
        conform.format({ async = true, lsp_format = "fallback" })
      else
        vim.lsp.buf.format({ async = true })
      end
    end, "Format")
    map("<leader>la", vim.lsp.buf.code_action, "Code Action")
    map("<leader>lk", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, "Prev Diagnostic")
    map("<leader>lj", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, "Next Diagnostic")

    local snacks = require("snacks")
    map("gr", function() snacks.picker.lsp_references() end, "References")
    map("gi", function() snacks.picker.lsp_implementations() end, "Implementations")
    map("<leader>ls", function() snacks.picker.lsp_workspace_symbols() end, "Workspace Symbols")

    pcall(vim.keymap.del, "n", "grr", { buffer = ev.buf })
    pcall(vim.keymap.del, "n", "gri", { buffer = ev.buf })
    pcall(vim.keymap.del, "n", "gra", { buffer = ev.buf })
    pcall(vim.keymap.del, "n", "grn", { buffer = ev.buf })

    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})

if vim.fn.executable("typescript-language-server") == 1 then
  vim.lsp.enable("ts_ls")
else
  vim.api.nvim_create_autocmd("FileType", {
    group = lsp_group,
    pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    once = true,
    callback = function()
      vim.notify(
        "typescript-language-server not found in PATH.\nnpm i -g typescript-language-server typescript",
        vim.log.levels.WARN,
        { title = "nvim-lspconfig" }
      )
    end,
  })
end

if vim.fn.executable("vscode-eslint-language-server") == 1 then
  vim.lsp.enable("eslint")
else
  vim.api.nvim_create_autocmd("FileType", {
    group = lsp_group,
    pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    once = true,
    callback = function()
      vim.notify(
        "vscode-eslint-language-server not found in PATH.\nnpm i -g vscode-langservers-extracted",
        vim.log.levels.WARN,
        { title = "nvim-lspconfig" }
      )
    end,
  })
end

if vim.fn.executable("tailwindcss-language-server") == 1 then
  vim.lsp.enable("tailwindcss")
else
  vim.api.nvim_create_autocmd("FileType", {
    group = lsp_group,
    pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact", "html", "css" },
    once = true,
    callback = function()
      vim.notify(
        "tailwindcss-language-server not found in PATH.\nnpm i -g @tailwindcss/language-server",
        vim.log.levels.WARN,
        { title = "nvim-lspconfig" }
      )
    end,
  })
end

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

if vim.fn.executable("zls") == 1 then
  vim.lsp.enable("zls")
else
  vim.api.nvim_create_autocmd("FileType", {
    group = lsp_group,
    pattern = "zig",
    once = true,
    callback = function()
      vim.notify(
        "zls not found in PATH.\nbrew install zig zls",
        vim.log.levels.WARN,
        { title = "nvim-lspconfig" }
      )
    end,
  })
end

local sqrl_repo = vim.fn.expand("~/dev/datasqrl/sqrl")
vim.opt.runtimepath:append(sqrl_repo .. "/sqrl-nvim-plugin")
require("sqrl").setup({ jar = sqrl_repo .. "/sqrl-cli/target/sqrl-cli.jar" })

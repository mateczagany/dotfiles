local rust_group = vim.api.nvim_create_augroup("NvimNewRust", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = rust_group,
  pattern = "rust",
  once = true,
  callback = function()
    if vim.fn.executable("rust-analyzer") == 0 then
      vim.notify(
        "rust-analyzer not found in PATH.\nhttps://rust-analyzer.github.io/",
        vim.log.levels.WARN,
        { title = "rustaceanvim" }
      )
    end
  end,
})

vim.g.rustaceanvim = {
  server = {
    on_attach = function(_, bufnr)
      vim.keymap.set("n", "<leader>cR", function()
        vim.cmd.RustLsp("codeAction")
      end, { buffer = bufnr, desc = "Rust Code Action" })
    end,
    default_settings = {
      ["rust-analyzer"] = {
        diagnostics = {
          enable = true,
          disabled = {
            "unresolved-macro-call",
            "unresolved-proc-macro",
          },
        },
        checkOnSave = {
          allFeatures = true,
          command = "clippy",
          extraArgs = { "--no-deps" },
        },
        cargo = {
          allFeatures = true,
          loadOutDirsFromCheck = true,
          buildScripts = {
            enable = true,
          },
        },
        procMacro = {
          enable = true,
          ignored = {
            ["async-recursion"] = { "async_recursion" },
            ["napi-derive"] = { "napi" },
          },
        },
        files = {
          excludeDirs = {
            ".direnv",
            ".git",
            ".github",
            ".gitlab",
            "bin",
            "node_modules",
            "target",
            "venv",
            ".venv",
          },
          watcher = "client",
        },
      },
    },
  },
}

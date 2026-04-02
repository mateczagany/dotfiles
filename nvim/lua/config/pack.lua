local pack_group = vim.api.nvim_create_augroup("NvimNewPackHooks", { clear = true })
local treesitter_languages = {
  "bash",
  "helm",
  "html",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "regex",
  "ron",
  "rust",
  "vim",
  "yaml",
}

vim.api.nvim_create_autocmd("PackChanged", {
  group = pack_group,
  callback = function(ev)
    local spec = ev.data.spec
    local kind = ev.data.kind

    if spec.name == "nvim-treesitter" and (kind == "install" or kind == "update") then
      if not ev.data.active then
        vim.cmd.packadd(spec.name)
      end

      vim.cmd("TSUpdate")
    end
  end,
})

vim.pack.add({
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
  "https://github.com/folke/snacks.nvim",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/max397574/better-escape.nvim",
  "https://github.com/christoomey/vim-tmux-navigator",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/neovim/nvim-lspconfig",
  { src = "https://github.com/mrcjkb/rustaceanvim", version = vim.version.range("8.x") },
  "https://github.com/qvalentin/helm-ls.nvim",
}, { confirm = false })

require("catppuccin").setup({
  integrations = {
    treesitter = true,
    native_lsp = {
      enabled = true,
      underlines = {
        errors = { "undercurl" },
        hints = { "undercurl" },
        information = { "undercurl" },
        warnings = { "undercurl" },
      },
    },
  },
})

vim.cmd.colorscheme("catppuccin-mocha")

require("better_escape").setup()
require("snacks").setup({
  picker = {},
})
require("which-key").setup({
  preset = "classic",
})
require("which-key").add({
  { "<leader>b", group = "buffers" },
  { "<leader>d", group = "delete" },
  { "<leader>f", group = "find" },
  { "<leader>l", group = "lsp" },
  { "<leader>p", group = "paste" },
  { "<leader>y", group = "yank" },
})

require("nvim-treesitter").setup({})

do
  local installed = require("nvim-treesitter.config").get_installed()
  local missing = vim.tbl_filter(function(lang)
    return not vim.list_contains(installed, lang)
  end, treesitter_languages)

  if vim.fn.executable("tree-sitter") == 1 and #missing > 0 then
    require("nvim-treesitter").install(missing):wait(300000)
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("NvimNewTreesitter", { clear = true }),
  callback = function(args)
    local filetype = vim.bo[args.buf].filetype
    local lang = vim.treesitter.language.get_lang(filetype) or filetype
    local installed = require("nvim-treesitter.config").get_installed()

    if vim.list_contains(installed, lang) then
      pcall(vim.treesitter.start, args.buf, lang)
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

require("helm-ls").setup({
  conceal_templates = { enabled = false },
  indent_hints = { enabled = false },
  action_highlight = { enabled = false },
})

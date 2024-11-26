local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out,                            "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        -- add LazyVim and import its plugins
        {
            "LazyVim/LazyVim",
            import = "lazyvim.plugins",
            opts = {
                colorscheme = "catppuccin",
            },
        },
        -- Disable snacks dashboard
        { "folke/snacks.nvim", opts = { dashboard = { enabled = false } } },
        -- import/override with your plugins
        { import = "lazyvim.plugins.extras.lang.rust" },
        { import = "lazyvim.plugins.extras.lang.helm" },
        { import = "lazyvim.plugins.extras.lang.java" },
        { import = "lazyvim.plugins.extras.dap.core" },
        { import = "lazyvim.plugins.extras.editor.harpoon2" },
        {
            import = "lazyvim.plugins.extras.test.core",
            opts = {
                adatapters = { ["rustaceanvim.neotest"] = {} },
                ft = { "rs" },
                keys = {
                    { "<leader>t",  "",                                                                                 desc = "+test" },
                    { "<leader>tt", function() require("neotest").run.run(vim.fn.expand("%")) end,                      desc = "Run File" },
                    { "<leader>tT", function() require("neotest").run.run(vim.uv.cwd()) end,                            desc = "Run All Test Files" },
                    { "<leader>tr", function() require("neotest").run.run() end,                                        desc = "Run Nearest" },
                    -- { "<leader>tl", function() require("neotest").run.run_last() end,                                   desc = "Run Last" },
                    { "<leader>ts", function() require("neotest").summary.toggle() end,                                 desc = "Toggle Summary" },
                    { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show Output" },
                    { "<leader>tO", function() require("neotest").output_panel.toggle() end,                            desc = "Toggle Output Panel" },
                    { "<leader>tS", function() require("neotest").run.stop() end,                                       desc = "Stop" },
                    -- { "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end,                 desc = "Toggle Watch" },
                },
            }
        },
        { import = "plugins" },
    },
    defaults = {
        -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
        -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
        lazy = false,
        -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
        -- have outdated releases, which may break your Neovim install.
        version = false, -- always use the latest git commit
        -- version = "*", -- try installing the latest stable version for plugins that support semver
    },
    -- install = { colorscheme = { "tokyonight", "habamax" } },
    install = { colorscheme = { "catppuccin" } },
    checker = {
        enabled = true, -- check for plugin updates periodically
        notify = false, -- notify on update
    },                  -- automatically check for plugin updates
    performance = {
        rtp = {
            -- disable some rtp plugins
            disabled_plugins = {
                "gzip",
                -- "matchit",
                -- "matchparen",
                -- "netrwPlugin",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
})

return {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    opts = {
        modes = {
            lsp = {
                win = { position = "right", size = 0.4 },
            },
            symbols = {
                win = { position = "right", size = 0.4 },
            },
            diagnostics = {
                win = { position = "bottom", size = 0.4 },
            },
        },
    }
}

return {
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" },
    -- stylua: ignore
    keys = {
        { "<leader>du", function() require("dapui").toggle({}) end,      desc = "Dap UI" },
        { "<leader>de", function() require("dapui").eval() end,          desc = "Eval",             mode = { "n", "v" } },
        { "<leader>df", function() require("dapui").float_element() end, desc = "Dap Float Element" },
    },
    opts = {
        layouts = { {
            elements = { {
                id = "console",
                size = 1.0
            } },
            position = "bottom",
            size = 20
        }, {
            elements = { {
                id = "scopes",
                size = 0.50
            }, {
                id = "stacks",
                size = 0.50
            } },
            position = "left",
            size = 40
        } }
    },
    config = function(_, opts)
        local dap = require("dap")
        local dapui = require("dapui")
        dapui.setup(opts)
        dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open({})
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close({})
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close({})
        end
    end,
}

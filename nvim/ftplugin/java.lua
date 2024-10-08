-- vim.list_extend(vim.lsp.automatic_configuration.skipped_servers, { "jdtls" })
local status, jdtls = pcall(require, "jdtls")
if not status then
    return
end

local home = os.getenv "HOME"
local workspace_path = home .. "/.local/share/nvim/jdtls-workspace/"
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = workspace_path .. project_name

local os_config = "linux"
if vim.fn.has "mac" == 1 then
    os_config = "mac"
end

local extendedClientCapabilities = jdtls.extendedClientCapabilities
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true
extendedClientCapabilities.advancedOrganizeImportsSupport = true

-- vim.builtin.dap.active = true
local bundles = {}
local mason_path = vim.fn.glob(vim.fn.stdpath 'data' .. '/mason/')
vim.list_extend(bundles, vim.split(vim.fn.glob(mason_path .. 'packages/java-test/extension/server/*.jar'), '\n'))
vim.list_extend(
    bundles,
    vim.split(
        vim.fn.glob(mason_path .. 'packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar'),
        '\n'
    )
)

-- See `:help vim.lsp.start_client` for an overview of the supported `config` options.
local config = {
    -- The command that starts the language server
    -- See: https://github.com/eclipse/eclipse.jdt.ls#running-from-the-command-line
    cmd = {

        -- 💀
        '/usr/bin/java', -- or '/path/to/java17_or_newer/bin/java'
        -- depends on if `java` is in your $PATH env variable and if it points to the right version.

        '-Declipse.application=org.eclipse.jdt.ls.core.id1',
        '-Dosgi.bundles.defaultStartLevel=4',
        '-Declipse.product=org.eclipse.jdt.ls.core.product',
        '-Dlog.protocol=true',
        '-Dlog.level=ALL',
        '-Xmx1g',
        '--add-modules=ALL-SYSTEM',
        '--add-opens', 'java.base/java.util=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
        '-javaagent:' .. home .. '/.local/share/nvim/mason/packages/jdtls/lombok.jar',
        '-jar',
        vim.fn.glob(home .. '/.local/share/nvim/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar'),
        '-configuration',
        home .. '/.local/share/nvim/mason/packages/jdtls/config_' .. os_config,
        '-data',
        workspace_dir, },

    -- 💀
    -- This is the default if not provided, you can remove it. Or adjust as needed.
    -- One dedicated LSP server & client will be started per unique root_dir
    --
    -- vim.fs.root requires Neovim 0.10.
    -- If you're using an earlier version, use: require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew'}),
    root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew" }),

    -- Here you can configure eclipse.jdt.ls specific settings
    -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
    -- for a list of options
    settings = {
        java = {
            eclipse = {
                downloadSources = true,
            },
            configuration = {
                updateBuildConfiguration = 'interactive',
                runtimes = {
                    {
                        name = 'JavaSE-11',
                        path = '~/Library/Java/JavaVirtualMachines/temurin-11.0.23/Contents/Home',
                    },
                    {
                        name = 'JavaSE-17',
                        path = '~/Library/Java/JavaVirtualMachines/temurin-17.0.11/Contents/Home',
                    },
                },
            },
            maven = {
                downloadSources = true,
            },
            referencesCodeLens = {
                enabled = true,
            },
            references = {
                includeDecompiledSources = true,
            },
            inlayHints = {
                parameterNames = {
                    enabled = 'all', -- literals, all, none
                },
            },
            format = {
                enabled = false,
            },
        },
        signatureHelp = { enabled = true },
        extendedClientCapabilities = extendedClientCapabilities
    },

    -- Language server `initializationOptions`
    -- You need to extend the `bundles` with paths to jar files
    -- if you want to use additional eclipse.jdt.ls plugins.
    --
    -- See https://github.com/mfussenegger/nvim-jdtls#java-debug-installation
    --
    -- If you don't plan on using the debugger or other eclipse.jdt.ls plugins you can remove this
    init_options = {
        bundles = bundles
    },
}

config["on_attach"] = function(client, bufnr)
    local _, _ = pcall(vim.lsp.codelens.refresh)
    require("jdtls").setup_dap({ hotcodereplace = "auto" })
    -- require("lvim.lsp").on_attach(client, bufnr)
    local status_ok, jdtls_dap = pcall(require, "jdtls.dap")
    if status_ok then
        jdtls_dap.setup_dap_main_class_configs()
    end
end

require('jdtls').start_or_attach(config)



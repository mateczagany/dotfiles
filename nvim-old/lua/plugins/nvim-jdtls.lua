return {
    "mfussenegger/nvim-jdtls",
    lazy = true,
    opts = {
        settings = {
            java = {
                configuration = {
                    runtimes = {
                        {
                            name = "JavaSE-11",
                            path = "~/Library/Java/JavaVirtualMachines/temurin-11.0.23/Contents/Home"
                        },
                        {
                            name = "JavaSE-17",
                            path = "~/Library/Java/JavaVirtualMachines/temurin-17.0.11/Contents/Home"
                        }
                    }
                }
            }
        }
    }
}

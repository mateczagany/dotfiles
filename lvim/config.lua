-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

lvim.plugins = {
  { "ggandor/lightspeed.nvim" }
}

vim.opt.relativenumber = true
vim.opt.showtabline = 0

lvim.keys.normal_mode["S"] = "<Plug>Lightspeed_S"
lvim.keys.normal_mode["<Tab>"] = ":bnext<cr>"
lvim.keys.normal_mode["<S-Tab>"] = ":bprev<cr>"

vim.cmd("nnoremap <C-u> <C-u>zz")
vim.cmd("nnoremap <C-d> <C-d>zz")

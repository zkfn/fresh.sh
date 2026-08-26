vim.wo[0][0].wrap = true
vim.wo[0][0].linebreak = true
vim.bo.textwidth = 80

local opts = { buffer = true, silent = true }
vim.keymap.set("n", "j", "gj", opts)
vim.keymap.set("n", "k", "gk", opts)

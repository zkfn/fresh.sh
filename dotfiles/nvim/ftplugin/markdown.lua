vim.wo.wrap = true
vim.wo.linebreak = true
vim.bo.textwidth = 80

local opts = { buffer = true, silent = true }
vim.keymap.set("n", "j", "gj", opts)
vim.keymap.set("n", "k", "gk", opts)

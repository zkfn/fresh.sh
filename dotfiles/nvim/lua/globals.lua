-- Line numbering
vim.o.number = true
vim.o.relativenumber = true

-- Disable line breaks
vim.o.wrap = false

-- Tabs are inserted as 4 spaces, to insert actual tab (8 spaces wide), use
-- the keymap CTRL-V <Tab> in insert mode.
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4

-- Dont hide buffers when last window is closed
vim.o.hidden = true

-- Set the leader ey
vim.g.mapleader = " "

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes:1"

-- Default colorscheme in case the plugins fail
vim.o.termguicolors = true
vim.o.background = "dark"

vim.cmd("colorscheme habamax")

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

-- Set the leader
vim.g.mapleader = " "

-- pass mouse events (incl. wheel) through to :terminal buffer apps
vim.opt.mouse = "a"

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes:1"

-- Default colorscheme in case the plugins fail
vim.o.termguicolors = true
vim.o.background = "dark"

vim.cmd("colorscheme habamax")

-- Source a repo's own `.nvim.lua` (prompts once per file via :h trust). Lets a
-- repo switch servers and formatters off for itself:
--   vim.g.lsp_off = { "tailwindcss" }
--   vim.g.js_formatter = "prettier"
vim.o.exrc = true

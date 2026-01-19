vim.pack.add({
  "https://github.com/folke/which-key.nvim",
  "https://github.com/folke/snacks.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",

  -- Looks!
  "https://github.com/sainnhe/gruvbox-material",
  "https://github.com/nvim-tree/nvim-web-devicons",

  -- Session management
  "https://github.com/folke/persistence.nvim",

  -- Util plugins used as dependencies
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/MunifTanjim/nui.nvim",

  -- Editor ...
  "https://github.com/lukas-reineke/indent-blankline.nvim",
  "https://github.com/windwp/nvim-autopairs",
  "https://github.com/windwp/nvim-ts-autotag",
  { src = "https://github.com/kylechui/nvim-surround", tag = "^3.0.0" },

  -- Comments
  "https://github.com/numToStr/Comment.nvim",
  "https://github.com/JoosepAlviste/nvim-ts-context-commentstring",
})

vim.g.snacks_animate = false
vim.o.termguicolors = true
vim.o.background = "dark"

vim.g.gruvbox_material_enable_italic = true
vim.g.gruvbox_material_background = "soft"
vim.g.gruvbox_material_better_performance = 1

vim.cmd.colorscheme("gruvbox-material")
local wk = require("which-key")

-- Indent bank line
require("ibl").setup()

local treesitter = require("nvim-treesitter")

treesitter.setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
  indent = { enable = true },
  highlight = { enable = true },
  folds = { enable = true },
  ensure_installed = {
    "c",
    "lua",
    "vim",
    "diff",
    "vimdoc",
    "markdown",
    "markdown_inline",
    "tsx",
    "typescript",
    "javascript",
    "lua",
    "json",
    "html",
    "css",
  },
})

local ts_ft = {
  javascriptreact = true,
  typescriptreact = true,
  lua = true,
  python = true,
  javascript = true,
  typescript = true,
  tsx = true,
  jsx = true,
  html = true,
  css = true,
  json = true,
  yaml = true,
  bash = true,
  diff = true,
  c = true,
  cpp = true,
  vim = true,
  vimdoc = true,
  markdown = true,
}

vim.api.nvim_create_autocmd("FileType", {
  desc = "Enable built-in Tree-sitter highlight/folds/indent for selected filetypes",
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if not ts_ft[ft] then
      return
    end

    pcall(vim.treesitter.start, ev.buf)

    if vim.treesitter.indentexpr then
      vim.bo[ev.buf].indentexpr = "v:lua.vim.treesitter.indentexpr()"
    else
      vim.bo[ev.buf].indentexpr = "v:lua.require('nvim-treesitter').indentexpr()"
    end
  end,
})

---@diagnostic disable: missing-fields
require("ts_context_commentstring").setup({
  enable_autocmd = false,
})

require("Comment").setup({
  pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
  toggler = {
    line = "<leader>cc",
    block = "<leader>cb",
  },
  opleader = {
    line = "<leader>cc",
    block = "<leader>cb",
  },
})
---@diagnostic enable: missing-fields

local api = require("Comment.api")

wk.add({
  { "<leader>c", group = "comments", desc = "[C]omments" },
  {
    "<leader>c%",
    function()
      local orig = vim.api.nvim_win_get_cursor(0)
      vim.cmd("normal [%v%")

      local pos = vim.api.nvim_win_get_cursor(0)
      local line = vim.api.nvim_get_current_line()
      local col = pos[2] + 1
      local ch = line:sub(col, col)

      if ch:match("[%w_]") then
        vim.cmd.normal({ args = { "e" }, bang = true })
      end

      vim.cmd("normal v")
      api.toggle.blockwise(vim.fn.visualmode())
      vim.api.nvim_win_set_cursor(0, orig)
    end,
    desc = "Comment out enclosing[%] block",
    mode = "n",
    silent = true,
    noremap = true,
  },
})

require("nvim-surround").setup({})
require("nvim-autopairs").setup({})
require("nvim-ts-autotag").setup({
  opts = {
    enable_close = true,
    enable_rename = true,
    enable_close_on_slash = false,
  },
})

require("nvim-web-devicons").setup({ color_icons = false })
require("persistence").setup({})

require("snacks").setup({
  bigfile = { enabled = true },
  input = { enabled = true },
  scroll = { enabled = true },
  gh = { enabled = true },
  lazygit = { enabled = true },
  picker = { enabled = true },
  explorer = {
    enabled = true,
    replace_netrw = true,
    trash = true,
  },
  bufdelete = { enabled = true },

  indent = { enabled = false },
  statuscolumn = { enabled = false },
})

wk.add({
  mode = "n",
  {
    "<leader>qs",
    function()
      require("persistence").load()
    end,
    desc = "Load session for current dir",
  },
  {
    "<leader>qS",
    function()
      require("persistence").select()
    end,
    desc = "Select session to restore",
  },
})

require("packages.ui")
require("packages.git")
require("packages.lsp")
require("packages.nav")

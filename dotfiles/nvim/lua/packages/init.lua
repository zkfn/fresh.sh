vim.pack.add({
  "https://github.com/folke/which-key.nvim",
  "https://github.com/folke/snacks.nvim",

  -- Looks!
  "https://github.com/sainnhe/gruvbox-material",
  "https://github.com/nvim-tree/nvim-web-devicons",

  -- Session management
  "https://github.com/folke/persistence.nvim",

  -- Util plugins used as dependencies
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/MunifTanjim/nui.nvim",
})

vim.o.termguicolors = true
vim.o.background = "dark"

vim.g.gruvbox_material_enable_italic = true
vim.g.gruvbox_material_background = "soft"
vim.g.gruvbox_material_better_performance = 1

vim.cmd.colorscheme("gruvbox-material")

require("nvim-web-devicons").setup({ color_icons = false })
require("persistence").setup({})

require("snacks").setup({
  bigfile = { enabled = true },
  indent = { enabled = true },
  input = { enabled = true },
  scroll = { enabled = true },
  gh = { enabled = true },
  lazygit = { enabled = true },
  picker = { enabled = true },
  bufdelete = { enabled = true },
})

local wk = require("which-key")

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

require("packages.git")
require("packages.lsp")
require("packages.nav")

vim.pack.add({
  "https://github.com/SmiteshP/nvim-navbuddy",
  "https://github.com/SmiteshP/nvim-navic",
  "https://github.com/ThePrimeagen/harpoon",
  "https://github.com/folke/todo-comments.nvim",
})

local helpers = require("helpers")
local wk = require("which-key")
local Snacks = require("snacks")

require("nvim-navbuddy").setup({ lsp = { auto_attach = true } })
require("todo-comments").setup({})

wk.add({
  mode = "n",
  {
    "<leader>e",
    function()
      Snacks.explorer()
    end,
    desc = "File Explorer",
  },
  {
    "<leader>bc",
    helpers.cmd(":Navbuddy"),
    silent = true,
    noremap = true,
    desc = "Open Navbuddy ([b]read[c]rumbs)",
  },
  {
    "<leader>ff",
    function()
      Snacks.picker.files()
    end,
    desc = "Find Files",
  },
  {
    "<leader>st",
    function()
      Snacks.picker.todo_comments()
    end,
    desc = "Search TODO commnets",
  },
  {
    "<leader>sl",
    function()
      Snacks.picker.git_grep()
    end,
    desc = "Grep",
  },
  {
    "<leader>su",
    function()
      Snacks.picker.grep()
    end,
    desc = "Grep",
  },
})

local harpoon_mark = require("harpoon.mark")
local harpoon_ui = require("harpoon.ui")

---@param idx number
---@return function
local function harpoon_idx(idx)
  return function()
    harpoon_ui.nav_file(idx)
  end
end

wk.add({
  { "<leader>h", group = "harpoon", desc = "[H]arpoon commands" },

  -- Menus
  { "<leader>m", harpoon_mark.add_file, desc = "[M]ark current file" },
  { "<leader>l", harpoon_ui.toggle_quick_menu, desc = "[L]ist marked files" },

  -- Goto marked files using right-hand keys
  { "<leader>1", harpoon_idx(1), desc = "Goto 1st file" },
  { "<leader>2", harpoon_idx(2), desc = "Goto 2nd file" },
  { "<leader>3", harpoon_idx(3), desc = "Goto 3rd file" },
  { "<leader>4", harpoon_idx(4), desc = "Goto 4th file" },
})

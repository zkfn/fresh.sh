vim.pack.add({
  "https://github.com/tpope/vim-fugitive",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/sindrets/diffview.nvim",
})

---Helper to run commands silently
---@param command string
---@return function
local function cmd(command)
  return function()
    vim.cmd(command)
  end
end

local wk = require("which-key")
local actions = require("diffview.actions")

require("diffview").setup({
  view = {
    default = {
      layout = "diff2_vertical",
    },
    merge_tool = {
      layout = "diff4_mixed",
    },
  },
  keymaps = {
    diff4 = {
      {
        { "n", "x" },
        "gb",
        actions.diffget("base"),
        { desc = "Obtain the diff hunk from the BASE version of the file" },
      },
      {
        { "n", "x" },
        "go",
        actions.diffget("ours"),
        { desc = "Obtain the diff hunk from the OURS version of the file" },
      },
      {
        { "n", "x" },
        "gt",
        actions.diffget("theirs"),
        { desc = "Obtain the diff hunk from the THEIRS version of the file" },
      },
    },
    diff3 = {
      {
        { "n", "x" },
        "go",
        actions.diffget("ours"),
        { desc = "Obtain the diff hunk from the OURS version of the file" },
      },
      {
        { "n", "x" },
        "gt",
        actions.diffget("theirs"),
        { desc = "Obtain the diff hunk from the THEIRS version of the file" },
      },
    },
  },
})

wk.add({ "<leader>gg", cmd(":Git"), noremap = true, silent = true, mode = "n" })

vim.opt.diffopt:append("algorithm:patience")
vim.opt.diffopt:append("indent-heuristic")

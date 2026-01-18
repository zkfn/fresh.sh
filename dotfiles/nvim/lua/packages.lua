vim.pack.add({
  "https://github.com/tpope/vim-fugitive",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/sindrets/diffview.nvim",
  "https://github.com/folke/snacks.nvim",
  "https://github.com/sainnhe/gruvbox-material",
  "https://github.com/SmiteshP/nvim-navbuddy",
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/SmiteshP/nvim-navic",
  "https://github.com/MunifTanjim/nui.nvim",
})

vim.o.termguicolors = true
vim.o.background = "dark"

vim.g.gruvbox_material_enable_italic = true
vim.g.gruvbox_material_background = "soft"
vim.g.gruvbox_material_better_performance = 1

vim.cmd.colorscheme("gruvbox-material")

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
local Snacks = require("snacks")

vim.keymap.set("n", "<leader>gL", function()
  Snacks.picker.git_log({
    confirm = function(picker, item)
      if not item then
        return
      end

      local sha = item.commit or item.hash or item.oid

      if not sha and type(item.item) == "table" then
        sha = item.item.commit or item.item.hash or item.item.oid
      end
      if not sha then
        return
      end

      picker:close()
      vim.cmd("DiffviewOpen " .. sha .. "^!")
    end,
  })
end, { desc = "Pick commit (Snacks) -> Diffview" })

require("nvim-navbuddy").setup({ lsp = { auto_attach = true } })

require("snacks").setup({
  bigfile = { enabled = true },
  indent = { enabled = true },
  input = { enabled = true },
  scroll = { enabled = true },
  gh = { enabled = true },
  lazygit = { enabled = true },
  picker = { enabled = true },
})

wk.add({
  mode = "n",
  {
    "<leader>gL",
    function()
      Snacks.picker.git_log({
        confirm = function(picker, item)
          if not item then
            return
          end

          local sha = item.commit or item.hash or item.oid
          if not sha and type(item.item) == "table" then
            sha = item.item.commit or item.item.hash or item.item.oid
          end
          if not sha then
            return
          end

          picker:close()
          vim.cmd("DiffviewOpen " .. sha .. "^!")
        end,
      })
    end,
  },
  {
    "<leader>bc",
    cmd(":Navbuddy"),
    silent = true,
    noremap = true,
    desc = "Open Navbuddy ([b]read[c]rumbs)",
  },
  {
    "<leader>gi",
    function()
      Snacks.picker.gh_issue()
    end,
    desc = "GitHub Issues (open)",
  },
  {
    "<leader>gI",
    function()
      Snacks.picker.gh_issue({ state = "all" })
    end,
    desc = "GitHub Issues (all)",
  },
  {
    "<leader>gp",
    function()
      Snacks.picker.gh_pr()
    end,
    desc = "GitHub Pull Requests (open)",
  },
  {
    "<leader>gP",
    function()
      Snacks.picker.gh_pr({ state = "all" })
    end,
    desc = "GitHub Pull Requests (all)",
  },
})

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

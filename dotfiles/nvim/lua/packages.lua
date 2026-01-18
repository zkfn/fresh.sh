vim.pack.add({
  "https://github.com/tpope/vim-fugitive",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/sindrets/diffview.nvim",
  "https://github.com/folke/snacks.nvim",
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
local Snacks = require("snacks")

vim.keymap.set("n", "<leader>gL", function()
  Snacks.picker.git_log({
    -- override what <CR> does
    confirm = function(picker, item)
      if not item then
        return
      end

      -- Snacks' git_log items typically expose the sha as `item.commit`.
      -- Keep it robust across versions:
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

require("snacks").setup({
  bigfile = { enabled = true },
  indent = { enabled = true },
  input = { enabled = true },
  scroll = { enabled = true },
  gh = {
    enabled = true,
  },
  lazygit = {
    -- your lazygit configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  },
  picker = {
    enabled = true,
    sources = {
      gh_issue = {
        -- your gh_issue picker configuration comes here
        -- or leave it empty to use the default settings
      },
      gh_pr = {
        -- your gh_pr picker configuration comes here
        -- or leave it empty to use the default settings
      },
    },
  },
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

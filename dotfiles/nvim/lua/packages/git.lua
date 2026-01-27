vim.pack.add({
  "https://github.com/tpope/vim-fugitive",
  "https://github.com/sindrets/diffview.nvim",
  "https://github.com/tpope/vim-fugitive",
  "https://github.com/lewis6991/gitsigns.nvim",
})

local function refresh_fugitive_status()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "fugitive" then
      vim.api.nvim_win_call(win, function()
        vim.cmd("silent! edit")
      end)
    end
  end
end

local gs = require("gitsigns")
local wk = require("which-key")
local actions = require("diffview.actions")
local Snacks = require("snacks")
local helpers = require("helpers")

gs.setup({
  signs = {
    add = { text = "▎" },
    change = { text = "▎" },
    delete = { text = "" },
    topdelete = { text = "" },
    changedelete = { text = "▎" },
    untracked = { text = "▎" },
  },

  on_attach = function(bufnr)
    ---@diagnostic disable: param-type-mismatch

    local function prev_hunk()
      gs.nav_hunk("prev")
    end

    local function next_hunk()
      gs.nav_hunk("next")
    end
    ---@diagnostic enable: param-type-mismatch

    local function vis_stage_hunk()
      gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      refresh_fugitive_status()
    end

    local function vis_reset_hunk()
      gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      refresh_fugitive_status()
    end

    local function stage_hunk()
      gs.stage_hunk()
      refresh_fugitive_status()
    end

    local function reset_hunk()
      gs.reset_hunk()
      refresh_fugitive_status()
    end

    local function stage_buffer()
      gs.stage_buffer()
      refresh_fugitive_status()
    end

    local function reset_buffer()
      gs.reset_buffer()
      refresh_fugitive_status()
    end

    local function blame_line()
      gs.blame_line({ full = true })
    end

    ---@param cmd string
    ---@param fn function
    local function if_diff(cmd, fn)
      return function()
        if vim.wo.diff then
          vim.cmd.normal({ cmd, bang = true })
        else
          fn()
        end
      end
    end

    wk.add({
      {
        mode = "n",

        -- Navigate between hunks
        { "]g", if_diff("]g", next_hunk), desc = "Next hunk" },
        { "[g", if_diff("[g", prev_hunk), desc = "Prev hunk" },

        { "<leader>gs", stage_hunk, desc = "[S]tage hunk" },
        { "<leader>gp", gs.preview_hunk(), desc = "[P]review hunk" },
        { "<leader>gr", reset_hunk, desc = "[R]eset hunk" },
        { "<leader>gS", stage_buffer, desc = "[S]tage buffer" },
        { "<leader>gR", reset_buffer, desc = "[R]eset buffer" },
        { "<leader>gd", gs.diffthis, desc = "[D]iff this" },
        { "<leader>gb", blame_line, desc = "[B]lame line (full)" },
      },
      {
        mode = "v",
        { "<leader>gs", vis_stage_hunk, desc = "[S]tage hunk (visual)" },
        { "<leader>gr", vis_reset_hunk, desc = "[R]eset hunk (visual)" },
      },
      {
        mode = { "o", "x" },
        { "ih", gs.select_hunk, desc = "inner [h]unk" },
      },
    }, {
      buffer = bufnr,
      silent = true,
      bang = true,
    })
  end,
})

require("diffview").setup({
  view = {
    default = {
      layout = "diff2_horizontal",
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

wk.add({
  mode = "n",
  noremap = true,
  silent = true,
  { "<leader>g", group = "git", desc = "[G]it" },
  { "<leader>gm", helpers.cmd(":DiffviewOpen"), desc = "Open git-diff view" },
  { "<leader>gg", helpers.cmd(":Git"), desc = "Open figitive menu" },
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
    "<leader>gB",
    function()
      Snacks.picker.git_branches()
    end,
    desc = "Git [B]ranches",
  },
  {
    "<leader>gl",
    function()
      Snacks.picker.git_log()
    end,
    desc = "Search git log (checkout)",
  },
  {
    "<leader>gw",
    function()
      Snacks.lazygit.open()
    end,
    desc = "Lazygit open",
  },
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
    desc = "Search git log (display diff)",
  },
})

vim.opt.diffopt:append("algorithm:patience")
vim.opt.diffopt:append("indent-heuristic")

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
  { src = "https://github.com/chomosuke/typst-preview.nvim", tag = "v1.*" },
  -- Claude
  "https://github.com/coder/claudecode.nvim",
})

vim.g.snacks_animate = false
vim.o.termguicolors = true
vim.o.background = "dark"

vim.g.gruvbox_material_enable_italic = true
vim.g.gruvbox_material_background = "soft"
vim.g.gruvbox_material_better_performance = 1

vim.cmd.colorscheme("gruvbox-material")
local wk = require("which-key")
local helpers = require("helpers")

require("claudecode").setup()

wk.add({
  { "<leader>a", group = "AI/Claude Code", desc = "[A]I/Claude Code" },
  { "<leader>ac", helpers.cmd("ClaudeCode"), desc = "[A]I [C]laude Toggle" },
  { "<leader>af", helpers.cmd("ClaudeCodeFocus"), desc = "[A]I [F]ocus" },
  { "<leader>ar", helpers.cmd("ClaudeCode --resume"), desc = "[A]I [R]esume" },
  { "<leader>aC", helpers.cmd("ClaudeCode --continue"), desc = "[A]I [C]ontinue" },
  { "<leader>am", helpers.cmd("ClaudeCodeSelectModel"), desc = "[A]I select [M]odel" },
  { "<leader>ab", helpers.cmd("ClaudeCodeAdd %"), desc = "[A]I add [B]uffer" },
  { "<leader>aa", helpers.cmd("ClaudeCodeDiffAccept"), desc = "[A]I [A]ccept diff" },
  { "<leader>ad", helpers.cmd("ClaudeCodeDiffDeny"), desc = "[A]I [D]eny diff" },
  { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "[A]I [S]end selection" },
})

-- Indent bank line
require("ibl").setup()

local treesitter = require("nvim-treesitter")

-- setup() on the main branch takes exactly one option, install_dir. `indent`,
-- `highlight`, `folds` and `ensure_installed` are master-branch spellings; the
-- rewrite folds them into the config table and never reads them again, so they
-- looked like they worked while installing nothing. Parsers now come from
-- install() below, and highlight/indent from the FileType autocmd.
treesitter.setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})

-- One language per thing actually edited here: the filetypes with an ftplugin,
-- the ones with an LSP server in lsp.lua, and latex + typst, which snacks.image
-- needs to find math and diagrams in a document.
--
-- install() is async and a no-op for parsers already present, so this is cheap
-- on every start but leaves the first one after adding a language downloading
-- in the background. :checkhealth nvim-treesitter shows what landed.
treesitter.install({
  -- editor and plumbing
  "c",
  "cpp",
  "lua",
  "vim",
  "vimdoc",
  "diff",
  "query",
  "kitty",
  -- prose and markup
  "markdown",
  "markdown_inline",
  "latex",
  "typst",
  "html",
  "css",
  "json",
  "yaml",
  "toml",
  -- code
  "javascript",
  "typescript",
  "tsx",
  "python",
  "go",
  "rust",
  "bash",
  "haskell",
  "prisma",
  "proto",
})

-- Enable for any buffer whose language has a parser on disk, rather than
-- against a hand-kept filetype allowlist. The old list had drifted from the
-- install list in both directions: `diff` was installed but never enabled,
-- while `haskell`, `yaml`, `bash` and `cpp` were enabled with no parser to back
-- them, and the indentexpr below was set anyway — a treesitter indentexpr with
-- no tree behind it, which indents worse than the built-in rules it replaced.
vim.api.nvim_create_autocmd("FileType", {
  desc = "Enable built-in Tree-sitter highlight and indent where a parser exists",
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
    if not lang or not vim.treesitter.language.add(lang) then
      return
    end

    vim.treesitter.start(ev.buf, lang)

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
  terminal = { enabled = true },
  picker = { enabled = true },
  explorer = {
    enabled = true,
    replace_netrw = true,
    trash = true,
  },
  bufdelete = { enabled = true },
  scratch = { enabled = true },

  -- Inline images, mermaid diagrams and latex math in markdown/typst buffers.
  -- Draws with the kitty graphics protocol, so it needs kitty (or another
  -- terminal that speaks it) plus `allow-passthrough on` in tmux.conf, and
  -- ImageMagick to convert anything that is not already a PNG. Mermaid blocks
  -- additionally shell out to `mmdc` (@mermaid-js/mermaid-cli).
  image = {
    enabled = true,
    doc = {
      -- Both are terminal cells, not pixels. Defaults are 80x40; 40 rows of a
      -- 64 row pane means a tall diagram runs off the bottom and fights the
      -- scroll, since tmux cannot reposition pixels it does not track.
      max_width = 120,
      max_height = 30,
      -- Default conceals math only, which left the mermaid source stacked on
      -- top of its own rendered diagram. Charts hide their source the same way
      -- now; moving the cursor into the block swaps the image back for the
      -- text so it stays editable.
      conceal = function(_, type)
        return type == "math" or type == "chart"
      end,
    },
    convert = {
      -- mermaid lays out at 16px and a wide graph then gets scaled down to fit
      -- the buffer, so the labels land somewhere unreadable. Rendering at 28px
      -- makes the diagram taller for the same width, which is the same thing as
      -- making the text bigger relative to it: ~1.75x on screen, for four extra
      -- rows. mermaid.json carries that plus a little more node spacing so the
      -- larger labels do not collide.
      mermaid = function()
        local theme = vim.o.background == "light" and "neutral" or "dark"
        return {
          "-i", "{src}",
          "-o", "{file}",
          "-b", "transparent",
          "-t", theme,
          "-s", "{scale}",
          "-c", vim.fn.stdpath("config") .. "/mermaid.json",
        }
      end,
    },
  },

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
  {
    "<leader>.",
    function()
      Snacks.scratch()
    end,
    desc = "Toggle Scratch Buffer",
  },
  {
    "<leader>S",
    function()
      Snacks.scratch.select()
    end,
    desc = "Select Scratch Buffer",
  },
})

require("packages.ui")
require("packages.git")
require("packages.lsp")
require("packages.nav")

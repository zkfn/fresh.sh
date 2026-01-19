local wk = require("which-key")
local helpers = require("helpers")
local conform = require("conform")

-- Clear search results (remove annoying highlights)
wk.add({ "<leader>/", helpers.cmd('let @/ = ""'), desc = "Clear search[/] highlights", mode = "n" })

wk.add({
  mode = "nv",
  { "<leader>y", '"+y', desc = "[Y]ank to system clipboard" },
  { "<leader>p", '"+p', desc = "[P]aste from system clipboard" },
  { "<leader>x", helpers.cmd(":bdel"), desc = "Close current buffer" },

  --CRTL-P to go to a newer position
  { "<C-p>", "<C-i>", desc = "Jumplist forward" },
})

wk.add({
  mode = "i",
  { "<C-Q>", "<C-O>q", desc = "Stop/start macro recording (same as [q] in normal mode)" },

  -- CTRL to allow hjkl in insert mode
  { "<C-h>", "<left>", desc = "Left" },
  { "<C-j>", "<down>", desc = "Down" },
  { "<C-k>", "<up>", desc = "Up" },
  { "<C-l>", "<right>", desc = "Right" },
})

-- Don't exit the visual mode after using > or < to shift lines
wk.add({
  mode = "v",
  { ">", ">gv", desc = "Shift lines [>] and return keep the visual mode" },
  { "<", "<gv", desc = "Unshift lines [<] and return keep the visual mode" },
  { "J", ":m '>+1<CR>gv=gv", desc = "Move selection up" },
  { "K", ":m '<-2<CR>gv=gv", desc = "Move selection down" },
})

-- Formatting
wk.add({
  {
    "<leader>w",
    helpers.cmd("noa w"),
    desc = "Write without triggering formatters",
  },
  {

    "<leader><leader>",
    function()
      conform.format({
        lsp_fallback = true,
        async = false,
        timeout_ms = 500,
      })
    end,
    desc = "Format file or range",
  },
  mode = { "n", "v" },
})

-- Terminal exit
wk.add({
  "<C-n>",
  [[<C-\><C-n>]],
  mode = "t",
  silent = true,
  noremap = true,
})

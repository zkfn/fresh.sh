vim.pack.add({
  "https://github.com/nvim-lualine/lualine.nvim",
  "https://github.com/nvim-mini/mini.nvim",
  "https://github.com/MeanderingProgrammer/render-markdown.nvim",
  { src = "https://github.com/akinsho/bufferline.nvim", tag = "*" },

  -- Live markdown preview in the browser: :MarkdownPreview / :MarkdownPreviewStop.
  -- Replaces iamcco/markdown-preview.nvim, which has had no commit since October
  -- 2023 and bundles mermaid 10.2.3 — old enough to throw "Syntax error in text"
  -- on graphs that mermaid 11 renders fine, with no upstream left to fix it.
  -- This one draws mermaid as interactive SVG: expand to fullscreen, zoom, pan,
  -- export. It is also pure Lua over its own HTTP server, so the binary download
  -- the old plugin needed after every update is gone with it.
  "https://github.com/selimacerbas/live-server.nvim",
  "https://github.com/selimacerbas/markdown-preview.nvim",
})

require("markdown_preview").setup({
  default_theme = "dark",
  open_browser = true,
  scroll_sync = true,
})

-- :md — preview the current buffer in the browser. Inline rendering is fine for
-- a glance, but a dense diagram needs real pixels and a zoom, so this is the
-- way out of squinting at a downscaled png.
vim.api.nvim_create_user_command("Md", function()
  if vim.bo.filetype ~= "markdown" then
    vim.notify("Not a markdown buffer (ft=" .. vim.bo.filetype .. ")", vim.log.levels.WARN)
    return
  end
  vim.cmd("MarkdownPreview")
end, { desc = "Preview this markdown buffer in the browser" })
-- User commands must start with a capital, so `md` is a command-line abbrev.
-- Guarded on the whole line being exactly "md": a bare `cnoreabbrev md Md`
-- expands anywhere on the line, which quietly turns `:e md.txt` into `:e Md.txt`.
vim.cmd([[cnoreabbrev <expr> md (getcmdtype() == ':' && getcmdline() ==# 'md') ? 'Md' : 'md']])

-- Both this and snacks.image want to own a fenced code block. render-markdown
-- paints the language pill and border onto the fence lines, which is exactly
-- where snacks anchors the rendered diagram, so the image only surfaced when
-- anti-conceal stripped those marks off the cursor's row. Hand mermaid blocks
-- to snacks and leave every other block, and all the table and heading
-- rendering, alone.
require("render-markdown").setup({
  code = { disable = { "mermaid" } },
})

local collect = function(from)
  local names = {}
  for _, f in ipairs(from) do
    table.insert(names, f.name or f)
  end
  return (#names > 0) and (table.concat(names, ",")) or "[none]"
end

local lsp = {
  function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if next(clients) == nil then
      return "[none]"
    end

    return collect(clients)
  end,
  icon = " ",
}

local fmt = {
  function()
    local ok, conform = pcall(require, "conform")
    if not ok then
      return "[none]"
    end
    return collect(conform.list_formatters(0) or {})
  end,
  icon = " ",
}

local wk = require("which-key")
local helpers = require("helpers")

require("lualine").setup({
  options = {
    globalstatus = true,
    icons_enabled = true,
    theme = "gruvbox-material",
    component_separators = "|",
    section_separators = { left = "▌", right = "▐" },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = {
      {
        "filename",
        file_status = true, -- Displays file status (readonly status, modified status)
        newfile_status = false, -- Display new file status (new file means no write after created)
        path = 1,
      },
      "filetype",
    },
    lualine_x = { lsp, fmt },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

require("bufferline").setup({
  options = {
    separator_style = { "", "" },
    diagnostics = "nvim_lsp",
    diagnostics_indicator = function(count, level)
      local icon = level:match("error") and " " or " "
      return " " .. icon .. count
    end,
  },
})

wk.add({
  mode = "n",
  { "<Tab>", helpers.cmd("BufferLineCycleNext"), { desc = "Next buffer" } },
  { "<S-Tab>", helpers.cmd("BufferLineCyclePrev"), { desc = "Next buffer" } },
  { "<leader>bb", helpers.cmd("BufferLinePick"), { desc = "[B]ufferline pick" } },
  { "<leader>bo", helpers.cmd("BufferLineCloseOthers"), { desc = "[B]ufferline close [o]thers" } },
})

-- markdown-preview.nvim ships a server binary that must be downloaded after the
-- plugin is installed/updated. vim.pack doesn't run build hooks, so do it here.
-- Registered before vim.pack.add so it also catches the very first install.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name == "markdown-preview.nvim" and ev.data.kind ~= "delete" then
      vim.fn["mkdp#util#install"]()
    end
  end,
})

vim.pack.add({
  "https://github.com/nvim-lualine/lualine.nvim",
  "https://github.com/nvim-mini/mini.nvim",
  "https://github.com/MeanderingProgrammer/render-markdown.nvim",
  { src = "https://github.com/akinsho/bufferline.nvim", tag = "*" },
  -- Live markdown preview in the browser: :MarkdownPreview / :MarkdownPreviewStop
  "https://github.com/iamcco/markdown-preview.nvim",
})

-- Refresh the preview live as you type (default only refreshes on save/leave).
vim.g.mkdp_refresh_slow = 0
-- Don't auto-close the browser tab when leaving a markdown buffer.
vim.g.mkdp_auto_close = 0

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

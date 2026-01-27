vim.pack.add({
  "https://github.com/nvim-lualine/lualine.nvim",
  "https://github.com/nvim-mini/mini.nvim",
  "https://github.com/MeanderingProgrammer/render-markdown.nvim",
  { src = "https://github.com/akinsho/bufferline.nvim", tag = "*" },
})

require("render-markdown").setup({})

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

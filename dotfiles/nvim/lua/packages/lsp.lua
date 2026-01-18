vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/mason-org/mason-lspconfig.nvim",
  "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
  "https://github.com/folke/lazydev.nvim",
})

require("lazydev").setup({ library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } } })

require("mason").setup()
require("mason-lspconfig").setup()
require("mason-tool-installer").setup({
  ensure_installed = {
    "lua_ls",
    "stylua",
    "ts_ls",
    "html",
    "cssls",
    "jsonls",
    "yamlls",
    "pyright",
    "black",
    "prettier",
    "biome",
  },
})

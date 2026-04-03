vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/mason-org/mason-lspconfig.nvim",
  "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
  "https://github.com/folke/lazydev.nvim",
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/mfussenegger/nvim-lint",
  "https://github.com/hrsh7th/nvim-cmp",
  "https://github.com/hrsh7th/cmp-nvim-lsp",
  "https://github.com/hrsh7th/cmp-nvim-lsp-signature-help",
  "https://github.com/hrsh7th/cmp-path",
})

local cmp = require("cmp")
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
local helpers = require("helpers")
local Snacks = require("snacks")
local wk = require("which-key")

cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
vim.lsp.config("*", { capabilities = require("cmp_nvim_lsp").default_capabilities() })

vim.lsp.config("hls", {
  cmd = { "haskell-language-server-wrapper", "--lsp" },
  filetypes = { "haskell", "lhaskell", "cabal" },
})
vim.lsp.enable("hls")

wk.add({
  {
    "gd",
    function()
      Snacks.picker.lsp_definitions()
    end,
    desc = "Goto Definition",
  },
  {
    "gD",
    function()
      Snacks.picker.lsp_declarations()
    end,
    desc = "Goto Declaration",
  },
  {
    "gr",
    function()
      Snacks.picker.lsp_references()
    end,
    nowait = true,
    desc = "References",
  },
  {
    "gI",
    function()
      Snacks.picker.lsp_implementations()
    end,
    desc = "Goto Implementation",
  },
  {
    "gt",
    function()
      Snacks.picker.lsp_type_definitions()
    end,
    desc = "Goto T[y]pe Definition",
  },
  {
    "gai",
    function()
      Snacks.picker.lsp_incoming_calls()
    end,
    desc = "C[a]lls Incoming",
  },
  {
    "gao",
    function()
      Snacks.picker.lsp_outgoing_calls()
    end,
    desc = "C[a]lls Outgoing",
  },
  {
    "<leader>ss",
    function()
      Snacks.picker.lsp_symbols()
    end,
    desc = "LSP Symbols",
  },
  {
    "<leader>sS",
    function()
      Snacks.picker.lsp_workspace_symbols()
    end,
    desc = "LSP Workspace Symbols",
  },
  { "<leader>dq", vim.diagnostic.setloclist, desc = "[Q]uicklist from buffer [d]iagnostics" },
  { "<leader>qa", vim.diagnostic.setqflist, desc = "[Q]uicklist from [a]ll diagnostics" },
  { "<leader>dc", vim.lsp.buf.code_action, desc = "[D]o code [a]ction" },
  { "<leader>df", vim.diagnostic.open_float, desc = "[D]iagnostic as [f]loat" },
  { "<leader>rn", vim.lsp.buf.rename, desc = "[R]e[n]ame symbol" },
  { "K", vim.lsp.buf.hover, desc = "Symbol info" },
  { "<C-s>", vim.lsp.buf.signature_help, desc = "Show [s]ignature" },
})

cmp.setup({
  mapping = {
    -- docs
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),

    -- menu toggle
    ["<C-Space>"] = cmp.mapping(function()
      if cmp.visible() then
        cmp.close()
      else
        cmp.complete()
      end
    end, { "i", "c" }),

    -- confirm
    ["<C-l>"] = cmp.mapping.confirm({ select = true }),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),

    -- select
    ["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
    ["<Up>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
    ["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
    ["<Down>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),

    -- abort
    ["<C-m>"] = cmp.mapping.abort(),
  },

  sources = cmp.config.sources({
    { name = "lazydev", group_index = 0 },
    { name = "nvim_lsp" },
    { name = "nvim_lsp_signature_help" },
    { name = "path" },
  }, {
    { name = "buffer" },
  }),
})

local lint = require("lint")

lint.linters_by_ft = {
  javascript = { "eslint_d" },
  javascriptreact = { "eslint_d" },
  typescript = { "eslint_d" },
  typescriptreact = { "eslint_d" },
  svelte = { "eslint_d" },
  -- go = { "golangcilint" },
}

local function run_linter()
  lint.try_lint()
end

local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

-- hook into BufEnter
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
  group = lint_augroup,
  callback = run_linter,
})

wk.add({ { "<leader>;;", run_linter, desc = "[L]int", mode = "n" } })

require("conform").setup({
  formatters_by_ft = {
    javascript = { "prettier", "biome-organize-imports" },
    typescript = { "prettier", "biome-organize-imports" },
    javascriptreact = { "prettier", "biome-organize-imports" },
    typescriptreact = { "prettier", "biome-organize-imports" },
    json = { "prettier" },
    jsonc = { "prettier" },
    svelte = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },
    graphql = { "prettier" },
    lua = { "stylua" },
    python = { "black" },
    php = { "pint", "php_cs_fixer" },
    blade = { "blade-formatter" },
    typst = { "typstyle" },
  },
  log_level = vim.log.levels.DEBUG,
  formatters = {
    stylua = {
      prepend_args = { "--indent-type", "Spaces", "--indent-width", "2", "--column-width", "110" },
    },
    formatters = {
      black = {
        prepend_args = { "--fast" },
      },
    },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_format = "fallback",
  },
})

wk.add({
  {
    "<leader>w",
    helpers.cmd("noa w"),
    mode = "nv",
  },
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
  },
})

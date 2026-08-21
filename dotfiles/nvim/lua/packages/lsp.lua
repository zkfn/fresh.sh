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
local project = require("project")
local lsputil = require("lspconfig.util")
local Snacks = require("snacks")
local wk = require("which-key")

cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
vim.lsp.config("*", { capabilities = require("cmp_nvim_lsp").default_capabilities() })

vim.lsp.config("hls", {
  cmd = { "haskell-language-server-wrapper", "--lsp" },
  filetypes = { "haskell", "lhaskell", "cabal" },
})

-- tailwindcss lists `.git` as a root marker (a fallback for v4, where
-- tailwind.config.* is optional) and claims `markdown` as a filetype, so it
-- starts in *every* git repo the moment you open a README. Require a real
-- config file or a tailwindcss dependency in package.json instead — v4 repos
-- still carry the dep, so they keep working.
vim.lsp.config("tailwindcss", {
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root_files = lsputil.insert_package_json({
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "tailwind.config.ts",
      "postcss.config.js",
      "postcss.config.cjs",
      "postcss.config.mjs",
      "postcss.config.ts",
    }, "tailwindcss", fname)
    local found = vim.fs.find(root_files, { path = fname, upward = true, type = "file", limit = 1 })[1]
    if found then
      on_dir(vim.fs.dirname(found))
    end
  end,
})

-- lspconfig accepts *any* package.json containing the string "biomejs" as proof
-- the repo uses biome, so a leftover `@biomejs/biome` devDependency starts the
-- server in a repo that formats with prettier. Require a real biome.json — the
-- same test project.uses() applies to the formatter, so the two cannot disagree.
vim.lsp.config("biome", {
  root_dir = function(bufnr, on_dir)
    if not project.uses("biome", bufnr) then
      return
    end
    -- biome resolves the nearest biome.json itself, so hand it the project root
    -- and let one server cover the whole monorepo.
    on_dir(vim.fs.root(bufnr, {
      { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" },
      { ".git" },
    }) or vim.fn.getcwd())
  end,
})

--- Wrap a server's root resolution so a repo can veto it from its .nvim.lua.
--- Returning without calling on_dir() means the server is never spawned, so
--- the veto costs nothing — unlike stopping the client after it attaches.
local function gate(name)
  local cfg = vim.lsp.config[name] or {}
  local base_root_dir, base_markers = cfg.root_dir, cfg.root_markers

  vim.lsp.config(name, {
    root_dir = function(bufnr, on_dir)
      if project.lsp_off(name) then
        return
      end
      if type(base_root_dir) == "function" then
        return base_root_dir(bufnr, on_dir)
      end
      if base_root_dir ~= nil then
        return on_dir(base_root_dir)
      end
      on_dir(base_markers and vim.fs.root(bufnr, base_markers) or nil)
    end,
  })
end

-- Enabled explicitly. Mason installing a server is not a reason to run it.
-- Each of these still gates itself on root markers, so opening one .ts file
-- does not drag in the servers whose config files the repo does not have.
local servers = {
  "lua_ls",
  "ts_ls",
  "biome",
  "eslint",
  "tailwindcss",
  "html",
  "cssls",
  "jsonls",
  "yamlls",
  "pyright",
  "gopls",
  "rust_analyzer",
  "bashls",
  "prismals",
  "tinymist",
  "hls",
}

vim.iter(servers):each(gate)
vim.lsp.enable(servers)

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

-- JS/TS eslint is handled by the eslint LSP, which already finds the repo's
-- config, reuses one process per project and gives code actions. Running
-- eslint_d here as well meant two eslint engines per buffer.
lint.linters_by_ft = {
  -- go = { "golangcilint" },
}

local function run_linter()
  lint.try_lint()
end

local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

-- BufEnter fired a lint run on every buffer switch, including switching back
-- to a buffer that had not changed.
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  group = lint_augroup,
  callback = run_linter,
})

wk.add({ { "<leader>;;", run_linter, desc = "[L]int", mode = "n" } })

-- Exactly one formatter per repo. prettier and biome-organize-imports both
-- rewriting the same file meant every save flipped quote style and import
-- order back and forth. Repo picks via biome.json, or vim.g.js_formatter.
local function web(bufnr)
  local pick = project.js_formatter(bufnr)
  if pick == "none" then
    return {}
  elseif pick == "biome" then
    return { "biome-check" }
  end
  return { "prettier" }
end

require("conform").setup({
  formatters_by_ft = {
    javascript = web,
    typescript = web,
    javascriptreact = web,
    typescriptreact = web,
    json = web,
    jsonc = web,
    svelte = { "prettier" },
    css = web,
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
-- automatic_enable defaults to true, which calls vim.lsp.enable() on all 22
-- installed packages. Enabling is done by hand above.
require("mason-lspconfig").setup({ automatic_enable = false })
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

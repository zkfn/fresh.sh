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

-- Two `root` strategies and two `when` vetoes, used by the server table below.

--- Root at the directory of the nearest `files` entry above the buffer, and do
--- not start where there is none. `dep` also accepts a package.json naming it.
---@param files string[]
---@param dep string|nil
local function nearest(files, dep)
  return function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    -- insert_package_json appends to the list it is handed, so hand it a copy.
    -- Sharing one list across calls meant the first repo whose package.json
    -- named `dep` left "package.json" in it, and every repo opened afterwards
    -- matched on merely having one.
    local markers = vim.list_extend({}, files)
    if dep then
      markers = lsputil.insert_package_json(markers, dep, fname)
    end
    local found = vim.fs.find(markers, { path = fname, upward = true, type = "file", limit = 1 })[1]
    if found then
      on_dir(vim.fs.dirname(found))
    end
  end
end

--- Root at the project, so one server covers a whole monorepo.
local function repo_root(bufnr, on_dir)
  on_dir(vim.fs.root(bufnr, {
    { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" },
    { ".git" },
  }) or vim.fn.getcwd())
end

--- Only where the repo really configures `tool`, by a config file rather than
--- by a dependency left behind in package.json.
local function uses(tool)
  return function(bufnr)
    return project.uses(tool, bufnr)
  end
end

--- Only where `name` is the repo's JS/TS linter. See project.js_linter().
local function linting_with(name)
  return function(bufnr)
    local pick = project.js_linter(bufnr)
    return pick == name or pick == "both"
  end
end

-- The one place that decides which servers run and where they root. Mason
-- installing a server is not a reason to run it, so nothing starts unless it is
-- listed, and a listed server still has to find its own config files. An entry
-- is a bare name unless it needs:
--
--   when = an extra veto, asked per buffer. Failing it means the server is
--          never spawned, which costs nothing — unlike stopping a client that
--          has already attached.
--   root = replaces nvim-lspconfig's root resolution, whole.
--
-- A repo switches any of them off in its .nvim.lua: vim.g.lsp_off = { "eslint" }
local servers = {
  "lua_ls",
  "ts_ls",
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

  -- lspconfig accepts *any* package.json containing the string "biomejs" as
  -- proof the repo uses biome, so a leftover `@biomejs/biome` devDependency
  -- starts the server in a repo that formats with prettier. The biome.json test
  -- is the one conform uses to pick the formatter, so the two cannot disagree.
  -- biome finds the nearest biome.json itself, hence one server per repo.
  { "biome", when = uses("biome"), root = repo_root },

  -- Exactly one JS/TS linter per repo, the rule the formatter already follows.
  -- Both servers accept a bare package.json mentioning their name as proof, so
  -- a repo carrying both configs started both and reported every shared rule
  -- twice.
  { "eslint", when = linting_with("eslint") },
  { "oxlint", when = linting_with("oxlint") },

  -- tailwindcss lists `.git` as a root marker (a fallback for v4, where
  -- tailwind.config.* is optional) and claims `markdown` as a filetype, so it
  -- starts in *every* git repo the moment you open a README. Require a real
  -- config file or a tailwindcss dependency in package.json instead — v4 repos
  -- still carry the dep, so they keep working.
  {
    "tailwindcss",
    root = nearest({
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "tailwind.config.ts",
      "postcss.config.js",
      "postcss.config.cjs",
      "postcss.config.mjs",
      "postcss.config.ts",
    }, "tailwindcss"),
  },
}

local enabled = {}

for _, entry in ipairs(servers) do
  local server = type(entry) == "string" and { entry } or entry
  local name, when = server[1], server.when
  local base = vim.lsp.config[name] or {}
  local root, markers = server.root or base.root_dir, base.root_markers

  vim.lsp.config(name, {
    root_dir = function(bufnr, on_dir)
      if project.lsp_off(name) or (when and not when(bufnr)) then
        return
      end
      if type(root) == "function" then
        return root(bufnr, on_dir)
      end
      if root ~= nil then
        return on_dir(root)
      end
      on_dir(markers and vim.fs.root(bufnr, markers) or nil)
    end,
  })

  enabled[#enabled + 1] = name
end

vim.lsp.enable(enabled)

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

-- JS/TS linting is handled by the eslint and oxlint LSP servers, which already
-- find the repo's config, reuse one process per project and give code actions.
-- Running eslint_d here as well meant two eslint engines per buffer.
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
    -- Unlike eslint, oxlint is often used without being a repo dependency, and
    -- the LSP prefers node_modules/.bin/oxlint anyway. Without a copy on PATH
    -- the server just never starts, with no error to explain why.
    "oxlint",
  },
})

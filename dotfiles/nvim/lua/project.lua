-- Per-repo toolchain detection.
--
-- Every question here is answered by walking upward from the *buffer's own
-- path*, not from cwd, so a monorepo package that ships its own biome.json
-- wins over the repo root's prettier config.
--
-- A repo can override any of it from a `.nvim.lua` at its root (see :h exrc,
-- and `vim.o.exrc` in globals.lua):
--
--   vim.g.lsp_off = { "tailwindcss", "eslint" }  -- never start these here
--   vim.g.js_formatter = "biome"                 -- "biome" | "prettier" | "none"

local M = {}

local markers = {
  biome = { "biome.json", "biome.jsonc" },
  prettier = {
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.json5",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    ".prettierrc.toml",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    "prettier.config.js",
    "prettier.config.cjs",
    "prettier.config.mjs",
    "prettier.config.ts",
  },
  eslint = {
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    ".eslintrc.json",
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    "eslint.config.ts",
    "eslint.config.mts",
    "eslint.config.cts",
  },
}

--- Does the repo owning `bufnr` configure `tool`?
---@param tool "biome"|"prettier"|"eslint"
---@param bufnr integer|nil
---@return boolean
function M.uses(tool, bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr or vim.api.nvim_get_current_buf())
  if fname == "" then
    return false
  end
  local hit = vim.fs.find(markers[tool], { path = fname, upward = true, type = "file", limit = 1 })[1]
  return hit ~= nil
end

--- Has this repo switched `name` off in its .nvim.lua?
---@param name string
---@return boolean
function M.lsp_off(name)
  for _, off in ipairs(vim.g.lsp_off or {}) do
    if off == name then
      return true
    end
  end
  return false
end

--- Which formatter should run on this JS/TS/CSS buffer.
---@param bufnr integer|nil
---@return "biome"|"prettier"|"none"
function M.js_formatter(bufnr)
  if vim.g.js_formatter then
    return vim.g.js_formatter
  end
  return M.uses("biome", bufnr) and "biome" or "prettier"
end

return M

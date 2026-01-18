local M = {}

---@param keys string[]
---@return table<string, boolean>
function M.as_set(keys)
  ---@type table<string, boolean>
  local set = {}

  for _, key in ipairs(keys) do
    set[key] = true
  end

  return set
end

---@param value_to_files table<string, string[]>
---@return string|nil
function M.find_cwdfile(value_to_files)
  local cwd = vim.fn.getcwd()

  for value, files in pairs(value_to_files) do
    for _, file in ipairs(files) do
      if vim.fn.filereadable(cwd .. "/" .. file) == 1 then
        return value
      end
    end
  end

  return nil
end

---Helper to run commands silently
---@param command string
---@return function
function M.cmd(command)
  return function()
    vim.cmd(command)
  end
end

return M

local M = {}

--- @class TermBufConfig
--- @field on_open fun(term:Terminal)?
local config = {}

function M.set(opts)
  config = vim.tbl_deep_extend('force', {}, opts or {})
end

---@return TermBufConfig
return setmetatable(M, {
  __index = function(_, k) return config[k] end,
})

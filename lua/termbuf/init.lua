local config = require('termbuf.config')

local M = {}

function M.setup(opts)
  config.set(opts)
end

return M

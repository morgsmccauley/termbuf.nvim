local config = require('termbuf.config')

local AUGROUP = vim.api.nvim_create_augroup("CustomTermBuffer", { clear = true })

---@type Terminal[]
local terminals = {}

---@class Terminal
---@field id number
---@field bufnr number
---@field job_id number
---@field hidden boolean
---@field name string
local Terminal = {}
Terminal.__index = Terminal

function Terminal:new(opts)
  opts = opts or {}

  local bufnr = vim.api.nvim_create_buf(false, true)

  local term = setmetatable({
    id = opts.id,
    bufnr = bufnr,
    job_id = nil,
    hidden = opts.hidden or false,
    name = opts.name or string.format("terminal://%d", opts.id),
  }, Terminal)

  table.insert(terminals, term)

  return term
end

function Terminal:open()
  if config.on_open then
    config.on_open(self)
  end

  vim.cmd(string.format("buffer %d", self.bufnr))

  vim.bo.buflisted = true
  vim.wo.number = false

  self.job_id = vim.fn.termopen(vim.o.shell)

  vim.cmd.startinsert()

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = self.bufnr,
    group = AUGROUP,
    callback = function() self:close() end,
  })
end

function Terminal:close()
  if self.job_id then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end

  for i, term in ipairs(terminals) do
    if term.id == self.id then
      table.remove(terminals, i)
      break
    end
  end

  -- `TermClose` will be called before `BufDelete` so we schedule closing to happen after
  -- the buffer is deleted to prevent premature deletion
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
  end)
end

function Terminal:send(cmd)
  if self.job_id then
    vim.fn.chansend(self.job_id, cmd .. "\n")
  end
end

function Terminal:is_open()
  return self.job_id ~= nil and vim.api.nvim_buf_is_valid(self.bufnr)
end

return Terminal

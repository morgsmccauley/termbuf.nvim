local config = require('termbuf.config')

local AUGROUP = vim.api.nvim_create_augroup("CustomTermBuffer", { clear = true })


---@class Terminal
---@field id number
---@field bufnr number
---@field job_id number
---@field hidden boolean
---@field name string
---@field dir string
---@field on_close fun(id:number)?
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
    dir = opts.dir or vim.uv.cwd(),
    cmd = opts.cmd or vim.o.shell,
    on_close = opts.on_close
  }, Terminal)


  return term
end

function Terminal:open()
  vim.cmd(string.format("buffer %d", self.bufnr))

  vim.bo.buflisted = true
  vim.opt_local.number = false

  self.job_id = vim.fn.termopen(self.cmd, { cwd = self.dir })

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = self.bufnr,
    group = AUGROUP,
    callback = function() self:close() end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = self.bufnr,
    group = AUGROUP,
    callback = function()
      if config.on_enter then
        config.on_enter(self)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = self.bufnr,
    group = AUGROUP,
    callback = function()
      if self.on_close then
        self.on_close(self.id)
      end
    end,
  })

  if config.on_open then
    config.on_open(self)
  end
end

function Terminal:close()
  if self.job_id then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end

  if self.on_close then
    self.on_close(self.id)
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
  if type(cmd) == "table" then
    cmd = table.concat(cmd, "\n")
  end

  if self.job_id then
    vim.fn.chansend(self.job_id, cmd .. "\n")
  end
end

function Terminal:is_open()
  return self.job_id ~= nil and vim.api.nvim_buf_is_valid(self.bufnr)
end

function Terminal:change_dir(dir)
  dir = dir and vim.fn.expand(dir) or vim.uv.cwd()

  if self.dir == dir then
    return
  end

  self:send({ string.format("cd %s", dir), "clear" })

  self.dir = dir
end

function Terminal:clear()
  self:send("clear")
end

---Get the full command of the currently running process in the terminal
---@return string|nil command The full command of the current process, or nil if not found
function Terminal:get_current_process()
  if not self.job_id then
    return nil
  end

  local pid = vim.fn.jobpid(self.job_id)
  if not pid then
    return nil
  end

  -- Try to find child processes using pgrep
  local cmd = string.format("pgrep -P %d", pid)
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end

  local child_pid = handle:read("*a"):gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
  handle:close()

  -- If child process found, get its command
  if child_pid and child_pid ~= "" then
    cmd = string.format("ps -p %s -o command=", child_pid)
  else
    -- Otherwise get the top-level process command
    cmd = string.format("ps -p %d -o command=", pid)
  end

  handle = io.popen(cmd)
  if not handle then
    return nil
  end

  local result = handle:read("*a"):gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
  handle:close()

  return result ~= "" and result or nil
end

return Terminal

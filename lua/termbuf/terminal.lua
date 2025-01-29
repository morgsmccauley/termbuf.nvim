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
    on_close = opts.on_close
  }, Terminal)


  return term
end

function Terminal:open()
  vim.cmd(string.format("buffer %d", self.bufnr))

  vim.bo.buflisted = true
  vim.opt_local.number = false

  self.job_id = vim.fn.termopen(vim.o.shell)

  self:change_dir(self.dir)

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

---Get the name of the currently running process in the terminal
---@return string|nil process_name The name of the current process, or nil if not found
function Terminal:get_current_process()
  if not self.job_id then
    return nil
  end

  local pid = vim.fn.jobpid(self.job_id)
  if not pid then
    return nil
  end

  -- Use pstree to get the full process hierarchy
  local cmd = string.format("pstree -p %d", pid)
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end

  local result = handle:read("*l")
  handle:close()

  if result then
    -- Extract the last process in the tree (rightmost process)
    local last_process = result:match("%-([^%(]+)%(") -- Match last process name before its PID
    if last_process and last_process ~= "zsh" and last_process ~= "bash" then
      return last_process:gsub("^%s*(.-)%s*$", "%1")
    end
    
    -- If no non-shell process found, try ps for any child processes
    cmd = string.format("ps -o comm= --ppid %d", pid)
    handle = io.popen(cmd)
    if handle then
      result = handle:read("*l")
      handle:close()
      if result and result ~= "zsh" and result ~= "bash" then
        return vim.fn.fnamemodify(result, ":t"):gsub("^%s*(.-)%s*$", "%1")
      end
    end
  end

  return nil
end

return Terminal

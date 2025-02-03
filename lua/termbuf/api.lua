local Terminal = require('termbuf.terminal')

local M = {}

---@type Terminal[]
local terminals = {}

M.__terminals = terminals

local function next_id()
  local id = #terminals + 1
  for i, term in ipairs(terminals) do
    if term.id ~= i then
      id = i
      break
    end
  end
  return id
end

function M.open_terminal(opts)
  opts = opts or {}

  local term = Terminal:new({
    id = next_id(),
    dir = opts.dir,
    cmd = opts.cmd,
    on_close = function(id) terminals[id] = nil end
  })
  term:open()
  terminals[term.id] = term
  return term
end

---@return { terminal: Terminal, process: string|nil }[] List of open terminals with their current processes
function M.list_terminals()
  local open_terminals = {}
  for _, term in ipairs(terminals) do
    if term:is_open() then
      table.insert(open_terminals, {
        terminal = term,
        process = term:get_current_process()
      })
    end
  end
  return open_terminals
end

function M.close_terminal(id)
  for _, term in ipairs(terminals) do
    if term.id == id then
      term:close()
      terminals[id] = nil
      break
    end
  end
end

function M.send_to_terminal(id, cmd)
  for _, term in ipairs(terminals) do
    if term.id == id then
      term:send(cmd)
      break
    end
  end
end

return M

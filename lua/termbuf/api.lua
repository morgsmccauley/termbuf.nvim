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
    on_close = function(id) terminals[id] = nil end
  })
  term:open()
  terminals[term.id] = term
  return term
end

---@param print_output? boolean Whether to print the terminal list to the console
---@return Terminal[] List of open terminals
function M.list_terminals(print_output)
  local open_terminals = {}
  for _, term in ipairs(terminals) do
    if term:is_open() then
      table.insert(open_terminals, term)
      if print_output then
        print(string.format("ID: %d, Name: %s", term.id, term.name))
      end
    end
  end
  
  if print_output and #open_terminals == 0 then
    print("No terminals opened")
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

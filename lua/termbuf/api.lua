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
  opts.id = opts.id or next_id()
  local term = Terminal:new(opts)
  term:open()
  return term
end

function M.list_terminals()
  if #terminals == 0 then
    print("No terminals opened")
    return
  end
  for _, term in ipairs(terminals) do
    if term:is_open() then
      print(string.format("ID: %d, Name: %s", term.id, term.name))
    end
  end
end

function M.close_terminal(id)
  for _, term in ipairs(terminals) do
    if term.id == id then
      term:close()
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

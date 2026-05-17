local M = {}
local handlers = {}

function M.subscribe(event, handler)
  if not handlers[event] then
    handlers[event] = {}
  end
  handlers[event][#handlers[event] + 1] = handler
  return handler
end

function M.unsubscribe(event, handler)
  if not handlers[event] then return end
  for i = #handlers[event], 1, -1 do
    if handlers[event][i] == handler then
      table.remove(handlers[event], i)
      return
    end
  end
end

function M.fire(event, ...)
  if not handlers[event] then return end
  for _, handler in ipairs(handlers[event]) do
    pcall(handler, ...)
  end
end

function M.clear(event)
  if event then
    handlers[event] = nil
  else
    handlers = {}
  end
end

return M

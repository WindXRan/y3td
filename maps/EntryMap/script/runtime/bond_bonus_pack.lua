local M = {}

function M.add_value(target, key, value)
  if not target or not key or value == nil or value == 0 then
    return
  end
  target[key] = (target[key] or 0) + value
end

function M.remove_value(target, key, value)
  if not target or not key or value == nil or value == 0 then
    return
  end
  target[key] = (target[key] or 0) - value
  if target[key] == 0 then
    target[key] = nil
  end
end

function M.merge(target, source)
  if not target or not source then
    return
  end
  for key, value in pairs(source) do
    M.add_value(target, key, value)
  end
end

function M.subtract(target, source)
  if not target or not source then
    return
  end
  for key, value in pairs(source) do
    M.remove_value(target, key, value)
  end
end

function M.copy(source)
  local result = {}
  M.merge(result, source)
  return result
end

return M

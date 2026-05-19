local M = {}

function M.create()
  local store = {}
  local order = {}
  local api = {}

  function api.register(def)
    if type(def) ~= 'table' then
      return false, 'skill def 必须是 table'
    end
    local id = tostring(def.id or '')
    if id == '' then
      return false, 'skill def 缺少 id'
    end
    if not store[id] then
      order[#order + 1] = id
    end
    store[id] = def
    return true
  end

  function api.get(id)
    return store[tostring(id or '')]
  end

  function api.list()
    local result = {}
    for _, id in ipairs(order) do
      local def = store[id]
      if def then
        result[#result + 1] = def
      end
    end
    return result
  end

  return api
end

return M


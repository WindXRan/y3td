local M = {}

function M.list_to_map(list, key_field)
  local map = {}
  local key_name = key_field or 'id'
  for _, item in ipairs(list or {}) do
    if type(item) == 'table' then
      local key = item[key_name]
      if key ~= nil and key ~= '' then
        map[key] = item
      end
    end
  end
  return map
end

function M.build_field_map(list, field_name, default_value)
  local result = {}
  for _, item in ipairs(list or {}) do
    if type(item) == 'table' then
      local key = item.id
      if key ~= nil and key ~= '' then
        local value = item[field_name]
        if value == nil then
          value = default_value
        end
        result[key] = value
      end
    end
  end
  return result
end

return M


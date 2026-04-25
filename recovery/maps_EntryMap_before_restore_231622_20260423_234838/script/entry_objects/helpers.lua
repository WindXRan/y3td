local M = {}

function M.load_list(module_paths)
  local list = {}
  for _, module_path in ipairs(module_paths or {}) do
    list[#list + 1] = require(module_path)
  end
  return list
end

function M.list_to_map(list)
  local map = {}
  for _, object in ipairs(list or {}) do
    if object and object.id then
      map[object.id] = object
    end
  end
  return map
end

function M.build_field_map(list, field_name, fallback)
  local map = {}
  for _, object in ipairs(list or {}) do
    if object and object.id then
      map[object.id] = object[field_name]
      if map[object.id] == nil and fallback ~= nil then
        map[object.id] = fallback
      end
    end
  end
  return map
end

return M

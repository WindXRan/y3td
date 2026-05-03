local CsvLoader = require 'data.csv_loader'

local CATEGORIES = {
  DAMAGE = '伤害属性',
  DEFENSE = '防守属性',
  RESOURCE = '资源属性',
  AMPLIFY = '增幅属性',
  OTHER = '其他属性',
}

local function to_boolean(value)
  if value == 'true' or value == '1' then
    return true
  elseif value == 'false' or value == '0' then
    return false
  end
  return nil
end

local rows = CsvLoader.read_rows('data_csv/by_feature/common/attr_defs.csv')

local list = {}
local by_name = {}
local aliases = {}

for _, row in ipairs(rows) do
  local name = row.name
  if name and name ~= '' then
    local def = {
      name = name,
      category = CATEGORIES[row.category] or row.category,
      order = tonumber(row.order) or 999,
      format = row.format or 'integer',
      is_ratio = to_boolean(row.is_ratio) or false,
      derived_output = to_boolean(row.derived_output) or false,
      persist = to_boolean(row.persist) ~= false,
      growth_kind = row.growth_kind or nil,
    }
    list[#list + 1] = def
    by_name[name] = def
  end
end

table.sort(list, function(a, b)
  if a.category ~= b.category then
    return a.category < b.category
  end
  return a.order < b.order
end)

return {
  CATEGORIES = CATEGORIES,
  list = list,
  by_name = by_name,
  aliases = aliases,
}
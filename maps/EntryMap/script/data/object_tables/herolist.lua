local JsonTableLoader = require 'data.object_tables.editor_json_table'
local helpers = require 'entry_objects.helpers'

local rows = JsonTableLoader.read_rows('herolist')

local function to_optional_number(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local list = {}
for index, row in ipairs(rows) do
  local hero_name = row['英雄名称']
  if hero_name and hero_name ~= '' then
    list[#list + 1] = {
      id = string.format('herolist_%03d', index),
      order_index = index,
      hero_name = tostring(hero_name),
      talent_skill = row['天赋技能'] and tostring(row['天赋技能']) or '',
      star_effect = row['效果'] and tostring(row['效果']) or '',
      awaken_effect = row['觉醒效果'] and tostring(row['觉醒效果']) or '',
      hero_model = to_optional_number(row['英雄模型']),
      skill_icon = to_optional_number(row['技能图片']),
    }
  end
end

local by_id = helpers.list_to_map(list)
local by_hero_name = {}
for _, entry in ipairs(list) do
  by_hero_name[entry.hero_name] = entry
end

return {
  list = list,
  by_id = by_id,
  by_hero_name = by_hero_name,
}

local EditorJsonTable = require 'data.object_tables.editor_json_table'
local helpers = require 'entry_objects.helpers'

local M = {}

local ATTR_KEY_BY_TABLE_NAME = {
  ['生命'] = '最大生命',
  ['生命值'] = '最大生命',
  ['攻击'] = '物理攻击',
  ['攻击力'] = '物理攻击',
  ['护甲'] = '物理防御',
}

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function split_pipe(value)
  local result = {}
  for part in tostring(value or ''):gmatch('[^|]+') do
    result[#result + 1] = trim(part)
  end
  return result
end

local function to_number(value)
  if value == nil or value == '' then
    return nil
  end
  return tonumber(value)
end

local function build_attr_overrides(attr_text, value_text)
  local attrs = split_pipe(attr_text)
  local values = split_pipe(value_text)
  local attr_overrides = {}
  local display_attrs = {}

  for index, attr_name in ipairs(attrs) do
    local attr_key = ATTR_KEY_BY_TABLE_NAME[attr_name] or attr_name
    local value = to_number(values[index])
    if attr_name ~= '' and value ~= nil then
      attr_overrides[attr_key] = value
      display_attrs[#display_attrs + 1] = {
        name = attr_name,
        key = attr_key,
        value = value,
      }
    end
  end

  return attr_overrides, display_attrs
end

local list = {}

for _, row in ipairs(EditorJsonTable.read_rows('monster_maintask')) do
  local id = trim(row.key)
  local spawn_unit_id = to_number(row['模型'])
  local target_count = math.max(1, tonumber(row['数量']) or 1)
  local attr_overrides, display_attrs = build_attr_overrides(row['属性'], row['属性数值'])
  local monster_name = trim(row['名称'])

  if id ~= '' then
    list[#list + 1] = {
      id = id,
      monster_name = monster_name ~= '' and monster_name or nil,
      objective_text = monster_name ~= '' and ('击杀' .. monster_name) or nil,
      target_count = target_count,
      spawn_unit_id = spawn_unit_id,
      is_boss_task = target_count <= 1 or (spawn_unit_id ~= nil and spawn_unit_id >= 400000),
      attr_overrides = next(attr_overrides) and attr_overrides or nil,
      display_attrs = display_attrs,
      reward_text = trim(row['奖励']),
      reward_value_text = trim(row['奖励数值']),
      source = 'monster_maintask',
    }
  end
end

table.sort(list, function(a, b)
  local a_chapter, a_order = tostring(a.id):match('^(%d+)%-(%d+)$')
  local b_chapter, b_order = tostring(b.id):match('^(%d+)%-(%d+)$')
  a_chapter = tonumber(a_chapter) or 0
  a_order = tonumber(a_order) or 0
  b_chapter = tonumber(b_chapter) or 0
  b_order = tonumber(b_order) or 0
  if a_chapter == b_chapter then
    return a_order < b_order
  end
  return a_chapter < b_chapter
end)

M.list = list
M.by_id = helpers.list_to_map(list)

return M

local EditorJsonTable = require 'data.object_tables.editor_json_table'

local M = {}

local DEFAULT_ICON = 906565

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

local function build_attr_lines(attr_text, value_text)
  local attrs = split_pipe(attr_text)
  local values = split_pipe(value_text)
  local lines = {}
  for index, attr_name in ipairs(attrs) do
    local value = values[index] or ''
    if attr_name ~= '' then
      lines[#lines + 1] = value ~= '' and string.format('%s +%s', attr_name, value) or attr_name
    end
  end
  return lines
end

local list = {}
local by_key = {}
local categories = {}
local category_seen = {}

local source_rows = EditorJsonTable.read_rows('shangchengdaojv')
if #source_rows <= 0 then
  source_rows = EditorJsonTable.read_rows('商城道具')
end

for index, row in ipairs(source_rows) do
  local name = trim(row['名称'])
  if name ~= '' then
    local quality = trim(row['品质'])
    local category = trim(row['页签'])
    if category == '' then
      category = quality ~= '' and quality or '全部'
    end
    local key = string.format('shop_item_%03d', index)
    local attr_lines = build_attr_lines(row['属性'], row['数值'])
    local spec = {
      key = key,
      node = key,
      index = index,
      title = name,
      icon = tonumber(row['图片']) or DEFAULT_ICON,
      default_icon = DEFAULT_ICON,
      attr_text = trim(row['属性']),
      value_text = trim(row['数值']),
      special_effect = trim(row['特殊效果']),
      obtain = trim(row['获取方式']),
      owned_text = trim(row['拥有数量']),
      stackable = row['能否堆叠'] == true or row['能否堆叠'] == 1 or row['能否堆叠'] == '1',
      quality = quality,
      category = category,
      attr_lines = attr_lines,
      line_1 = attr_lines[1] or '暂无属性',
      line_2 = attr_lines[2] or trim(row['特殊效果']),
      line_3 = trim(row['获取方式']),
      source = 'shop_item',
    }
    list[#list + 1] = spec
    by_key[key] = spec
    if category_seen[category] ~= true then
      category_seen[category] = true
      categories[#categories + 1] = category
    end
  end
end

M.list = list
M.by_key = by_key
M.categories = categories
M.default_icon = DEFAULT_ICON

return M

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

local PERCENT_ATTR_KEYWORDS = {
  '加成',
  '增幅',
  '伤害',
  '减免',
  '暴率',
  '暴伤',
  '暴击',
  '攻速',
  '速度',
  '概率',
  '几率',
  '收益',
  '效果',
}

local function is_percent_attr(attr_name)
  local name = tostring(attr_name or '')
  for _, keyword in ipairs(PERCENT_ATTR_KEYWORDS) do
    if name:find(keyword, 1, true) then
      return true
    end
  end
  return false
end

local function format_attr_value(attr_name, value_text)
  local text = trim(value_text)
  if text == '' then
    return text
  end
  if text:find('%%', 1, true) then
    return text
  end
  if is_percent_attr(attr_name) then
    return text .. '%'
  end
  return text
end

local function build_attr_lines(attr_text, value_text)
  local attrs = split_pipe(attr_text)
  local values = split_pipe(value_text)
  local lines = {}
  for index, attr_name in ipairs(attrs) do
    local value = format_attr_value(attr_name, values[index] or '')
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
local primary_tabs = {}
local primary_seen = {}
local categories_by_primary = {}
local category_seen_by_primary = {}

local function resolve_primary_tab(row)
  return trim(row['一级页签'] or row['一级页签 '] or row['一级标签'] or row['一级分类'])
end

local function resolve_secondary_tab(row)
  return trim(row['二级页签'] or row['页签'] or row['二级标签'] or row['二级分类'])
end

local function append_source_rows(target, table_name, fallback_primary)
  local rows = EditorJsonTable.read_rows(table_name)
  for index, row in ipairs(rows or {}) do
    target[#target + 1] = {
      row = row,
      table_name = table_name,
      row_index = index,
      fallback_primary = fallback_primary,
    }
  end
end

local source_rows = {}
append_source_rows(source_rows, 'tongyongcundang', '通用存档')
append_source_rows(source_rows, '通用存档', '通用存档')
append_source_rows(source_rows, 'shangchengdaojv', '商城道具')
append_source_rows(source_rows, '商城道具', '商城道具')

local primary_tab = ''
local row_fingerprint_seen = {}

for index, source in ipairs(source_rows) do
  local row = source.row or {}
  local name = trim(row['名称'])
  if name ~= '' then
    local primary = resolve_primary_tab(row)
    if primary == '' then
      primary = source.fallback_primary or '地图商城'
    end
    if primary_tab == '' and primary ~= '' then
      primary_tab = primary
    end
    local quality = trim(row['品质'])
    local category = resolve_secondary_tab(row)
    if category == '' then
      category = quality ~= '' and quality or '全部'
    end
    local fingerprint = table.concat({
      name,
      primary,
      category,
      trim(row['属性']),
      trim(row['数值']),
      trim(row['特殊效果'] or row['额外效果字符串']),
      trim(row['获取方式']),
    }, '|')
    if row_fingerprint_seen[fingerprint] == true then
      goto continue
    end
    row_fingerprint_seen[fingerprint] = true

    local key = string.format('shop_item_%s_%03d_%03d', source.table_name or 'unknown', source.row_index or 0, index)
    local attr_lines = build_attr_lines(row['属性'], row['数值'])
    local spec = {
      key = key,
      node = key,
      index = index,
      title = name,
      icon = tonumber(row['图片']) or tonumber(row['图标']) or DEFAULT_ICON,
      default_icon = DEFAULT_ICON,
      attr_text = trim(row['属性']),
      value_text = trim(row['数值']),
      special_effect = trim(row['特殊效果'] or row['额外效果字符串']),
      obtain = trim(row['获取方式']),
      owned_text = trim(row['拥有数量'] or row['是否初始解锁']),
      stackable = row['能否堆叠'] == true or row['能否堆叠'] == 1 or row['能否堆叠'] == '1' or row['能否堆叠'] == 'true',
      quality = quality,
      primary = primary,
      category = category,
      attr_lines = attr_lines,
      line_1 = attr_lines[1] or '暂无属性',
      line_2 = attr_lines[2] or trim(row['特殊效果'] or row['额外效果字符串']),
      line_3 = trim(row['获取方式']),
      source = source.table_name or 'shop_item',
    }
    list[#list + 1] = spec
    by_key[key] = spec

    if primary_seen[primary] ~= true then
      primary_seen[primary] = true
      primary_tabs[#primary_tabs + 1] = primary
    end

    if categories_by_primary[primary] == nil then
      categories_by_primary[primary] = {}
      category_seen_by_primary[primary] = {}
    end
    if category_seen_by_primary[primary][category] ~= true then
      category_seen_by_primary[primary][category] = true
      categories_by_primary[primary][#categories_by_primary[primary] + 1] = category
    end

    if category_seen[category] ~= true then
      category_seen[category] = true
      categories[#categories + 1] = category
    end
  end
  ::continue::
end

M.list = list
M.by_key = by_key
M.categories = categories
M.default_icon = DEFAULT_ICON
M.primary_tab = primary_tab ~= '' and primary_tab or '地图商城'
M.primary_tabs = primary_tabs
M.categories_by_primary = categories_by_primary

return M

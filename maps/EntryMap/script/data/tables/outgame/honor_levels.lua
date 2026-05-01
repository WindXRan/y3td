local EditorJsonTable = require 'data.tables.editor_json_table'

local M = {}

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

local function to_bool(value)
  return value == true or value == 1 or value == '1' or value == 'true' or value == 'TRUE'
end

local function build_attr_lines(attr_text, value_text)
  local attrs = split_pipe(attr_text)
  local values = split_pipe(value_text)
  local lines = {}
  for index, attr_name in ipairs(attrs) do
    local number_text = format_attr_value(attr_name, values[index] or '')
    if attr_name ~= '' then
      lines[#lines + 1] = number_text ~= '' and string.format('%s +%s', attr_name, number_text) or attr_name
    end
  end
  return lines
end

local list = {}
local by_key = {}

local function resolve_primary_tab(row)
  return trim(row['一级页签'] or row['一级页签 '] or row['一级标签'] or row['一级分类'])
end

local function resolve_secondary_tab(row)
  return trim(row['二级页签'] or row['页签'] or row['二级标签'] or row['二级分类'])
end

local function is_honor_row(row)
  local primary = resolve_primary_tab(row)
  local secondary = resolve_secondary_tab(row)
  local name = trim(row['名称'])
  if name == '' then
    return false
  end
  return primary == '通用存档' or secondary == '荣誉等级' or name:find('荣誉', 1, true) ~= nil
end

local function find_honor_rows(source_rows)
  local rows = {}
  for _, row in ipairs(source_rows or {}) do
    if is_honor_row(row) then
      rows[#rows + 1] = row
    end
  end
  return rows
end

local function pick_source_rows()
  local candidates = {
    EditorJsonTable.read_rows('tongyongcundang'),
    EditorJsonTable.read_rows('通用存档'),
    EditorJsonTable.read_rows('shangchengdaojv_rongyudengji'),
    EditorJsonTable.read_rows('商城道具-荣誉等级'),
  }
  for _, rows in ipairs(candidates) do
    local matched = find_honor_rows(rows)
    if #matched > 0 then
      return matched
    end
  end
  return {}
end

local source_rows = pick_source_rows()

for index, row in ipairs(source_rows) do
  local level = tonumber(tostring(row['名称'] or ''):match('(%d+)')) or index
  local key = string.format('honor_level_%d', level)
  local attr_lines = build_attr_lines(row['属性'], row['数值'])
  local spec = {
    key = key,
    node = key,
    level = level,
    title = trim(row['名称']) ~= '' and trim(row['名称']) or string.format('荣誉%d级', level),
    icon = tonumber(row['图标']) or tonumber(row['图片']) or nil,
    quality = trim(row['品质']),
    obtain = trim(row['获取方式']),
    extra_effect = trim(row['额外效果字符串']),
    initial_unlocked = to_bool(row['是否初始解锁']),
    attr_lines = attr_lines,
    line_1 = attr_lines[1] or '荣誉等级奖励',
    line_2 = attr_lines[2] or trim(row['获取方式']),
    line_3 = attr_lines[3] or '',
    glyph = tostring(level),
    source = 'honor_level',
  }
  list[#list + 1] = spec
  by_key[key] = spec
end

table.sort(list, function(left, right)
  return (left.level or 0) < (right.level or 0)
end)

M.list = list
M.by_key = by_key

return M


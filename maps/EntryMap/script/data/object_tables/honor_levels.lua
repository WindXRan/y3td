local EditorJsonTable = require 'data.object_tables.editor_json_table'

local M = {}

local FALLBACK_ROWS = {
  { ['名称'] = '荣誉1级', ['图标'] = 131360, ['属性'] = '生命值|生命成长', ['数值'] = '300|10', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到100', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉2级', ['图标'] = 131360, ['属性'] = '攻击力|攻击成长', ['数值'] = '10|1', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到300', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉3级', ['图标'] = 131360, ['属性'] = '金币加成|经验加成', ['数值'] = '3|3', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉4级', ['图标'] = 131360, ['属性'] = '攻击加成|生命加成', ['数值'] = '3|3', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到1000', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉5级', ['图标'] = 131360, ['属性'] = '物理暴伤|法术暴伤', ['数值'] = '5|5', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到1500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉6级', ['图标'] = 131360, ['属性'] = '大招伤害|射箭伤害', ['数值'] = '3|3', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到2000', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉7级', ['图标'] = 131360, ['属性'] = '物理伤害|法术伤害', ['数值'] = '3|3', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到2500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉8级', ['图标'] = 131360, ['属性'] = '物理暴率|法术暴率', ['数值'] = '2|2', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到3500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉9级', ['图标'] = 131360, ['属性'] = '力量加成|敏捷加成|智力加成', ['数值'] = '3|3|3', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到4500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉10级', ['图标'] = 131360, ['属性'] = '开局木头|最终伤害|最终减免', ['数值'] = '200|3|1', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到5500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉11级', ['图标'] = 131360, ['属性'] = '对BOSS伤害', ['数值'] = '4', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到7500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉12级', ['图标'] = 131360, ['属性'] = '对精英伤害|对小怪伤害', ['数值'] = '4|4', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到9500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉13级', ['图标'] = 131360, ['属性'] = '金币加成', ['数值'] = '5', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到11500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉14级', ['图标'] = 131360, ['属性'] = '物理伤害|法术伤害', ['数值'] = '4|4', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到13500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉15级', ['图标'] = 131360, ['属性'] = '经验加成', ['数值'] = '5', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到15500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉16级', ['图标'] = 131360, ['属性'] = '力量加成|敏捷加成|智力加成', ['数值'] = '4|4|4', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到17500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉17级', ['图标'] = 131360, ['属性'] = '最终伤害', ['数值'] = '5', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到17500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉18级', ['图标'] = 131360, ['属性'] = '攻击加成', ['数值'] = '5', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到17500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉19级', ['图标'] = 131360, ['属性'] = '对BOSS伤害', ['数值'] = '5', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到17500', ['是否初始解锁'] = '1' },
  { ['名称'] = '荣誉20级', ['图标'] = 131360, ['属性'] = '最终伤害|最终减免', ['数值'] = '5|1', ['品质'] = 'SSR', ['获取方式'] = '荣誉积分达到17500', ['是否初始解锁'] = '1' },
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

local function to_bool(value)
  return value == true or value == 1 or value == '1' or value == 'true' or value == 'TRUE'
end

local function build_attr_lines(attr_text, value_text)
  local attrs = split_pipe(attr_text)
  local values = split_pipe(value_text)
  local lines = {}
  for index, attr_name in ipairs(attrs) do
    local number_text = values[index] or ''
    if attr_name ~= '' then
      lines[#lines + 1] = number_text ~= '' and string.format('%s +%s', attr_name, number_text) or attr_name
    end
  end
  return lines
end

local list = {}
local by_key = {}

local source_rows = EditorJsonTable.read_rows('shangchengdaojv_rongyudengji')
if #source_rows <= 0 then
  source_rows = EditorJsonTable.read_rows('商城道具-荣誉等级')
end
if #source_rows <= 0 then
  source_rows = FALLBACK_ROWS
end

for index, row in ipairs(source_rows) do
  local level = tonumber(tostring(row['名称'] or ''):match('(%d+)')) or index
  local key = string.format('honor_level_%d', level)
  local attr_lines = build_attr_lines(row['属性'], row['数值'])
  local spec = {
    key = key,
    node = key,
    level = level,
    title = trim(row['名称']) ~= '' and trim(row['名称']) or string.format('荣誉%d级', level),
    icon = tonumber(row['图标']) or nil,
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

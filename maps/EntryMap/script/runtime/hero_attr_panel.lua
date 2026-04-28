local M = {}

local CORE_ATTRS = {
  ['攻击'] = true,
  ['攻击白字'] = true,
  ['攻击绿字'] = true,
  ['攻击结算值'] = true,
  ['攻击范围'] = true,
  ['攻击速度'] = true,
  ['生命'] = true,
  ['生命结算值'] = true,
  ['护甲'] = true,
  ['护甲白字'] = true,
  ['护甲绿字'] = true,
  ['护甲结算值'] = true,
  ['力量'] = true,
  ['力量白字'] = true,
  ['力量绿字'] = true,
  ['敏捷'] = true,
  ['敏捷白字'] = true,
  ['敏捷绿字'] = true,
  ['智力'] = true,
  ['智力白字'] = true,
  ['智力绿字'] = true,
  ['最终攻击'] = true,
  ['最终生命'] = true,
  ['最终护甲'] = true,
  ['物理暴击'] = true,
  ['物理暴伤'] = true,
  ['命中'] = true,
  ['物理吸血'] = true,
}

local function round_number(value)
  return math.floor((value or 0) + 0.5)
end

local function format_number(value, digits)
  local number = tonumber(value) or 0
  digits = digits or 0
  if digits <= 0 then
    return tostring(round_number(number))
  end
  local fmt = '%.' .. tostring(digits) .. 'f'
  local text = string.format(fmt, number)
  text = string.gsub(text, '(%..-)0+$', '%1')
  text = string.gsub(text, '%.$', '')
  return text
end

local function format_value(def, value)
  local format_kind = def and def.format or 'fixed1'
  if format_kind == 'integer' then
    return format_number(value, 0)
  end
  if format_kind == 'fixed2' then
    return format_number(value, 2)
  end
  if format_kind == 'fixed1' then
    return format_number(value, 1)
  end
  if format_kind == 'percent' or format_kind == 'percent_or_zero' then
    local ratio = tonumber(value) or 0
    if math.abs(ratio) <= 1 then
      ratio = ratio * 100
    end
    return format_number(ratio, 1) .. '%'
  end
  return format_number(value, 1)
end

local function should_show_attr(def, value)
  local number = tonumber(value) or 0
  if def.name == '生命白字' or def.name == '生命绿字' then
    return false
  end
  if CORE_ATTRS[def.name] then
    return true
  end
  if def.derived_output then
    return number ~= 0
  end
  return number ~= 0
end

local function read_value(snapshot, get_fallback_value, name)
  local value = snapshot and snapshot[name] or nil
  if value == nil and get_fallback_value then
    value = get_fallback_value(name)
  end
  return tonumber(value) or 0
end

local function format_named_value(snapshot, defs, get_fallback_value, name, label)
  local def = defs.by_name[name] or { name = name, format = 'fixed1' }
  return string.format('%s：%s', label or name, format_value(def, read_value(snapshot, get_fallback_value, name)))
end

local function pad_right(text, width)
  text = tostring(text or '')
  local len = #text
  if len >= width then
    return text
  end
  return text .. string.rep(' ', width - len)
end

local function join_columns(columns, separator)
  separator = separator or '    '
  local max_rows = 0
  for _, column in ipairs(columns) do
    max_rows = math.max(max_rows, #column.lines)
  end

  local result = {}
  for row = 1, max_rows do
    local parts = {}
    for _, column in ipairs(columns) do
      parts[#parts + 1] = pad_right(column.lines[row] or '', column.width or 18)
    end
    result[#result + 1] = table.concat(parts, separator):gsub('%s+$', '')
  end
  return result
end

local function build_runtime_attr_lines(snapshot, defs, get_fallback_value)
  local left = {
    format_named_value(snapshot, defs, get_fallback_value, '每秒攻击', '攻击成长'),
    format_named_value(snapshot, defs, get_fallback_value, '每秒生命', '生命成长'),
    format_named_value(snapshot, defs, get_fallback_value, '攻击范围'),
    format_named_value(snapshot, defs, get_fallback_value, '多重数量'),
    format_named_value(snapshot, defs, get_fallback_value, '生命恢复'),
    format_named_value(snapshot, defs, get_fallback_value, '攻击速度'),
    format_named_value(snapshot, defs, get_fallback_value, '闪避', '闪避概率'),
    format_named_value(snapshot, defs, get_fallback_value, '命中', '命中概率'),
  }

  local middle = {
    format_named_value(snapshot, defs, get_fallback_value, '护甲穿透'),
    format_named_value(snapshot, defs, get_fallback_value, '物理暴击'),
    format_named_value(snapshot, defs, get_fallback_value, '物理暴伤'),
    format_named_value(snapshot, defs, get_fallback_value, '魔法暴击'),
    format_named_value(snapshot, defs, get_fallback_value, '魔法暴伤'),
    format_named_value(snapshot, defs, get_fallback_value, '普攻伤害', '射箭伤害'),
    format_named_value(snapshot, defs, get_fallback_value, '物理伤害', '物理增伤'),
    format_named_value(snapshot, defs, get_fallback_value, '魔法伤害', '法术增伤'),
    format_named_value(snapshot, defs, get_fallback_value, '最终伤害'),
    format_named_value(snapshot, defs, get_fallback_value, '伤害减免', '最终减免'),
  }

  local right = {
    format_named_value(snapshot, defs, get_fallback_value, '杀敌经验', '经验加成'),
    format_named_value(snapshot, defs, get_fallback_value, '杀敌金币', '金币加成'),
    format_named_value(snapshot, defs, get_fallback_value, '挑战伤害', 'BOSS增伤'),
    format_named_value(snapshot, defs, get_fallback_value, '精控伤害', '精英增伤'),
    format_named_value(snapshot, defs, get_fallback_value, '所有伤害', '全伤增幅'),
    format_named_value(snapshot, defs, get_fallback_value, '技能伤害', '技能增伤'),
    format_named_value(snapshot, defs, get_fallback_value, '无视护甲'),
    format_named_value(snapshot, defs, get_fallback_value, '物理吸血'),
  }

  return join_columns({
    { lines = left, width = 22 },
    { lines = middle, width = 22 },
    { lines = right, width = 22 },
  }, '  ')
end

local function build_growth_rule_lines()
  return {
    '每1点力量',
    '增加5攻击力',
    '增加1生命值',
    '增加0.1%最大生命',
    '',
    '每1点敏捷',
    '增加5攻击力',
    '增加0.1%物理伤害',
    '',
    '每1点智力',
    '增加5攻击力',
    '增加0.1%法术伤害',
  }
end

function M.build_chunks(snapshot, defs, get_fallback_value)
  if not snapshot then
    return { '属性面板暂不可用' }
  end

  local attr_lines = build_runtime_attr_lines(snapshot, defs, get_fallback_value)
  local growth_lines = build_growth_rule_lines()
  local rows = {
    '属性面板',
    '',
  }

  local max_rows = math.max(#attr_lines, #growth_lines)
  for index = 1, max_rows do
    local left = attr_lines[index] or ''
    local right = growth_lines[index] or ''
    if right ~= '' then
      rows[#rows + 1] = pad_right(left, 72) .. right
    else
      rows[#rows + 1] = left
    end
  end

  return { table.concat(rows, '\n') }
end

return M

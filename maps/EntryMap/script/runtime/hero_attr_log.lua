local M = {}

local LOG_ATTR_ORDER = {
  '攻击',
  '攻击白字',
  '攻击绿字',
  '攻击速度',
  '攻击范围',
  '生命',
  '护甲',
  '护甲白字',
  '护甲绿字',
  '力量',
  '力量白字',
  '力量绿字',
  '敏捷',
  '敏捷白字',
  '敏捷绿字',
  '智力',
  '智力白字',
  '智力绿字',
  '最终攻击',
  '最终生命',
  '最终护甲',
  '攻击结算值',
  '生命结算值',
  '护甲结算值',
}

local function round_number(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local function format_value(name, value)
  local number = tonumber(value) or 0
  if name == '最终攻击' or name == '最终生命' or name == '最终护甲' then
    if math.abs(number) <= 1 then
      number = number * 100
    end
    return string.format('%d%%', round_number(number))
  end
  return tostring(round_number(number))
end

function M.build_summary(label, snapshot, extra)
  local parts = { string.format('[hero_attr] %s', tostring(label or 'snapshot')) }
  for _, name in ipairs(LOG_ATTR_ORDER) do
    parts[#parts + 1] = string.format('%s=%s', name, format_value(name, snapshot and snapshot[name] or 0))
  end
  if extra and extra ~= '' then
    parts[#parts + 1] = tostring(extra)
  end
  return table.concat(parts, ' | ')
end

function M.emit(label, snapshot, extra)
  local line = M.build_summary(label, snapshot, extra)
  if log and log.info then
    log.info(line)
    return
  end
  print(line)
end

return M

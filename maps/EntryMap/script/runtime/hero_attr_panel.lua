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

function M.build_chunks(snapshot, defs, get_fallback_value)
  if not snapshot then
    return { '属性面板暂不可用' }
  end

  local category_order = {
    defs.categories.DAMAGE,
    defs.categories.DEFENSE,
    defs.categories.RESOURCE,
    defs.categories.AMPLIFY,
    defs.categories.OTHER,
  }

  local lines = {
    '==========',
    '英雄属性面板',
    '==========',
  }

  for _, category in ipairs(category_order) do
    local category_lines = {}
    local entries = defs.sorted_by_category[category] or {}
    for _, def in ipairs(entries) do
      local value = snapshot[def.name]
      if value == nil and get_fallback_value then
        value = get_fallback_value(def.name)
      end
      if should_show_attr(def, value) then
        category_lines[#category_lines + 1] = string.format('%s: %s', tostring(def.name), format_value(def, value))
      end
    end
    if #category_lines > 0 then
      lines[#lines + 1] = '[' .. tostring(category) .. ']'
      for _, line in ipairs(category_lines) do
        lines[#lines + 1] = line
      end
    end
  end

  local chunks = {}
  local chunk_lines = {}
  local max_lines_per_chunk = 12
  for _, line in ipairs(lines) do
    chunk_lines[#chunk_lines + 1] = line
    if #chunk_lines >= max_lines_per_chunk then
      chunks[#chunks + 1] = table.concat(chunk_lines, '\n')
      chunk_lines = {}
    end
  end
  if #chunk_lines > 0 then
    chunks[#chunks + 1] = table.concat(chunk_lines, '\n')
  end
  return chunks
end

return M

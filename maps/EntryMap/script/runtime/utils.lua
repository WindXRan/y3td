-- 委托 y3.util 的工具函数层，仅做 nil 安全兼容和项目特有函数
local M = {}
local U = y3.util

-- === 委托 y3.util 的函数（加 nil 安全兼容） ===

function M.clone_table(source)
  local result = {}
  for key, value in pairs(source or {}) do
    result[key] = value
  end
  return result
end

function M.deep_clone(source)
  return U.deepCopy(source or {}, nil)
end

function M.clone_point(point)
  if not point or not point.move then
    return nil
  end
  return point:move()
end

function M.table_size(tbl)
  return U.countTable(tbl or {})
end

function M.table_keys(tbl)
  return U.keysOf(tbl or {})
end

function M.table_values(tbl)
  return U.valuesOf(tbl or {})
end

function M.array_contains(arr, value)
  return U.arrayHas(arr or {}, value)
end

function M.array_remove(arr, value)
  for i = #arr, 1, -1 do
    if arr[i] == value then
      table.remove(arr, i)
      return true
    end
  end
  return false
end

function M.string_starts_with(str, prefix)
  return U.stringStartWith(tostring(str or ''), prefix, false)
end

function M.string_ends_with(str, suffix)
  return U.stringEndWith(tostring(str or ''), suffix, false)
end

function M.string_split(str, delimiter)
  return U.split(tostring(str or ''), delimiter)
end

function M.string_trim(str)
  return U.trim(tostring(str or ''))
end

-- === 项目特有函数 ===

function M.append_line(lines, text)
  if text and text ~= '' then
    lines[#lines + 1] = text
  end
end

function M.bool_label(value)
  return value and '是' or '否'
end

function M.format_percent(value)
  if value == nil then
    return nil
  end
  return string.format('%d%%', math.floor((tonumber(value) or 0) * 100 + 0.5))
end

function M.append_number_line(lines, label, value, suffix)
  if value ~= nil then
    lines[#lines + 1] = string.format('%s：%s%s', label, tostring(value), suffix or '')
  end
end

function M.build_attr_lines(attr)
  local result = {}
  for key, value in pairs(attr or {}) do
    local number_value = tonumber(value) or 0
    local sign = number_value >= 0 and '+' or ''
    result[#result + 1] = string.format('%s %s%s', tostring(key), sign, tostring(value))
  end
  table.sort(result)
  return result
end

function M.contains_any(content, patterns)
  for _, pattern in ipairs(patterns or {}) do
    if string.find(tostring(content or ''), pattern, 1, true) then
      return true
    end
  end
  return false
end

function M.is_ui_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

function M.is_empty_or_whitespace(str)
  return str == nil or str == '' or str:match('^%s*$') ~= nil
end

function M.clamp(value, min, max)
  return math.max(min, math.min(max, value))
end

function M.round(value, decimals)
  decimals = decimals or 0
  local multiplier = 10 ^ decimals
  return math.floor(value * multiplier + 0.5) / multiplier
end

function M.try_call(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok then
    return true, result
  end
  return false, result
end

function M.safe_call(fn, ...)
  local args = {...}
  return function()
    return M.try_call(fn, unpack(args))
  end
end

return M

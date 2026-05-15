local M = {}
local Json = nil

local function get_json()
  if not Json then
    Json = require 'y3.tools.json'
  end
  return Json
end

local function get_script_root()
  local source = debug.getinfo(1, 'S').source or ''
  local path = source:gsub('^@', '')
  local root = path:match('^(.*[/\\])data[/\\]csv_loader%.lua$')
  if root then
    return (root:gsub('[/\\]+$', ''))
  end
  return 'maps/EntryMap/script'
end

local SCRIPT_ROOT = get_script_root()
local warned_missing_paths = {}
local warned_invalid_paths = {}

local file_cache = {}

local function is_absolute_path(path)
  return path:match('^%a:[/\\]') ~= nil
      or path:match('^[/\\][/\\]') ~= nil
end

local function resolve_path(path)
  if is_absolute_path(path) then
    return path
  end
  if path:match('^maps[/\\]EntryMap[/\\]script[/\\]') then
    return path
  end
  return SCRIPT_ROOT .. '/' .. path
end

local function strip_utf8_bom(value)
  if type(value) ~= 'string' then
    return value
  end
  if value:sub(1, 3) == '\239\187\191' then
    return value:sub(4)
  end
  return value
end

local function warn_once(registry, key, message)
  if registry[key] then
    return
  end
  registry[key] = true
  if log and log.warn then
    log.warn(message)
  else
    print(message)
  end
end

local function parse_csv_line_fast(line)
  local result = {}
  local len = #line
  local i = 1
  local current = {}

  while i <= len do
    local c = line:sub(i, i)
    if c == '"' then
      i = i + 1
      while i <= len do
        local next_c = line:sub(i, i)
        if next_c == '"' then
          local peek = line:sub(i + 1, i + 1)
          if peek == '"' then
            current[#current + 1] = '"'
            i = i + 2
          else
            break
          end
        else
          current[#current + 1] = next_c
          i = i + 1
        end
      end
      result[#result + 1] = table.concat(current)
      current = {}
      i = i + 1
      if line:sub(i, i) == ',' then
        i = i + 1
      end
    elseif c == ',' then
      result[#result + 1] = table.concat(current)
      current = {}
      i = i + 1
    else
      current[#current + 1] = c
      i = i + 1
    end
  end

  if #current > 0 then
    result[#result + 1] = table.concat(current)
  end

  -- 处理 CSV 末尾逗号产生的空字段（例如 "a,b,c," → 应有 4 个字段，最后一个是空字符串）
  if line:sub(-1, -1) == ',' then
    result[#result + 1] = ''
  end

  for j = 1, #result do
    result[j] = result[j] and result[j]:gsub('^%s+', ''):gsub('%s+$', '') or ''
  end

  return result
end

local function read_rows_safe(path, optional)
  local resolved = resolve_path(path)

  if file_cache[resolved] then
    local cached = file_cache[resolved]
    local copy = {}
    for i, row in ipairs(cached) do
      local row_copy = {}
      for k, v in pairs(row) do
        row_copy[k] = v
      end
      copy[i] = row_copy
    end
    return copy
  end

  local file, err = io.open(resolved, 'r')
  if not file then
    if not optional then
      warn_once(
        warned_missing_paths,
        resolved,
        string.format('[csv] required file missing: %s (%s)', resolved, tostring(err))
      )
    end
    return {}
  end

  local headers = nil
  local rows = {}
  local line_num = 0

  for line in file:lines() do
    line_num = line_num + 1
    line = strip_utf8_bom(line:gsub('\r$', ''))

    if line ~= '' and not line:match('^%s*#') then
      if not headers then
        headers = parse_csv_line_fast(line)
      else
        local values = parse_csv_line_fast(line)
        local row = {}
        local header_len = #headers

        for index = 1, header_len do
          row[headers[index]] = values[index] or ''
        end

        -- 跳过 __字段说明__ 注释行和空行的列数不匹配警告
        local first_value = tostring(row[headers[1]] or '')
        local is_field_comment = (first_value == '__字段说明__')

        if #values ~= header_len and not is_field_comment then
          warn_once(
            warned_invalid_paths,
            resolved .. ':' .. line_num,
            string.format('[csv] row %d has %d values but header has %d columns in %s', 
              line_num, #values, header_len, resolved)
          )
        end

        if header_len > 0 then
          if not is_field_comment and first_value ~= '' then
            rows[#rows + 1] = row
          end
        end
      end
    end
  end

  file:close()

  if not headers then
    if not optional then
      warn_once(
        warned_invalid_paths,
        resolved,
        string.format('[csv] file invalid (missing headers): %s', resolved)
      )
    end
    return {}
  end

  file_cache[resolved] = rows

  return rows
end

function M.read_rows(options)
  return read_rows_safe(options.path, false)
end

function M.read_rows_optional(options)
  return read_rows_safe(options.path, true)
end

local json_cache = {}

function M.read_json(options)
  if json_cache[options.path] then
    return json_cache[options.path]
  end

  local resolved = resolve_path(options.path)
  local file, err = io.open(resolved, 'r')
  if not file then
    warn_once(
      warned_missing_paths,
      resolved,
      string.format('[csv] JSON file missing: %s (%s)', resolved, tostring(err))
    )
    return nil
  end

  local content = file:read('*a')
  file:close()

  local json = get_json()
  local ok, data = pcall(json.decode, content)
  if not ok then
    warn_once(
      warned_invalid_paths,
      resolved,
      string.format('[csv] JSON parse error in %s: %s', resolved, tostring(data))
    )
    return nil
  end

  json_cache[options.path] = data
  return data
end

function M.read_json_optional(options)
  local resolved = resolve_path(options.path)
  local file, err = io.open(resolved, 'r')
  if not file then
    return nil
  end
  file:close()
  return M.read_json(options)
end

function M.read_rows_as_map(options)
  local id_key = options.id_field or 'skill_id'
  local rows = M.read_rows_optional(options)
  local result = {}

  for _, row in ipairs(rows) do
    local id = row[id_key]
    if id and id ~= '' and id ~= '__字段说明__' then
      result[id] = row
    end
  end

  return result
end

function M.read_rows_as_map_optional(options)
  local resolved = resolve_path(options.path)
  local file = io.open(resolved, 'r')
  if not file then
    return {}
  end
  file:close()
  return M.read_rows_as_map(options)
end

function M.clear_json_cache()
  json_cache = {}
end

function M.group_by(rows, key_field)
  local grouped = {}
  for _, row in ipairs(rows or {}) do
    local key = row[key_field]
    if key == nil or key == '' then
      error(string.format('[csv] missing group key "%s"', key_field))
    end
    grouped[key] = grouped[key] or {}
    grouped[key][#grouped[key] + 1] = row
  end
  return grouped
end

function M.to_number(value, default)
  if value == nil or value == '' then
    return default
  end
  local num = tonumber(value)
  return num ~= nil and num or default
end

function M.to_number_list(value, sep)
  if value == nil or value == '' then
    return {}
  end
  sep = sep or '[|,]'
  local result = {}
  for part in tostring(value):gmatch('[^' .. sep .. ']+') do
    local num = tonumber(part)
    if num then
      result[#result + 1] = num
    end
  end
  return result
end

function M.to_string_list(value, sep)
  if value == nil or value == '' then
    return {}
  end
  sep = sep or '[|,]'
  local result = {}
  for part in tostring(value):gmatch('[^' .. sep .. ']+') do
    part = part:gsub('^%s+', ''):gsub('%s+$', '')
    if part ~= '' then
      result[#result + 1] = part
    end
  end
  return result
end

function M.to_boolean(value)
  if value == nil or value == '' then
    return false
  end
  local lower = string.lower(tostring(value))
  return lower == 'true' or lower == '1' or lower == 'yes'
end

function M.list_to_map(list, key)
  local map = {}
  key = key or 'id'
  for _, row in ipairs(list or {}) do
    local k = row and row[key]
    if k ~= nil and k ~= '' then
      map[k] = row
    end
  end
  return map
end

function M.clear_cache()
  file_cache = {}
end

function M.clear_json_cache()
  json_cache = {}
end

function M.clear_all_caches()
  M.clear_cache()
  M.clear_json_cache()
end

function M.get_cache_info()
  local info = {
    csv_cached_files = {},
    csv_total_rows = 0,
    json_cached_files = {},
  }
  for path, rows in pairs(file_cache) do
    info.csv_cached_files[#info.csv_cached_files + 1] = path
    info.csv_total_rows = info.csv_total_rows + #rows
  end
  for path, _ in pairs(json_cache) do
    info.json_cached_files[#info.json_cached_files + 1] = path
  end
  return info
end

function M.process_rows(options)
  local rows = options.optional and M.read_rows_optional(options) or M.read_rows(options)
  local list = {}

  for _, row in ipairs(rows) do
    local ok, result = pcall(options.builder, row)
    if ok then
      list[#list + 1] = result
    else
      warn_once(warned_invalid_paths, options.path,
        string.format('[csv] row processing failed in %s: %s', options.path, tostring(result)))
    end
  end

  if options.order_key then
    table.sort(list, function(a, b)
      return (a[options.order_key] or 0) < (b[options.order_key] or 0)
    end)
  end

  return { list = list, by_id = M.list_to_map(list) }
end

return M

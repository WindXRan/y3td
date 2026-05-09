local M = {}

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
      i = i + 1
      if line:sub(i, i) == ',' then
        result[#result + 1] = table.concat(current)
        current = {}
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

        if header_len > 0 then
          local first_value = tostring(row[headers[1]] or '')
          if first_value ~= '__字段说明__' and first_value ~= '' then
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

function M.read_rows(path)
  return read_rows_safe(path, false)
end

function M.read_rows_optional(path)
  return read_rows_safe(path, true)
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

function M.get_cache_info()
  local info = {
    cached_files = {},
    total_rows = 0
  }
  for path, rows in pairs(file_cache) do
    info.cached_files[#info.cached_files + 1] = path
    info.total_rows = info.total_rows + #rows
  end
  return info
end

function M.process_rows(csv_path, order_key, builder, optional)
  local rows = optional and M.read_rows_optional(csv_path) or M.read_rows(csv_path)
  local list = {}

  for _, row in ipairs(rows) do
    local ok, result = pcall(builder, row)
    if ok then
      list[#list + 1] = result
    else
      warn_once(warned_invalid_paths, csv_path,
        string.format('[csv] row processing failed in %s: %s', csv_path, tostring(result)))
    end
  end

  if order_key then
    table.sort(list, function(a, b)
      return (a[order_key] or 0) < (b[order_key] or 0)
    end)
  end

  return { list = list, by_id = M.list_to_map(list) }
end

return M

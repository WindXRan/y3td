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

local function split_csv_line(line)
  local result = {}
  local buffer = {}
  local in_quotes = false
  local i = 1

  while i <= #line do
    local char = line:sub(i, i)
    if char == '"' then
      local next_char = line:sub(i + 1, i + 1)
      if in_quotes and next_char == '"' then
        buffer[#buffer + 1] = '"'
        i = i + 1
      else
        in_quotes = not in_quotes
      end
    elseif char == ',' and not in_quotes then
      result[#result + 1] = table.concat(buffer)
      buffer = {}
    else
      buffer[#buffer + 1] = char
    end
    i = i + 1
  end

  result[#result + 1] = table.concat(buffer)
  return result
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

local function read_rows_safe(path, optional)
  local resolved = resolve_path(path)
  local file, err = io.open(resolved, 'r')
  if not file then
    local level = optional and 'optional' or 'required'
    warn_once(
      warned_missing_paths,
      resolved,
      string.format('[csv] %s file missing, fallback to empty rows: %s (%s)', level, resolved, tostring(err))
    )
    return {}
  end

  local headers = nil
  local rows = {}

  for line in file:lines() do
    line = line:gsub('\r$', '')
    if line ~= '' then
      if not headers then
        headers = split_csv_line(line)
      else
        local values = split_csv_line(line)
        local row = {}
        for index, header in ipairs(headers) do
          row[header] = values[index] or ''
        end
        rows[#rows + 1] = row
      end
    end
  end

  file:close()

  if not headers then
    local level = optional and 'optional' or 'required'
    warn_once(
      warned_invalid_paths,
      resolved,
      string.format('[csv] %s file invalid (missing headers), fallback to empty rows: %s', level, resolved)
    )
    return {}
  end

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

return M

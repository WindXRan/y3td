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

function M.read_rows(path)
  local resolved = resolve_path(path)
  local file, err = io.open(resolved, 'r')
  if not file then
    error(string.format('[csv] failed to open %s: %s', resolved, tostring(err)))
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
    error(string.format('[csv] missing headers in %s', resolved))
  end

  return rows
end

function M.read_rows_optional(path)
  local resolved = resolve_path(path)
  local file, err = io.open(resolved, 'r')
  if not file then
    if not warned_missing_paths[resolved] then
      warned_missing_paths[resolved] = true
      local message = string.format('[csv] optional file missing, fallback to empty rows: %s (%s)', resolved, tostring(err))
      if log and log.warn then
        log.warn(message)
      else
        print(message)
      end
    end
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
    return {}
  end
  return rows
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

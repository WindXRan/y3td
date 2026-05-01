local M = {}

local function get_script_root()
  local source = debug.getinfo(1, 'S').source or ''
  local path = source:gsub('^@', '')
  local root = path:match('^(.*[/\\])data[/\\]object_tables[/\\]editor_json_table%.lua$')
  if root then
    return (root:gsub('[/\\]+$', ''))
  end
  return 'maps/EntryMap/script'
end

local SCRIPT_ROOT = get_script_root()

local TABLE_PATH_PATTERNS = {
  SCRIPT_ROOT .. '/data_csv/%s.csv',
  'maps/EntryMap/script/data_csv/%s.csv',
  'data_csv/%s.csv',
}

local cache = {}

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

local function strip_utf8_bom(value)
  if type(value) ~= 'string' then
    return value
  end
  return (value:gsub('^\239\187\191', ''))
end

local function read_csv_file(path)
  local handle = io.open(path, 'r')
  if not handle then
    return nil
  end

  local rows = {}
  for line in handle:lines() do
    line = line:gsub('\r$', '')
    if line ~= '' then
      rows[#rows + 1] = split_csv_line(line)
    end
  end
  handle:close()
  if #rows == 0 then
    return nil
  end

  if type(rows[1][1]) == 'string' then
    rows[1][1] = strip_utf8_bom(rows[1][1])
  end
  return rows
end

local function load_csv_table(table_name)
  if cache[table_name] ~= nil then
    return cache[table_name] or nil
  end

  for _, path_pattern in ipairs(TABLE_PATH_PATTERNS) do
    local rows = read_csv_file(string.format(path_pattern, table_name))
    if rows then
      cache[table_name] = rows
      return rows
    end
  end

  cache[table_name] = false
  return nil
end

local function is_empty_cell(value)
  return value == nil or value == ''
end

local TYPE_DECL_TOKENS = {
  ['string'] = true,
  ['number'] = true,
  ['int'] = true,
  ['float'] = true,
  ['bool'] = true,
  ['boolean'] = true,
  ['table'] = true,
  ['array'] = true,
}

local function is_helper_row(raw_row)
  if type(raw_row) ~= 'table' then
    return true
  end
  local first = tostring(raw_row[1] or '')
  if first == '__字段说明__' then
    return true
  end
  local has_any = false
  for _, value in ipairs(raw_row) do
    local text = tostring(value or '')
    if text ~= '' then
      has_any = true
      if not TYPE_DECL_TOKENS[string.lower(text)] then
        return false
      end
    end
  end
  return has_any
end

function M.read_rows(table_name)
  local raw_rows = load_csv_table(table_name)
  if type(raw_rows) ~= 'table' or type(raw_rows[1]) ~= 'table' then
    return {}
  end

  local headers = raw_rows[1]
  local rows = {}
  -- row 1: headers; compatible with optional helper rows (字段说明/类型声明)
  for row_index = 2, #raw_rows do
    local raw_row = raw_rows[row_index]
    if is_helper_row(raw_row) then
      goto continue
    end
    local row = {}
    local has_value = false

    for column_index, header in ipairs(headers) do
      if not is_empty_cell(header) then
        local value = raw_row and raw_row[column_index] or nil
        if not is_empty_cell(value) then
          row[tostring(header)] = value
          has_value = true
        end
      end
    end

    if has_value then
      rows[#rows + 1] = row
    end

    ::continue::
  end

  return rows
end

return M

local Json = require 'y3.tools.json'

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
local MAP_ROOT = SCRIPT_ROOT:gsub('[/\\]script$', '')

local TABLE_PATH_PATTERNS = {
  MAP_ROOT .. '/tables/%s.json',
  SCRIPT_ROOT .. '/../tables/%s.json',
  'maps/EntryMap/tables/%s.json',
  '../tables/%s.json',
  'tables/%s.json',
}

local cache = {}

local function read_text_file(path)
  local handle = io.open(path, 'r')
  if not handle then
    return nil
  end
  local content = handle:read('*a')
  handle:close()
  return content
end

local function load_json_table(table_name)
  if cache[table_name] ~= nil then
    return cache[table_name] or nil
  end

  for _, path_pattern in ipairs(TABLE_PATH_PATTERNS) do
    local content = read_text_file(string.format(path_pattern, table_name))
    if content and content ~= '' then
      local ok, data = pcall(Json.decode, content)
      if ok and type(data) == 'table' then
        cache[table_name] = data
        return data
      end
    end
  end

  cache[table_name] = false
  return nil
end

local function is_empty_cell(value)
  return value == nil or value == Json.null or value == ''
end

function M.read_rows(table_name)
  local data = load_json_table(table_name)
  local raw_rows = data
    and data.table_data
    and data.table_data.data
    or nil
  if type(raw_rows) ~= 'table' or type(raw_rows[1]) ~= 'table' then
    return {}
  end

  local headers = raw_rows[1]
  local rows = {}
  for row_index = 3, #raw_rows do
    local raw_row = raw_rows[row_index]
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
  end

  return rows
end

return M

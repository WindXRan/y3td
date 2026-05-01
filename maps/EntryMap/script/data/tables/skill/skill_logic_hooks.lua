local CsvLoader = require 'data.csv_loader'

local M = {
  by_key = {},
}

local function trim(v)
  return tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function is_enabled(raw)
  local s = string.lower(trim(raw))
  return s == '' or s == '1' or s == 'true'
end

for _, row in ipairs(CsvLoader.read_rows_optional('data_csv/skill_logic_hooks.csv')) do
  if is_enabled(row.enabled) then
    local key = trim(row.hook_key)
    if key ~= '' then
      M.by_key[key] = {
        hook_key = key,
        target_kind = trim(row.target_kind),
        target_name = trim(row.target_name),
        file_name = trim(row.file_name),
        function_name = trim(row.function_name),
        enabled = true,
        notes = trim(row.notes),
      }
    end
  end
end

function M.get_target_name(hook_key, fallback)
  local row = M.by_key[trim(hook_key)]
  if row and row.target_name ~= '' then
    return row.target_name
  end
  return fallback
end

function M.get_binding(hook_key)
  return M.by_key[trim(hook_key)]
end

return M

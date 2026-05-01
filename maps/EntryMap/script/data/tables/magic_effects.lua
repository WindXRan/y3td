local CsvLoader = require 'data.csv_loader'

local rows = CsvLoader.read_rows_optional('data_csv/magic_effects.csv')

local M = {
  list = {},
  by_id = {},
  by_scope = {},
}

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function parse_enabled(raw)
  local value = string.lower(trim(raw))
  return value == '' or value == '1' or value == 'true'
end

for _, row in ipairs(rows or {}) do
  if parse_enabled(row.enabled) then
    local scope = trim(row.scope)
    local target_name = trim(row.target_name)
    local entry = {
      id = trim(row.id),
      scope = scope,
      target_name = target_name,
      stack_duration = tonumber(row.stack_duration),
      max_stacks = tonumber(row.max_stacks),
      attack_per_stack = tonumber(row.attack_per_stack),
      attack_speed_per_stack = tonumber(row.attack_speed_per_stack),
      notes = trim(row.notes),
    }
    M.list[#M.list + 1] = entry
    if entry.id ~= '' then
      M.by_id[entry.id] = entry
    end
    if scope ~= '' and target_name ~= '' then
      M.by_scope[scope] = M.by_scope[scope] or {}
      M.by_scope[scope][target_name] = entry
    end
  end
end

return M

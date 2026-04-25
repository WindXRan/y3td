local CsvLoader = require 'data.csv_loader'

local root_rows = CsvLoader.read_rows('data_csv/bond_root_sets.csv')
local attr_rows = CsvLoader.read_rows('data_csv/bond_root_set_attr.csv')
local runtime_rows = CsvLoader.read_rows('data_csv/bond_root_set_runtime.csv')

local attr_groups = CsvLoader.group_by(attr_rows, 'root_id')
local runtime_groups = CsvLoader.group_by(runtime_rows, 'root_id')

local function build_phase_number_maps(rows, key_field)
  local result = {
    base = {},
    set = {},
  }

  for _, row in ipairs(rows or {}) do
    local phase = row.phase == 'set' and 'set' or 'base'
    local key = row[key_field]
    if key and key ~= '' then
      result[phase][key] = tonumber(row.value) or 0
    end
  end

  return result.base, result.set
end

local list = {}
local by_id = {}

for _, row in ipairs(root_rows) do
  local base_attr, set_attr = build_phase_number_maps(attr_groups[row.root_id], 'attr_name')
  local base_runtime, set_runtime = build_phase_number_maps(runtime_groups[row.root_id], 'runtime_key')

  local def = {
    root_id = row.root_id,
    required_count = tonumber(row.required_count) or 0,
    completion_mode = row.completion_mode ~= '' and row.completion_mode or 'consume_all',
    base_text = row.base_text ~= '' and row.base_text or nil,
    effect_text = row.effect_text ~= '' and row.effect_text or nil,
    base_attr = base_attr,
    base_runtime = base_runtime,
    set_attr = set_attr,
    set_runtime = set_runtime,
  }

  list[#list + 1] = def
  by_id[def.root_id] = def
end

return {
  list = list,
  by_id = by_id,
}

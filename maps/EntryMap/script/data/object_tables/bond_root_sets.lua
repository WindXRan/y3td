local CsvLoader = require 'data.csv_loader'

local root_rows = CsvLoader.read_rows('data_csv/bond_root_sets.csv')
local attr_rows = CsvLoader.read_rows('data_csv/bond_root_set_attr.csv')
local runtime_rows = CsvLoader.read_rows('data_csv/bond_root_set_runtime.csv')
local REQUIRED_BOND_COUNT = 30
local ATTR_AXES = { ['力量'] = true, ['智力'] = true, ['敏捷'] = true }
local ROUTE_AXES = { ['物理'] = true, ['法术'] = true, ['召唤'] = true }

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
local attr_axis_seen = {}
local route_axis_seen = {}

for _, row in ipairs(root_rows) do
  local base_attr, set_attr = build_phase_number_maps(attr_groups[row.root_id], 'attr_name')
  local base_runtime, set_runtime = build_phase_number_maps(runtime_groups[row.root_id], 'runtime_key')
  local attr_axis = tostring(row.attr_axis or ''):gsub('^%s+', ''):gsub('%s+$', '')
  local route_axis = tostring(row.route_axis or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if not ATTR_AXES[attr_axis] then
    error(string.format('bond_root_sets invalid attr_axis: root_id=%s attr_axis=%s', tostring(row.root_id), tostring(attr_axis)))
  end
  if not ROUTE_AXES[route_axis] then
    error(string.format('bond_root_sets invalid route_axis: root_id=%s route_axis=%s', tostring(row.root_id), tostring(route_axis)))
  end

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
    attr_axis = attr_axis,
    route_axis = route_axis,
  }

  list[#list + 1] = def
  by_id[def.root_id] = def
  attr_axis_seen[attr_axis] = true
  route_axis_seen[route_axis] = true
end

if #list ~= REQUIRED_BOND_COUNT then
  error(string.format('bond_root_sets count mismatch: expect=%d actual=%d', REQUIRED_BOND_COUNT, #list))
end

for axis, _ in pairs(ATTR_AXES) do
  if not attr_axis_seen[axis] then
    error(string.format('bond_root_sets missing attr axis: %s', axis))
  end
end

for axis, _ in pairs(ROUTE_AXES) do
  if not route_axis_seen[axis] then
    error(string.format('bond_root_sets missing route axis: %s', axis))
  end
end

return {
  list = list,
  by_id = by_id,
}

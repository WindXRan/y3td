local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local effect_rows = CsvLoader.read_rows_optional('data_csv/auto_active_effects.csv')
local attr_rows = CsvLoader.read_rows_optional('data_csv/auto_active_effect_attr.csv')
local attr_groups = CsvLoader.group_by(attr_rows, 'effect_id')

local OPTIONAL_NUMBER_FIELDS = {
  cooldown = true,
  range = true,
  radius = true,
  damage_ratio = true,
  chance = true,
  threshold_step = true,
  blast_radius = true,
  heal_ratio = true,
  counter_required = true,
  duration = true,
  attack_speed_bonus = true,
  modifier_key = true,
  hp_threshold = true,
  extra_hp_ratio = true,
  armor_reduction_ratio = true,
  attack_reduction_ratio = true,
}

local function to_optional_number(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local function build_attr(effect_id)
  local result = {}
  for _, row in ipairs(attr_groups[effect_id] or {}) do
    if row.attr_name ~= '' then
      result[row.attr_name] = tonumber(row.value) or 0
    end
  end
  return next(result) and result or nil
end

local list = {}
for _, row in ipairs(effect_rows) do
  local def = {
    id = row.id,
    source_type = row.source_type,
    source_id = row.source_id,
    trigger_type = row.trigger_type,
    vfx = row.vfx,
  }

  for field_name, _ in pairs(OPTIONAL_NUMBER_FIELDS) do
    def[field_name] = to_optional_number(row[field_name])
  end

  local attr = build_attr(row.id)
  if attr then
    def.attr = attr
  end

  list[#list + 1] = def
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
}


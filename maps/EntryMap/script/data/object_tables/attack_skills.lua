local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'
local SecondBatchBlueprints = require 'entry_objects.attack_skill_blueprints.second_batch_skills'
local SkillTaxonomy = require 'data.object_tables.attack_skill_taxonomy'

local skill_rows = CsvLoader.read_rows('data_csv/attack_skills.csv')
local vfx_rows = CsvLoader.read_rows('data_csv/attack_skill_vfx.csv')
local vfx_by_skill = CsvLoader.group_by(vfx_rows, 'skill_id')

local OPTIONAL_NUMBER_FIELDS = {
  default_slot = true,
  base_damage_ratio = true,
  base_cooldown = true,
  base_range = true,
  base_pierce = true,
  base_pierce_width = true,
  base_control_lock_time = true,
  base_knockback_distance = true,
  base_knockback_speed = true,
  base_explosion_ratio = true,
  base_explosion_radius = true,
  base_extra_targets = true,
  base_repeat_count = true,
  ui_icon = true,
  icon = true,
}

local OPTIONAL_VFX_NUMBER_FIELDS = {
  projectile_key = true,
  projectile_speed = true,
  projectile_time = true,
  target_distance = true,
  cast_particle = true,
  cast_scale = true,
  cast_time = true,
  impact_particle = true,
  impact_scale = true,
  impact_time = true,
  explosion_particle = true,
  explosion_scale = true,
  explosion_time = true,
  charge_particle = true,
  charge_scale = true,
  charge_time = true,
  chain_particle = true,
  chain_scale = true,
  chain_time = true,
  strike_delay = true,
}

local LEGACY_DAMAGE_TYPE_MAP = {
  ['物理'] = { damage_form = 'weapon', element = 'none', damage_label = '兵刃伤害' },
  ['法术'] = { damage_form = 'spell', element = 'none', damage_label = '术法伤害' },
}

local function to_optional_number(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local function build_vfx(skill_id)
  local row = (vfx_by_skill[skill_id] or {})[1]
  if not row then
    return {}
  end

  local result = {}
  for field_name, _ in pairs(OPTIONAL_VFX_NUMBER_FIELDS) do
    local value = to_optional_number(row[field_name])
    if value ~= nil then
      result[field_name] = value
    end
  end
  return result
end

local function build_damage_meta(row)
  local damage_form = row.damage_form
  local element = row.element
  local damage_label = row.damage_label

  if damage_form and damage_form ~= '' and element and element ~= '' and damage_label and damage_label ~= '' then
    return damage_form, element, damage_label
  end

  local fallback = LEGACY_DAMAGE_TYPE_MAP[row.damage_type]
  if fallback then
    return fallback.damage_form, fallback.element, fallback.damage_label
  end

  error(string.format('attack skill %s missing damage metadata', tostring(row.id)))
end

local function apply_taxonomy(def, skill_id)
  local taxonomy = SkillTaxonomy.by_id and SkillTaxonomy.by_id[skill_id] or nil
  if not taxonomy then
    return def
  end

  def.category = taxonomy.category
  def.cast_family = taxonomy.cast_family
  def.presentation_family = taxonomy.presentation_family
  def.eca_reference = taxonomy.eca_reference
  def.tactical_tags = taxonomy.tactical_tags
  return def
end

local list = {}
for _, row in ipairs(skill_rows) do
  local damage_form, element, damage_label = build_damage_meta(row)
  local def = {
    id = row.id,
    name = row.name,
    summary = row.summary,
    damage_type = row.damage_type,
    damage_form = damage_form,
    element = element,
    damage_label = damage_label,
    vfx = build_vfx(row.id),
  }

  for field_name, _ in pairs(OPTIONAL_NUMBER_FIELDS) do
    def[field_name] = to_optional_number(row[field_name])
  end

  apply_taxonomy(def, row.id)

  list[#list + 1] = def
end

local defs_by_id = helpers.list_to_map(list)
local vfx_by_id = helpers.build_field_map(list, 'vfx', {})

for _, blueprint in ipairs(SecondBatchBlueprints.list or {}) do
  if not defs_by_id[blueprint.id] then
    defs_by_id[blueprint.id] = {
      id = blueprint.id,
      name = blueprint.name,
      summary = blueprint.summary,
      damage_type = blueprint.damage_type,
      damage_form = blueprint.damage_form,
      element = blueprint.element,
      damage_label = blueprint.damage_label,
      ui_icon = blueprint.ui_icon or blueprint.icon,
      icon = blueprint.ui_icon or blueprint.icon,
      archetype = blueprint.archetype,
      category = nil,
      cast_family = nil,
      presentation_family = nil,
      eca_reference = nil,
      base_damage_ratio = blueprint.base and blueprint.base.damage_ratio or 0,
      base_cooldown = blueprint.base and blueprint.base.cooldown or 0,
      base_range = blueprint.base and blueprint.base.range or 0,
      base_pierce = blueprint.base and blueprint.base.pierce or 0,
      base_duration = blueprint.base and blueprint.base.duration or 0,
      base_radius = blueprint.base and blueprint.base.radius or 0,
      base_bounce = blueprint.base and blueprint.base.bounce or 0,
      evolution_name = blueprint.evolution and blueprint.evolution.name or nil,
      evolution_summary = blueprint.evolution and blueprint.evolution.summary or nil,
      vfx = build_vfx(blueprint.id),
    }
    apply_taxonomy(defs_by_id[blueprint.id], blueprint.id)
    vfx_by_id[blueprint.id] = defs_by_id[blueprint.id].vfx
  end
end

return {
  list = list,
  defs_by_id = defs_by_id,
  vfx_by_id = vfx_by_id,
  blueprints = SecondBatchBlueprints,
  blueprint_by_id = helpers.list_to_map(SecondBatchBlueprints.list),
}

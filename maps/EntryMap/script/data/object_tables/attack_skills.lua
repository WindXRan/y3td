local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'
local SecondBatchBlueprints = require 'data.object_tables.attack_skill_second_batch_blueprints'
local SkillTaxonomy = require 'data.object_tables.attack_skill_taxonomy'
local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'
local Json = require 'y3.tools.json'

local skill_rows = CsvLoader.read_rows_optional('data_csv/attack_skills.csv')

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

local VFX_MANIFEST_FIELD_MAP = {
  projectile_key = 'entry_projectile_id',
  projectile_speed = 'entry_projectile_speed',
  projectile_time = 'entry_projectile_time',
  target_distance = 'entry_target_distance',
  strike_delay = 'entry_strike_delay',
  cast_particle = 'entry_cast_effect_id',
  cast_scale = 'entry_cast_scale',
  cast_time = 'entry_cast_time',
  impact_particle = 'entry_impact_effect_id',
  impact_scale = 'entry_impact_scale',
  impact_time = 'entry_impact_time',
  explosion_particle = 'entry_explosion_effect_id',
  explosion_scale = 'entry_explosion_scale',
  explosion_time = 'entry_explosion_time',
  charge_particle = 'entry_charge_effect_id',
  charge_scale = 'entry_charge_scale',
  charge_time = 'entry_charge_time',
  chain_particle = 'entry_chain_effect_id',
  chain_scale = 'entry_chain_scale',
  chain_time = 'entry_chain_time',
}

local ABILITY_VISIBLE_STAGE_FIELD_MAP = {
  cast = 'cst_sfx_list',
  impact = 'hit_sfx_list',
  explosion = 'end_sfx_list',
  charge = 'sp_sfx_list',
  chain = 'bs_sfx_list',
}

local POSITIVE_ONLY_VFX_FIELDS = {
  projectile_key = true,
  cast_particle = true,
  impact_particle = true,
  explosion_particle = true,
  charge_particle = true,
  chain_particle = true,
}

local EDITOR_JSON_CACHE = {
  abilityall = {},
  projectileall = {},
}

local EDITOR_JSON_PATH_PATTERNS = {
  'maps/EntryMap/editor_table/%s/%s.json',
  'editor_table/%s/%s.json',
  '../editor_table/%s/%s.json',
}

local LEGACY_DAMAGE_TYPE_MAP = {
  ['物理'] = { damage_form = 'weapon', element = 'none', damage_label = '兵刃伤害' },
  ['法术'] = { damage_form = 'spell', element = 'none', damage_label = '术法伤害' },
}

local function unwrap_editor_kv_entry(raw)
  if type(raw) == 'table' and raw.value ~= nil then
    return raw.value
  end
  return raw
end

local function to_optional_number(raw)
  raw = unwrap_editor_kv_entry(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local function read_text_file(path)
  local handle = io.open(path, 'r')
  if not handle then
    return nil
  end
  local content = handle:read('*a')
  handle:close()
  return content
end

local function load_editor_json(table_name, object_key)
  if not table_name or not object_key then
    return nil
  end

  local cache = EDITOR_JSON_CACHE[table_name]
  if cache and cache[object_key] ~= nil then
    return cache[object_key] or nil
  end

  local content
  for _, path_pattern in ipairs(EDITOR_JSON_PATH_PATTERNS) do
    local path = string.format(path_pattern, table_name, tostring(object_key))
    content = read_text_file(path)
    if content then
      break
    end
  end

  if not content or content == '' then
    if cache then
      cache[object_key] = false
    end
    return nil
  end

  local ok, data = pcall(Json.decode, content)
  if not ok or type(data) ~= 'table' then
    if cache then
      cache[object_key] = false
    end
    return nil
  end

  if cache then
    cache[object_key] = data
  end
  return data
end

local function get_editor_object_data(table_name, object_key)
  if not table_name or not object_key then
    return nil
  end

  -- Runtime-generated manifests are synced into editor_table first.
  -- Prefer the local JSON so gameplay sees the latest generated values
  -- even if the editor object pool or GMP has not been hotfixed yet.
  local local_json_data = load_editor_json(table_name, object_key)
  if local_json_data then
    return local_json_data
  end

  local y3_runtime = rawget(_G, 'y3')
  if y3_runtime and y3_runtime.object then
    local object_pool
    if table_name == 'abilityall' then
      object_pool = y3_runtime.object.ability
    elseif table_name == 'projectileall' then
      object_pool = y3_runtime.object.projectile
    end
    local editor_object = object_pool and object_pool[object_key] or nil
    if editor_object and type(editor_object.data) == 'table' then
      return editor_object.data
    end
  end

  return load_editor_json(table_name, object_key)
end

local function get_editor_kv(table_name, object_key)
  local data = get_editor_object_data(table_name, object_key)
  if type(data) == 'table' and type(data.kv) == 'table' then
    return data.kv
  end
  return {}
end

local function unwrap_tuple_items(raw)
  raw = unwrap_editor_kv_entry(raw)
  if type(raw) ~= 'table' then
    return nil
  end
  if type(raw.items) == 'table' then
    return raw.items
  end
  return raw
end

local function read_visible_stage_effect(entry)
  local items = unwrap_tuple_items(entry)
  if type(items) ~= 'table' then
    return nil, nil, nil
  end

  local effect_id = to_optional_number(items[1])
  if type(effect_id) == 'number' and effect_id <= 0 then
    effect_id = nil
  end

  local scale_items = unwrap_tuple_items(items[4])
  local scale
  if type(scale_items) == 'table' then
    for index = 1, 3 do
      local candidate = to_optional_number(scale_items[index])
      if type(candidate) == 'number' and candidate > 0 then
        scale = candidate
        break
      end
    end
  end

  local time = to_optional_number(items[5])
  return effect_id, scale, time
end

local function apply_visible_ability_vfx(result, ability_data)
  if type(ability_data) ~= 'table' then
    return
  end

  for stage, field_name in pairs(ABILITY_VISIBLE_STAGE_FIELD_MAP) do
    local effect_list = unwrap_tuple_items(ability_data[field_name])
    local effect_id, scale, time = read_visible_stage_effect(effect_list and effect_list[1] or nil)
    if effect_id ~= nil and result[stage .. '_particle'] == nil then
      result[stage .. '_particle'] = effect_id
    end
    if scale ~= nil and result[stage .. '_scale'] == nil then
      result[stage .. '_scale'] = scale
    end
    if time ~= nil and result[stage .. '_time'] == nil then
      result[stage .. '_time'] = time
    end
  end
end

local function apply_manifest_vfx(result, manifest)
  if type(manifest) ~= 'table' then
    return
  end
  for field_name, manifest_field in pairs(VFX_MANIFEST_FIELD_MAP) do
    local value = to_optional_number(manifest[manifest_field])
    if value ~= nil then
      result[field_name] = value
    end
  end
end

local function normalize_vfx(result)
  for field_name, _ in pairs(POSITIVE_ONLY_VFX_FIELDS) do
    local value = to_optional_number(result[field_name])
    if type(value) == 'number' and value <= 0 then
      result[field_name] = nil
    end
  end
  return result
end

local function build_vfx(ability_key, projectile_key)
  local result = {}
  local ability_data = get_editor_object_data('abilityall', ability_key)
  apply_manifest_vfx(result, get_editor_kv('projectileall', projectile_key))
  apply_manifest_vfx(result, get_editor_kv('abilityall', ability_key))
  apply_visible_ability_vfx(result, ability_data)
  if projectile_key and result.projectile_key == nil then
    result.projectile_key = projectile_key
  end
  for field_name, _ in pairs(OPTIONAL_VFX_NUMBER_FIELDS) do
    local value = to_optional_number(result[field_name])
    if value ~= nil then
      result[field_name] = value
    end
  end
  return normalize_vfx(result)
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
  local editor_ability_key = RuntimeEditorIds.ability[row.id]
  local editor_projectile_key = RuntimeEditorIds.projectile and RuntimeEditorIds.projectile[row.id] or nil
  local def = {
    id = row.id,
    name = row.name,
    summary = row.summary,
    damage_type = row.damage_type,
    damage_form = damage_form,
    element = element,
    damage_label = damage_label,
    editor_ability_key = editor_ability_key,
    editor_projectile_key = editor_projectile_key,
    vfx = build_vfx(editor_ability_key, editor_projectile_key),
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
    local editor_ability_key = RuntimeEditorIds.ability[blueprint.id]
    local editor_projectile_key = RuntimeEditorIds.projectile and RuntimeEditorIds.projectile[blueprint.id] or nil
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
      editor_ability_key = editor_ability_key,
      editor_projectile_key = editor_projectile_key,
      base_damage_ratio = blueprint.base and blueprint.base.damage_ratio or 0,
      base_cooldown = blueprint.base and blueprint.base.cooldown or 0,
      base_range = blueprint.base and blueprint.base.range or 0,
      base_pierce = blueprint.base and blueprint.base.pierce or 0,
      base_duration = blueprint.base and blueprint.base.duration or 0,
      base_radius = blueprint.base and blueprint.base.radius or 0,
      base_bounce = blueprint.base and blueprint.base.bounce or 0,
      evolution_name = blueprint.evolution and blueprint.evolution.name or nil,
      evolution_summary = blueprint.evolution and blueprint.evolution.summary or nil,
      vfx = build_vfx(editor_ability_key, editor_projectile_key),
    }
    apply_taxonomy(defs_by_id[blueprint.id], blueprint.id)
    vfx_by_id[blueprint.id] = defs_by_id[blueprint.id].vfx
  end
end

if not defs_by_id.basic_attack then
  local fallback_basic_editor_ability_key = RuntimeEditorIds.ability and RuntimeEditorIds.ability.basic_attack or nil
  local fallback_basic_editor_projectile_key = RuntimeEditorIds.projectile and RuntimeEditorIds.projectile.basic_attack or nil
  local fallback_basic_vfx = build_vfx(fallback_basic_editor_ability_key, fallback_basic_editor_projectile_key)
  local fallback_basic_def = {
    id = 'basic_attack',
    name = '基础攻击',
    summary = '默认普攻（CSV 缺失兜底）',
    damage_type = '物理',
    damage_form = 'weapon',
    element = 'none',
    damage_label = '兵刃伤害',
    editor_ability_key = fallback_basic_editor_ability_key,
    editor_projectile_key = fallback_basic_editor_projectile_key,
    base_damage_ratio = 1.0,
    base_cooldown = 1.7,
    base_range = 250,
    base_pierce = 0,
    base_pierce_width = 90,
    base_repeat_count = 1,
    vfx = fallback_basic_vfx,
  }
  -- 普攻运行时分发依赖 taxonomy（尤其 cast_family=basic_projectile），
  -- CSV 缺失时也必须补齐，否则不会进入普攻施法/索敌链路。
  defs_by_id.basic_attack = apply_taxonomy(fallback_basic_def, 'basic_attack')
  vfx_by_id.basic_attack = defs_by_id.basic_attack.vfx
end

return {
  list = list,
  defs_by_id = defs_by_id,
  vfx_by_id = vfx_by_id,
  blueprints = SecondBatchBlueprints,
  blueprint_by_id = helpers.list_to_map(SecondBatchBlueprints.list),
}

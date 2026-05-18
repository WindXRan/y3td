local helpers = require 'data.tables.helpers'

local SKILL_DATA = {
  { id = 'basic_attack', name = '普攻', default_slot = 1, summary = '射出 1 支破空箭矢直取敌人，造成 125% 攻击的金行箭矢伤害。',
    damage_type = '物理', damage_form = 'weapon', element = 'metal', damage_label = '金行箭矢',
    base_damage_ratio = 1.25, base_cooldown = 1.05, base_range = 820, base_pierce = 0,
    base_pierce_width = 96, base_control_lock_time = 0, base_knockback_distance = 0, base_knockback_speed = 0,
    base_explosion_ratio = 0, base_explosion_radius = 0, base_extra_targets = 0, base_repeat_count = 1,
    ui_icon = 100508, icon = 100508,
  },
}

local SKILL_VFX = {
  basic_attack = {
    projectile_key = 134267104, projectile_speed = 3760, projectile_time = 2.9, target_distance = 28,
    cast_particle = 101175, cast_scale = 0.90, cast_time = 0.14,
    impact_particle = 101175, impact_scale = 1.08, impact_time = 0.28,
    explosion_particle = 101175, explosion_scale = 1.08, explosion_time = 0.30,
    charge_particle = 101175, charge_scale = 0.86, charge_time = 0.20,
    chain_particle = 101175, chain_scale = 0.92, chain_time = 0.22,
  },
}

local TAXONOMY_LIST = {
  { id = 'basic_attack', category = '弓箭普攻', cast_family = 'basic_projectile', presentation_family = 'eca_projectile_hit', eca_reference = '弓箭普攻/箭矢命中', tactical_tags = { 'single', 'projectile', 'basic_attack', 'archery', 'arrow' } },
  { id = 'sword_wave', category = '直线贯穿', cast_family = 'line_pierce', presentation_family = 'eca_line_pierce', eca_reference = '直线穿透型技能', tactical_tags = { 'line', 'pierce', 'clear' } },
  { id = 'arcane_laser', category = '持续照射', cast_family = 'beam', presentation_family = 'eca_beam_tick', eca_reference = '持续照射型技能', tactical_tags = { 'beam', 'sustain', 'aoe' } },
  { id = 'arcane_ray', category = '长线爆发', cast_family = 'line_pierce', presentation_family = 'eca_line_pierce', eca_reference = '长线穿透爆发', tactical_tags = { 'line', 'burst', 'pierce' } },
  { id = 'frost_nova', category = '近身爆发', cast_family = 'nova', presentation_family = 'eca_nova_burst', eca_reference = '以自身为心范围爆发', tactical_tags = { 'nova', 'aoe', 'control' } },
  { id = 'chain_lightning', category = '连锁弹射', cast_family = 'chain', presentation_family = 'eca_chain_hit', eca_reference = '命中后链式扩散', tactical_tags = { 'chain', 'bounce', 'clear' } },
  { id = 'earthquake', category = '区域爆发', cast_family = 'area_burst', presentation_family = 'eca_ground_burst', eca_reference = '区域落点爆发', tactical_tags = { 'aoe', 'burst', 'ground' } },
  { id = 'tornado', category = '移动场域', cast_family = 'moving_field', presentation_family = 'eca_moving_field', eca_reference = '持续移动切割场', tactical_tags = { 'field', 'moving', 'pull' } },
  { id = 'electro_net', category = '控制场域', cast_family = 'control_field', presentation_family = 'eca_control_field', eca_reference = '区域束缚控制场', tactical_tags = { 'field', 'control', 'aoe' } },
  { id = 'meteor', category = '延迟终结', cast_family = 'delayed_area_burst', presentation_family = 'eca_charge_burst', eca_reference = '蓄力后高爆发落点', tactical_tags = { 'delayed', 'burst', 'aoe' } },
  { id = 'hurricane', category = '聚怪场域', cast_family = 'persistent_field', presentation_family = 'eca_persistent_field', eca_reference = '持续聚怪切割场', tactical_tags = { 'field', 'pull', 'sustain' } },
  { id = 'fireball', category = '点爆炸裂', cast_family = 'area_burst', presentation_family = 'eca_ground_burst', eca_reference = '点面兼顾爆炸', tactical_tags = { 'burst', 'aoe', 'fire' } },
  { id = 'moon_blade', category = '往返轮斩', cast_family = 'line_return', presentation_family = 'eca_return_blade', eca_reference = '往返飞刃收割', tactical_tags = { 'line', 'return', 'bounce' } },
  { id = 'lotus_flame', category = '火域持续', cast_family = 'ignite_field', presentation_family = 'eca_persistent_field', eca_reference = '持续火域焚烧', tactical_tags = { 'field', 'ignite', 'aoe' } },
  { id = 'demon_seal', category = '封镇爆发', cast_family = 'seal_burst', presentation_family = 'eca_seal_burst', eca_reference = '先封后爆控制', tactical_tags = { 'seal', 'control', 'burst' } },
  { id = 'flying_swords', category = '追击飞剑', cast_family = 'seeking_swords', presentation_family = 'eca_seeking_projectile', eca_reference = '追踪飞剑攒射', tactical_tags = { 'projectile', 'seek', 'bounce' } },
}

local TAXONOMY_BY_ID = helpers.list_to_map(TAXONOMY_LIST)

local PRESENTATION_PROFILES = {
  default = {
    cast = { min_scale = 0.72, min_time = 0.14, socket = 'origin' },
    impact = { min_scale = 0.96, min_time = 0.22, height = 12 },
    burst = { min_scale = 1.08, min_time = 0.30, height = 0 },
    terminal = { min_scale = 1.08, min_time = 0.30, height = 0 },
    charge = { min_scale = 0.86, min_time = 0.20, height = 90 },
    chain = { min_scale = 0.82, min_time = 0.18, height = 0 },
    sustain = { min_scale = 0.82, min_time = 0.20, height = 0 },
    tick = { min_scale = 0.82, min_time = 0.20, height = 0 },
  },
  eca_projectile_hit = {
    cast = { min_scale = 0.76, min_time = 0.16, socket = 'origin' },
    impact = { min_scale = 1.00, min_time = 0.24, height = 18 },
    chain = { min_scale = 0.84, min_time = 0.20, height = 16 },
  },
}

local LEGACY_DAMAGE_TYPE_MAP = {
  ['物理'] = { damage_form = 'weapon', element = 'none', damage_label = '兵刃伤害' },
  ['法术'] = { damage_form = 'spell', element = 'none', damage_label = '术法伤害' },
}

local function apply_taxonomy(def, skill_id)
  local taxonomy = TAXONOMY_BY_ID[skill_id]
  if taxonomy then
    def.category = taxonomy.category
    def.cast_family = taxonomy.cast_family
    def.presentation_family = taxonomy.presentation_family
    def.eca_reference = taxonomy.eca_reference
    def.tactical_tags = taxonomy.tactical_tags
  end
  return def
end

local list = {}
for _, row in ipairs(SKILL_DATA) do
  local def = {
    id = row.id, name = row.name, summary = row.summary,
    damage_type = row.damage_type, damage_form = row.damage_form, element = row.element, damage_label = row.damage_label,
    base_damage_ratio = row.base_damage_ratio, base_cooldown = row.base_cooldown, base_range = row.base_range,
    base_pierce = row.base_pierce, base_pierce_width = row.base_pierce_width,
    base_control_lock_time = row.base_control_lock_time, base_knockback_distance = row.base_knockback_distance,
    base_knockback_speed = row.base_knockback_speed, base_explosion_ratio = row.base_explosion_ratio,
    base_explosion_radius = row.base_explosion_radius, base_extra_targets = row.base_extra_targets,
    base_repeat_count = row.base_repeat_count, default_slot = row.default_slot, ui_icon = row.ui_icon, icon = row.icon,
    vfx = SKILL_VFX[row.id] or {},
  }
  apply_taxonomy(def, row.id)
  list[#list + 1] = def
end

local defs_by_id = helpers.list_to_map(list)
local vfx_by_id = helpers.build_field_map(list, 'vfx', {})

if not defs_by_id.basic_attack then
  defs_by_id.basic_attack = {
    id = 'basic_attack', name = '基础攻击', summary = '默认普攻（兜底）',
    damage_type = '物理', damage_form = 'weapon', element = 'none', damage_label = '兵刃伤害',
    base_damage_ratio = 1.0, base_cooldown = 1.7, base_range = 250, base_pierce = 0,
    base_pierce_width = 90, base_repeat_count = 1, vfx = {},
  }
  apply_taxonomy(defs_by_id.basic_attack, 'basic_attack')
  vfx_by_id.basic_attack = defs_by_id.basic_attack.vfx
end

local CsvLoader = require 'data.csv_loader'

local function trim(v) return tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '') end
local function to_num(v) local s = trim(v); return s == '' and nil or tonumber(s) end
local function parse_enabled(v) local s = string.lower(trim(v)); return s == '' or s == '1' or s == 'true' end

local visual_by_bond = {}
local visual_by_skill_id = {}
local bond_to_skill_id = {}

for _, row in ipairs(CsvLoader.read_rows_optional({path = 'data_csv/skill_visuals.csv'})) do
  if parse_enabled(row.enabled) then
    local skill_id = trim(row.skill_id)
    local bond_name = trim(row.bond_name)
    if bond_name ~= '' then
      local cfg = {
        projectile_key = to_num(row.projectile_key), particle_key = to_num(row.particle_key), icon_key = to_num(row.icon_key),
        line_particle_key = to_num(row.line_particle_key), template_ref = to_num(row.template_ref),
        projectile_speed = to_num(row.projectile_speed), projectile_time = to_num(row.projectile_time),
        target_distance = to_num(row.target_distance), projectile_line_distance = to_num(row.projectile_line_distance),
        projectile_angle_offset = to_num(row.projectile_angle_offset), projectile_motion_angle_offset = to_num(row.projectile_motion_angle_offset),
        trajectory_style = trim(row.trajectory_style), projectile_parabola_height = to_num(row.projectile_parabola_height),
        projectile_rotate_time = to_num(row.projectile_rotate_time), projectile_init_max_rotate_angle = to_num(row.projectile_init_max_rotate_angle),
        area_fx_base_radius = to_num(row.area_fx_base_radius), area_fx_scale_bias = to_num(row.area_fx_scale_bias),
        particle_scale_bias = to_num(row.particle_scale_bias), delivery_mode = trim(row.delivery_mode),
        motion_mode = trim(row.motion_mode), hit_fx_mode = trim(row.hit_fx_mode),
      }
      visual_by_bond[bond_name] = cfg
      if skill_id ~= '' and skill_id ~= '__字段说明__' then
        visual_by_skill_id[skill_id] = cfg
        bond_to_skill_id[bond_name] = skill_id
      end
    end
  end
end

local function get_by_bond_name(bond_name)
  local bond = trim(bond_name)
  if bond == '' then return nil end
  local skill_id = bond_to_skill_id[bond]
  if skill_id and visual_by_skill_id[skill_id] then return visual_by_skill_id[skill_id] end
  return visual_by_bond[bond]
end

local function get_by_skill_id(skill_id) return visual_by_skill_id[trim(skill_id)] end

return {
  list = list, defs_by_id = defs_by_id, vfx_by_id = vfx_by_id,
  blueprints = { list = {} },
  blueprint_by_id = {},
  taxonomy_list = TAXONOMY_LIST, taxonomy_by_id = TAXONOMY_BY_ID,
  presentation_profiles = PRESENTATION_PROFILES,
  skills = SKILL_DATA, vfx = SKILL_VFX,
  visual_by_bond = visual_by_bond, visual_by_skill_id = visual_by_skill_id, bond_to_skill_id = bond_to_skill_id,
  get_by_bond_name = get_by_bond_name, get_by_skill_id = get_by_skill_id,
}
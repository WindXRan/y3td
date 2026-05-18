local AttackSkillsData = require 'data.tables.skill.attack_skills'
local PresentationProfiles = AttackSkillsData.presentation_profiles or { by_id = {} }
local RuntimeEditorIds = require 'data.tables.runtime_editor_ids'
local SkillRuntimeTuning = require 'data.tables.skill.skill_runtime_tuning'
local SkillDamageTemplates = require 'runtime.skill_damage_templates'
local BootCombat = require 'runtime.boot_combat'

local STATE = _G.STATE
local ATTACK_SKILL_RUNTIME_TUNING =
    CONFIG.attack_skill_runtime_tuning
    or (CONFIG.skill_runtime_tuning and CONFIG.skill_runtime_tuning.attack)
    or SkillRuntimeTuning.attack
    or {}
local ATTACK_SKILL_DEPRECATED = CONFIG.attack_skill_deprecated == true
local VISUAL_TUNING = ATTACK_SKILL_RUNTIME_TUNING.visual or {}
local PROJECTILE_TUNING = ATTACK_SKILL_RUNTIME_TUNING.projectile or {}
local COOLDOWN_TUNING = ATTACK_SKILL_RUNTIME_TUNING.cooldown or {}
local SEARCH_TUNING = ATTACK_SKILL_RUNTIME_TUNING.search or {}
local DAMAGE_TEMPLATE_MAP = SkillDamageTemplates.cast_family_map or {}
local DEFAULT_DAMAGE_TEMPLATE_ID = SkillDamageTemplates.default_template_id or 'single'
local ATTACK_SKILL_SLOT_COUNT = math.max(1, tonumber(_G.ATTACK_SKILL_SLOT_COUNT) or 5)
local round_number = _G.round_number
local message = _G.message
local ATTACK_SKILL_DEFS = _G.ATTACK_SKILL_DEFS
local ATTACK_SKILL_BLUEPRINTS = _G.ATTACK_SKILL_BLUEPRINTS or { by_id = {} }
local ATTACK_SKILL_VFX = _G.AttackSkillObjects and _G.AttackSkillObjects.vfx_by_id
local hero_attr_system = _G.hero_attr_system
local get_player = _G.get_player
local create_attack_skill_instance = _G.create_attack_skill_instance

local get_hero_point = BootCombat.get_hero_point
local get_bond_runtime_bonus = BootCombat.get_bond_runtime_bonus
local is_active_enemy = BootCombat.is_active_enemy
local deal_skill_damage = BootCombat.deal_skill_damage
local get_enemies_in_range = BootCombat.get_enemies_in_range
local get_enemies_on_line = BootCombat.get_enemies_on_line
local launch_projectile_from_hero = BootCombat.launch_projectile_from_hero
local spawn_particle = BootCombat.spawn_particle
local get_hero_attack = BootCombat.get_hero_attack
local get_primary_target = BootCombat.get_primary_target

local function get_hero_attr(name, fallback_name)
  if not STATE.hero or not STATE.hero:is_exist() then
    return 0
  end
  local attr = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name)
  if attr and attr > 0 then
    return attr
  end
  if fallback_name then
    return hero_attr_system and hero_attr_system.get_attr(STATE.hero, fallback_name) or STATE.hero:get_attr(fallback_name) or 0
  end
  return STATE.hero:get_attr(name) or 0
end

local function get_basic_attack_multishot_bonus()
  local skill_runtime = STATE.skill_runtime
  local multishot_count = (skill_runtime and skill_runtime:get('multishot_count') or 0) + get_bond_runtime_bonus('multishot_count')
  local multishot_ratio = (skill_runtime and skill_runtime:get('multishot_ratio') or 0) + get_bond_runtime_bonus('multishot_ratio')
  return math.max(0, multishot_count), math.max(0, multishot_ratio)
end

local function get_basic_attack_runtime_chain_stats()
  local skill_runtime = STATE.skill_runtime
  if not skill_runtime then
    return 0, 0, 0, 0
  end
  return skill_runtime:get_chain()
end

local function get_weapon_arrow_style_flags()
  local flags = {
    has_pierce = false,
    has_splash = false,
    has_chain = false,
    has_execute = false,
    has_bounce = false,
    has_multishot = false,
  }
  local chain_bounces = get_basic_attack_runtime_chain_stats()
  flags.has_chain = chain_bounces > 0
  local multishot_count = get_basic_attack_multishot_bonus()
  flags.has_multishot = multishot_count > 0
  local skill_runtime = STATE.skill_runtime
  if skill_runtime then
    flags.has_pierce = skill_runtime:get('pierce') and skill_runtime:get('pierce') > 0 or false
    flags.has_splash = skill_runtime:get('splash_ratio') and skill_runtime:get('splash_ratio') > 0 or false
    flags.has_execute = skill_runtime:get('execute_threshold') and skill_runtime:get('execute_threshold') > 0 or false
    flags.has_bounce = skill_runtime:get('bounce') and skill_runtime:get('bounce') > 0 or false
  end
  return flags
end

local function get_basic_attack_bonus_chain_stats()
  local skill_runtime = STATE.skill_runtime
  if not skill_runtime then
    return 0, 0
  end
  local chain_chance = skill_runtime:get('chain_chance') or 0
  local chain_ratio = skill_runtime:get('chain_ratio') or 0
  return chain_chance + get_bond_runtime_bonus('chain_chance'), chain_ratio + get_bond_runtime_bonus('chain_ratio')
end

local function get_basic_attack_skill()
  if not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
    return nil
  end
  return STATE.attack_skill_state.by_id.basic_attack
end

local function get_global_skill_bonus(field)
  local state_bonus = STATE.skill_runtime and STATE.skill_runtime:get(field) or 0
  return state_bonus + get_bond_runtime_bonus(field)
end

local function get_effective_skill_value(skill, field)
  return math.max(0, (skill and skill[field] or 0) + get_global_skill_bonus(field))
end

local function remember_basic_attack_range(range)
  local number = y3.helper.tonumber(range) or 0
  if number > 0 then
    STATE.last_valid_basic_attack_range = number
    return number
  end
  return 0
end

local function get_current_basic_attack_range()
  if not STATE.hero or not STATE.hero:is_exist() then
    return math.max(1, round_number(
      STATE.last_valid_basic_attack_range
      or ATTACK_SKILL_DEFS.basic_attack.base_range
      or 0
    ))
  end

  local range = remember_basic_attack_range(
    hero_attr_system and hero_attr_system.get_attr(STATE.hero, '攻击范围') or STATE.hero:get_attr('攻击范围')
  )
  if range <= 0 then
    range = remember_basic_attack_range(
      hero_attr_system and hero_attr_system.get_attr(STATE.hero, 'attack_range') or STATE.hero:get_attr('attack_range')
    )
  end
  if range <= 0 then
    range = STATE.last_valid_basic_attack_range
        or ATTACK_SKILL_DEFS.basic_attack.base_range
        or 0
  end
  return math.max(1, round_number(range))
end

local function disable_native_basic_attack_ability(ability)
  if not ability or not ability:is_exist() then
    return
  end
  pcall(function()
    ability:stop_cast()
  end)
  pcall(function()
    ability:disable()
  end)
end

local function sync_basic_attack_ability()
  if not STATE.hero or not STATE.hero:is_exist() then
    return nil
  end

  local ability = STATE.hero_common_attack
  if not ability or not ability:is_exist() then
    ability = STATE.hero:get_common_attack()
    STATE.hero_common_attack = ability
  end

  if not ability or not ability:is_exist() then
    if not STATE.basic_attack_ability_warned then
      STATE.basic_attack_ability_warned = true
      message('[attack_skills] basic_attack ability not found')
    end
    return nil
  end

  if not STATE.basic_attack_ability_bound then
    STATE.basic_attack_ability_bound = true
    bind_basic_attack_ability_events(ability)
  end

  local skill = get_basic_attack_skill()
  if not skill then
    return ability
  end

  local range = get_current_basic_attack_range()
  pcall(function()
    ability:set_range(range)
  end)

  local cooldown = skill.base_cooldown or 1.7
  pcall(function()
    ability:set_cooldown(cooldown)
  end)

  return ability
end

local function bind_basic_attack_ability_events(ability)
  if not ability or not ability:is_exist() then
    return
  end

  local function on_basic_attack_start(_, data)
    if ATTACK_SKILL_DEPRECATED then
      return
    end
    local skill = get_basic_attack_skill()
    if not skill then
      return
    end
    local target_unit = data.target_unit
    if not target_unit or not target_unit:is_exist() then
      return
    end
    if not is_active_enemy(target_unit) then
      return
    end
    execute_basic_attack(skill, target_unit)
  end

  ability:event('单位-开始攻击', function(_, data)
    on_basic_attack_start(_, data)
  end)

  ability:event('单位-攻击命中', function(_, data)
    if ATTACK_SKILL_DEPRECATED then
      return
    end
    local target_unit = data.target_unit
    if not target_unit or not target_unit:is_exist() then
      return
    end
  end)
end

local function setup_basic_attack_ability()
  if not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  if STATE.basic_attack_ability_bound then
    return
  end

  local ability = STATE.hero:get_common_attack()
  if not ability or not ability:is_exist() then
    if not STATE.basic_attack_ability_warned then
      STATE.basic_attack_ability_warned = true
      message('[attack_skills] basic_attack ability not found on hero')
    end
    return
  end

  STATE.hero_common_attack = ability
  bind_basic_attack_ability_events(ability)
  STATE.basic_attack_ability_bound = true
end

local function get_attack_skill(skill_id)
  if not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
    return nil
  end
  return STATE.attack_skill_state.by_id[skill_id]
end

local function get_attack_skill_slot(slot)
  if not STATE.attack_skill_state then
    return nil
  end
  return STATE.attack_skill_state:get_slot(slot)
end

local function get_empty_attack_skill_slot()
  for i = 1, ATTACK_SKILL_SLOT_COUNT do
    local skill = get_attack_skill_slot(i)
    if not skill then
      return i
    end
  end
  return nil
end

local function get_unlocked_attack_skill_count()
  if not STATE.attack_skill_state then
    return 0
  end
  local count = 0
  for i = 1, ATTACK_SKILL_SLOT_COUNT do
    local skill = get_attack_skill_slot(i)
    if skill then
      count = count + 1
    end
  end
  return count
end

local function get_skill_current_cooldown(skill)
  if not skill then
    return 0
  end
  local base_cd = skill.base_cooldown or 0
  local cd_reduction = skill.cooldown_reduction or 0
  local final_cd = math.max(0.1, base_cd * (1 - cd_reduction))
  return final_cd
end

local function get_basic_attack_interval(skill)
  local base_interval = skill.base_cooldown or 1.7
  local attack_speed = get_hero_attr('attack_speed') or 0
  local speed_bonus = 1 + attack_speed / 100
  return base_interval / speed_bonus
end

local function build_attack_skill_slot_text(slot)
  local skill = get_attack_skill_slot(slot)
  if not skill then
    return ''
  end
  return string.format('%s (CD: %.1fs)', skill.name or '?', get_skill_current_cooldown(skill))
end

local function show_attack_skill_loadout()
  local lines = { '[Attack Skills Loadout]' }
  for i = 1, ATTACK_SKILL_SLOT_COUNT do
    local skill = get_attack_skill_slot(i)
    if skill then
      lines[#lines + 1] = string.format('  Slot %d: %s (CD: %.1fs, Range: %d)',
        i, skill.name or '?', get_skill_current_cooldown(skill), skill.cast_range or 0)
    else
      lines[#lines + 1] = string.format('  Slot %d: [empty]', i)
    end
  end
  message(table.concat(lines, '\n'))
end

local function unlock_attack_skill(skill_id)
  local def = ATTACK_SKILL_DEFS[skill_id]
  if not def then
    return false
  end
  local slot = get_empty_attack_skill_slot()
  if not slot then
    return false
  end
  local instance = create_attack_skill_instance(skill_id, slot)
  if not instance then
    return false
  end
  if STATE.attack_skill_state then
    STATE.attack_skill_state:set_slot(slot, instance)
    STATE.attack_skill_state:add_skill(instance)
  end
  return true
end

local function get_skill_damage(skill, ratio_override)
  if not skill then
    return 0
  end
  local ratio = ratio_override or skill.damage_ratio or skill.base_damage_ratio or 1.0
  local attack = get_hero_attack()
  return attack * ratio
end

local function clone_point(point)
  return y3.point.create(point.x, point.y, point.z or 0)
end

local function get_unit_point_snapshot(unit)
  if not unit or not unit:is_exist() then
    return nil
  end
  return clone_point(unit:get_point())
end

local function is_unit_alive_now(unit)
  if not unit or not unit:is_exist() then
    return false
  end
  return unit:get_hp() > 0
end

local function play_particle_on_unit(unit, effect_key, scale, time, socket)
  spawn_particle(unit, effect_key, scale, time)
end

local function play_particle_on_point(point, effect_key, scale, time, height)
  spawn_particle(point, effect_key, scale, time, height)
end

local function get_skill_vfx(skill)
  if not skill then
    return {}
  end
  if skill.vfx then
    return skill.vfx
  end
  if ATTACK_SKILL_VFX and ATTACK_SKILL_VFX[skill.id] then
    return ATTACK_SKILL_VFX[skill.id]
  end
  return {}
end

local function get_skill_presentation_family(skill)
  if not skill then
    return 'eca_projectile_hit'
  end
  return skill.presentation_family or skill.cast_family or 'eca_projectile_hit'
end

local function get_skill_stage_profile(skill, stage)
  local family = get_skill_presentation_family(skill)
  local profiles = PresentationProfiles.by_id or {}
  local profile = profiles[family] or profiles.default or {}
  return profile[stage] or {}
end

local function resolve_skill_stage_particle(skill, stage)
  local vfx = get_skill_vfx(skill)
  local stage_particle = vfx[stage .. '_particle']
  if stage_particle then
    return stage_particle
  end
  local stage_key = stage .. '_key'
  if vfx[stage_key] then
    return vfx[stage_key]
  end
  return nil
end

local function play_skill_particle_on_unit(skill, unit, stage, socket)
  local particle_key = resolve_skill_stage_particle(skill, stage)
  if not particle_key or not unit or not unit:is_exist() then
    return
  end
  local profile = get_skill_stage_profile(skill, stage)
  local scale = profile.min_scale or 1.0
  local time = scale_visual_duration(profile.min_time or 0.2)
  play_particle_on_unit(unit, particle_key, scale, time, socket)
end

local function play_skill_particle_on_point(skill, point, stage, height)
  local particle_key = resolve_skill_stage_particle(skill, stage)
  if not particle_key or not point then
    return
  end
  local profile = get_skill_stage_profile(skill, stage)
  local scale = profile.min_scale or 1.0
  local time = scale_visual_duration(profile.min_time or 0.2)
  local h = height or profile.height or 0
  play_particle_on_point(point, particle_key, scale, time, h)
end

local function play_basic_attack_sound(sound_id, position)
  if not sound_id then
    return
  end
  local player = get_player()
  if not player then
    return
  end
  pcall(function()
    y3.audio.play_3d(player, sound_id, position, {
      ensure = true,
      height = 0,
      volume = 100,
    })
  end)
end

local function play_attack_skill_sound(skill, stage, position)
  if not skill then
    return
  end
  local vfx = get_skill_vfx(skill)
  local sound_key = vfx[stage .. '_sound']
  if sound_key then
    play_basic_attack_sound(sound_key, position)
  end
end

local function play_skill_audio(skill, stage, source_unit)
  if not source_unit or not source_unit:is_exist() then
    return
  end
  local position = get_unit_point_snapshot(source_unit)
  if not position then
    return
  end
  play_attack_skill_sound(skill, stage, position)
end

local function play_basic_attack_impact_effect(target, damage, is_critical)
  if is_hit_effect_hidden() then
    return
  end
  local skill = get_basic_attack_skill()
  if not skill then
    return
  end
  play_skill_particle_on_unit(skill, target, 'impact', 'chest')
end

local function play_basic_attack_cast_effect()
  local skill = get_basic_attack_skill()
  if not skill then
    return
  end
  local hero = STATE.hero
  if not hero or not hero:is_exist() then
    return
  end
  play_skill_particle_on_unit(skill, hero, 'cast', 'right_hand')
end

local function create_basic_attack_projectile(target)
  local skill = get_basic_attack_skill()
  if not skill then
    return nil
  end
  local hero = STATE.hero
  if not hero or not hero:is_exist() then
    return nil
  end
  local vfx = get_skill_vfx(skill)
  local projectile_key = vfx.projectile_key
  if not projectile_key then
    return nil
  end
  return launch_projectile_from_hero(hero, target, {
    projectile_key = projectile_key,
    projectile_speed = vfx.projectile_speed or 3000,
    projectile_time = vfx.projectile_time or 1.0,
    target_distance = vfx.target_distance or 20,
    cast_particle = vfx.cast_particle,
    cast_scale = vfx.cast_scale or 1.0,
    cast_time = vfx.cast_time or 0.1,
    impact_particle = vfx.impact_particle,
    impact_scale = vfx.impact_scale or 1.0,
    impact_time = vfx.impact_time or 0.2,
  })
end

local function deal_basic_attack_damage(target, skill, bonus_ratio)
  if not target or not target:is_exist() then
    return 0
  end
  local base_damage = get_skill_damage(skill)
  local ratio = bonus_ratio or 1.0
  local final_damage = base_damage * ratio
  if final_damage <= 0 then
    return 0
  end
  deal_skill_damage(target, final_damage, skill, {})
  return final_damage
end

local function execute_basic_attack(skill, target)
  if not skill or not target or not target:is_exist() then
    return
  end

  play_basic_attack_cast_effect()

  local flags = get_weapon_arrow_style_flags()
  local damage = deal_basic_attack_damage(target, skill, 1.0)

  if flags.has_chain then
    local chain_bounces, chain_chance, chain_ratio, chain_radius = get_basic_attack_runtime_chain_stats()
    if chain_bounces > 0 and chain_chance > 0 and math.random() <= chain_chance then
      local chain_enemies = get_enemies_in_range(target:get_point(), chain_radius, target, chain_bounces)
      for i, chain_target in ipairs(chain_enemies) do
        deal_basic_attack_damage(chain_target, skill, chain_ratio)
      end
    end
  end

  if flags.has_multishot then
    local multishot_count, multishot_ratio = get_basic_attack_multishot_bonus()
    for i = 1, multishot_count do
      local nearby = get_enemies_in_range(target:get_point(), 300, target, 1)
      if #nearby > 0 then
        deal_basic_attack_damage(nearby[1], skill, multishot_ratio)
      end
    end
  end

  play_basic_attack_impact_effect(target, damage, false)
end

local function sync_basic_attack_ability_range()
  local ability = STATE.hero_common_attack
  if not ability or not ability:is_exist() then
    return
  end
  local range = get_current_basic_attack_range()
  pcall(function()
    ability:set_range(range)
  end)
end

local function api_sync_basic_attack_ability()
  return sync_basic_attack_ability()
end

local function api_get_basic_attack_skill()
  return get_basic_attack_skill()
end

local function api_get_current_basic_attack_range()
  return get_current_basic_attack_range()
end

local function api_get_attack_skill(skill_id)
  return get_attack_skill(skill_id)
end

local function api_get_attack_skill_slot(slot)
  return get_attack_skill_slot(slot)
end

local function api_unlock_attack_skill(skill_id)
  return unlock_attack_skill(skill_id)
end

local function api_show_attack_skill_loadout()
  show_attack_skill_loadout()
end

local function api_setup_basic_attack_ability()
  setup_basic_attack_ability()
end

local function api_sync_basic_attack_ability_range()
  sync_basic_attack_ability_range()
end

function api_set_active_skill_ids(active_ids)
  if not STATE.active_skill_runtime then
    STATE.active_skill_runtime = { active_ids = {}, queue = {}, cursor = 1, next_cast_ready_time = 0 }
  end
  STATE.active_skill_runtime.active_ids = active_ids
  STATE.active_skill_runtime.cursor = 1
  return #active_ids
end

local api = {
  sync_basic_attack_ability = api_sync_basic_attack_ability,
  get_basic_attack_skill = api_get_basic_attack_skill,
  get_current_basic_attack_range = api_get_current_basic_attack_range,
  get_attack_skill = api_get_attack_skill,
  get_attack_skill_slot = api_get_attack_skill_slot,
  unlock_attack_skill = api_unlock_attack_skill,
  show_attack_skill_loadout = api_show_attack_skill_loadout,
  setup_basic_attack_ability = api_setup_basic_attack_ability,
  sync_basic_attack_ability_range = api_sync_basic_attack_ability_range,
  set_active_skill_ids = api_set_active_skill_ids,
}

_G.attack_skills_system = api
_G.SYSTEM.attack_skills = api

return api
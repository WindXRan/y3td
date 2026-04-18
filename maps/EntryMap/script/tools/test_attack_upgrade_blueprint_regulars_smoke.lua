package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local AttackUpgrades = require 'runtime.attack_upgrades'
local AttackSkillDefs = require 'data.object_tables.attack_skills'
local AttackSkillBlueprints = require 'data.object_tables.attack_skill_second_batch_blueprints'

local sword_wave_def = assert(AttackSkillDefs.defs_by_id.sword_wave, 'expected sword_wave def')

local state = {
  skill_points = 1,
  resources = { wood = 999 },
  current_wave_index = 3,
  attack_skill_state = {
    unlock_offer_fail_streak = 0,
    upgrade_counts = {},
  },
}

local upgrade_counts = {}
local sword_wave = {
  id = 'sword_wave',
  name = sword_wave_def.name,
  level = 1,
  damage_ratio = sword_wave_def.base_damage_ratio or 0,
  base_cooldown = sword_wave_def.base_cooldown or 0,
  cooldown_reduction = 0,
  cast_range = sword_wave_def.base_range or 0,
  range_bonus = 0,
  pierce = sword_wave_def.base_pierce or 0,
  base_duration = sword_wave_def.base_duration or 0,
  base_radius = sword_wave_def.base_radius or 0,
  base_bounce = sword_wave_def.base_bounce or 0,
  repeat_count = 1,
  boss_bonus_ratio = 0,
  armor_break_ratio = 0,
  armor_break_duration = 0,
  armor_break_max_stacks = 0,
  followup_count = 0,
  followup_ratio = 0,
  echo_count = 0,
  echo_ratio = 0,
  terminal_burst_radius = 0,
  terminal_burst_ratio = 0,
  return_pass_enabled = false,
  return_pass_ratio = 0.75,
  sweep_enabled = false,
  field_track_target = false,
  persistent_field_duration = 0,
  persistent_field_ratio = 0,
  persistent_field_control = false,
  persistent_field_ignite = false,
  apply_generic_armor_break = false,
  apply_generic_ignite = false,
  apply_generic_shock = false,
  apply_generic_control = false,
  ignite_duration = 0,
  ignite_tick_ratio = 0,
  shock_duration = 0,
  shock_bonus = 0,
  control_lock_time = 0,
  pull_strength = 0,
}

local old_random = math.random
math.random = function(a, b)
  if a and b then
    return a
  end
  return 0
end

local api = AttackUpgrades.create({
  STATE = state,
  message = function() end,
  ATTACK_SKILL_DEFS = AttackSkillDefs.defs_by_id,
  ATTACK_SKILL_BLUEPRINTS = AttackSkillBlueprints,
  get_attack_skill = function(skill_id)
    if skill_id == 'sword_wave' then
      return sword_wave
    end
    return nil
  end,
  get_empty_attack_skill_slot = function()
    return nil
  end,
  get_unlocked_attack_skill_count = function()
    return 2
  end,
  get_upgrade_pick_count = function(key)
    return upgrade_counts[key] or 0
  end,
  record_upgrade_pick = function(key)
    upgrade_counts[key] = (upgrade_counts[key] or 0) + 1
  end,
  unlock_attack_skill = function()
    return nil
  end,
  sync_basic_attack_ability = function() end,
  build_attack_skill_slot_text = function()
    return ''
  end,
  has_active_treasure = function()
    return false
  end,
  collect_bond_route_tags = function()
    return { sword_wave = true }
  end,
})

api.show_upgrade_choices()
math.random = old_random

assert(state.current_upgrade_choices ~= nil, 'expected blueprint regular upgrades to enter current choices')
assert(#state.current_upgrade_choices == 3, 'expected three blueprint upgrade choices')
for _, choice in ipairs(state.current_upgrade_choices) do
  assert(choice.skill_id == 'sword_wave', 'expected only unlocked blueprint skill upgrades to be offered')
end

assert(state.current_upgrade_choices[1].key == 'bp_sword_wave_damage', 'expected first deterministic choice to be sword_wave damage')
assert(state.current_upgrade_choices[2].key == 'bp_sword_wave_frequency', 'expected second deterministic choice to be sword_wave frequency')
assert(state.current_upgrade_choices[3].key == 'bp_sword_wave_function', 'expected third deterministic choice to be sword_wave function')

api.apply_upgrade(1)

assert(sword_wave.damage_ratio > (sword_wave_def.base_damage_ratio or 0), 'damage card should raise sword_wave damage ratio')
assert(upgrade_counts.bp_sword_wave_damage == 1, 'damage card pick count should be recorded')

print('[OK] attack upgrade blueprint regulars smoke passed')

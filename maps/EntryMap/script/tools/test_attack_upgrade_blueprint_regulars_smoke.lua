package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local AttackUpgrades = require 'runtime.attack_upgrades'
local AttackSkillDefs = require 'data.object_tables.attack_skills'
local AttackSkillBlueprints = require 'data.object_tables.attack_skill_second_batch_blueprints'

local flying_swords_def = assert(AttackSkillDefs.defs_by_id.flying_swords, 'expected flying_swords def')

local function clone_counts(source)
  local result = {}
  for key, value in pairs(source or {}) do
    result[key] = value
  end
  return result
end

local function make_state(seed_counts)
  return {
    skill_points = 1,
    resources = { wood = 999 },
    current_wave_index = 3,
    attack_skill_state = {
      unlock_offer_fail_streak = 0,
      upgrade_counts = clone_counts(seed_counts),
    },
  }
end

local function make_flying_swords()
  return {
    id = 'flying_swords',
    name = flying_swords_def.name,
    level = 1,
    damage_ratio = flying_swords_def.base_damage_ratio or 0,
    base_cooldown = flying_swords_def.base_cooldown or 0,
    cooldown_reduction = 0,
    cast_range = flying_swords_def.base_range or 0,
    range_bonus = 0,
    pierce = flying_swords_def.base_pierce or 0,
    base_duration = flying_swords_def.base_duration or 0,
    base_radius = flying_swords_def.base_radius or 0,
    base_bounce = flying_swords_def.base_bounce or 0,
    repeat_count = 1,
    boss_bonus_ratio = 0,
    armor_break_ratio = 0,
    armor_break_duration = 0,
    armor_break_max_stacks = 0,
    followup_count = 0,
    followup_ratio = 0,
    split_seek_count = 0,
    split_seek_ratio = 0,
    split_seek_radius = 0,
    split_seek_depth = 0,
    kill_seek_count = 0,
    kill_seek_ratio = 0,
    kill_seek_radius = 0,
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
end

local function make_api(state, flying_swords, upgrade_counts)
  return AttackUpgrades.create({
    STATE = state,
    message = function() end,
    ATTACK_SKILL_DEFS = AttackSkillDefs.defs_by_id,
    ATTACK_SKILL_BLUEPRINTS = AttackSkillBlueprints,
    get_attack_skill = function(skill_id)
      if skill_id == 'flying_swords' then
        return flying_swords
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
      return { flying_swords = true }
    end,
  })
end

local old_random = math.random
math.random = function(a, b)
  if a and b then
    return a
  end
  return 0
end

local state = make_state()
local upgrade_counts = clone_counts(state.attack_skill_state.upgrade_counts)
local flying_swords = make_flying_swords()
local api = make_api(state, flying_swords, upgrade_counts)

api.show_upgrade_choices()
math.random = old_random

assert(state.current_upgrade_choices ~= nil, 'expected blueprint regular upgrades to enter current choices')
assert(#state.current_upgrade_choices == 3, 'expected three blueprint upgrade choices')
for _, choice in ipairs(state.current_upgrade_choices) do
  assert(choice.skill_id == 'flying_swords', 'expected only unlocked blueprint skill upgrades to be offered')
end

assert(state.current_upgrade_choices[1].key == 'bp_flying_swords_damage', 'expected first deterministic choice to be flying_swords damage')
assert(state.current_upgrade_choices[2].key == 'bp_flying_swords_frequency', 'expected second deterministic choice to be flying_swords frequency')
assert(state.current_upgrade_choices[3].key == 'bp_flying_swords_function', 'expected third deterministic choice to be flying_swords function')

api.apply_upgrade(1)

assert(flying_swords.damage_ratio > (flying_swords_def.base_damage_ratio or 0), 'damage card should raise flying_swords damage ratio')
assert(upgrade_counts.bp_flying_swords_damage == 1, 'damage card pick count should be recorded')

local form_seed_counts = {
  bp_flying_swords_damage = 1,
  bp_flying_swords_frequency = 1,
  bp_flying_swords_function = 1,
  bp_flying_swords_range = 1,
  bp_flying_swords_count = 1,
  bp_flying_swords_state = 1,
  bp_flying_swords_elite = 1,
  bp_flying_swords_trigger = 1,
}
local form_state = make_state(form_seed_counts)
local form_counts = clone_counts(form_state.attack_skill_state.upgrade_counts)
local form_skill = make_flying_swords()
local form_api = make_api(form_state, form_skill, form_counts)

form_api.show_upgrade_choices()

assert(form_state.current_upgrade_choices ~= nil, 'expected form-only scenario to produce choices')
assert(#form_state.current_upgrade_choices == 1, 'expected only the form card to remain available')
assert(form_state.current_upgrade_choices[1].key == 'bp_flying_swords_form', 'expected focused form choice to be 回风剑阵')

form_api.apply_upgrade(1)

assert(form_skill.split_seek_count == 2, 'form card should grant two split pursuit swords')
assert(form_skill.split_seek_ratio >= 0.45, 'form card should grant split pursuit damage ratio')
assert(form_skill.split_seek_depth == 1, 'form card should only allow one layer of split pursuit by default')

local trigger_seed_counts = {
  bp_flying_swords_damage = 1,
  bp_flying_swords_frequency = 1,
  bp_flying_swords_function = 1,
  bp_flying_swords_range = 1,
  bp_flying_swords_count = 1,
  bp_flying_swords_form = 1,
  bp_flying_swords_state = 1,
  bp_flying_swords_elite = 1,
}
local trigger_state = make_state(trigger_seed_counts)
local trigger_counts = clone_counts(trigger_state.attack_skill_state.upgrade_counts)
local trigger_skill = make_flying_swords()
local trigger_api = make_api(trigger_state, trigger_skill, trigger_counts)

trigger_api.show_upgrade_choices()
math.random = old_random

assert(trigger_state.current_upgrade_choices ~= nil, 'expected trigger-only scenario to produce choices')
assert(#trigger_state.current_upgrade_choices == 1, 'expected only the trigger card to remain available')
assert(trigger_state.current_upgrade_choices[1].key == 'bp_flying_swords_trigger', 'expected focused trigger choice to be 追命连诛')

trigger_api.apply_upgrade(1)

assert(trigger_skill.kill_seek_count == 1, 'trigger card should grant one kill pursuit sword')
assert(trigger_skill.kill_seek_ratio >= 0.80, 'trigger card should grant kill pursuit damage ratio')
assert(trigger_skill.kill_seek_radius >= 520, 'trigger card should grant a larger kill pursuit search radius')
print('[OK] attack upgrade blueprint regulars smoke passed')

local CONFIG = require 'entry_config'
local BondSystem = require 'runtime_bonds'
local AttackSkillObjects = require 'entry_objects.attack_skills'
local MarkObjects = require 'entry_objects.marks'
local MarkNodeObjects = require 'entry_objects.mark_nodes'
local TreasureObjects = require 'entry_objects.treasures'
local ProgressionSystem = require 'entry_runtime_progression'
local BattlefieldSystem = require 'entry_runtime_battlefield'
local DebugToolsSystem = require 'entry_runtime_debug_tools'
local DebugActionsSystem = require 'entry_runtime_debug_actions'
local RuntimeHUDSystem = require 'entry_runtime_hud'
local RuntimeOverviewSystem = require 'ui.runtime_overview'
local OutgameSystem = require 'entry_runtime_outgame'
local AttackUpgradeSystem = require 'entry_runtime_attack_upgrades'
local AttackSkillsSystem = require 'entry_runtime_attack_skills'
local develop_command = require 'y3.develop.command'
local M = {}
local helper_signals_started = false
local heal_hero
local progression_system
local battlefield_system
local debug_tools_system
local debug_actions_system
local runtime_hud_system
local runtime_overview_system
local outgame_system
local attack_upgrade_system
local attack_skills_system

local function trace_boot(message)
  print('[entry_runtime] ' .. tostring(message))
end

local function ensure_helper_signals()
  if helper_signals_started or not y3.game.is_debug_mode() then
    return
  end

  helper_signals_started = true

  y3.ltimer.wait(1, function()
    print('[Y3_HELPER_READY]')
  end)

  y3.ltimer.loop(5, function()
    print('[HEARTBEAT]')
  end)
end

trace_boot('chunk loaded')

local function create_skill_runtime()
  return {
    normal_attack_bonus_ratio = 0,
    splash_ratio = 0,
    splash_radius = 220,
    chain_chance = 0,
    chain_bounces = 0,
    chain_ratio = 0,
    chain_radius = 420,
    execute_threshold = 0,
    medbot_every = 0,
    medbot_heal = 0,
    medbot_kills = 0,
    artillery_interval = 0,
    artillery_ratio = 0,
    artillery_base = 0,
    artillery_radius = 0,
    artillery_cd = 0,
    bonus_gold_on_kill = 0,
  }
end

local ATTACK_SKILL_DEFS = AttackSkillObjects.defs_by_id
local ATTACK_SKILL_VFX = AttackSkillObjects.vfx_by_id

local function create_attack_skill_instance(skill_id, slot)
  local def = ATTACK_SKILL_DEFS[skill_id]
  return {
    id = def.id,
    name = def.name,
    slot = slot or def.default_slot or 0,
    summary = def.summary,
    damage_type = def.damage_type,
    level = 1,
    unlocked = true,
    damage_ratio = def.base_damage_ratio or 0,
    base_cooldown = def.base_cooldown or 0,
    cooldown_reduction = 0,
    cooldown_remaining = 0,
    cast_range = def.base_range or 0,
    range_bonus = 0,
    attack_speed_bonus = 0,
    pierce = def.base_pierce or 0,
    pierce_width = def.base_pierce_width or 90,
    repeat_count = def.base_repeat_count or 1,
    explosion_ratio = def.base_explosion_ratio or 0,
    explosion_radius = def.base_explosion_radius or 0,
    extra_targets = def.base_extra_targets or 0,
    control_lock_time = def.base_control_lock_time or 0,
    knockback_distance = def.base_knockback_distance or 0,
    knockback_speed = def.base_knockback_speed or 900,
  }
end

local function create_attack_skill_state()
  local basic_attack = create_attack_skill_instance('basic_attack', 1)
  return {
    slots = {
      [1] = basic_attack,
      [2] = nil,
      [3] = nil,
      [4] = nil,
    },
    by_id = {
      basic_attack = basic_attack,
    },
    upgrade_counts = {},
    last_picked_skill_id = nil,
    new_skill_feed = {},
    unlock_offer_fail_streak = 0,
  }
end

local function create_bond_runtime()
  return BondSystem.create_runtime()
end

local TREASURE_QUALITY_LABELS = {
  common = '普通',
  rare = '稀有',
  epic = '史诗',
}

local MARK_QUALITY_LABELS = {
  common = '普通',
  rare = '稀有',
  epic = '史诗',
}

local TREASURE_DEF_LIST = TreasureObjects.list
local TREASURE_DEFS = TreasureObjects.by_id
local MARK_DEF_LIST = MarkObjects.list
local MARK_DEFS = MarkObjects.by_id
local MARK_NODES_BY_LEVEL = MarkNodeObjects.by_level

local function create_treasure_runtime()
  return {
    active_slots = {
      [1] = nil,
      [2] = nil,
      [3] = nil,
    },
    active_by_id = {},
    acquired_treasure_ids = {},
    discarded_treasure_ids = {},
    no_high_quality_rounds = 0,
    next_round_id = 1,
    current_round = nil,
    current_choices = nil,
    awaiting_choice = false,
    awaiting_replace = false,
    pending_replace_choice = nil,
    applied = {
      attr = {},
      skill_runtime = {},
      reward_ratio = {},
      passive_income = {},
      attack_skill = {},
    },
  }
end

local function create_mark_runtime()
  return {
    owned_mark_ids = {},
    ordered_mark_ids = {},
    triggered_node_ids = {},
    rounds_by_id = {},
    next_round_id = 1,
    current_round = nil,
    current_choices = nil,
    awaiting_choice = false,
    applied = {
      attr = {},
      runtime = {},
      attack_skill = {},
    },
  }
end

local STATE = {
  hero = nil,
  hero_common_attack = nil,
  hero_spawn_point = nil,
  defense_point = nil,
  all_enemies = nil,
  total_enemy_alive = 0,
  current_wave_index = 0,
  started_wave_count = 0,
  active_wave = nil,
  active_challenges = nil,
  resources = nil,
  resource_income_elapsed = 0,
  bond_runtime = nil,
  mark_runtime = nil,
  treasure_runtime = nil,
  enemy_info_map = nil,
  skill_points = 0,
  hero_progress = nil,
  awaiting_upgrade = false,
  current_upgrade_choices = nil,
  skill_runtime = nil,
  attack_skill_state = nil,
  reward_queue = nil,
  challenge_charges = 0,
  challenge_recover_elapsed = 0,
  bond_draw_count = 0,
  defeated_boss_waves = nil,
  basic_attack_ability_bound = false,
  basic_attack_ability_warned = false,
  debug_ctrl_down_count = 0,
  runtime_elapsed = 0,
  runtime_hud = nil,
  runtime_overview = nil,
  runtime_overview_mode = 'build',
  gm_ui = nil,
  session_phase = 'outgame',
  outgame_profile = nil,
  selected_stage_id = nil,
  selected_mode_id = nil,
  current_stage_def = nil,
  current_mode_def = nil,
  last_battle_result = nil,
  outgame_ui = nil,
  outgame_profile_save_enabled = false,
  outgame_profile_save_warned = false,
  game_finished = false,
}

local function get_player()
  return y3.player(CONFIG.player_id)
end

local function get_enemy_player()
  return y3.player(CONFIG.enemy_player_id)
end

local function message(text)
  print(text)
  get_player():display_message(text)
end

local function make_point(data)
  return y3.point.create(data.x, data.y, data.z or 0)
end

local function round_number(value)
  return math.floor((value or 0) + 0.5)
end

local create_bond_env
local award_rewards
local show_mark_choices
local show_treasure_choices
local try_open_queued_treasure_round
local is_battle_active
local reset_battle_state
local set_battle_hud_visible

progression_system = ProgressionSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  round_number = round_number,
  message = message,
})

local function sync_basic_attack_ability()
  return attack_skills_system.sync_basic_attack_ability()
end

local function setup_basic_attack_ability()
  return attack_skills_system.setup_basic_attack_ability()
end

local function set_attr_pack(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end

  for attr_name, value in pairs(attr_pack) do
    if value ~= nil then
      unit:set_attr(attr_name, value)
    end
  end
end

local function add_attr_pack(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end

  for attr_name, value in pairs(attr_pack) do
    if value ~= nil and value ~= 0 then
      unit:add_attr(attr_name, value)
    end
  end
end

local function get_hero_progression_rules()
  return progression_system.get_hero_progression_rules()
end

local function get_resource_rules()
  return progression_system.get_resource_rules()
end

local function update_bond_effects(dt)
  BondSystem.update_effects(create_bond_env(), dt)
end

local function get_hero_max_level()
  return progression_system.get_hero_max_level()
end

local function get_engine_exp_cap_level()
  return progression_system.get_engine_exp_cap_level()
end

local function get_post_cap_exp_required(level)
  return progression_system.get_post_cap_exp_required(level)
end

local function get_hero_level()
  return progression_system.get_hero_level()
end

local function get_hero_next_level_exp(level)
  return progression_system.get_hero_next_level_exp(level)
end

local function sync_hero_progression()
  return progression_system.sync_hero_progression()
end

local function initialize_hero_progression()
  return progression_system.initialize_hero_progression()
end

local function sync_hero_progress_from_engine()
  return progression_system.sync_hero_progress_from_engine()
end

local function get_hero_progress_text()
  return progression_system.get_hero_progress_text()
end

local function grant_hero_exp(amount)
  return progression_system.grant_hero_exp(amount)
end

local ReservedRuntimeApi = {}

function ReservedRuntimeApi.point_to_table(point)
  return debug_tools_system.point_to_table(point)
end

function ReservedRuntimeApi.format_point(point)
  return debug_tools_system.format_point(point)
end

local function design_seconds(seconds)
  if CONFIG.debug_time_scale <= 0 then
    return seconds
  end
  return seconds / CONFIG.debug_time_scale
end

local function get_area(area_id)
  return debug_tools_system.get_area(area_id)
end

local function random_point_in_area(area_id)
  local area = get_area(area_id)
  if not area then
    return STATE.defense_point
  end

  local x = math.random(area.x_min, area.x_max)
  local y = math.random(area.y_min, area.y_max)
  return y3.point.create(x, y, area.z or 0)
end

function ReservedRuntimeApi.get_area_size(area_id)
  return debug_tools_system.get_area_size(area_id)
end

local function get_hero_point()
  if not STATE.hero or not STATE.hero:is_exist() then
    return nil
  end
  return STATE.hero:get_point()
end

function ReservedRuntimeApi.update_point_config(point_key, point)
  return debug_tools_system.update_point_config(point_key, point)
end

function ReservedRuntimeApi.recenter_area(area_id, center_point, width, height, offset_x, offset_y)
  return debug_tools_system.recenter_area(area_id, center_point, width, height, offset_x, offset_y)
end

function ReservedRuntimeApi.dump_calibration_file()
  return debug_tools_system.dump_calibration_file()
end

function ReservedRuntimeApi.show_calibration_help()
  return debug_tools_system.show_calibration_help()
end

local function debug_message(text)
  return debug_tools_system.debug_message(text)
end

local function show_debug_hotkey_help()
  return debug_tools_system.show_debug_hotkey_help()
end

local function register_dev_commands()
  return debug_tools_system.register_dev_commands()
end

function ReservedRuntimeApi.has_unit_data(unit_id)
  return battlefield_system.has_unit_data(unit_id)
end

local function is_active_enemy(unit)
  return battlefield_system.is_active_enemy(unit)
end

local function get_enemy_runtime_info(unit)
  return battlefield_system.get_enemy_runtime_info(unit)
end

local function is_boss_runtime_enemy(info)
  return battlefield_system.is_boss_runtime_enemy(info)
end

local function is_elite_runtime_enemy(info)
  return battlefield_system.is_elite_runtime_enemy(info)
end

local function get_bond_runtime_bonus(key)
  local mark_runtime = STATE.mark_runtime
  local mark_bonus = 0
  if mark_runtime and mark_runtime.applied and mark_runtime.applied.runtime then
    mark_bonus = mark_runtime.applied.runtime[key] or 0
  end
  return BondSystem.get_runtime_bonus(STATE, key) + mark_bonus
end

local function is_bond_active(bond_id)
  return BondSystem.is_active(STATE, bond_id)
end

create_bond_env = function()
  return {
    STATE = STATE,
    message = message,
    round_number = round_number,
    y3 = y3,
    heal_hero = heal_hero,
    sync_basic_attack_ability = sync_basic_attack_ability,
    is_active_enemy = is_active_enemy,
    get_enemy_runtime_info = get_enemy_runtime_info,
    is_boss_runtime_enemy = is_boss_runtime_enemy,
    is_elite_runtime_enemy = is_elite_runtime_enemy,
    basic_attack_damage_type = ATTACK_SKILL_DEFS.basic_attack.damage_type,
  }
end

local function get_enemies_in_range(center, radius, except_unit, max_count)
  local result = {}
  local selector = y3.selector.create()
    :is_enemy(get_player())
    :in_range(center, radius)
    :sort_type('由近到远')

  if max_count and max_count > 0 then
    selector:count(max_count + (except_unit and 1 or 0))
  end

  local picked = selector:pick()

  for _, unit in ipairs(picked) do
    if unit ~= except_unit and is_active_enemy(unit) then
      result[#result + 1] = unit
    end
  end

  return result
end

local function resolve_damage_text_type(damage_type, visual)
  if visual and visual.text_type then
    return visual.text_type
  end

  if damage_type == ATTACK_SKILL_DEFS.basic_attack.damage_type
    or damage_type == ATTACK_SKILL_DEFS.flame_arrow.damage_type then
    return 'physics'
  end

  return 'magic'
end

local function get_target_hp_ratio(target)
  if not target or not target:is_exist() then
    return 1
  end
  local max_hp = y3.helper.tonumber(target:get_attr('最大生命')) or 0
  if max_hp <= 0 then
    return 1
  end
  return math.max(0, (target:get_hp() or 0) / max_hp)
end

local function get_damage_bonus_multiplier(target, context)
  local multiplier = 1
  multiplier = multiplier * (1 + get_bond_runtime_bonus('all_damage_bonus'))

  if context and context.is_skill then
    multiplier = multiplier * (1 + get_bond_runtime_bonus('skill_damage_bonus'))
  end
  if context and context.is_basic_attack then
    multiplier = multiplier * (1 + get_bond_runtime_bonus('normal_attack_damage_bonus'))
  end

  local info = get_enemy_runtime_info(target)
  if is_boss_runtime_enemy(info) then
    multiplier = multiplier * (1 + get_bond_runtime_bonus('boss_damage_bonus'))
  end
  if is_elite_runtime_enemy(info) then
    multiplier = multiplier * (1 + get_bond_runtime_bonus('elite_damage_bonus'))
  end

  local execute_threshold = get_bond_runtime_bonus('execute_threshold')
  if execute_threshold > 0 and get_target_hp_ratio(target) <= execute_threshold then
    multiplier = multiplier * (1 + get_bond_runtime_bonus('execute_damage_bonus'))
  end

  return multiplier
end

local function try_trigger_hunter_first_hit(target)
  BondSystem.try_trigger_hunter_first_hit(create_bond_env(), target)
end

local function build_reward_with_bond_bonus(reward)
  return BondSystem.build_reward_with_bonus(create_bond_env(), reward)
end

local function get_treasure_runtime()
  if not STATE.treasure_runtime then
    STATE.treasure_runtime = create_treasure_runtime()
  end
  return STATE.treasure_runtime
end

local function get_mark_runtime()
  if not STATE.mark_runtime then
    STATE.mark_runtime = create_mark_runtime()
  end
  return STATE.mark_runtime
end

local function get_reward_queue()
  if not STATE.reward_queue then
    STATE.reward_queue = {}
  end
  return STATE.reward_queue
end

local function get_reward_queue_count()
  return #get_reward_queue()
end

local function get_treasure_quality_label(quality)
  return TREASURE_QUALITY_LABELS[quality] or '普通'
end

local function get_mark_quality_label(quality)
  return MARK_QUALITY_LABELS[quality] or '普通'
end

local function clone_reward(reward)
  if not reward then
    return nil
  end

  return {
    gold = reward.gold or 0,
    wood = reward.wood or 0,
    exp = reward.exp or 0,
    special = reward.special,
  }
end

local function add_bonus_pack(target, pack)
  if not target or not pack then
    return
  end

  for key, value in pairs(pack) do
    if value ~= nil and value ~= 0 then
      target[key] = (target[key] or 0) + value
    end
  end
end

local function enqueue_reward_entry(entry)
  local queue = get_reward_queue()
  local priority = entry.priority or 0
  local insert_at = #queue + 1

  for index, queued in ipairs(queue) do
    if priority > (queued.priority or 0) then
      insert_at = index
      break
    end
  end

  table.insert(queue, insert_at, entry)
  return entry
end

local function get_treasure_active_count()
  local runtime = get_treasure_runtime()
  local count = 0
  for slot = 1, 3, 1 do
    if runtime.active_slots[slot] then
      count = count + 1
    end
  end
  return count
end

local function get_empty_treasure_slot()
  local runtime = get_treasure_runtime()
  for slot = 1, 3, 1 do
    if not runtime.active_slots[slot] then
      return slot
    end
  end
  return nil
end

local function build_treasure_choice_text(index, def)
  return string.format(
    '%d. [%s] %s：%s',
    index,
    get_treasure_quality_label(def.quality),
    def.name,
    def.summary
  )
end

local function build_treasure_slot_text(slot)
  local runtime = get_treasure_runtime()
  local treasure_id = runtime.active_slots[slot]
  if not treasure_id then
    return string.format('宝物位 %d：空。', slot)
  end

  local def = TREASURE_DEFS[treasure_id]
  if not def then
    return string.format('宝物位 %d：未知宝物 %s。', slot, tostring(treasure_id))
  end

  return string.format(
    '宝物位 %d：[%s] %s - %s',
    slot,
    get_treasure_quality_label(def.quality),
    def.name,
    def.summary
  )
end

local function get_mark_active_count()
  local runtime = get_mark_runtime()
  return #runtime.ordered_mark_ids
end

local function build_mark_choice_text(index, def)
  return string.format(
    '%d. [%s] %s：%s',
    index,
    get_mark_quality_label(def.quality),
    def.name,
    def.summary
  )
end

local function build_mark_slot_text(slot)
  local runtime = get_mark_runtime()
  local mark_id = runtime.ordered_mark_ids[slot]
  if not mark_id then
    return string.format('烙印位 %d：空。', slot)
  end

  local def = MARK_DEFS[mark_id]
  if not def then
    return string.format('烙印位 %d：未知烙印 %s。', slot, tostring(mark_id))
  end

  return string.format(
    '烙印位 %d：[%s] %s - %s',
    slot,
    get_mark_quality_label(def.quality),
    def.name,
    def.summary
  )
end

local function show_mark_loadout()
  message('烙印栏：')
  local count = math.max(4, get_mark_active_count())
  for slot = 1, count, 1 do
    message(build_mark_slot_text(slot))
  end
end

local function is_high_quality_treasure(def)
  return def and (def.quality == 'rare' or def.quality == 'epic') or false
end

local function build_current_treasure_tags()
  local tags = {
    basic_attack = true,
  }

  local attack_state = STATE.attack_skill_state
  if attack_state and attack_state.by_id then
    if attack_state.by_id.arcane_arrow
      or attack_state.by_id.flame_arrow
      or attack_state.by_id.frost_arrow
      or attack_state.by_id.thunder then
      tags.skill = true
      tags.spell_cycle = true
    end
    if attack_state.by_id.flame_arrow then
      tags.aoe = true
    end
    if attack_state.by_id.thunder then
      tags.bounce = true
    end
  end

  if STATE.skill_runtime and STATE.skill_runtime.splash_ratio > 0 then
    tags.aoe = true
  end
  if STATE.skill_runtime and STATE.skill_runtime.chain_bounces > 0 then
    tags.bounce = true
  end

  local runtime = get_treasure_runtime()
  if runtime.active_by_id.coin_casket or runtime.active_by_id.harvest_flask then
    tags.economy = true
  end
  if runtime.active_by_id.field_bandage
    or runtime.active_by_id.heart_guard_mirror
    or runtime.active_by_id.dragonblood_ring then
    tags.survival = true
  end

  return tags
end

local function get_treasure_quality_weights()
  local wave_index = math.max(STATE.current_wave_index or 0, STATE.started_wave_count or 0, 1)
  local weights

  if wave_index <= 2 then
    weights = { common = 72, rare = 24, epic = 4 }
  elseif wave_index <= 4 then
    weights = { common = 54, rare = 34, epic = 12 }
  else
    weights = { common = 38, rare = 40, epic = 22 }
  end

  local runtime = get_treasure_runtime()
  if runtime.no_high_quality_rounds >= 2 then
    weights.common = math.max(10, weights.common - 24)
    weights.rare = weights.rare + 18
    weights.epic = weights.epic + 6
  end

  return weights
end

local function build_available_treasure_defs(require_high_quality)
  local runtime = get_treasure_runtime()
  local result = {}

  for _, def in ipairs(TREASURE_DEF_LIST) do
    if not runtime.acquired_treasure_ids[def.id]
      and not runtime.discarded_treasure_ids[def.id]
      and not runtime.active_by_id[def.id]
      and (not require_high_quality or is_high_quality_treasure(def)) then
      result[#result + 1] = def
    end
  end

  return result
end

local function remove_treasure_def(list, treasure_id)
  for index, def in ipairs(list) do
    if def.id == treasure_id then
      table.remove(list, index)
      return
    end
  end
end

local function get_treasure_pick_weight(def, build_tags, quality_weights)
  local weight = (def.pool_weight or 1) * (quality_weights[def.quality] or 1)

  for _, tag in ipairs(def.tags or {}) do
    if build_tags[tag] then
      weight = weight * 1.35
      break
    end
  end

  return math.max(0.01, weight)
end

local function pick_weighted_treasure(pool, build_tags, quality_weights)
  if #pool == 0 then
    return nil
  end

  local total_weight = 0
  local weights = {}
  for index, def in ipairs(pool) do
    local weight = get_treasure_pick_weight(def, build_tags, quality_weights)
    weights[index] = weight
    total_weight = total_weight + weight
  end

  if total_weight <= 0 then
    return pool[math.random(1, #pool)]
  end

  local roll = math.random() * total_weight
  local passed = 0
  for index, def in ipairs(pool) do
    passed = passed + weights[index]
    if roll <= passed then
      return def
    end
  end

  return pool[#pool]
end

local function pick_treasure_choices(choice_count)
  local runtime = get_treasure_runtime()
  local available = build_available_treasure_defs(false)
  if #available == 0 then
    return {}
  end

  local build_tags = build_current_treasure_tags()
  local quality_weights = get_treasure_quality_weights()
  local choices = {}
  local guarantee_high_quality = runtime.no_high_quality_rounds >= 2

  if guarantee_high_quality then
    local high_quality_pool = build_available_treasure_defs(true)
    local guaranteed = pick_weighted_treasure(high_quality_pool, build_tags, quality_weights)
    if guaranteed then
      choices[#choices + 1] = guaranteed
      remove_treasure_def(available, guaranteed.id)
    end
  end

  while #choices < choice_count and #available > 0 do
    local picked = pick_weighted_treasure(available, build_tags, quality_weights)
    if not picked then
      break
    end
    choices[#choices + 1] = picked
    remove_treasure_def(available, picked.id)
  end

  local has_high_quality = false
  for _, def in ipairs(choices) do
    if is_high_quality_treasure(def) then
      has_high_quality = true
      break
    end
  end
  runtime.no_high_quality_rounds = has_high_quality and 0 or (runtime.no_high_quality_rounds + 1)

  return choices
end

local function build_available_mark_defs()
  local runtime = get_mark_runtime()
  local result = {}

  for _, def in ipairs(MARK_DEF_LIST) do
    if not runtime.owned_mark_ids[def.id] then
      result[#result + 1] = def
    end
  end

  return result
end

local function remove_mark_def(list, mark_id)
  for index, def in ipairs(list) do
    if def.id == mark_id then
      table.remove(list, index)
      return
    end
  end
end

local function get_mark_pick_weight(def)
  return math.max(0.01, def.pool_weight or 1)
end

local function pick_weighted_mark(pool)
  if #pool == 0 then
    return nil
  end

  local total_weight = 0
  local weights = {}
  for index, def in ipairs(pool) do
    local weight = get_mark_pick_weight(def)
    weights[index] = weight
    total_weight = total_weight + weight
  end

  if total_weight <= 0 then
    return pool[math.random(1, #pool)]
  end

  local roll = math.random() * total_weight
  local passed = 0
  for index, def in ipairs(pool) do
    passed = passed + weights[index]
    if roll <= passed then
      return def
    end
  end

  return pool[#pool]
end

local function pick_mark_choices(choice_count)
  local available = build_available_mark_defs()
  if #available == 0 then
    return {}
  end

  local choices = {}
  while #choices < choice_count and #available > 0 do
    local picked = pick_weighted_mark(available)
    if not picked then
      break
    end
    choices[#choices + 1] = picked
    remove_mark_def(available, picked.id)
  end

  return choices
end

local function get_treasure_reward_ratio(key)
  local runtime = get_treasure_runtime()
  return runtime.applied.reward_ratio[key] or 0
end

local function get_treasure_passive_income(key)
  local runtime = get_treasure_runtime()
  return runtime.applied.passive_income[key] or 0
end

local function build_reward_with_treasure_bonus(reward)
  if not reward then
    return nil
  end

  local result = clone_reward(reward)
  local gold_ratio = get_treasure_reward_ratio('gold')
  local wood_ratio = get_treasure_reward_ratio('wood')
  local exp_ratio = get_treasure_reward_ratio('exp')

  if result.gold > 0 and gold_ratio > 0 then
    result.gold = result.gold + round_number(result.gold * gold_ratio)
  end
  if result.wood > 0 and wood_ratio > 0 then
    result.wood = result.wood + round_number(result.wood * wood_ratio)
  end
  if result.exp > 0 and exp_ratio > 0 then
    result.exp = result.exp + round_number(result.exp * exp_ratio)
  end

  return result
end

local function apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)
  if not skill or not bonus then
    return
  end
  if not bonus.include_basic and skill_id == 'basic_attack' then
    return
  end

  local factor = direction or 1
  if bonus.cooldown_reduction and bonus.cooldown_reduction ~= 0 then
    skill.cooldown_reduction = math.max(0, (skill.cooldown_reduction or 0) + bonus.cooldown_reduction * factor)
  end
  if bonus.damage_ratio and bonus.damage_ratio ~= 0 then
    skill.damage_ratio = math.max(0, (skill.damage_ratio or 0) + bonus.damage_ratio * factor)
  end
  if bonus.repeat_count and bonus.repeat_count ~= 0 then
    skill.repeat_count = math.max(1, (skill.repeat_count or 1) + bonus.repeat_count * factor)
  end
  if bonus.range_bonus and bonus.range_bonus ~= 0 then
    skill.range_bonus = math.max(0, (skill.range_bonus or 0) + bonus.range_bonus * factor)
  end
end

local function apply_treasure_attack_skill_bonus(bonus, direction)
  if not bonus or not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
    return
  end

  for skill_id, skill in pairs(STATE.attack_skill_state.by_id) do
    apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)
  end
end

local function build_treasure_bonus_pack()
  local runtime = get_treasure_runtime()
  local aggregate = {
    attr = {},
    skill_runtime = {},
    reward_ratio = {},
    passive_income = {},
    attack_skill = {},
  }
  local rare_count = 0
  local epic_count = 0

  for slot = 1, 3, 1 do
    local treasure_id = runtime.active_slots[slot]
    local def = treasure_id and TREASURE_DEFS[treasure_id] or nil
    if def then
      if def.quality == 'rare' then
        rare_count = rare_count + 1
      elseif def.quality == 'epic' then
        epic_count = epic_count + 1
      end

      add_bonus_pack(aggregate.attr, def.bonuses and def.bonuses.attr)
      add_bonus_pack(aggregate.skill_runtime, def.bonuses and def.bonuses.skill_runtime)
      add_bonus_pack(aggregate.reward_ratio, def.bonuses and def.bonuses.reward_ratio)
      add_bonus_pack(aggregate.passive_income, def.bonuses and def.bonuses.passive_income)
      add_bonus_pack(aggregate.attack_skill, def.bonuses and def.bonuses.attack_skill)
    end
  end

  if runtime.active_by_id.crown_fragment then
    aggregate.attr['物理攻击'] = (aggregate.attr['物理攻击'] or 0) + rare_count * 12 + epic_count * 24
  end

  return aggregate
end

local function sync_treasure_effects()
  local runtime = get_treasure_runtime()
  local previous = runtime.applied or {
    attr = {},
    skill_runtime = {},
    reward_ratio = {},
    passive_income = {},
    attack_skill = {},
  }

  if STATE.hero and STATE.hero:is_exist() then
    local negative_attr = {}
    for attr_name, value in pairs(previous.attr or {}) do
      if value ~= 0 then
        negative_attr[attr_name] = -value
      end
    end
    add_attr_pack(STATE.hero, negative_attr)
  end

  for key, value in pairs(previous.skill_runtime or {}) do
    if value ~= 0 then
      STATE.skill_runtime[key] = (STATE.skill_runtime[key] or 0) - value
    end
  end
  apply_treasure_attack_skill_bonus(previous.attack_skill or {}, -1)

  local aggregate = build_treasure_bonus_pack()

  if STATE.hero and STATE.hero:is_exist() then
    add_attr_pack(STATE.hero, aggregate.attr)
  end
  for key, value in pairs(aggregate.skill_runtime) do
    if value ~= 0 then
      STATE.skill_runtime[key] = (STATE.skill_runtime[key] or 0) + value
    end
  end
  apply_treasure_attack_skill_bonus(aggregate.attack_skill, 1)

  if (STATE.skill_runtime.medbot_every or 0) <= 0 then
    STATE.skill_runtime.medbot_kills = 0
  else
    STATE.skill_runtime.medbot_kills = math.min(
      STATE.skill_runtime.medbot_kills or 0,
      math.max(0, STATE.skill_runtime.medbot_every - 1)
    )
  end

  runtime.applied = aggregate
  sync_basic_attack_ability()
end

local function apply_mark_attack_skill_bonus(bonus, direction)
  if not bonus or not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
    return
  end

  local factor = direction or 1
  for skill_id, skill in pairs(STATE.attack_skill_state.by_id) do
    if skill_id ~= 'basic_attack' then
      apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, factor)
    end
  end
end

local function build_mark_bonus_pack()
  local runtime = get_mark_runtime()
  local aggregate = {
    attr = {},
    runtime = {},
    attack_skill = {},
  }

  for _, mark_id in ipairs(runtime.ordered_mark_ids) do
    local def = MARK_DEFS[mark_id]
    if def and def.bonuses then
      add_bonus_pack(aggregate.attr, def.bonuses.attr)
      add_bonus_pack(aggregate.runtime, def.bonuses.runtime)
      add_bonus_pack(aggregate.attack_skill, def.bonuses.attack_skill)
    end
  end

  return aggregate
end

local function sync_mark_effects()
  local runtime = get_mark_runtime()
  local previous = runtime.applied or {
    attr = {},
    runtime = {},
    attack_skill = {},
  }

  if STATE.hero and STATE.hero:is_exist() then
    local negative_attr = {}
    for attr_name, value in pairs(previous.attr or {}) do
      if value ~= 0 then
        negative_attr[attr_name] = -value
      end
    end
    add_attr_pack(STATE.hero, negative_attr)
  end

  apply_mark_attack_skill_bonus(previous.attack_skill or {}, -1)

  local aggregate = build_mark_bonus_pack()

  if STATE.hero and STATE.hero:is_exist() then
    add_attr_pack(STATE.hero, aggregate.attr)
  end

  apply_mark_attack_skill_bonus(aggregate.attack_skill or {}, 1)

  runtime.applied = aggregate
  sync_basic_attack_ability()
end

local function show_treasure_loadout()
  message('宝物栏：')
  for slot = 1, 3, 1 do
    message(build_treasure_slot_text(slot))
  end
end

local function resolve_treasure_pick(def, replace_slot)
  local runtime = get_treasure_runtime()
  local target_slot = replace_slot or get_empty_treasure_slot() or 1
  local replaced_id = runtime.active_slots[target_slot]

  if replaced_id then
    runtime.active_slots[target_slot] = nil
    runtime.active_by_id[replaced_id] = nil
    runtime.discarded_treasure_ids[replaced_id] = true
  end

  runtime.active_slots[target_slot] = def.id
  runtime.active_by_id[def.id] = {
    slot = target_slot,
    acquired_round_id = runtime.current_round and runtime.current_round.round_id or 0,
  }
  runtime.acquired_treasure_ids[def.id] = true

  runtime.awaiting_choice = false
  runtime.awaiting_replace = false
  runtime.current_choices = nil
  runtime.pending_replace_choice = nil
  runtime.current_round = nil

  sync_treasure_effects()

  message(string.format(
    '已获得宝物：[%s] %s。',
    get_treasure_quality_label(def.quality),
    def.name
  ))
  if replaced_id then
    local replaced_def = TREASURE_DEFS[replaced_id]
    if replaced_def then
      message(string.format('已替换宝物位 %d：%s。', target_slot, replaced_def.name))
    end
  end
  show_treasure_loadout()

  try_open_queued_treasure_round()
end

show_treasure_choices = function()
  local runtime = get_treasure_runtime()

  if runtime.awaiting_replace and runtime.pending_replace_choice then
    local def = runtime.pending_replace_choice
    message(string.format(
      '已选中 [%s] %s，请按 1 / 2 / 3 选择要替换的宝物位。',
      get_treasure_quality_label(def.quality),
      def.name
    ))
    for slot = 1, 3, 1 do
      message(string.format('%d. %s', slot, build_treasure_slot_text(slot)))
    end
    return
  end

  if not runtime.awaiting_choice or not runtime.current_choices then
    return
  end

  message('宝物 3选1：按 1 / 2 / 3 选择。')
  if get_treasure_active_count() >= 3 then
    message('当前 3 个宝物位已满，选中后还需要再指定一个被替换的旧宝物。')
  end
  for index, def in ipairs(runtime.current_choices) do
    message(build_treasure_choice_text(index, def))
  end
  show_treasure_loadout()
end

local function apply_treasure_choice(index)
  local runtime = get_treasure_runtime()

  if runtime.awaiting_replace and runtime.pending_replace_choice then
    if not runtime.active_slots[index] then
      return
    end
    resolve_treasure_pick(runtime.pending_replace_choice, index)
    return
  end

  if not runtime.awaiting_choice or not runtime.current_choices then
    return
  end

  local def = runtime.current_choices[index]
  if not def then
    return
  end

  local empty_slot = get_empty_treasure_slot()
  if empty_slot then
    resolve_treasure_pick(def, empty_slot)
    return
  end

  runtime.awaiting_choice = false
  runtime.awaiting_replace = true
  runtime.pending_replace_choice = def
  if runtime.current_round then
    runtime.current_round.state = 'await_replace'
    runtime.current_round.selected_treasure_id = def.id
  end
  show_treasure_choices()
end

local function resolve_mark_pick(def)
  local runtime = get_mark_runtime()
  runtime.owned_mark_ids[def.id] = true
  runtime.ordered_mark_ids[#runtime.ordered_mark_ids + 1] = def.id

  if runtime.current_round then
    runtime.current_round.selected_mark_id = def.id
    runtime.current_round.state = 'resolved'
  end

  runtime.awaiting_choice = false
  runtime.current_choices = nil
  runtime.current_round = nil

  sync_mark_effects()

  message(string.format(
    '已获得烙印：[%s] %s。',
    get_mark_quality_label(def.quality),
    def.name
  ))
  show_mark_loadout()

  try_open_queued_treasure_round()
end

show_mark_choices = function()
  local runtime = get_mark_runtime()
  if not runtime.awaiting_choice or not runtime.current_choices then
    return
  end

  local title = runtime.current_round and runtime.current_round.ui_title or '烙印选择'
  message(string.format('%s：按 1 / 2 / 3 选择。', title))
  for index, def in ipairs(runtime.current_choices) do
    message(build_mark_choice_text(index, def))
  end
  show_mark_loadout()
end

local function apply_mark_choice(index)
  local runtime = get_mark_runtime()
  if not runtime.awaiting_choice or not runtime.current_choices then
    return
  end

  local def = runtime.current_choices[index]
  if not def then
    return
  end

  resolve_mark_pick(def)
end

local function can_process_reward_queue()
  local runtime = get_treasure_runtime()
  if STATE.game_finished then
    return false
  end
  local mark_runtime = get_mark_runtime()
  if mark_runtime.awaiting_choice then
    return false
  end
  if runtime.awaiting_choice or runtime.awaiting_replace then
    return false
  end
  if STATE.awaiting_upgrade then
    return false
  end
  if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice then
    return false
  end
  return true
end

local function open_treasure_reward_entry(entry)
  local runtime = get_treasure_runtime()
  local choices = pick_treasure_choices(3)
  if #choices == 0 then
    message('本局可用宝物已经抽空，本次不再生成新的宝物候选。')
    return true
  end

  runtime.current_round = {
    round_id = runtime.next_round_id,
    source_type = entry.source_type,
    source_name = entry.source_name,
    state = 'pending',
    candidate_treasure_ids = {},
  }
  runtime.next_round_id = runtime.next_round_id + 1
  runtime.current_choices = choices
  runtime.awaiting_choice = true
  runtime.awaiting_replace = false
  runtime.pending_replace_choice = nil

  for _, def in ipairs(choices) do
    runtime.current_round.candidate_treasure_ids[#runtime.current_round.candidate_treasure_ids + 1] = def.id
  end

  message(string.format('%s 奖励：获得一次宝物 3选1。', entry.source_name or '宝物挑战'))
  show_treasure_choices()
  return true
end

local function open_mark_reward_entry(entry)
  local runtime = get_mark_runtime()
  local round = entry.round_id and runtime.rounds_by_id[entry.round_id] or nil
  if not round then
    message('烙印轮次数据不存在，本次奖励已跳过。')
    return true
  end

  local choices = {}
  for _, mark_id in ipairs(round.candidate_mark_ids or {}) do
    local def = MARK_DEFS[mark_id]
    if def and not runtime.owned_mark_ids[mark_id] then
      choices[#choices + 1] = def
    end
  end

  if #choices == 0 then
    message(string.format('%s：没有可用烙印候选，本轮已跳过。', round.ui_title or '烙印选择'))
    round.state = 'skipped'
    return true
  end

  runtime.current_round = round
  runtime.current_choices = choices
  runtime.awaiting_choice = true
  round.state = 'pending'

  message(string.format('%s：获得一次烙印 3选1。', round.ui_title or '烙印选择'))
  show_mark_choices()
  return true
end

local function try_open_reward_entry(entry)
  if not entry then
    return false
  end
  if entry.kind == 'mark_choice' then
    return open_mark_reward_entry(entry)
  end
  if entry.kind == 'treasure_choice' then
    return open_treasure_reward_entry(entry)
  end

  message(string.format('存在未识别的奖励队列类型：%s。', tostring(entry.kind)))
  return true
end

local function try_process_reward_queue()
  if not can_process_reward_queue() then
    return false
  end

  local queue = get_reward_queue()
  local next_entry = table.remove(queue, 1)
  if not next_entry then
    return false
  end

  return try_open_reward_entry(next_entry)
end

try_open_queued_treasure_round = function()
  return try_process_reward_queue()
end

local function queue_treasure_round(source_type, source_name)
  local entry = enqueue_reward_entry({
    kind = 'treasure_choice',
    priority = 90,
    source_type = source_type,
    source_name = source_name,
  })

  local runtime = get_treasure_runtime()
  if runtime.awaiting_choice or runtime.awaiting_replace then
    message('新的宝物候选已加入待处理队列。')
    return
  end

  if not try_process_reward_queue() and entry and get_reward_queue_count() > 0 then
    message('宝物候选已加入待处理队列，完成当前选择后会自动弹出。')
  end
end

local function try_queue_mark_node_for_level(level)
  local node = MARK_NODES_BY_LEVEL[level]
  if not node then
    return false
  end

  local runtime = get_mark_runtime()
  if runtime.triggered_node_ids[node.id] then
    return false
  end

  runtime.triggered_node_ids[node.id] = true

  local choices = pick_mark_choices(node.choice_count or 3)
  if #choices == 0 then
    message(string.format('%s：本局没有可用烙印候选。', node.ui_title or '烙印选择'))
    return false
  end

  local round_id = runtime.next_round_id
  runtime.next_round_id = runtime.next_round_id + 1
  runtime.rounds_by_id[round_id] = {
    round_id = round_id,
    node_id = node.id,
    trigger_level = node.trigger_level,
    ui_title = node.ui_title,
    state = 'queued',
    candidate_mark_ids = {},
  }

  for _, def in ipairs(choices) do
    runtime.rounds_by_id[round_id].candidate_mark_ids[#runtime.rounds_by_id[round_id].candidate_mark_ids + 1] = def.id
  end

  enqueue_reward_entry({
    kind = 'mark_choice',
    priority = node.queue_priority or 95,
    round_id = round_id,
    source_name = node.ui_title or '烙印选择',
  })

  if runtime.awaiting_choice then
    message(string.format('%s 已加入待处理奖励队列。', node.ui_title or '烙印选择'))
    return true
  end

  if not try_process_reward_queue() and get_reward_queue_count() > 0 then
    message(string.format('%s 已加入待处理奖励队列。', node.ui_title or '烙印选择'))
  end
  return true
end

local function deal_skill_damage(target, amount, damage_type, visual)
  if not STATE.hero or not STATE.hero:is_exist() or not is_active_enemy(target) then
    return
  end

  local final_damage = math.floor((amount or 0) * get_damage_bonus_multiplier(target, {
    is_skill = true,
  }))
  if final_damage <= 0 then
    return
  end

  STATE.hero:damage({
    target = target,
    damage = final_damage,
    type = damage_type or '法术',
    text_type = resolve_damage_text_type(damage_type, visual),
    text_track = visual and visual.text_track or 934269508,
    particle = visual and visual.particle or nil,
    socket = visual and visual.socket or '',
    pos_socket = visual and visual.pos_socket or '',
    common_attack = false,
    no_miss = true,
  })

  if not (visual and visual.skip_hunter_first_hit) then
    try_trigger_hunter_first_hit(target)
  end
end

heal_hero = function(amount)
  if amount <= 0 or not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  local before = STATE.hero:get_hp()
  STATE.hero:add_hp(amount)
  if STATE.hero:get_hp() > before then
    message(string.format('急救生效，英雄生命恢复至 %.0f。', STATE.hero:get_hp()))
  end
end

award_rewards = function(reward, source_text, silent)
  local final_reward = build_reward_with_treasure_bonus(reward)
  if not final_reward then
    return
  end

  if final_reward.gold and final_reward.gold > 0 then
    STATE.resources.gold = STATE.resources.gold + final_reward.gold
  end

  if final_reward.wood and final_reward.wood > 0 then
    STATE.resources.wood = STATE.resources.wood + final_reward.wood
  end

  if final_reward.exp and final_reward.exp > 0 then
    grant_hero_exp(final_reward.exp)
  end

  if silent then
    return
  end

  local parts = {}
  if final_reward.gold and final_reward.gold > 0 then
    parts[#parts + 1] = ('金币 +' .. tostring(final_reward.gold))
  end
  if final_reward.wood and final_reward.wood > 0 then
    parts[#parts + 1] = ('木材 +' .. tostring(final_reward.wood))
  end
  if final_reward.exp and final_reward.exp > 0 then
    parts[#parts + 1] = ('经验 +' .. tostring(final_reward.exp))
  end
  if final_reward.special then
    parts[#parts + 1] = tostring(final_reward.special)
  end

  if #parts > 0 then
    message(string.format('%s：%s', source_text or '获得奖励', table.concat(parts, '，')))
  end
end

local function update_passive_resources(dt)
  local rules = get_resource_rules()
  local gold_per_sec = math.max(
    0,
    (rules.gold_per_sec or 0)
      + get_bond_runtime_bonus('gold_per_sec_bonus')
      + get_treasure_passive_income('gold')
  )
  local wood_per_sec = math.max(
    0,
    (rules.wood_per_sec or 0)
      + get_bond_runtime_bonus('wood_per_sec_bonus')
      + get_treasure_passive_income('wood')
  )
  if (gold_per_sec <= 0 and wood_per_sec <= 0) or not STATE.resources then
    return
  end

  local interval = math.max(0.05, CONFIG.debug_time_scale or 1.0)
  STATE.resource_income_elapsed = (STATE.resource_income_elapsed or 0) + dt

  while STATE.resource_income_elapsed >= interval do
    STATE.resource_income_elapsed = STATE.resource_income_elapsed - interval
    STATE.resources.gold = STATE.resources.gold + gold_per_sec
    STATE.resources.wood = STATE.resources.wood + wood_per_sec
  end
end

local function handle_bond_enemy_kill(info)
  BondSystem.handle_enemy_kill(create_bond_env(), info)
end

local function get_current_wave()
  return battlefield_system.get_current_wave()
end

local function get_boss_name(wave)
  return battlefield_system.get_boss_name(wave)
end

local function show_runtime_status()
  if STATE.session_phase ~= 'battle' then
    local stage_name = STATE.current_stage_def and STATE.current_stage_def.display_name or '未选择'
    local mode_name = STATE.current_mode_def and STATE.current_mode_def.display_name or '标准模式'
    message(string.format('当前处于局外选关阶段：%s %s。', stage_name, mode_name))
    return
  end

  local wave = get_current_wave()
  local wave_text = wave and wave.name or '未开始'
  local boss_text = '无'
  if STATE.active_wave then
    if STATE.active_wave.boss_spawned then
      boss_text = get_boss_name(STATE.active_wave.wave) .. ' 已登场'
    else
      local remain = math.max(0, STATE.active_wave.wave.boss_spawn_sec - STATE.active_wave.elapsed)
      boss_text = string.format('Boss倒计时 %.1f', remain)
    end
  end

  local challenge_count = 0
  for _ in pairs(STATE.active_challenges) do
    challenge_count = challenge_count + 1
  end

  message(string.format(
    '状态：%s，%s，英雄 %s，敌人数 %d，金币 %d，木材 %d，技能点 %d，挑战次数 %d/%d，进行中挑战 %d，待领奖励 %d。',
    wave_text,
    boss_text,
    get_hero_progress_text(),
    STATE.total_enemy_alive,
    STATE.resources.gold,
    STATE.resources.wood,
    STATE.skill_points,
    STATE.challenge_charges,
    CONFIG.challenge_rules.max_charges,
    challenge_count,
    get_reward_queue_count()
  ))
  show_attack_skill_loadout()
  BondSystem.show_loadout(create_bond_env())
  if STATE.bond_runtime and STATE.bond_runtime.swallowed_bonds and #STATE.bond_runtime.swallowed_bonds > 0 then
    BondSystem.show_swallowed_bonds(create_bond_env())
  end
  show_mark_loadout()
  show_treasure_loadout()
  if get_mark_runtime().awaiting_choice then
    show_mark_choices()
  end
  if get_treasure_runtime().awaiting_choice or get_treasure_runtime().awaiting_replace then
    show_treasure_choices()
  end
end

local function trigger_td_skills_on_hit(data)
  if STATE.game_finished or not data.is_normal_hit or data.source_unit ~= STATE.hero then
    return
  end

  local skill = STATE.skill_runtime
  local target = data.target_unit
  if not is_active_enemy(target) then
    return
  end

  if skill.normal_attack_bonus_ratio > 0 then
    deal_skill_damage(target, data.damage * skill.normal_attack_bonus_ratio, '物理', {
      text_type = 'physics',
    })
  end

  if skill.splash_ratio > 0 then
    for _, unit in ipairs(get_enemies_in_range(target, skill.splash_radius, target)) do
      deal_skill_damage(unit, data.damage * skill.splash_ratio, '物理', {
        text_type = 'physics',
      })
    end
  end

  if skill.chain_bounces > 0 and skill.chain_chance > 0 and math.random() <= skill.chain_chance then
    local bounced = 0
    for _, unit in ipairs(get_enemies_in_range(target, skill.chain_radius, target, skill.chain_bounces)) do
      deal_skill_damage(unit, data.damage * skill.chain_ratio, '法术', {
        text_type = 'magic',
        particle = ATTACK_SKILL_VFX.thunder.chain_particle,
      })
      bounced = bounced + 1
      if bounced >= skill.chain_bounces then
        break
      end
    end
  end

  local bond_chain_bounces = math.max(0, round_number(get_bond_runtime_bonus('chain_bounces')))
  local bond_chain_ratio = math.max(0, get_bond_runtime_bonus('chain_ratio'))
  if bond_chain_bounces > 0 and bond_chain_ratio > 0 then
    local bounced = 0
    for _, unit in ipairs(get_enemies_in_range(target, math.max(skill.chain_radius or 0, 420), target, bond_chain_bounces)) do
      deal_skill_damage(unit, data.damage * bond_chain_ratio, '法术', {
        text_type = 'magic',
        particle = ATTACK_SKILL_VFX.thunder.chain_particle,
        skip_hunter_first_hit = true,
      })
      bounced = bounced + 1
      if bounced >= bond_chain_bounces then
        break
      end
    end
  end

  if skill.execute_threshold > 0 and target:is_exist() and target:get_hp() > 0 then
    local max_hp = target:get_attr('最大生命')
    if max_hp > 0 and target:get_hp() / max_hp <= skill.execute_threshold then
      target:kill_by(STATE.hero)
    end
  end
end

local function handle_challenge_success(instance)
  if not instance or not instance.def or instance.def.id ~= 'treasure_trial' then
    return false
  end

  award_rewards(instance.def.reward, instance.def.name .. ' 成功', false)
  queue_treasure_round(instance.def.id, instance.def.name)
  return true
end

local function handle_battle_finished(result)
  if battlefield_system and battlefield_system.cleanup_battle_units then
    battlefield_system.cleanup_battle_units()
  end
  set_battle_hud_visible(false)
  reset_battle_state()
  STATE.session_phase = 'outgame'
  STATE.game_finished = true
  STATE.last_battle_result = result
  if outgame_system then
    outgame_system.enter_outgame(result)
  end
end

battlefield_system = BattlefieldSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  design_seconds = design_seconds,
  random_point_in_area = random_point_in_area,
  set_attr_pack = set_attr_pack,
  add_attr_pack = add_attr_pack,
  get_player = get_player,
  get_enemy_player = get_enemy_player,
  get_hero_level = get_hero_level,
  award_rewards = function(reward, source_text, silent)
    return award_rewards(reward, source_text, silent)
  end,
  build_reward_with_bond_bonus = function(reward)
    return build_reward_with_bond_bonus(reward)
  end,
  handle_bond_enemy_kill = function(info)
    return handle_bond_enemy_kill(info)
  end,
  heal_hero = function(amount)
    return heal_hero(amount)
  end,
  on_hero_damage = function(data)
    return trigger_td_skills_on_hit(data)
  end,
  handle_challenge_success = function(instance)
    return handle_challenge_success(instance)
  end,
  on_finish_game = function(result)
    return handle_battle_finished(result)
  end,
})

local function get_attack_skill(skill_id)
  return attack_skills_system.get_attack_skill(skill_id)
end

local function get_empty_attack_skill_slot()
  return attack_skills_system.get_empty_attack_skill_slot()
end

local function get_unlocked_attack_skill_count()
  return attack_skills_system.get_unlocked_attack_skill_count()
end

local function get_upgrade_pick_count(upgrade_key)
  return attack_skills_system.get_upgrade_pick_count(upgrade_key)
end

local function record_upgrade_pick(upgrade_key)
  return attack_skills_system.record_upgrade_pick(upgrade_key)
end

local function build_attack_skill_slot_text(slot)
  return attack_skills_system.build_attack_skill_slot_text(slot)
end

local function show_attack_skill_loadout()
  return attack_skills_system.show_attack_skill_loadout()
end

local function unlock_attack_skill(skill_id)
  local skill, slot, is_new = attack_skills_system.unlock_attack_skill(skill_id)
  if is_new and STATE.treasure_runtime and STATE.treasure_runtime.applied then
    apply_treasure_bonus_to_attack_skill(
      skill_id,
      skill,
      STATE.treasure_runtime.applied.attack_skill or {},
      1
    )
  end
  if is_new and STATE.mark_runtime and STATE.mark_runtime.applied then
    apply_treasure_bonus_to_attack_skill(
      skill_id,
      skill,
      STATE.mark_runtime.applied.attack_skill or {},
      1
    )
  end
  return skill, slot, is_new
end

local function update_attack_skills(dt)
  return attack_skills_system.update_attack_skills(dt)
end
attack_skills_system = AttackSkillsSystem.create({
  STATE = STATE,
  y3 = y3,
  round_number = round_number,
  message = message,
  ATTACK_SKILL_DEFS = ATTACK_SKILL_DEFS,
  ATTACK_SKILL_VFX = ATTACK_SKILL_VFX,
  get_player = get_player,
  get_hero_point = get_hero_point,
  get_bond_runtime_bonus = get_bond_runtime_bonus,
  is_bond_active = is_bond_active,
  is_active_enemy = is_active_enemy,
  create_attack_skill_instance = create_attack_skill_instance,
  deal_skill_damage = deal_skill_damage,
  get_damage_bonus_multiplier = get_damage_bonus_multiplier,
  get_enemies_in_range = get_enemies_in_range,
  try_trigger_hunter_first_hit = try_trigger_hunter_first_hit,
})

attack_upgrade_system = AttackUpgradeSystem.create({
  STATE = STATE,
  message = message,
  get_attack_skill = get_attack_skill,
  get_empty_attack_skill_slot = get_empty_attack_skill_slot,
  get_unlocked_attack_skill_count = get_unlocked_attack_skill_count,
  get_upgrade_pick_count = get_upgrade_pick_count,
  record_upgrade_pick = record_upgrade_pick,
  unlock_attack_skill = unlock_attack_skill,
  sync_basic_attack_ability = sync_basic_attack_ability,
  build_attack_skill_slot_text = build_attack_skill_slot_text,
})

local function get_pending_round_choice_kind()
  if STATE.awaiting_upgrade and STATE.current_upgrade_choices then
    return 'upgrade'
  end
  if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice and STATE.bond_runtime.current_choices then
    return 'bond'
  end
  if STATE.mark_runtime and STATE.mark_runtime.awaiting_choice and STATE.mark_runtime.current_choices then
    return 'mark'
  end
  if STATE.treasure_runtime then
    if STATE.treasure_runtime.awaiting_choice and STATE.treasure_runtime.current_choices then
      return 'treasure'
    end
    if STATE.treasure_runtime.awaiting_replace and STATE.treasure_runtime.pending_replace_choice then
      return 'treasure'
    end
  end
  return nil
end

local function get_pending_round_choice_label(kind)
  if kind == 'upgrade' then
    return 'G 技能强化'
  end
  if kind == 'bond' then
    return 'F 羁绊抽卡'
  end
  if kind == 'mark' then
    return '烙印选择'
  end
  if kind == 'treasure' then
    return '宝物选择'
  end
  return '当前选择'
end

local function get_active_challenge_count_value()
  local count = 0
  for _ in pairs(STATE.active_challenges or {}) do
    count = count + 1
  end
  return count
end

local function format_attr_value(value)
  return round_number(value or 0)
end

local function build_overview_summary_lines()
  if STATE.session_phase ~= 'battle' then
    return {
      string.format('当前阶段：局外 %s / %s', STATE.selected_stage_id or '未选章节', STATE.selected_mode_id or '未选模式'),
    }
  end

  local lines = {}
  local wave = get_current_wave()
  lines[#lines + 1] = string.format(
    '章节：%s / %s',
    STATE.current_stage_def and STATE.current_stage_def.display_name or '未命名章节',
    STATE.current_mode_def and STATE.current_mode_def.display_name or '未命名模式'
  )
  lines[#lines + 1] = string.format(
    '波次：%s',
    wave and wave.name or '未开始'
  )

  if STATE.active_wave and STATE.active_wave.wave then
    if STATE.active_wave.boss_spawned then
      lines[#lines + 1] = string.format('Boss：%s 已登场', get_boss_name(STATE.active_wave.wave))
    else
      lines[#lines + 1] = string.format(
        'Boss：%.1f 秒后登场',
        math.max(0, (STATE.active_wave.wave.boss_spawn_sec or 0) - (STATE.active_wave.elapsed or 0))
      )
    end
  else
    lines[#lines + 1] = 'Boss：当前无主线波次'
  end

  if STATE.hero and STATE.hero:is_exist() then
    lines[#lines + 1] = string.format(
      '英雄：%s  HP %d/%d  攻击 %d  攻速 %d',
      get_hero_progress_text(),
      format_attr_value(STATE.hero:get_hp()),
      format_attr_value(STATE.hero:get_attr('hp_max')),
      format_attr_value(STATE.hero:get_attr('attack_phy')),
      format_attr_value(STATE.hero:get_attr('attack_speed'))
    )
    lines[#lines + 1] = string.format(
      '暴击 %d%%  爆伤 %d%%  吸血 %d%%  射程 %d',
      format_attr_value(STATE.hero:get_attr('critical_chance')),
      format_attr_value(STATE.hero:get_attr('critical_dmg')),
      format_attr_value(STATE.hero:get_attr('vampire_phy')),
      format_attr_value(STATE.hero:get_attr('attack_range'))
    )
  else
    lines[#lines + 1] = '英雄：当前未创建'
  end

  lines[#lines + 1] = string.format(
    '资源：金币 %d  木材 %d  技能点 %d',
    STATE.resources and STATE.resources.gold or 0,
    STATE.resources and STATE.resources.wood or 0,
    STATE.skill_points or 0
  )
  lines[#lines + 1] = string.format(
    '挑战：%d/%d  进行中 %d  待领奖励 %d  敌人数 %d',
    STATE.challenge_charges or 0,
    CONFIG.challenge_rules.max_charges or 0,
    get_active_challenge_count_value(),
    get_reward_queue_count(),
    STATE.total_enemy_alive or 0
  )

  return lines
end

local function build_attack_skill_overview_lines()
  local lines = {}
  for slot = 1, 4, 1 do
    lines[#lines + 1] = attack_skills_system.build_attack_skill_slot_text(slot)
  end
  return lines
end

local function build_bond_overview_lines()
  local lines = {}
  for slot = 1, 7, 1 do
    lines[#lines + 1] = BondSystem.build_slot_text(STATE, slot)
  end
  return lines
end

local function build_swallowed_bond_overview_lines()
  local runtime = STATE.bond_runtime
  if not runtime or #(runtime.swallowed_bonds or {}) == 0 then
    return { '当前没有已吞噬整套羁绊。' }
  end

  local lines = {}
  local total = #runtime.swallowed_bonds
  local start_index = math.max(1, total - 2)
  for index = start_index, total, 1 do
    lines[#lines + 1] = BondSystem.build_swallowed_bond_text(index, runtime.swallowed_bonds[index])
  end
  return lines
end

local function build_treasure_and_mark_overview_lines()
  local lines = {}
  for slot = 1, 3, 1 do
    lines[#lines + 1] = build_treasure_slot_text(slot)
  end
  local mark_count = math.max(4, get_mark_active_count())
  for slot = 1, mark_count, 1 do
    lines[#lines + 1] = build_mark_slot_text(slot)
  end
  return lines
end

local function build_pending_overview_lines()
  local lines = {}
  local pending_kind = get_pending_round_choice_kind()
  if pending_kind == 'upgrade' then
    lines[#lines + 1] = string.format('当前待选：技能强化，剩余技能点 %d', STATE.skill_points or 0)
  elseif pending_kind == 'bond' then
    lines[#lines + 1] = '当前待选：羁绊三选一'
  elseif pending_kind == 'treasure' then
    local runtime = get_treasure_runtime()
    if runtime.awaiting_replace and runtime.pending_replace_choice then
      lines[#lines + 1] = string.format(
        '当前待选：宝物替换 [%s] %s',
        get_treasure_quality_label(runtime.pending_replace_choice.quality),
        runtime.pending_replace_choice.name
      )
    else
      lines[#lines + 1] = '当前待选：宝物三选一'
    end
  elseif pending_kind == 'mark' then
    local runtime = get_mark_runtime()
    lines[#lines + 1] = string.format('当前待选：%s', runtime.current_round and runtime.current_round.ui_title or '烙印选择')
  else
    lines[#lines + 1] = '当前没有进行中的待选轮次。'
  end

  local queue = get_reward_queue()
  if #queue <= 0 then
    lines[#lines + 1] = '奖励队列：空'
    return lines
  end

  lines[#lines + 1] = string.format('奖励队列：共 %d 项', #queue)
  for index = 1, math.min(4, #queue), 1 do
    local entry = queue[index]
    local label = entry.source_name or entry.kind or '未命名奖励'
    lines[#lines + 1] = string.format('%d. %s [%s]', index, label, tostring(entry.kind or 'unknown'))
  end
  return lines
end

local function build_attribute_summary_lines()
  if not STATE.hero or not STATE.hero:is_exist() then
    return { '英雄：当前未创建。' }
  end

  return {
    string.format('等级：%s', get_hero_progress_text()),
    string.format('生命：%d / %d',
      format_attr_value(STATE.hero:get_hp()),
      format_attr_value(STATE.hero:get_attr('hp_max'))
    ),
    string.format('攻击：%d  攻速：%d  射程：%d',
      format_attr_value(STATE.hero:get_attr('attack_phy')),
      format_attr_value(STATE.hero:get_attr('attack_speed')),
      format_attr_value(STATE.hero:get_attr('attack_range'))
    ),
    string.format('暴击：%d%%  爆伤：%d%%  吸血：%d%%',
      format_attr_value(STATE.hero:get_attr('critical_chance')),
      format_attr_value(STATE.hero:get_attr('critical_dmg')),
      format_attr_value(STATE.hero:get_attr('vampire_phy'))
    ),
  }
end

local function build_damage_bonus_lines()
  return {
    string.format('全伤加成：%d%%', format_attr_value(get_bond_runtime_bonus('all_damage_bonus') * 100)),
    string.format('技能加成：%d%%  普攻加成：%d%%',
      format_attr_value(get_bond_runtime_bonus('skill_damage_bonus') * 100),
      format_attr_value(get_bond_runtime_bonus('normal_attack_damage_bonus') * 100)
    ),
    string.format('Boss加成：%d%%  精英加成：%d%%',
      format_attr_value(get_bond_runtime_bonus('boss_damage_bonus') * 100),
      format_attr_value(get_bond_runtime_bonus('elite_damage_bonus') * 100)
    ),
    string.format('处决阈值：%d%%  处决增伤：%d%%',
      format_attr_value(get_bond_runtime_bonus('execute_threshold') * 100),
      format_attr_value(get_bond_runtime_bonus('execute_damage_bonus') * 100)
    ),
  }
end

local function build_skill_runtime_lines()
  local skill = STATE.skill_runtime or {}
  return {
    string.format('普攻追伤：%d%%  杀敌金币：%d',
      format_attr_value((skill.normal_attack_bonus_ratio or 0) * 100),
      format_attr_value(skill.bonus_gold_on_kill or 0)
    ),
    string.format('溅射：%d%% / 半径 %d',
      format_attr_value((skill.splash_ratio or 0) * 100),
      format_attr_value(skill.splash_radius or 0)
    ),
    string.format('连锁：%d%% / %d 跳 / %d%%',
      format_attr_value((skill.chain_chance or 0) * 100),
      format_attr_value(skill.chain_bounces or 0),
      format_attr_value((skill.chain_ratio or 0) * 100)
    ),
    string.format('医疗无人机：每 %d 杀回复 %d',
      format_attr_value(skill.medbot_every or 0),
      format_attr_value(skill.medbot_heal or 0)
    ),
    string.format('火炮：间隔 %d / 基础 %d / 系数 %d%% / 半径 %d',
      format_attr_value(skill.artillery_interval or 0),
      format_attr_value(skill.artillery_base or 0),
      format_attr_value((skill.artillery_ratio or 0) * 100),
      format_attr_value(skill.artillery_radius or 0)
    ),
  }
end

local function build_economy_bonus_lines()
  return {
    string.format('资源恢复：金币每秒 %+d  木材每秒 %+d',
      format_attr_value(get_bond_runtime_bonus('gold_per_sec_bonus')),
      format_attr_value(get_bond_runtime_bonus('wood_per_sec_bonus'))
    ),
    string.format('奖励倍率：金币 %+d%%  木材 %+d%%  经验 %+d%%',
      format_attr_value(get_treasure_reward_ratio('gold') * 100),
      format_attr_value(get_treasure_reward_ratio('wood') * 100),
      format_attr_value(get_treasure_reward_ratio('exp') * 100)
    ),
    string.format('被动收入：金币 %+d / 秒  木材 %+d / 秒',
      format_attr_value(get_treasure_passive_income('gold')),
      format_attr_value(get_treasure_passive_income('wood'))
    ),
    string.format('构筑计数：宝物 %d / 3  烙印 %d  吞噬羁绊 %d',
      get_treasure_active_count(),
      get_mark_active_count(),
      STATE.bond_runtime and #(STATE.bond_runtime.swallowed_bonds or {}) or 0
    ),
  }
end

local get_runtime_overview_model

local function show_pending_round_choice(kind)
  local current_kind = kind or get_pending_round_choice_kind()
  if current_kind == 'upgrade' then
    attack_upgrade_system.show_upgrade_choices()
    return
  end
  if current_kind == 'bond' then
    BondSystem.try_draw(create_bond_env())
    return
  end
  if current_kind == 'mark' then
    show_mark_choices()
    return
  end
  if current_kind == 'treasure' then
    show_treasure_choices()
  end
end

local function ensure_round_choice_available(allowed_kind)
  local kind = get_pending_round_choice_kind()
  if not kind or kind == allowed_kind then
    return true
  end

  message('请先完成当前' .. get_pending_round_choice_label(kind) .. '。')
  show_pending_round_choice(kind)
  return false
end

local function show_upgrade_choices()
  if not ensure_round_choice_available('upgrade') then
    return
  end
  return attack_upgrade_system.show_upgrade_choices()
end

local function apply_upgrade(index)
  local result = attack_upgrade_system.apply_upgrade(index)
  sync_mark_effects()
  sync_treasure_effects()
  try_open_queued_treasure_round()
  return result
end

local function apply_bond_choice(index)
  BondSystem.apply_choice(create_bond_env(), index)
  try_open_queued_treasure_round()
end

local function apply_round_choice(index)
  if STATE.awaiting_upgrade then
    apply_upgrade(index)
    return
  end
  if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice then
    apply_bond_choice(index)
    return
  end
  if STATE.mark_runtime and STATE.mark_runtime.awaiting_choice then
    apply_mark_choice(index)
    return
  end
  if STATE.treasure_runtime and (STATE.treasure_runtime.awaiting_choice or STATE.treasure_runtime.awaiting_replace) then
    apply_treasure_choice(index)
  end
end

local function try_bond_draw()
  if not ensure_round_choice_available('bond') then
    return
  end
  BondSystem.try_draw(create_bond_env())
end

local function finish_game(is_win, reason)
  return battlefield_system.finish_game(is_win, reason)
end


debug_actions_system = DebugActionsSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  debug_message = debug_message,
  is_battle_active = function()
    return is_battle_active and is_battle_active() or false
  end,
  get_hero_max_level = get_hero_max_level,
  sync_hero_progression = sync_hero_progression,
  unlock_attack_skill = unlock_attack_skill,
  show_attack_skill_loadout = show_attack_skill_loadout,
  show_upgrade_choices = show_upgrade_choices,
  try_bond_draw = try_bond_draw,
  force_spawn_boss = function()
    return battlefield_system.force_spawn_boss()
  end,
  execute_enemy = function(unit)
    return battlefield_system.execute_enemy(unit)
  end,
})

debug_tools_system = DebugToolsSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  make_point = make_point,
  develop_command = develop_command,
  get_player = get_player,
  get_hero_point = get_hero_point,
  get_current_wave = get_current_wave,
  get_boss_name = get_boss_name,
  get_hero_level = get_hero_level,
  get_active_challenge_count = function()
    return battlefield_system.get_active_challenge_count()
  end,
  show_runtime_status = show_runtime_status,
  debug_add_test_resources = function()
    return debug_actions_system.debug_add_test_resources()
  end,
  debug_grant_levels = function(level_count)
    return debug_actions_system.debug_grant_levels(level_count)
  end,
  debug_unlock_all_attack_skills = function()
    return debug_actions_system.debug_unlock_all_attack_skills()
  end,
  debug_open_upgrade_panel = function()
    return debug_actions_system.debug_open_upgrade_panel()
  end,
  debug_trigger_bond_draw = function()
    return debug_actions_system.debug_trigger_bond_draw()
  end,
  debug_refill_challenge_charges = function()
    return debug_actions_system.debug_refill_challenge_charges()
  end,
  debug_force_spawn_boss = function()
    return debug_actions_system.debug_force_spawn_boss()
  end,
  debug_kill_all_active_enemies = function()
    return debug_actions_system.debug_kill_all_active_enemies()
  end,
})

function M.start_wave(index)
  return battlefield_system.start_wave(index)
end

function M.finish_challenge(instance, is_success)
  return battlefield_system.finish_challenge(instance, is_success)
end

local function try_start_challenge(challenge_id)
  if not ensure_round_choice_available(nil) then
    return
  end
  return battlefield_system.try_start_challenge(challenge_id)
end

runtime_hud_system = RuntimeHUDSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  round_number = round_number,
  get_player = get_player,
  get_boss_name = get_boss_name,
  get_hero_level = get_hero_level,
  get_hero_progress_text = get_hero_progress_text,
  get_active_challenge_count = function()
    return battlefield_system.get_active_challenge_count()
  end,
  get_reward_queue_count = get_reward_queue_count,
  get_current_stage_text = function()
    if STATE.current_stage_def and STATE.current_stage_def.display_name then
      return STATE.current_stage_def.display_name
    end
    return '主线 1-1'
  end,
  get_current_decision_panel_model = function()
    local kind = get_pending_round_choice_kind()
    if not kind then
      return nil
    end

    if kind == 'upgrade' then
      local options = {}
      for index, upgrade in ipairs(STATE.current_upgrade_choices or {}) do
        options[#options + 1] = {
          index = index,
          title = upgrade.name,
          desc = upgrade.desc,
          rarity = (upgrade and type(upgrade.key) == 'string' and string.sub(upgrade.key, 1, 7) == 'unlock_')
              and 'rare'
            or 'common',
          tag = upgrade.tag or '强化',
        }
      end
      return {
        kind = kind,
        title = '技能强化',
        subtitle = string.format('消耗 1 点技能点，当前剩余 %d 点', STATE.skill_points or 0),
        hint = '点击卡片或按 1 / 2 / 3 选择',
        options = options,
      }
    end

    if kind == 'bond' then
      local options = {}
      local runtime = STATE.bond_runtime
      local bond_defs = require('entry_objects.bonds').defs_by_id
      for index, card in ipairs(runtime and runtime.current_choices or {}) do
        local bond = bond_defs[card.bond_id]
        local current_count = BondSystem.get_progress_count(STATE, card.bond_id)
        local next_count = bond and math.min(bond.required_count, current_count + 1) or current_count
        options[#options + 1] = {
          index = index,
          title = bond and string.format('%s - %s', bond.name, card.name) or card.name,
          desc = bond and string.format(
            '单卡：%s  成套：%s  进度 %d/%d',
            card.base_effect_desc,
            bond.bond_effect_desc,
            next_count,
            bond.required_count
          ) or card.base_effect_desc,
          rarity = card.quality or 'common',
          tag = '羁绊',
        }
      end
      return {
        kind = kind,
        title = '羁绊抽卡',
        subtitle = #((runtime and runtime.slots) or {}) >= 7
          and '当前羁绊位已满，选择后会自动吞噬 1 张旧卡'
          or '选择 1 张羁绊卡加入当前构筑',
        hint = '点击卡片或按 1 / 2 / 3 选择',
        options = options,
      }
    end

    if kind == 'mark' then
      local options = {}
      local runtime = STATE.mark_runtime
      for index, def in ipairs(runtime and runtime.current_choices or {}) do
        options[#options + 1] = {
          index = index,
          title = def.name,
          desc = def.summary,
          rarity = def.quality or 'common',
          tag = '烙印',
        }
      end
      return {
        kind = kind,
        title = runtime and runtime.current_round and runtime.current_round.ui_title or '烙印选择',
        subtitle = '选择 1 个烙印加入本局成长',
        hint = '点击卡片或按 1 / 2 / 3 选择',
        options = options,
      }
    end

    if kind == 'treasure' then
      local runtime = STATE.treasure_runtime
      local options = {}
      local subtitle = '选择 1 件宝物加入本局构筑'
      local tag = '宝物'

      if runtime and runtime.awaiting_replace and runtime.pending_replace_choice then
        subtitle = string.format(
          '已选中 [%s] %s，请再选择 1 个被替换的宝物位',
          get_treasure_quality_label(runtime.pending_replace_choice.quality),
          runtime.pending_replace_choice.name
        )
        tag = '替换'
        for slot = 1, 3, 1 do
          options[#options + 1] = {
            index = slot,
            title = string.format('宝物位 %d', slot),
            desc = build_treasure_slot_text(slot),
            rarity = 'common',
            tag = tag,
          }
        end
      else
        for index, def in ipairs(runtime and runtime.current_choices or {}) do
          options[#options + 1] = {
            index = index,
            title = def.name,
            desc = def.summary,
            rarity = def.quality or 'common',
            tag = tag,
          }
        end
        if get_treasure_active_count() >= 3 then
          subtitle = '当前 3 个宝物位已满，选中后还需要再指定被替换的旧宝物'
        end
      end

      return {
        kind = kind,
        title = '宝物选择',
        subtitle = subtitle,
        hint = '点击卡片或按 1 / 2 / 3 选择',
        options = options,
      }
    end

    return nil
  end,
  apply_round_choice = apply_round_choice,
  show_upgrade_choices = show_upgrade_choices,
  try_bond_draw = try_bond_draw,
  try_start_challenge = try_start_challenge,
})

get_runtime_overview_model = function()
  if STATE.runtime_overview_mode == 'attr' then
    return {
      title = '局内属性总览',
      subtitle = string.format(
        '按 TAB 查看属性  按 B 返回构筑  当前战斗时长 %s',
        os.date('!%M:%S', math.max(0, math.floor(STATE.runtime_elapsed or 0)))
      ),
      close_label = '关闭 B',
      sections = {
        summary = {
          title = '英雄面板',
          lines = build_attribute_summary_lines(),
        },
        skills = {
          title = '伤害加成',
          lines = build_damage_bonus_lines(),
        },
        bonds = {
          title = '技能运行时',
          lines = build_skill_runtime_lines(),
        },
        treasures = {
          title = '经济与奖励',
          lines = build_economy_bonus_lines(),
        },
        pending = {
          title = '待处理轮次',
          lines = build_pending_overview_lines(),
        },
        swallowed = {
          title = '已吞噬羁绊',
          lines = build_swallowed_bond_overview_lines(),
        },
      },
    }
  end

  return {
    title = '局内构筑总览',
    subtitle = string.format(
      '按 B 收起  按 TAB 查看属性  当前战斗时长 %s',
      os.date('!%M:%S', math.max(0, math.floor(STATE.runtime_elapsed or 0)))
    ),
    close_label = '关闭 B',
    sections = {
      summary = {
        title = '战况摘要',
        lines = build_overview_summary_lines(),
      },
      skills = {
        title = '攻击技能',
        lines = build_attack_skill_overview_lines(),
      },
      bonds = {
        title = '羁绊',
        lines = build_bond_overview_lines(),
      },
      treasures = {
        title = '宝物与烙印',
        lines = build_treasure_and_mark_overview_lines(),
      },
      pending = {
        title = '待处理轮次',
        lines = build_pending_overview_lines(),
      },
      swallowed = {
        title = '已吞噬羁绊',
        lines = build_swallowed_bond_overview_lines(),
      },
    },
  }
end

runtime_overview_system = RuntimeOverviewSystem.create({
  STATE = STATE,
  y3 = y3,
  round_number = round_number,
  get_player = get_player,
  get_runtime_overview_model = function()
    return get_runtime_overview_model()
  end,
  toggle_overview = function(force_visible)
    return runtime_overview_system.toggle_overview(force_visible)
  end,
})

local function ensure_runtime_hud()
  return runtime_hud_system.ensure_hud()
end

local function refresh_runtime_hud()
  return runtime_hud_system.refresh_hud()
end

local function refresh_runtime_overview()
  if runtime_overview_system and runtime_overview_system.refresh_overview then
    runtime_overview_system.refresh_overview()
  end
end

set_battle_hud_visible = function(visible)
  if runtime_hud_system and runtime_hud_system.set_visible then
    runtime_hud_system.set_visible(visible)
  end
  if runtime_overview_system and runtime_overview_system.set_visible and visible ~= true then
    runtime_overview_system.set_visible(false)
  end
end

local function create_hero()
  return battlefield_system.create_hero(ATTACK_SKILL_DEFS.basic_attack.base_range or 250)
end

local function validate_config()
  return battlefield_system.validate_config()
end

is_battle_active = function()
  return STATE.session_phase == 'battle' and STATE.game_finished ~= true
end

reset_battle_state = function()
  STATE.hero = nil
  STATE.hero_common_attack = nil
  STATE.hero_spawn_point = make_point(CONFIG.points.hero_spawn)
  STATE.defense_point = make_point(CONFIG.points.defense_point)
  STATE.all_enemies = y3.unit_group.create()
  STATE.total_enemy_alive = 0
  STATE.current_wave_index = 0
  STATE.started_wave_count = 0
  STATE.active_wave = nil
  STATE.active_challenges = {}
  STATE.resources = {
    gold = get_resource_rules().initial_gold or 0,
    wood = get_resource_rules().initial_wood or 0,
  }
  STATE.resource_income_elapsed = 0
  STATE.bond_runtime = create_bond_runtime()
  STATE.mark_runtime = create_mark_runtime()
  STATE.treasure_runtime = create_treasure_runtime()
  STATE.enemy_info_map = {}
  STATE.skill_points = 0
  STATE.hero_progress = nil
  STATE.awaiting_upgrade = false
  STATE.current_upgrade_choices = nil
  STATE.skill_runtime = create_skill_runtime()
  STATE.attack_skill_state = create_attack_skill_state()
  STATE.reward_queue = {}
  STATE.challenge_charges = CONFIG.challenge_rules.initial_charges
  STATE.challenge_recover_elapsed = 0
  STATE.bond_draw_count = 0
  STATE.defeated_boss_waves = {}
  STATE.basic_attack_ability_bound = false
  STATE.basic_attack_ability_warned = false
  STATE.runtime_elapsed = 0
  STATE.game_finished = false
end

local function reset_session_state()
  reset_battle_state()
  STATE.session_phase = 'outgame'
  STATE.outgame_profile = nil
  STATE.selected_stage_id = nil
  STATE.selected_mode_id = nil
  STATE.current_stage_def = nil
  STATE.current_mode_def = nil
  STATE.last_battle_result = nil
  STATE.outgame_ui = nil
  STATE.outgame_profile_save_enabled = false
  STATE.outgame_profile_save_warned = false
  STATE.runtime_hud = nil
  STATE.runtime_overview = nil
  STATE.runtime_overview_mode = 'build'
  STATE.gm_ui = nil
  STATE.debug_ctrl_down_count = 0
  STATE.game_finished = true
  STATE.events_registered = STATE.events_registered or false
  STATE.dev_commands_registered = STATE.dev_commands_registered or false
end

local function start_selected_stage(stage_id, mode_id)
  local stage_def = CONFIG.stages and CONFIG.stages.by_id and CONFIG.stages.by_id[stage_id] or nil
  local mode_def = CONFIG.stage_modes and CONFIG.stage_modes.by_id and CONFIG.stage_modes.by_id[mode_id] or nil
  local content_source_stage_id = stage_def and (stage_def.content_source_stage_id or stage_def.stage_id) or nil
  local content_source_stage_def = content_source_stage_id
    and CONFIG.stages
    and CONFIG.stages.by_id
    and CONFIG.stages.by_id[content_source_stage_id]
    or nil

  if not stage_def or not mode_def then
    message('当前关卡或模式配置无效。')
    if outgame_system then
      outgame_system.set_ui_visible(true)
      outgame_system.refresh_ui()
    end
    return false
  end

  local mode_supported = false
  for _, supported_mode_id in ipairs(stage_def.mode_ids or {}) do
    if supported_mode_id == mode_id then
      mode_supported = true
      break
    end
  end
  if not mode_supported then
    message('当前章节不支持所选模式。')
    if outgame_system then
      outgame_system.set_ui_visible(true)
      outgame_system.refresh_ui()
    end
    return false
  end

  if not content_source_stage_def then
    message('当前章节复用源配置无效。')
    if outgame_system then
      outgame_system.set_ui_visible(true)
      outgame_system.refresh_ui()
    end
    return false
  end

  if battlefield_system and battlefield_system.cleanup_battle_units then
    battlefield_system.cleanup_battle_units()
  end

  reset_battle_state()
  STATE.session_phase = 'battle'
  STATE.selected_stage_id = stage_id
  STATE.selected_mode_id = mode_id
  STATE.current_stage_def = stage_def
  STATE.current_mode_def = mode_def
  STATE.last_battle_result = nil

  get_player():set_hostility(get_enemy_player(), true)
  get_enemy_player():set_hostility(get_player(), true)

  STATE.hero = create_hero()
  initialize_hero_progression()
  setup_basic_attack_ability()
  ensure_runtime_hud()
  set_battle_hud_visible(true)
  refresh_runtime_hud()

  message(string.format('已进入 %s %s。', stage_def.display_name, mode_def.display_name))
  if stage_def.content_source_stage_id and stage_def.content_source_stage_id ~= stage_def.stage_id then
    message(string.format(
      '%s 当前暂复用 %s 的战斗内容。',
      stage_def.display_name,
      tostring(content_source_stage_def.stage_id or stage_def.content_source_stage_id)
    ))
  end

  M.start_wave(1)
  return true
end

outgame_system = OutgameSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  get_player = get_player,
  start_selected_stage = function(stage_id, mode_id)
    return start_selected_stage(stage_id, mode_id)
  end,
  set_battle_hud_visible = function(visible)
    return set_battle_hud_visible(visible)
  end,
})

local function register_runtime_events()
  if STATE.events_registered then
    return
  end
  STATE.events_registered = true

  y3.game:event('单位-升级', function(_, data)
    if not is_battle_active() or data.unit ~= STATE.hero or not STATE.hero_progress then
      return
    end

    local engine_level = math.min(STATE.hero:get_level(), get_hero_max_level())
    if engine_level <= STATE.hero_progress.level then
      sync_hero_progress_from_engine()
      STATE.hero:set_ability_point(0)
      return
    end

    STATE.hero_progress.level = engine_level
    sync_hero_progress_from_engine()
    STATE.skill_points = STATE.skill_points + 1
    message(string.format('英雄升级至 %d，获得 1 点技能点。按 G 打开强化选择。', STATE.hero_progress.level))
    try_queue_mark_node_for_level(STATE.hero_progress.level)
  end)

  y3.game:event('键盘-按下', 'G', function()
    if not is_battle_active() then
      return
    end
    show_upgrade_choices()
  end)
  y3.game:event('键盘-按下', 'F', function()
    if not is_battle_active() then
      return
    end
    try_bond_draw()
  end)
  y3.game:event('键盘-按下', 'I', function()
    if not is_battle_active() then
      return
    end
    BondSystem.show_swallowed_bonds(create_bond_env())
  end)
  y3.game:event('键盘-按下', 'B', function()
    if not is_battle_active() then
      return
    end
    STATE.runtime_overview_mode = 'build'
    runtime_overview_system.ensure_panel()
    runtime_overview_system.toggle_overview()
  end)
  y3.game:event('键盘-按下', y3.const.KeyboardKey['TAB'], function()
    if not is_battle_active() then
      return
    end
    STATE.runtime_overview_mode = 'attr'
    runtime_overview_system.ensure_panel()
    runtime_overview_system.set_visible(true)
    refresh_runtime_overview()
  end)
  y3.game:event('键盘-按下', 'Q', function()
    if not is_battle_active() then
      return
    end
    try_start_challenge('gold_trial')
  end)
  y3.game:event('键盘-按下', 'W', function()
    if not is_battle_active() then
      return
    end
    try_start_challenge('wood_trial')
  end)
  y3.game:event('键盘-按下', 'E', function()
    if not is_battle_active() then
      return
    end
    try_start_challenge('exp_trial')
  end)
  y3.game:event('键盘-按下', 'R', function()
    if not is_battle_active() then
      return
    end
    try_start_challenge('treasure_trial')
  end)

  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_1'], function()
    if not is_battle_active() then
      return
    end
    apply_round_choice(1)
  end)
  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_2'], function()
    if not is_battle_active() then
      return
    end
    apply_round_choice(2)
  end)
  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_3'], function()
    if not is_battle_active() then
      return
    end
    apply_round_choice(3)
  end)
  y3.game:event('键盘-按下', 'SPACE', function()
    if not is_battle_active() then
      return
    end
    show_runtime_status()
  end)

  if y3.game.is_debug_mode() then
    local function add_debug_ctrl_state(delta)
      STATE.debug_ctrl_down_count = math.max(0, (STATE.debug_ctrl_down_count or 0) + delta)
    end

    y3.game:event('键盘-按下', y3.const.KeyboardKey['LCTRL'], function()
      add_debug_ctrl_state(1)
    end)
    y3.game:event('键盘-按下', y3.const.KeyboardKey['RCTRL'], function()
      add_debug_ctrl_state(1)
    end)
    y3.game:event('键盘-抬起', y3.const.KeyboardKey['LCTRL'], function()
      add_debug_ctrl_state(-1)
    end)
    y3.game:event('键盘-抬起', y3.const.KeyboardKey['RCTRL'], function()
      add_debug_ctrl_state(-1)
    end)

    local function register_debug_hotkey(key_name, callback)
      y3.game:event('键盘-按下', y3.const.KeyboardKey[key_name], function()
        if (STATE.debug_ctrl_down_count or 0) <= 0 then
          return
        end
        callback()
      end)
    end

    register_debug_hotkey('F1', show_debug_hotkey_help)
    register_debug_hotkey('F2', function()
      return debug_actions_system.debug_add_test_resources()
    end)
    register_debug_hotkey('F3', function()
      debug_actions_system.debug_grant_levels(3)
    end)
    register_debug_hotkey('F4', function()
      return debug_actions_system.debug_unlock_all_attack_skills()
    end)
    register_debug_hotkey('F5', function()
      return debug_actions_system.debug_open_upgrade_panel()
    end)
    register_debug_hotkey('F6', function()
      return debug_actions_system.debug_trigger_bond_draw()
    end)
    register_debug_hotkey('F7', function()
      return debug_actions_system.debug_refill_challenge_charges()
    end)
    register_debug_hotkey('F8', function()
      return debug_actions_system.debug_force_spawn_boss()
    end)
    register_debug_hotkey('F9', function()
      return debug_actions_system.debug_kill_all_active_enemies()
    end)
    register_debug_hotkey('F10', function()
      debug_tools_system.ensure_gm_panel()
      debug_tools_system.toggle_gm_panel()
    end)
  end
end

local function start_runtime_loops()
  y3.ltimer.loop(0.25, function()
    if is_battle_active() then
      STATE.runtime_elapsed = (STATE.runtime_elapsed or 0) + 0.25
      update_passive_resources(0.25)
      battlefield_system.update_wave(0.25)
      battlefield_system.update_challenges(0.25)
      battlefield_system.update_challenge_charges(0.25)
      update_bond_effects(0.25)
      update_attack_skills(0.25)
      ensure_runtime_hud()
      set_battle_hud_visible(true)
      refresh_runtime_hud()
      refresh_runtime_overview()
      return
    end

    set_battle_hud_visible(false)
    if outgame_system then
      outgame_system.refresh_ui()
    end
  end)

  y3.ltimer.loop(1, function()
    if not is_battle_active() then
      return
    end

    local skill = STATE.skill_runtime
    if skill.artillery_interval <= 0 or skill.artillery_radius <= 0 or skill.artillery_ratio <= 0 then
      return
    end

    skill.artillery_cd = skill.artillery_cd + 1
    if skill.artillery_cd < skill.artillery_interval then
      return
    end
    skill.artillery_cd = 0

    local anchor = STATE.all_enemies:get_random()
    if not is_active_enemy(anchor) then
      return
    end

    local damage = skill.artillery_base + STATE.hero:get_attr('物理攻击') * skill.artillery_ratio
    for _, unit in ipairs(get_enemies_in_range(anchor, skill.artillery_radius)) do
      deal_skill_damage(unit, damage, '法术')
    end
  end)

  if y3.game.is_debug_mode() then
    y3.ltimer.loop(0.25, function()
      debug_tools_system.ensure_gm_panel()
      debug_tools_system.refresh_gm_panel()
    end)
  end
end

function M.bootstrap()
  if not validate_config() then
    return
  end

  ensure_helper_signals()
  reset_session_state()
  register_runtime_events()
  register_dev_commands()
  start_runtime_loops()
  debug_tools_system.ensure_gm_panel()
  outgame_system.load_profile()
  outgame_system.enter_outgame(nil)
  message('局外选关已启动：先选择章节与模式，再进入战斗。')
  message('开发模式坐标校准：.epos / .eset hero / .eset defense / .earea main_spawn_wave_1 280 360 / .edump')
  message(string.format(
    '当前临时物编：英雄=%s，1-5波主怪=%s/%s/%s/%s/%s。',
    CONFIG.temp_unit_labels.hero,
    CONFIG.temp_unit_labels.wave_1_main,
    CONFIG.temp_unit_labels.wave_2_main,
    CONFIG.temp_unit_labels.wave_3_main,
    CONFIG.temp_unit_labels.wave_4_main,
    CONFIG.temp_unit_labels.wave_5_main
  ))
  if CONFIG.debug_time_scale < 1 then
    message(string.format('当前为调试模式，时间缩放为 %.1f 倍，便于快速验证波次与挑战流程。', CONFIG.debug_time_scale))
    message('调试快捷键已启用：按 Ctrl+F1 查看完整说明。')
    message('GM 调试面板已挂到右上角；也可按 Ctrl+F10 快速折叠。')
  end
end

return M

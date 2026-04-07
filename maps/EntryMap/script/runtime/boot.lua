local CONFIG = require 'entry_config'
local BondSystem = require 'runtime.bonds'
local AttackSkillObjects = require 'entry_objects.attack_skills'
local ProgressionSystem = require 'runtime.progression'
local BattlefieldSystem = require 'runtime.battlefield'
local DebugToolsSystem = require 'runtime.debug_tools'
local DebugActionsSystem = require 'runtime.debug_actions'
local OverviewModelSystem = require 'runtime.overview_model'
local SessionStateSystem = require 'runtime.session_state'
local InputEventsSystem = require 'runtime.input_events'
local RuntimeLoopsSystem = require 'runtime.loops'
local RuntimeOverviewSystem = require 'ui.runtime_overview'
local OutgameSystem = require 'ui.outgame'
local AttackUpgradeSystem = require 'runtime.attack_upgrades'
local AttackSkillsSystem = require 'runtime.attack_skills'
local RewardSystem = require 'runtime.rewards'
local M = {}
local helper_signals_started = false
local heal_hero
local progression_system
local battlefield_system
local debug_tools_system
local debug_actions_system
local runtime_hud_system
local choice_panel_system
local runtime_overview_system
local overview_model_system
local outgame_system
local session_state_system
local input_events_system
local runtime_loops_system
local attack_upgrade_system
local attack_skills_system
local reward_system

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
    split_count = 0,
    split_ratio = 0,
    boss_bonus_ratio = 0,
    armor_break_ratio = 0,
    armor_break_duration = 0,
    armor_break_max_stacks = 0,
    secondary_targets = 0,
    burst_radius = 0,
    burst_ratio = 0,
    extra_targets = 0,
    ignite_duration = 0,
    ignite_tick_ratio = 0,
    ignite_spread_radius = 0,
    frost_control_bonus = 0,
    shatter_bonus = 0,
    shard_count = 0,
    shard_ratio = 0,
    shock_duration = 0,
    shock_bonus = 0,
    field_radius = 0,
    field_ratio = 0,
  }
end

local ATTACK_SKILL_DEFS = AttackSkillObjects.defs_by_id
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
    split_count = 0,
    split_ratio = 0,
    boss_bonus_ratio = 0,
    armor_break_ratio = 0,
    armor_break_duration = 0,
    armor_break_max_stacks = 0,
    secondary_targets = 0,
    burst_radius = 0,
    burst_ratio = 0,
    ignite_duration = 0,
    ignite_tick_ratio = 0,
    ignite_spread_radius = 0,
    frost_control_bonus = 0,
    shatter_bonus = 0,
    shard_count = 0,
    shard_ratio = 0,
    shock_duration = 0,
    shock_bonus = 0,
    field_radius = 0,
    field_ratio = 0,
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
  current_upgrade_round = nil,
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
  choice_panel = nil,
  choice_panel_hidden = false,
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
local reset_session_state
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

reward_system = RewardSystem.create({
  STATE = STATE,
  message = message,
  round_number = round_number,
  add_attr_pack = add_attr_pack,
  sync_basic_attack_ability = sync_basic_attack_ability,
  heal_hero = function(amount)
    return heal_hero(amount)
  end,
})

local function create_treasure_runtime()
  return reward_system.create_treasure_runtime()
end

local function create_mark_runtime()
  return reward_system.create_mark_runtime()
end

local function get_treasure_runtime()
  return reward_system.get_treasure_runtime()
end

local function get_mark_runtime()
  return reward_system.get_mark_runtime()
end

local function get_reward_queue()
  return reward_system.get_reward_queue()
end

local function get_reward_queue_count()
  return reward_system.get_reward_queue_count()
end

local function get_treasure_quality_label(quality)
  return reward_system.get_treasure_quality_label(quality)
end

local function get_mark_quality_label(quality)
  return reward_system.get_mark_quality_label(quality)
end

local function get_treasure_active_count()
  return reward_system.get_treasure_active_count()
end

local function get_mark_active_count()
  return reward_system.get_mark_active_count()
end

local function build_treasure_slot_text(slot)
  return reward_system.build_treasure_slot_text(slot)
end

local function build_mark_slot_text(slot)
  return reward_system.build_mark_slot_text(slot)
end

local function pick_treasure_choices(choice_count)
  return reward_system.pick_treasure_choices(choice_count)
end

local function get_treasure_reward_ratio(key)
  return reward_system.get_treasure_reward_ratio(key)
end

local function get_treasure_passive_income(key)
  return reward_system.get_treasure_passive_income(key)
end

local function get_treasure_runtime_bonus(key)
  return reward_system.get_treasure_runtime_bonus(key)
end

local function build_reward_with_treasure_bonus(reward)
  return reward_system.build_reward_with_treasure_bonus(reward)
end

local function apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)
  return reward_system.apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)
end

local function sync_treasure_effects()
  return reward_system.sync_treasure_effects()
end

local function update_temporary_treasures(dt)
  return reward_system.update_temporary_treasures(dt)
end

local function sync_mark_effects()
  return reward_system.sync_mark_effects()
end

local function show_treasure_loadout()
  return reward_system.show_treasure_loadout()
end

local function show_mark_loadout()
  return reward_system.show_mark_loadout()
end

local function apply_treasure_choice(index)
  return reward_system.apply_treasure_choice(index)
end

local function apply_mark_choice(index)
  return reward_system.apply_mark_choice(index)
end

local function queue_treasure_round(source_type, source_name)
  return reward_system.queue_treasure_round(source_type, source_name)
end

local function try_queue_mark_node_for_level(level)
  return reward_system.try_queue_mark_node_for_level(level)
end

show_mark_choices = function()
  return reward_system.show_mark_choices()
end

show_treasure_choices = function()
  return reward_system.show_treasure_choices()
end

try_open_queued_treasure_round = function()
  return reward_system.try_process_reward_queue()
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

local function update_enemy_statuses(dt)
  return attack_skills_system.update_enemy_statuses(dt)
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

local function get_combat_bonus(key)
  return get_bond_runtime_bonus(key) + get_treasure_runtime_bonus(key)
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
  multiplier = multiplier * (1 + get_combat_bonus('all_damage_bonus'))

  if context and context.is_skill then
    multiplier = multiplier * (1 + get_combat_bonus('skill_damage_bonus'))
  end
  if context and context.is_basic_attack then
    multiplier = multiplier * (1 + get_combat_bonus('normal_attack_damage_bonus'))
  end

  local info = get_enemy_runtime_info(target)
  if is_boss_runtime_enemy(info) then
    multiplier = multiplier * (1 + get_combat_bonus('boss_damage_bonus'))
  end
  if is_elite_runtime_enemy(info) then
    multiplier = multiplier * (1 + get_combat_bonus('elite_damage_bonus'))
  end
  if info and info.kind == 'challenge' then
    multiplier = multiplier * (1 + get_combat_bonus('challenge_damage_bonus'))
  end

  local execute_threshold = get_combat_bonus('execute_threshold')
  if execute_threshold > 0 and get_target_hp_ratio(target) <= execute_threshold then
    multiplier = multiplier * (1 + get_combat_bonus('execute_damage_bonus'))
  end

  if info and info.status then
    local armor_break = info.status.armor_break
    if armor_break and (armor_break.stacks or 0) > 0 and (armor_break.ratio or 0) > 0 then
      multiplier = multiplier * (1 + armor_break.ratio * armor_break.stacks)
    end

    local shock = info.status.shock
    if shock and (shock.bonus or 0) > 0 then
      multiplier = multiplier * (1 + shock.bonus)
    end
  end

  return multiplier
end

local function try_trigger_hunter_first_hit(target)
  BondSystem.try_trigger_hunter_first_hit(create_bond_env(), target)
end

local function build_reward_with_bond_bonus(reward)
  return BondSystem.build_reward_with_bonus(create_bond_env(), reward)
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
        particle = AttackSkillObjects.vfx_by_id.thunder.chain_particle,
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
        particle = AttackSkillObjects.vfx_by_id.thunder.chain_particle,
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
  on_wave_started = function(wave_index)
    return reward_system.handle_wave_started(wave_index)
  end,
  on_boss_spawned = function(boss_info)
    return reward_system.handle_boss_spawned(boss_info)
  end,
  on_challenge_started = function(instance)
    return reward_system.handle_challenge_started(instance)
  end,
  on_challenge_finished = function(instance, is_success)
    return reward_system.handle_challenge_finished(instance, is_success)
  end,
  on_hero_be_hurt = function()
    return reward_system.handle_hero_be_hurt()
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
  ATTACK_SKILL_VFX = AttackSkillObjects.vfx_by_id,
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
  is_bond_active = function(bond_id)
    return BondSystem.is_active(STATE, bond_id)
  end,
  has_active_treasure = function(treasure_id)
    return STATE.treasure_runtime
      and STATE.treasure_runtime.active_by_id
      and STATE.treasure_runtime.active_by_id[treasure_id] ~= nil
  end,
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

local get_runtime_overview_model
overview_model_system = OverviewModelSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  round_number = round_number,
  get_current_wave = get_current_wave,
  get_boss_name = get_boss_name,
  get_pending_round_choice_kind = get_pending_round_choice_kind,
  get_hero_progress_text = get_hero_progress_text,
  get_reward_queue_count = get_reward_queue_count,
  get_reward_queue = get_reward_queue,
  get_mark_runtime = get_mark_runtime,
  get_treasure_runtime = get_treasure_runtime,
  get_treasure_quality_label = get_treasure_quality_label,
  get_treasure_active_count = get_treasure_active_count,
  get_mark_active_count = get_mark_active_count,
  build_treasure_slot_text = build_treasure_slot_text,
  build_mark_slot_text = build_mark_slot_text,
  get_bond_runtime_bonus = get_bond_runtime_bonus,
  get_treasure_reward_ratio = get_treasure_reward_ratio,
  get_treasure_passive_income = get_treasure_passive_income,
  build_attack_skill_slot_text = function(slot)
    return attack_skills_system.build_attack_skill_slot_text(slot)
  end,
  build_bond_slot_text = function(slot)
    return BondSystem.build_slot_text(STATE, slot)
  end,
  build_swallowed_bond_text = function(index, swallowed_bond)
    return BondSystem.build_swallowed_bond_text(index, swallowed_bond)
  end,
})

get_runtime_overview_model = function()
  return overview_model_system.get_runtime_overview_model()
end

local function show_pending_round_choice(kind)
  local current_kind = kind or get_pending_round_choice_kind()
  STATE.choice_panel_hidden = false
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
  STATE.choice_panel_hidden = false
  if not ensure_round_choice_available('upgrade') then
    return
  end
  return attack_upgrade_system.show_upgrade_choices()
end

local function apply_upgrade(index)
  local result = attack_upgrade_system.apply_upgrade(index)
  STATE.choice_panel_hidden = false
  sync_mark_effects()
  sync_treasure_effects()
  try_open_queued_treasure_round()
  return result
end

local function apply_bond_choice(index)
  BondSystem.apply_choice(create_bond_env(), index)
  STATE.choice_panel_hidden = false
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
    STATE.choice_panel_hidden = false
  end
end

local function try_bond_draw()
  STATE.choice_panel_hidden = false
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
  grant_bond_card = function(card_id)
    return BondSystem.debug_grant_card(create_bond_env(), card_id)
  end,
  grant_treasure = function(treasure_id, replace_slot)
    return reward_system.debug_grant_treasure(treasure_id, replace_slot)
  end,
  dump_temporary_treasures = function()
    return reward_system.debug_dump_temporary_treasures()
  end,
})

debug_tools_system = DebugToolsSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  make_point = make_point,
  develop_command = require 'y3.develop.command',
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
  debug_grant_bond_card = function(card_id)
    return debug_actions_system.debug_grant_bond_card(card_id)
  end,
  debug_grant_treasure = function(treasure_id, replace_slot)
    return debug_actions_system.debug_grant_treasure(treasure_id, replace_slot)
  end,
  debug_print_temporary_treasures = function()
    return debug_actions_system.debug_print_temporary_treasures()
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

local function has_pending_treasure_choice()
  return reward_system.has_pending_treasure_choice()
end

local function try_treasure_entry()
  if has_pending_treasure_choice() then
    STATE.choice_panel_hidden = false
    show_pending_round_choice('treasure')
    return
  end
  try_start_challenge('treasure_trial')
end

runtime_hud_system = require('ui.runtime_hud').create({
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
  apply_round_choice = apply_round_choice,
  show_upgrade_choices = show_upgrade_choices,
  try_bond_draw = try_bond_draw,
  try_start_challenge = try_start_challenge,
  try_treasure_entry = try_treasure_entry,
  has_pending_treasure_choice = has_pending_treasure_choice,
})

choice_panel_system = (function()
  local choice_panel_model_system = require('runtime.choice_panel_model').create({
    STATE = STATE,
    message = message,
    BondSystem = BondSystem,
    ATTACK_SKILL_DEFS = ATTACK_SKILL_DEFS,
    TREASURE_DEFS = reward_system.TREASURE_DEFS,
    get_pending_round_choice_kind = get_pending_round_choice_kind,
    get_treasure_runtime = get_treasure_runtime,
    get_treasure_quality_label = get_treasure_quality_label,
    get_treasure_active_count = get_treasure_active_count,
    pick_treasure_choices = pick_treasure_choices,
    create_bond_env = function()
      return create_bond_env()
    end,
    refresh_upgrade_choices = function()
      return attack_upgrade_system.refresh_upgrade_choices()
    end,
  })

  return require('ui.choice_panel').create({
    STATE = STATE,
    y3 = y3,
    round_number = round_number,
    get_player = get_player,
    get_current_choice_panel_model = choice_panel_model_system.get_current_choice_panel_model,
    apply_round_choice = apply_round_choice,
    hide_current_choice_panel = choice_panel_model_system.hide_current_choice_panel,
    refresh_current_choice_panel = choice_panel_model_system.refresh_current_choice_panel,
  })
end)()

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

local function ensure_choice_panel()
  if not choice_panel_system or not choice_panel_system.ensure_panel then
    return nil
  end
  return choice_panel_system.ensure_panel()
end

local function refresh_choice_panel()
  if not choice_panel_system or not choice_panel_system.refresh_panel then
    return nil
  end
  return choice_panel_system.refresh_panel()
end

local function destroy_choice_panel()
  if choice_panel_system and choice_panel_system.destroy_panel then
    choice_panel_system.destroy_panel()
  end
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
  if choice_panel_system and choice_panel_system.set_visible then
    choice_panel_system.set_visible(visible)
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

session_state_system = SessionStateSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  make_point = make_point,
  get_resource_rules = get_resource_rules,
  create_bond_runtime = create_bond_runtime,
  create_mark_runtime = create_mark_runtime,
  create_treasure_runtime = create_treasure_runtime,
  create_skill_runtime = create_skill_runtime,
  create_attack_skill_state = create_attack_skill_state,
  destroy_choice_panel = destroy_choice_panel,
  battlefield_system = battlefield_system,
  get_player = get_player,
  get_enemy_player = get_enemy_player,
  create_hero = create_hero,
  initialize_hero_progression = initialize_hero_progression,
  setup_basic_attack_ability = setup_basic_attack_ability,
  ensure_runtime_hud = ensure_runtime_hud,
  set_battle_hud_visible = function(visible)
    return set_battle_hud_visible(visible)
  end,
  refresh_runtime_hud = refresh_runtime_hud,
  get_outgame_system = function()
    return outgame_system
  end,
  start_wave = function(index)
    return M.start_wave(index)
  end,
})

is_battle_active = function()
  return session_state_system.is_battle_active()
end

reset_battle_state = function()
  return session_state_system.reset_battle_state()
end

reset_session_state = function()
  return session_state_system.reset_session_state()
end

outgame_system = OutgameSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  get_player = get_player,
  start_selected_stage = function(stage_id, mode_id)
    return session_state_system.start_selected_stage(stage_id, mode_id)
  end,
  set_battle_hud_visible = function(visible)
    return set_battle_hud_visible(visible)
  end,
})

input_events_system = InputEventsSystem.create({
  STATE = STATE,
  y3 = y3,
  message = message,
  is_battle_active = function()
    return is_battle_active()
  end,
  get_hero_max_level = get_hero_max_level,
  sync_hero_progress_from_engine = sync_hero_progress_from_engine,
  try_queue_mark_node_for_level = try_queue_mark_node_for_level,
  show_upgrade_choices = show_upgrade_choices,
  try_bond_draw = try_bond_draw,
  show_swallowed_bonds = function()
    return BondSystem.show_swallowed_bonds(create_bond_env())
  end,
  ensure_runtime_overview = function()
    runtime_overview_system.ensure_panel()
    runtime_overview_system.toggle_overview()
  end,
  show_runtime_attr_overview = function()
    runtime_overview_system.ensure_panel()
    runtime_overview_system.set_visible(true)
  end,
  refresh_runtime_overview = refresh_runtime_overview,
  try_start_challenge = try_start_challenge,
  try_treasure_entry = try_treasure_entry,
  apply_round_choice = apply_round_choice,
  show_runtime_status = show_runtime_status,
  show_debug_hotkey_help = show_debug_hotkey_help,
  debug_actions_system = debug_actions_system,
  debug_tools_system = debug_tools_system,
})

local function register_runtime_events()
  return input_events_system.register_runtime_events()
end

runtime_loops_system = RuntimeLoopsSystem.create({
  STATE = STATE,
  y3 = y3,
  is_battle_active = function()
    return is_battle_active()
  end,
  update_passive_resources = update_passive_resources,
  battlefield_system = battlefield_system,
  update_bond_effects = update_bond_effects,
  update_enemy_statuses = update_enemy_statuses,
  update_attack_skills = update_attack_skills,
  update_temporary_treasures = update_temporary_treasures,
  ensure_runtime_hud = ensure_runtime_hud,
  ensure_choice_panel = ensure_choice_panel,
  set_battle_hud_visible = set_battle_hud_visible,
  refresh_runtime_hud = refresh_runtime_hud,
  refresh_choice_panel = refresh_choice_panel,
  refresh_runtime_overview = refresh_runtime_overview,
  outgame_system = outgame_system,
  debug_tools_system = debug_tools_system,
  is_active_enemy = is_active_enemy,
  get_enemies_in_range = get_enemies_in_range,
  deal_skill_damage = deal_skill_damage,
})

local function start_runtime_loops()
  return runtime_loops_system.start_runtime_loops()
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

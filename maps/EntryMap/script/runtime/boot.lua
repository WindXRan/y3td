local CONFIG = require 'config.entry_config'
local BondSystem = require 'runtime.bonds_chain'
local AttackSkillObjects = require 'data.tables.skill.attack_skills'
local BondDrawConfig = require 'data.tables.bond.bond_effect_runtime_rules'
local ProgressionSystem = require 'runtime.progression'
local RewardSystem = require 'runtime.rewards'
local GearUpgrades = require 'runtime.gear_upgrades'
local AttrChoices = require 'runtime.attr_choices'
local HeroAttrSystem = require 'runtime.hero_attr_system'
local AudioSystem = require 'runtime.audio'
local BootCore = require 'runtime.boot_core'
local BootCombat = require 'runtime.boot_combat'
local BootHelpers = require 'runtime.boot_helpers'
local BootServices = require 'runtime.boot_services'
local BootCombatSetup = require 'runtime.boot_combat_setup'
local BootUISetup = require 'runtime.boot_ui_setup'
local BootDebugSetup = require 'runtime.boot_debug_setup'

local RuntimeEntry = {}
RuntimeEntry._services = {}
local projectile_create_original
local projectile_override_hook_installed = false
local helper_signals_started = false

local STATE
local hero_attr_system
local progression_system
local reward_system
local attr_choice_system
local audio_system
local attack_skills_system
local effect_debug_system
local mainline_task_system

local function trace_boot(message)
  return BootHelpers.trace_boot(message)
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

local boot_core = BootCore.create({
  AttackSkillObjects = AttackSkillObjects,
})

local ATTACK_SKILL_DEFS = boot_core.ATTACK_SKILL_DEFS
local ATTACK_SKILL_BLUEPRINTS = boot_core.ATTACK_SKILL_BLUEPRINTS
local ATTACK_SKILL_SLOT_COUNT = boot_core.ATTACK_SKILL_SLOT_COUNT
local create_skill_runtime = boot_core.create_skill_runtime
local create_attack_skill_instance = boot_core.create_attack_skill_instance
local create_attack_skill_state = boot_core.create_attack_skill_state

STATE = boot_core.create_initial_state()
STATE.effect_debug_runtime = nil
STATE.fixed_camera_enabled = true

local BuffSystem = require 'runtime.buff_system'
local CustomHealthBars = require 'runtime.custom_health_bars'

BuffSystem.init({
  STATE = STATE,
  y3 = y3,
  GameTables = CONFIG.GameTables,
})

if CustomHealthBars.set_buff_system then
  CustomHealthBars.set_buff_system(BuffSystem)
end

local function install_projectile_override_hook()
  if projectile_override_hook_installed then
    return
  end
  if not y3 or not y3.projectile or type(y3.projectile.create) ~= 'function' then
    return
  end
  projectile_create_original = y3.projectile.create
  y3.projectile.create = function(args, ...)
    local forced_key = tonumber(STATE and STATE.debug_force_projectile_key) or 0
    if forced_key > 0 and type(args) == 'table' then
      local copied = {}
      for k, v in pairs(args) do
        if k ~= 'skip_projectile_override' then
          copied[k] = v
        end
      end
      if args.skip_projectile_override ~= true then
        copied.key = math.floor(forced_key)
      end
      args = copied
    end
    return projectile_create_original(args, ...)
  end
  projectile_override_hook_installed = true
end

install_projectile_override_hook()

local ProjectileNameGuard = require 'runtime.projectile_name_guard'
ProjectileNameGuard.validate({
  y3 = y3,
}, {
  134255250,
})

local function get_player()
  return BootHelpers.get_player()
end

local function get_enemy_player()
  return BootHelpers.get_enemy_player()
end

function RuntimeEntry.has_valid_hero()
  return STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist()
end

function RuntimeEntry.apply_fixed_camera_mode(enabled)
  local player = get_player()
  if not player or not y3.camera then
    return false
  end

  if enabled == true then
    if not RuntimeEntry.has_valid_hero() then
      return false
    end
    if y3.camera.set_tps_follow_unit then
      y3.camera.set_tps_follow_unit(player, STATE.hero, 0, 0, -60, 300, 0, 220, 1800)
    elseif y3.camera.set_camera_follow_unit then
      y3.camera.set_camera_follow_unit(player, STATE.hero, 300, 0, 220)
    end
    if y3.camera.disable_camera_move then
      y3.camera.disable_camera_move(player)
    end
    if y3.camera.set_moving_with_mouse then
      y3.camera.set_moving_with_mouse(player, false)
    end
    if y3.camera.set_mouse_move_camera_speed then
      y3.camera.set_mouse_move_camera_speed(player, 0)
    end
    if y3.camera.set_keyboard_move_camera_speed then
      y3.camera.set_keyboard_move_camera_speed(player, 0)
    end
    if y3.camera.set_max_distance then
      y3.camera.set_max_distance(player, 1800)
    end
    if y3.camera.set_distance then
      y3.camera.set_distance(player, 1800, 0)
    end
    return true
  end

  if y3.camera.cancel_tps_follow_unit then
    y3.camera.cancel_tps_follow_unit(player)
  end
  if y3.camera.cancel_camera_follow_unit then
    y3.camera.cancel_camera_follow_unit(player)
  end
  if y3.camera.enable_camera_move then
    y3.camera.enable_camera_move(player)
  end
  if y3.camera.set_moving_with_mouse then
    y3.camera.set_moving_with_mouse(player, true)
  end
  return true
end

function RuntimeEntry.sync_fixed_camera_mode()
  return RuntimeEntry.apply_fixed_camera_mode(STATE.fixed_camera_enabled == true)
end

function RuntimeEntry.toggle_fixed_camera()
  STATE.fixed_camera_enabled = not (STATE.fixed_camera_enabled == true)
  local ok = RuntimeEntry.sync_fixed_camera_mode()
  local message = BootServices.get_service('message')
  if message then
    if STATE.fixed_camera_enabled then
      message(ok and '已切换为固定视角（F12 可切换）。' or '已设为固定视角：等待英雄创建后生效。')
    else
      message('已切换为自由视角（F12 可切换）。')
    end
  end
  return STATE.fixed_camera_enabled
end

local function set_ui_root_visible(path, visible)
  local player = get_player()
  if not player or not y3 or not y3.ui or not y3.ui.get_ui then
    return false
  end
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui or (ui.is_removed and ui:is_removed()) then
    return false
  end
  if ui.set_visible then
    ui:set_visible(visible == true)
    return true
  end
  return false
end

local function enforce_runtime_ui_phase(is_battle)
  if is_battle == true then
    local hidden_in_battle = {
      'outgame',
      'ArchivePanel',
      'ArchivePageProfile',
      'ArchivePageEquipment',
      'ArchivePageUniversal',
      'ArchivePageChest',
      'ArchivePagePool',
      'LoadingPanel',
      'LogoPanel',
      'win',
      'loss',
      'CommonTip',
      'SceneUI',
    }
    for _, path in ipairs(hidden_in_battle) do
      set_ui_root_visible(path, false)
    end
    return
  end

  local hidden_outside_battle = {
    'top',
    'GameHUD',
    'BattleHUD',
    'BattleBottomHUD',
    'bottom_bg',
    'Choice_Panel',
    'BondSwallowPanel',
    'CommonTip',
    'SceneUI',
    'LoadingPanel',
    'LogoPanel',
    'win',
    'loss',
    'panel_1',
    'panel',
  }
  for _, path in ipairs(hidden_outside_battle) do
    set_ui_root_visible(path, false)
  end
end

local function sync_gear_runtime_effects(state, hero, config)
  return GearUpgrades.sync_runtime_bonuses(state, hero, config, hero_attr_system)
end

hero_attr_system = HeroAttrSystem.create()
do
  local ratio = CONFIG
      and CONFIG.hero_progression
      and CONFIG.hero_progression.main_stat_attack_ratio
      or nil
  if HeroAttrSystem and HeroAttrSystem.set_main_stat_attack_ratio and ratio ~= nil then
    HeroAttrSystem.set_main_stat_attack_ratio(ratio)
  end
end

local make_point = function(data)
  return BootHelpers.make_point(data)
end

local round_number = function(value)
  return BootHelpers.round_number(value)
end

local design_seconds = function(seconds)
  return BootHelpers.design_seconds(seconds)
end

local get_area = function(area_id)
  if debug_tools_system and debug_tools_system.get_area then
    local area = debug_tools_system.get_area(area_id)
    if area then
      return area
    end
  end
  return CONFIG and CONFIG.areas and CONFIG.areas[area_id]
end

local random_point_in_area = function(area_id)
  local area = get_area(area_id)
  if not area then
    return STATE.defense_point
  end
  local x = math.random(area.x_min, area.x_max)
  local y = math.random(area.y_min, area.y_max)
  return y3.point.create(x, y, area.z or 0)
end

local set_attr_pack = function(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end
  for attr_name, value in pairs(attr_pack) do
    if value ~= nil then
      unit:set_attr(attr_name, value)
    end
  end
end

local add_attr_pack = function(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end
  for attr_name, value in pairs(attr_pack) do
    if value ~= nil and value ~= 0 then
      unit:add_attr(attr_name, value)
    end
  end
end

local add_hero_attr_pack = function(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end
  for attr_name, value in pairs(attr_pack) do
    if value ~= nil and value ~= 0 then
      hero_attr_system.add_attr(unit, attr_name, value)
    end
  end
  hero_attr_system.rebuild_derived_attrs(unit)
end

local snapshot_hero_attrs = function()
  if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
    return nil
  end
  return hero_attr_system.snapshot(STATE.hero, STATE)
end

local build_runtime_attr_dialog_chunks = function()
  local snapshot = snapshot_hero_attrs()
  if snapshot and hero_attr_system and hero_attr_system.log_snapshot then
    hero_attr_system.log_snapshot(STATE.hero, 'show_runtime_attr_dialog', nil, STATE)
  end
  return {}
end

local show_runtime_attr_dialog = function()
  local attr_tips_panel = STATE.attr_tips_panel_system
  if attr_tips_panel and attr_tips_panel.toggle then
    local visible = attr_tips_panel.toggle()
    if visible ~= nil then
      return visible
    end
  end
  local runtime_hud_system = BootServices.get_service('runtime_hud_system')
  if runtime_hud_system and runtime_hud_system.toggle_attr_panel then
    local visible = runtime_hud_system.toggle_attr_panel()
    if visible ~= nil then
      return visible
    end
  end
  local chunks = build_runtime_attr_dialog_chunks()
  for index, text in ipairs(chunks) do
    y3.ltimer.wait((index - 1) * 0.08, function()
      get_player():display_message(text)
    end)
  end
end

local get_resource_rules = function()
  return progression_system.get_resource_rules()
end

local update_passive_resources = function(dt)
  return BootHelpers.update_passive_resources(dt, STATE)
end

local create_bond_env = function()
  return {
    STATE = STATE,
    message = message,
    round_number = round_number,
    y3 = y3,
    hero_attr_system = hero_attr_system,
    heal_hero = heal_hero,
    sync_basic_attack_ability = sync_basic_attack_ability,
    is_active_enemy = is_active_enemy,
    get_enemy_runtime_info = get_enemy_runtime_info,
    is_boss_runtime_enemy = is_boss_runtime_enemy,
    is_elite_runtime_enemy = is_elite_runtime_enemy,
    get_enemies_in_range = get_enemies_in_range,
    deal_skill_damage = deal_skill_damage,
    emit_damage_debug = function(visual)
      emit_damage_debug_visual(visual, nil)
    end,
    reserve_formula_damage = BootCombat.reserve_formula_damage,
    basic_attack_damage_type = ATTACK_SKILL_DEFS.basic_attack.damage_type,
    get_player = get_player,
    report_auto_acceptance_event = function(payload)
      local battle_auto_acceptance_system = BootServices.get_service('battle_auto_acceptance_system')
      if battle_auto_acceptance_system and battle_auto_acceptance_system.record_event then
        battle_auto_acceptance_system.record_event(payload)
      end
    end,
  }
end

local update_bond_effects = function(dt)
  BondSystem.update_effects(create_bond_env(), dt)
end

local update_auto_active_effects = function(dt)
  local auto_active_effects_system = BootServices.get_service('auto_active_effects_system')
  if auto_active_effects_system then
    auto_active_effects_system.update(dt)
  end
  if STATE.hero_form_skills_system then
    STATE.hero_form_skills_system.update(dt)
  end
end

local update_buff_system = function(dt)
  BuffSystem.tick(dt)
end

local update_effect_debug = function(dt)
  local effect_debug_system = BootServices.get_service('effect_debug_system')
  if effect_debug_system then
    effect_debug_system.update(dt)
  end
end

local update_enemy_statuses = function(dt)
  return attack_skills_system and attack_skills_system.update_enemy_statuses(dt)
end

local update_attack_skills = function(dt)
  return attack_skills_system and attack_skills_system.update_attack_skills(dt)
end

local get_bond_runtime_bonus = function(key)
  local evolution_runtime = STATE.evolution_runtime
  local evolution_bonus = 0
  if evolution_runtime and evolution_runtime.applied and evolution_runtime.applied.runtime then
    evolution_bonus = evolution_runtime.applied.runtime[key] or 0
  end
  return BondSystem.get_runtime_bonus(STATE, key) + evolution_bonus
end

local get_combat_bonus = function(key)
  return get_bond_runtime_bonus(key)
end

BootHelpers.set_get_bond_runtime_bonus(get_bond_runtime_bonus)

local get_enemies_in_range = function(center, radius, except_unit, max_count)
  return BootCombat.get_enemies_in_range(center, radius, except_unit, max_count)
end

local get_enemies_on_line = function(origin_point, impact_point, max_distance, line_width, max_hits, except_unit)
  return BootCombat.get_enemies_on_line(origin_point, impact_point, max_distance, line_width, max_hits, except_unit)
end

local get_hero_point = function()
  return BootCombat.get_hero_point()
end

local is_active_enemy = function(unit)
  local battlefield_system = BootServices.get_service('battlefield_system')
  return battlefield_system and battlefield_system.is_active_enemy(unit) or false
end

local get_damage_bonus_multiplier = function(target, context)
  return BootCombat.get_damage_bonus_multiplier(target, context)
end

local try_trigger_hunter_first_hit = function(target)
  return BootCombat.try_trigger_hunter_first_hit(target)
end

local build_reward_with_bond_bonus = function(reward)
  return BootCombat.build_reward_with_bond_bonus(reward)
end

local emit_damage_debug_visual = function(visual, fallback_target)
  return BootCombat.emit_damage_debug_visual(visual, fallback_target)
end

local show_damage_debug_indicator = function(target, visual)
  return BootCombat.show_damage_debug_indicator(target, visual)
end

function RuntimeEntry.emit_skill_hit_feedback(target, final_damage, hp_before)
  return BootCombat.emit_skill_hit_feedback(target, final_damage, hp_before)
end

local deal_skill_damage = function(target, amount, damage, visual)
  return BootCombat.deal_skill_damage(target, amount, damage, visual)
end

local get_hero_attack = function()
  return BootCombat.get_hero_attack()
end

local get_current_hero = function()
  return BootCombat.get_current_hero()
end

local get_primary_target = function(range)
  return BootCombat.get_primary_target(range)
end

local spawn_particle = function(_, point, effect_id, scale, duration, height)
  return BootCombat.spawn_particle(_, point, effect_id, scale, duration, height)
end

local launch_projectile_from_hero = function(projectile_key, target, end_point, angle, time, height, on_finish)
  return BootCombat.launch_projectile_from_hero(projectile_key, target, end_point, angle, time, height, on_finish)
end

local message = function(text)
  if log and log.info then
    log.info('[entry_runtime] ' .. tostring(text))
  end
  if STATE.session_phase == 'battle' then
    local BattleEventPrompts = require 'runtime.battle_event_prompts'
    BattleEventPromptsFactory = require 'runtime.battle_event_prompts'
    local BattleEventPrompts = BattleEventPromptsFactory.create({
      STATE = STATE,
      BattleEventFeedSystem = require 'runtime.battle_event_feed',
      create_battle_event_feed_runtime = function()
        return require 'runtime.battle_event_feed'.create_runtime()
      end,
      infer_battle_event_style = BootHelpers.infer_battle_event_style,
      GearUpgrades = GearUpgrades,
      CONFIG = CONFIG,
      get_message_prompt_system = function()
        return STATE.message_prompt_system
      end,
      get_audio_system = function()
        return audio_system
      end,
      get_runtime_hud_system = function()
        return BootServices.get_service('runtime_hud_system')
      end,
      get_inventory_panel_system = function()
        return STATE.inventory_panel_system
      end,
      message = message,
      ensure_round_choice_available = ensure_round_choice_available,
      sync_gear_runtime_effects = sync_gear_runtime_effects,
    })
    BattleEventPrompts.push_battle_event(text)
    return
  end
  get_player():display_message(text)
end

local heal_hero = function(amount)
  if amount <= 0 or not STATE.hero or not STATE.hero:is_exist() then
    return
  end
  local before = STATE.hero:get_hp()
  STATE.hero:add_hp(amount)
  if STATE.hero:get_hp() > before then
    message(string.format('急救生效，英雄生命恢复至 %.0f。', STATE.hero:get_hp()))
  end
end

BootCombat.set_heal_hero(heal_hero)

local award_rewards = function(reward, source_text, silent)
  if not reward then
    return
  end
  if reward.gold and reward.gold > 0 then
    STATE.resources.gold = STATE.resources.gold + reward.gold
  end
  if reward.wood and reward.wood > 0 then
    STATE.resources.wood = STATE.resources.wood + reward.wood
  end
  if reward.exp and reward.exp > 0 then
    progression_system.grant_hero_exp(reward.exp)
  end
  if silent then
    return
  end
end

local handle_bond_enemy_kill = function(info)
  return BootCombat.handle_bond_enemy_kill(info, auto_active_effects_system, STATE.hero_form_skills_system)
end

local handle_bond_hero_pre_hurt = function(data)
  return BootCombat.handle_bond_hero_pre_hurt(data)
end

local get_current_wave = function()
  local battlefield_system = BootServices.get_service('battlefield_system')
  return battlefield_system and battlefield_system.get_current_wave()
end

local get_boss_name = function(wave)
  local battlefield_system = BootServices.get_service('battlefield_system')
  return battlefield_system and battlefield_system.get_boss_name(wave)
end

local show_runtime_status = function()
  if STATE.session_phase ~= 'battle' then
    local stage_name = STATE.current_stage_def and
        (STATE.current_stage_def.display_label or STATE.current_stage_def.display_name) or '未选择'
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

  local challenge_charge_text = ''
  if STATE.challenge_charge_map then
    local parts = {}
    for _, challenge_id in ipairs({ 'gold_trial', 'wood_trial', 'exp_trial' }) do
      local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
      if def then
        parts[#parts + 1] = string.format(
          '%s %d/%d',
          tostring(def.hotkey or challenge_id),
          tonumber(STATE.challenge_charge_map[challenge_id]) or 0,
          CONFIG.challenge_rules.max_charges or 0
        )
      end
    end
    challenge_charge_text = table.concat(parts, ' ')
  else
    challenge_charge_text = string.format('%d/%d', STATE.challenge_charges, CONFIG.challenge_rules.max_charges)
  end

  local reward_system = BootServices.get_service('reward_system')
  message(string.format(
    '状态：%s，%s，英雄 %s，敌人数 %d，金币 %d，木材 %d，挑战次数 %s，进行中挑战 %d，待领奖励 %d。',
    wave_text,
    boss_text,
    progression_system.get_hero_progress_text(),
    STATE.total_enemy_alive,
    STATE.resources.gold,
    STATE.resources.wood,
    challenge_charge_text,
    challenge_count,
    reward_system and reward_system.get_reward_queue_count() or 0
  ))
end

local set_battle_hud_visible = function(visible)
  local runtime_hud_system = BootServices.get_service('runtime_hud_system')
  if runtime_hud_system and runtime_hud_system.set_battle_hud_visible then
    return runtime_hud_system.set_battle_hud_visible(visible)
  end
  return false
end

local trigger_td_skills_on_hit = function(data)
  return BootCombat.trigger_td_skills_on_hit(data)
end

local handle_battle_finished = function(result)
  if audio_system and audio_system.handle_battle_finished then
    audio_system.handle_battle_finished(result)
  end
  local battlefield_system = BootServices.get_service('battlefield_system')
  if battlefield_system and battlefield_system.cleanup_battle_units then
    battlefield_system.cleanup_battle_units()
  end
  set_battle_hud_visible(false)

  local result_panel_system = BootServices.get_service('result_panel_system')
  local outgame_system = BootServices.get_service('outgame_system')

  local function finish_outgame_transition()
    local reset_func = RuntimeEntry._session_bundle and RuntimeEntry._session_bundle.reset_battle_state
    if reset_func then
      reset_func()
    end
    STATE.session_phase = 'outgame'
    STATE.game_finished = true
    STATE.last_battle_result = result
    enforce_runtime_ui_phase(false)
    if outgame_system then
      outgame_system.enter_outgame(result)
    end
    if result_panel_system then
      result_panel_system.hide()
    end
  end

  if result_panel_system then
    local gold = STATE.resources and STATE.resources.gold or 0
    local hp = STATE.hero and STATE.hero:is_exist() and STATE.hero:get_hp() or 0
    result_panel_system.show({
      is_win = result.is_win,
      reached_wave_index = result.reached_wave_index,
      gold = gold,
      hp = hp,
    }, finish_outgame_transition)
  else
    finish_outgame_transition()
  end
end

local debug_end_battle = function(is_win)
  if STATE.session_phase ~= 'battle' or STATE.game_finished then
    message('当前不在战斗中或游戏已经结束')
    return false
  end
  local result = {
    is_win = is_win,
    reached_wave_index = STATE.current_wave_index or 0,
  }
  handle_battle_finished(result)
  return true
end

local sync_basic_attack_ability = function()
  local attack_skills_system = BootServices.get_service('attack_skills_system')
  return attack_skills_system and attack_skills_system.sync_basic_attack_ability()
end

local setup_basic_attack_ability = function()
  local attack_skills_system = BootServices.get_service('attack_skills_system')
  return attack_skills_system and attack_skills_system.setup_basic_attack_ability()
end

BootCombat.set_sync_basic_attack_ability(sync_basic_attack_ability)
BootCombat.set_get_enemies_in_range(get_enemies_in_range)

progression_system = ProgressionSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  round_number = round_number,
  message = message,
  hero_attr_system = hero_attr_system,
  on_hero_level_up = function(level)
    if attr_choice_system and attr_choice_system.grant_diamond then
      attr_choice_system.grant_diamond(1, level)
    end
    if reward_system and reward_system.try_queue_evolution_node_for_level then
      reward_system.try_queue_evolution_node_for_level(level)
    end
  end,
})

attr_choice_system = AttrChoices.create({
  STATE = STATE,
  hero_attr_system = hero_attr_system,
  message = message,
})

reward_system = RewardSystem.create({
  STATE = STATE,
  message = message,
  round_number = round_number,
  y3 = y3,
  hero_attr_system = hero_attr_system,
  add_attr_pack = add_hero_attr_pack,
  sync_basic_attack_ability = sync_basic_attack_ability,
  setup_basic_attack_ability = setup_basic_attack_ability,
  get_player = get_player,
  heal_hero = heal_hero,
  collect_bond_route_tags = function()
    return BondSystem.collect_route_tags(STATE)
  end,
})

audio_system = AudioSystem.create({
  STATE = STATE,
  y3 = y3,
  get_player = get_player,
  trace = function(msg)
    if log and log.info then
      log.info(msg)
    else
      print(msg)
    end
  end,
  debug_missing_audio = true,
})

mainline_task_system = require('runtime.mainline_tasks').create({
  STATE = STATE,
  CONFIG = CONFIG,
  round_number = round_number,
  message = message,
  add_hero_attr_pack = add_hero_attr_pack,
  award_rewards = function(reward, source_text, silent)
    return award_rewards(reward, source_text, silent)
  end,
  start_mainline_task_challenge = function(task)
    local battlefield_system = BootServices.get_service('battlefield_system')
    return battlefield_system and battlefield_system.start_mainline_task_challenge and
        battlefield_system.start_mainline_task_challenge(task) or nil
  end,
})

local show_evolution_choices = function()
  return reward_system.show_evolution_choices()
end

local debug_message = function(text)
  local debug_tools_system = BootServices.get_service('debug_tools_system')
  return debug_tools_system and debug_tools_system.debug_message(text)
end

local show_debug_hotkey_help = function()
  local debug_tools_system = BootServices.get_service('debug_tools_system')
  return debug_tools_system and debug_tools_system.show_debug_hotkey_help()
end

local get_enemy_runtime_info = function(unit)
  local battlefield_system = BootServices.get_service('battlefield_system')
  return battlefield_system and battlefield_system.get_enemy_runtime_info(unit)
end

local is_boss_runtime_enemy = function(info)
  local battlefield_system = BootServices.get_service('battlefield_system')
  return battlefield_system and battlefield_system.is_boss_runtime_enemy(info)
end

local is_elite_runtime_enemy = function(info)
  local battlefield_system = BootServices.get_service('battlefield_system')
  return battlefield_system and battlefield_system.is_elite_runtime_enemy(info)
end

local get_pending_round_choice_kind = function()
  if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
    return 'gear'
  end
  if attr_choice_system and attr_choice_system.get_pending_choice_kind then
    local attr_kind = attr_choice_system.get_pending_choice_kind()
    if attr_kind then
      return attr_kind
    end
  end
  if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice and STATE.bond_runtime.current_choices then
    return 'bond'
  end
  local evolution_runtime = STATE.evolution_runtime
  if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
    return 'evolution'
  end
  return nil
end

local get_pending_round_choice_label = function(kind)
  if kind == 'bond' then
    return 'F 战术抽卡'
  end
  if kind == 'gear' then
    return '成长武器词条'
  end
  if kind == 'attr' then
    return '属性四选一'
  end
  if kind == 'evolution' then
    return '猎手专精'
  end
  return '当前选择'
end

local show_pending_round_choice = function(kind)
  local current_kind = kind or get_pending_round_choice_kind()
  STATE.choice_panel_hidden = false
  if current_kind == 'bond' then
    BondSystem.try_draw(create_bond_env())
    return
  end
  if current_kind == 'gear' then
    return
  end
  if current_kind == 'attr' then
    local runtime_hud_system = BootServices.get_service('runtime_hud_system')
    return runtime_hud_system and runtime_hud_system.refresh_hud and runtime_hud_system.refresh_hud() or nil
  end
  if current_kind == 'evolution' then
    show_evolution_choices()
    return
  end
end

local ensure_round_choice_available = function(allowed_kind)
  local kind = get_pending_round_choice_kind()
  if not kind or kind == allowed_kind then
    return true
  end
  message('请先完成当前' .. get_pending_round_choice_label(kind) .. '。')
  show_pending_round_choice(kind)
  return false
end

local apply_bond_choice = function(index)
  BondSystem.apply_choice(create_bond_env(), index)
  STATE.choice_panel_hidden = false
end

local apply_round_choice = function(index)
  local kind = get_pending_round_choice_kind()

  if kind == 'gear' then
    if GearUpgrades.apply_affix_choice({
          STATE = STATE,
          CONFIG = CONFIG,
          message = message,
        }, index) then
      if STATE.hero and sync_gear_runtime_effects then
        sync_gear_runtime_effects(STATE, STATE.hero, CONFIG.gear_upgrade_config)
      end
      STATE.choice_panel_hidden = false
      return true
    end
    return false
  end

  if kind == 'attr' then
    local ok = attr_choice_system and attr_choice_system.apply_choice and attr_choice_system.apply_choice(index) or false
    if ok then
      STATE.choice_panel_hidden = false
    end
    return ok
  end

  if kind == 'bond' then
    apply_bond_choice(index)
    return true
  end

  if kind == 'evolution' then
    reward_system.apply_evolution_choice(index)
    STATE.choice_panel_hidden = false
    return true
  end

  return false
end

local refresh_current_choice = function()
  STATE.choice_panel_hidden = false
  local kind = get_pending_round_choice_kind()

  if kind == 'gear' then
    return GearUpgrades.refresh_affix_choices({
      STATE = STATE,
      CONFIG = CONFIG,
      message = message,
    })
  end

  if kind == 'attr' then
    message('属性四选一不支持刷新。')
    return false
  end

  if kind == 'bond' then
    return BondSystem.refresh_choice(create_bond_env())
  end

  if kind == 'evolution' then
    message('当前猎手专精不支持刷新。')
    return false
  end

  return false
end

local try_bond_draw = function()
  STATE.choice_panel_hidden = false
  if not ensure_round_choice_available('bond') then
    return
  end
  if not STATE.resources or (STATE.resources.wood or 0) < (BondDrawConfig.draw_cost or 100) then
    local runtime_hud_system = BootServices.get_service('runtime_hud_system')
    if runtime_hud_system and runtime_hud_system.show_center_tip then
      runtime_hud_system.show_center_tip('木头不足，无法抽卡！')
    end
  end
  BondSystem.try_draw(create_bond_env())
end

local try_skill_draw = function()
  return try_bond_draw()
end

local finish_game = function(is_win, reason)
  local battlefield_system = BootServices.get_service('battlefield_system')
  return battlefield_system and battlefield_system.finish_game(is_win, reason)
end

local try_start_challenge = function(challenge_id)
  if not ensure_round_choice_available(nil) then
    return
  end
  local battlefield_system = BootServices.get_service('battlefield_system')
  return battlefield_system and battlefield_system.try_start_challenge(challenge_id)
end

local use_attr_diamond = function()
  if not ensure_round_choice_available('attr') then
    return false
  end
  local ok = attr_choice_system and attr_choice_system.use_diamond and attr_choice_system.use_diamond() or false
  if ok then
    STATE.choice_panel_hidden = false
    show_pending_round_choice('attr')
  end
  return ok
end

local open_bond_card_album = function()
  local runtime_ui_helpers = BootServices.get_service('runtime_ui_helpers')
  if runtime_ui_helpers and runtime_ui_helpers.show_bond_swallow_panel then
    local panel = runtime_ui_helpers.show_bond_swallow_panel()
    if panel then
      return true
    end
  end
  return false
end

local open_runtime_save_panel = function()
  STATE.choice_panel_hidden = true
  local runtime_ui_helpers = BootServices.get_service('runtime_ui_helpers')
  if runtime_ui_helpers and runtime_ui_helpers.destroy_choice_panel then
    runtime_ui_helpers.destroy_choice_panel()
  end
  if runtime_ui_helpers and runtime_ui_helpers.refresh_bond_swallow_panel then
    STATE.bond_swallow_panel_visible = false
    runtime_ui_helpers.refresh_bond_swallow_panel()
  end
  local outgame_system = BootServices.get_service('outgame_system')
  return outgame_system and outgame_system.open_save_panel and outgame_system.open_save_panel() or false
end

local get_attack_skill = function(skill_id)
  local attack_skills_system = BootServices.get_service('attack_skills_system')
  return attack_skills_system and attack_skills_system.get_attack_skill(skill_id)
end

local build_attack_skill_slot_text = function(slot)
  local attack_skills_system = BootServices.get_service('attack_skills_system')
  return attack_skills_system and attack_skills_system.build_attack_skill_slot_text(slot)
end

local show_attack_skill_loadout = function()
  local attack_skills_system = BootServices.get_service('attack_skills_system')
  return attack_skills_system and attack_skills_system.show_attack_skill_loadout()
end

local unlock_attack_skill = function(skill_id)
  if CONFIG.attack_skill_deprecated and skill_id ~= 'basic_attack' then
    return nil, nil, false
  end
  local attack_skills_system = BootServices.get_service('attack_skills_system')
  local skill, slot, is_new = attack_skills_system and attack_skills_system.unlock_attack_skill(skill_id)
  if is_new and STATE.evolution_runtime and STATE.evolution_runtime.applied then
    local bonus = STATE.evolution_runtime.applied.attack_skill or {}
    local factor = 1
    if bonus.damage_ratio and bonus.damage_ratio ~= 0 then
      skill.damage_ratio = math.max(0, (skill.damage_ratio or 0) + bonus.damage_ratio * factor)
    end
    if bonus.repeat_count and bonus.repeat_count ~= 0 then
      skill.repeat_count = math.max(1, (skill.repeat_count or 1) + bonus.repeat_count * factor)
    end
    if bonus.range_bonus and bonus.range_bonus ~= 0 then
      skill.range_bonus = math.max(0, (skill.range_bonus or 0) + bonus.range_bonus * factor)
    end
    if bonus.cooldown_reduction and bonus.cooldown_reduction ~= 0 then
      skill.cooldown_reduction = math.max(0, (skill.cooldown_reduction or 0) + bonus.cooldown_reduction * factor)
    end
  end
  return skill, slot, is_new
end

local has_bond_route_tag = function(tag)
  return BondSystem.has_route_tag(STATE, tag)
end

local is_debug_effect_mounted = function(effect_id)
  return STATE.effect_debug_runtime
      and STATE.effect_debug_runtime.mounted_effect_ids
      and STATE.effect_debug_runtime.mounted_effect_ids[effect_id] == true
      or false
end

local notify_bond_attack_skill_cast = function(skill, target)
  local battle_auto_acceptance_system = BootServices.get_service('battle_auto_acceptance_system')
  if battle_auto_acceptance_system and battle_auto_acceptance_system.record_event and skill then
    battle_auto_acceptance_system.record_event({
      scope = 'attack_skill',
      key = tostring(skill.id or skill.name or 'unknown'),
      cast = 1,
    })
  end
  return BondSystem.notify_attack_skill_cast(create_bond_env(), skill, target)
end

local notify_auto_active_basic_attack = function(target)
  local auto_active_effects_system = BootServices.get_service('auto_active_effects_system')
  if auto_active_effects_system then
    auto_active_effects_system.handle_basic_attack_cast(target)
  end
  if STATE.hero_form_skills_system then
    STATE.hero_form_skills_system.handle_basic_attack_cast(target)
  end
end

local notify_auto_active_skill_cast = function(skill, target)
  local auto_active_effects_system = BootServices.get_service('auto_active_effects_system')
  if auto_active_effects_system then
    auto_active_effects_system.handle_attack_skill_cast(skill, target)
  end
  if STATE.hero_form_skills_system then
    STATE.hero_form_skills_system.handle_attack_skill_cast(skill, target)
  end
end

local play_basic_attack_sound = function(source_unit)
  return audio_system and audio_system.play_basic_attack and audio_system.play_basic_attack(source_unit) or nil
end

local play_attack_skill_sound = function(skill, source_anchor, stage)
  return audio_system and audio_system.play_attack_skill and
      audio_system.play_attack_skill(skill, source_anchor, stage) or nil
end

local play_skill_sound = function(skill)
  return audio_system and audio_system.play_attack_skill and audio_system.play_attack_skill(skill, STATE.hero) or nil
end

local play_ui_click = function()
  return audio_system and audio_system.play_ui_click and audio_system.play_ui_click() or nil
end

local emit_damage_debug = function(visual)
  emit_damage_debug_visual(visual, nil)
end

local on_wave_started = function(wave_index)
  if audio_system and audio_system.handle_wave_started then
    audio_system.handle_wave_started(wave_index)
  end
  if reward_system and reward_system.handle_wave_started then
    return reward_system.handle_wave_started(wave_index)
  end
end

local on_mainline_task_wave_started = function(wave_index)
  return mainline_task_system.handle_wave_started()
end

local on_mainline_task_enemy_killed = function(info)
  return mainline_task_system.handle_enemy_killed(info)
end

local on_mainline_task_cleared = function(task)
  return mainline_task_system.handle_task_cleared()
end

local on_boss_spawned = function(boss_info)
  if audio_system and audio_system.handle_boss_spawned then
    audio_system.handle_boss_spawned(boss_info)
  end
  if reward_system and reward_system.handle_boss_spawned then
    return reward_system.handle_boss_spawned()
  end
end

local on_boss_warning = function(wave, remain)
  if audio_system and audio_system.handle_boss_warning then
    return audio_system.handle_boss_warning(wave, remain)
  end
  return nil
end

local on_challenge_started = function(instance)
  if audio_system and audio_system.handle_challenge_started then
    audio_system.handle_challenge_started(instance)
  end
  if reward_system and reward_system.handle_challenge_started then
    return reward_system.handle_challenge_started(instance)
  end
end

local on_challenge_finished = function(instance, is_success)
  if audio_system and audio_system.handle_challenge_finished then
    audio_system.handle_challenge_finished(instance, is_success)
  end
  if mainline_task_system and mainline_task_system.handle_challenge_finished then
    mainline_task_system.handle_challenge_finished(instance, is_success)
  end
  if reward_system and reward_system.handle_challenge_finished then
    return reward_system.handle_challenge_finished(instance, is_success)
  end
end

local on_hero_be_hurt = function()
  if audio_system and audio_system.handle_hero_be_hurt then
    audio_system.handle_hero_be_hurt()
  end
  if reward_system and reward_system.handle_hero_be_hurt then
    return reward_system.handle_hero_be_hurt()
  end
end

local play_enemy_death_sound = function(unit, info, death_point)
  local is_boss = info and info.kind == 'boss'
  if audio_system and audio_system.play_enemy_death then
    local played = audio_system.play_enemy_death(unit, is_boss, death_point)
    if played then return played end
  end
  if not death_point or not y3 or not y3.sound then return nil end
  local player = get_player()
  if not player then return nil end
  local death_id = is_boss and 134257420 or 134257799
  local ok, sound = pcall(y3.sound.play_3d, player, death_id, death_point, { ensure = true, height = 0 })
  if ok and sound then return sound end
  return nil
end

local get_attr_choice_runtime = function()
  return attr_choice_system and attr_choice_system.ensure_runtime and attr_choice_system.ensure_runtime() or nil
end

local try_upgrade_growth_weapon = function()
  local BattleEventPrompts = require 'runtime.battle_event_prompts'
  local BattleEventPromptsFactory = require 'runtime.battle_event_prompts'
  local BattleEventPrompts = BattleEventPromptsFactory.create({
    STATE = STATE,
    BattleEventFeedSystem = require 'runtime.battle_event_feed',
    create_battle_event_feed_runtime = function()
      return require 'runtime.battle_event_feed'.create_runtime()
    end,
    infer_battle_event_style = BootHelpers.infer_battle_event_style,
    GearUpgrades = GearUpgrades,
    CONFIG = CONFIG,
    get_message_prompt_system = function()
      return STATE.message_prompt_system
    end,
    get_audio_system = function()
      return audio_system
    end,
    get_runtime_hud_system = function()
      return BootServices.get_service('runtime_hud_system')
    end,
    get_inventory_panel_system = function()
      return STATE.inventory_panel_system
    end,
    message = message,
    ensure_round_choice_available = ensure_round_choice_available,
    sync_gear_runtime_effects = sync_gear_runtime_effects,
  })
  return BattleEventPrompts.try_upgrade_growth_weapon()
end

local toggle_gm_panel = function()
  local gm_bond_effects_system = BootServices.get_service('gm_bond_effects_system')
  if not gm_bond_effects_system then
    return
  end
  gm_bond_effects_system.ensure_board()
  gm_bond_effects_system.toggle_board()
end

local td_damage_api = BootCombatSetup.create_damage_templates({
  y3 = y3,
  deal_skill_damage = deal_skill_damage,
  emit_damage_debug_visual = emit_damage_debug_visual,
  get_enemies_in_range = get_enemies_in_range,
  get_enemies_on_line = get_enemies_on_line,
  is_active_enemy = is_active_enemy,
})

local skill_framework_system = BootCombatSetup.create_skill_framework_system({
  STATE = STATE,
  y3 = y3,
  td_damage_api = td_damage_api,
  get_enemies_in_range = get_enemies_in_range,
  get_current_hero = get_current_hero,
  get_hero_point = get_hero_point,
  get_hero_attack = get_hero_attack,
  get_primary_target = get_primary_target,
  spawn_particle = spawn_particle,
  launch_projectile_from_hero = launch_projectile_from_hero,
})

local sample_skills_system = BootCombatSetup.create_sample_skills_system({
  STATE = STATE,
  y3 = y3,
  message = message,
  hero_attr_system = hero_attr_system,
  skill_framework_system = skill_framework_system,
  td_damage_api = td_damage_api,
  get_enemies_in_range = get_enemies_in_range,
  is_active_enemy = is_active_enemy,
  get_current_hero = get_current_hero,
  get_hero_point = get_hero_point,
  get_hero_attack = get_hero_attack,
  get_primary_target = get_primary_target,
  spawn_particle = spawn_particle,
  launch_projectile_from_hero = launch_projectile_from_hero,
})

BootCombatSetup.register_generated_skills(skill_framework_system)

attack_skills_system = BootCombatSetup.create_attack_skills_system({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  skill_framework_system = skill_framework_system,
  ATTACK_SKILL_SLOT_COUNT = ATTACK_SKILL_SLOT_COUNT,
  round_number = round_number,
  message = message,
  hero_attr_system = hero_attr_system,
  ATTACK_SKILL_DEFS = ATTACK_SKILL_DEFS,
  AttackSkillObjects = AttackSkillObjects,
  get_player = get_player,
  get_hero_point = get_hero_point,
  get_bond_runtime_bonus = get_bond_runtime_bonus,
  is_active_enemy = is_active_enemy,
  create_attack_skill_instance = create_attack_skill_instance,
  deal_skill_damage = deal_skill_damage,
  emit_damage_debug = emit_damage_debug,
  get_damage_bonus_multiplier = get_damage_bonus_multiplier,
  get_enemies_in_range = get_enemies_in_range,
  try_trigger_hunter_first_hit = try_trigger_hunter_first_hit,
  notify_bond_attack_skill_cast = notify_bond_attack_skill_cast,
  notify_auto_active_basic_attack = notify_auto_active_basic_attack,
  notify_auto_active_skill_cast = notify_auto_active_skill_cast,
  play_basic_attack_sound = play_basic_attack_sound,
  play_attack_skill_sound = play_attack_skill_sound,
})

local auto_active_effects_system = BootCombatSetup.create_auto_active_effects_system({
  BootServices.attack_skills_system_setter(attack_skills_system),

  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  ATTACK_SKILL_SLOT_COUNT = ATTACK_SKILL_SLOT_COUNT,
  hero_attr_system = hero_attr_system,
  AttackSkillObjects = AttackSkillObjects,
  get_player = get_player,
  has_bond_route_tag = has_bond_route_tag,
  is_debug_effect_mounted = is_debug_effect_mounted,
  is_active_enemy = is_active_enemy,
  get_enemies_in_range = get_enemies_in_range,
  deal_skill_damage = deal_skill_damage,
  heal_hero = heal_hero,
})

local effect_debug_system = BootCombatSetup.create_effect_debug_system({
  STATE = STATE,
  message = message,
  y3 = y3,
  auto_active_effects_system = auto_active_effects_system,
})

BootServices.effect_debug_system_setter(effect_debug_system)

STATE.hero_form_skills_system = BootCombatSetup.create_hero_form_skills_system({
  STATE = STATE,
  y3 = y3,
  message = message,
  round_number = round_number,
  hero_attr_system = hero_attr_system,
  is_active_enemy = is_active_enemy,
  get_enemies_in_range = get_enemies_in_range,
  get_enemy_runtime_info = get_enemy_runtime_info,
  is_boss_runtime_enemy = is_boss_runtime_enemy,
  is_elite_runtime_enemy = is_elite_runtime_enemy,
  deal_skill_damage = deal_skill_damage,
  heal_hero = heal_hero,
  play_skill_sound = play_skill_sound,
})

local battlefield_system = BootCombatSetup.create_battlefield_system({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  design_seconds = design_seconds,
  random_point_in_area = random_point_in_area,
  hero_attr_system = hero_attr_system,
  set_attr_pack = set_attr_pack,
  add_attr_pack = add_attr_pack,
  get_player = get_player,
  get_enemy_player = get_enemy_player,
  get_hero_level = progression_system.get_hero_level,
  award_rewards = award_rewards,
  build_reward_with_bond_bonus = build_reward_with_bond_bonus,
  handle_bond_enemy_kill = handle_bond_enemy_kill,
  heal_hero = heal_hero,
  play_enemy_death_sound = play_enemy_death_sound,
  on_hero_damage = trigger_td_skills_on_hit,
  apply_formula_damage_override = BootCombat.apply_formula_damage_override,
  on_hero_before_hurt = handle_bond_hero_pre_hurt,
  on_wave_started = on_wave_started,
  on_mainline_task_wave_started = on_mainline_task_wave_started,
  on_mainline_task_enemy_killed = on_mainline_task_enemy_killed,
  on_mainline_task_cleared = on_mainline_task_cleared,
  on_boss_spawned = on_boss_spawned,
  on_boss_warning = on_boss_warning,
  on_challenge_started = on_challenge_started,
  on_challenge_finished = on_challenge_finished,
  on_hero_be_hurt = on_hero_be_hurt,
  on_hero_attr_changed = snapshot_hero_attrs,
  on_finish_game = handle_battle_finished,
})

BootCombat.set_dependencies(STATE, hero_attr_system, battlefield_system, nil, nil)

BootUISetup.set_ui_enhancements({
  STATE = STATE,
  CONFIG = CONFIG,
  apply_round_choice = apply_round_choice,
})

local overview_model_system = BootUISetup.create_overview_model_system({
  STATE = STATE,
  CONFIG = CONFIG,
  round_number = round_number,
  hero_attr_system = hero_attr_system,
  get_current_wave = get_current_wave,
  get_boss_name = get_boss_name,
  get_pending_round_choice_kind = get_pending_round_choice_kind,
  get_hero_progress_text = progression_system.get_hero_progress_text,
  get_reward_queue_count = reward_system.get_reward_queue_count,
  get_reward_queue = reward_system.get_reward_queue,
  get_evolution_runtime = reward_system.get_evolution_runtime,
  get_evolution_active_count = reward_system.get_evolution_active_count,
  build_evolution_slot_text = reward_system.build_evolution_slot_text,
  get_bond_runtime_bonus = get_bond_runtime_bonus,
  ATTACK_SKILL_SLOT_COUNT = ATTACK_SKILL_SLOT_COUNT,
  build_attack_skill_slot_text = build_attack_skill_slot_text,
})

get_runtime_overview_model = function()
  return overview_model_system.get_runtime_overview_model()
end

local runtime_hud_system = BootUISetup.create_runtime_hud_system({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  ATTACK_SKILL_SLOT_COUNT = ATTACK_SKILL_SLOT_COUNT,
  get_player = get_player,
  hero_attr_system = hero_attr_system,
  mainline_task_system = mainline_task_system,
  message = message,
  try_bond_draw = try_bond_draw,
  try_skill_draw = try_skill_draw,
  try_start_challenge = try_start_challenge,
  open_runtime_save_panel = open_runtime_save_panel,
  toggle_gm_panel = toggle_gm_panel,
  try_upgrade_growth_weapon = try_upgrade_growth_weapon,
  use_attr_diamond = use_attr_diamond,
  get_attr_choice_runtime = get_attr_choice_runtime,
  apply_attr_choice = function(index)
    return attr_choice_system and attr_choice_system.apply_choice and attr_choice_system.apply_choice(index) or false
  end,
  show_runtime_status = show_runtime_status,
  build_runtime_attr_dialog_chunks = build_runtime_attr_dialog_chunks,
  BondDrawConfig = BondDrawConfig,
  BootHelpers = BootHelpers,
  auto_active_effects_system = auto_active_effects_system,
  play_ui_click = play_ui_click,
})

STATE.attr_tips_panel_system = BootUISetup.create_attr_tips_panel_system({
  STATE = STATE,
  y3 = y3,
  get_player = get_player,
  hero_attr_system = hero_attr_system,
})

local runtime_ui_helpers = BootUISetup.create_runtime_ui_helpers({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  get_player = get_player,
  get_pending_round_choice_kind = get_pending_round_choice_kind,
  refresh_current_choice = refresh_current_choice,
  apply_round_choice = apply_round_choice,
  reward_system = reward_system,
  get_runtime_hud_system = function() return runtime_hud_system end,
  get_runtime_overview_model = get_runtime_overview_model,
})

local growth_weapon_item_tip_system = BootUISetup.create_growth_weapon_item_tip_system({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  get_player = get_player,
})

local result_panel_system = BootUISetup.create_result_panel_system({
  y3 = y3,
  get_player = get_player,
})

local debug_actions_system = BootDebugSetup.create_debug_actions_system({
  STATE = STATE,
  CONFIG = CONFIG,
  debug_message = debug_message,
  ATTACK_SKILL_SLOT_COUNT = ATTACK_SKILL_SLOT_COUNT,
  is_battle_active = function() return is_battle_active and is_battle_active() or false end,
  get_hero_max_level = progression_system.get_hero_max_level,
  sync_hero_progression = progression_system.sync_hero_progression,
  ATTACK_SKILL_BLUEPRINTS = ATTACK_SKILL_BLUEPRINTS,
  unlock_attack_skill = unlock_attack_skill,
  show_attack_skill_loadout = show_attack_skill_loadout,
  try_bond_draw = try_bond_draw,
  battlefield_system = battlefield_system,
  create_bond_env = create_bond_env,
  effect_debug_system = effect_debug_system,
  auto_active_effects_system = auto_active_effects_system,
  sample_skills_system = sample_skills_system,
})

local debug_tools_system = BootDebugSetup.create_debug_tools_system({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  make_point = make_point,
  get_player = get_player,
  get_hero_point = get_hero_point,
  get_current_wave = get_current_wave,
  get_boss_name = get_boss_name,
  get_hero_level = progression_system.get_hero_level,
  battlefield_system = battlefield_system,
  show_runtime_status = show_runtime_status,
  debug_actions_system = debug_actions_system,
  show_runtime_attr_dialog = show_runtime_attr_dialog,
  effect_debug_system = effect_debug_system,
  sample_skills_system = sample_skills_system,
})

local gm_bond_effects_system = BootDebugSetup.create_gm_bond_effects_system({
  STATE = STATE,
  y3 = y3,
  message = message,
  get_player = get_player,
  create_bond_env = create_bond_env,
  sample_skills_system = sample_skills_system,
  skill_framework_system = skill_framework_system,
  attack_skills_system = attack_skills_system,
  debug_actions_system = debug_actions_system,
  debug_end_battle_win = function() return debug_end_battle(true) end,
  debug_end_battle_lose = function() return debug_end_battle(false) end,
})

local battle_auto_acceptance_system = BootDebugSetup.create_battle_auto_acceptance_system({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  get_enemy_player = get_enemy_player,
  battlefield_system = battlefield_system,
  create_bond_env = create_bond_env,
})

BootServices.heal_hero_setter(heal_hero)
BootServices.progression_system_setter(progression_system)
BootServices.battlefield_system_setter(battlefield_system)
BootServices.debug_tools_system_setter(debug_tools_system)
BootServices.debug_actions_system_setter(debug_actions_system)
BootServices.gm_bond_effects_system_setter(gm_bond_effects_system)
BootServices.runtime_hud_system_setter(runtime_hud_system)
BootServices.overview_model_system_setter(overview_model_system)
BootServices.reward_system_setter(reward_system)
BootServices.attr_choice_system_setter(attr_choice_system)
BootServices.audio_system_setter(audio_system)
BootServices.skill_framework_system_setter(skill_framework_system)
BootServices.sample_skills_system_setter(sample_skills_system)
BootServices
    .message_setter(message)
BootServices.ensure_round_choice_available_setter(ensure_round_choice_available)
BootServices.get_enemies_in_range_setter(get_enemies_in_range)
BootServices.deal_skill_damage_setter(deal_skill_damage)

RuntimeEntry._session_bundle = require('runtime.boot_session_setup').create({
  RuntimeEntry = RuntimeEntry,
  HeroSelectionRangeSystem = require 'runtime.hero_selection_range',
  BootSession = require 'runtime.boot_session',
  OutgameSystem = require 'ui.outgame',
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  hero_attr_system = hero_attr_system,
  enforce_runtime_ui_phase = enforce_runtime_ui_phase,
  make_point = make_point,
  get_resource_rules = get_resource_rules,
  create_bond_runtime = function()
    return BondSystem.create_runtime()
  end,
  create_battle_event_feed_runtime = function()
    return require 'runtime.battle_event_feed'.create_runtime()
  end,
  create_effect_debug_runtime = function()
    return require 'runtime.effect_debug'.create_runtime()
  end,
  reward_system = reward_system,
  create_skill_runtime = create_skill_runtime,
  create_attack_skill_state = create_attack_skill_state,
  reset_skill_framework_runtime = function()
    if sample_skills_system and sample_skills_system.reset_framework_runtime then
      return sample_skills_system.reset_framework_runtime()
    end
    if skill_framework_system and skill_framework_system.reset_runtime then
      return skill_framework_system.reset_runtime()
    end
    return false
  end,
  ATTACK_SKILL_BLUEPRINTS = ATTACK_SKILL_BLUEPRINTS,
  ATTACK_SKILL_DEFS = ATTACK_SKILL_DEFS,
  runtime_ui_helpers = runtime_ui_helpers,
  battlefield_system = battlefield_system,
  progression_system = progression_system,
  GearUpgrades = GearUpgrades,
  get_player = get_player,
  get_enemy_player = get_enemy_player,
  get_outgame_system = function()
    return outgame_system
  end,
  unlock_attack_skill = unlock_attack_skill,
  show_attack_skill_loadout = show_attack_skill_loadout,
  setup_basic_attack_ability = setup_basic_attack_ability,
  set_battle_hud_visible = set_battle_hud_visible,
  audio_system = audio_system,
})

local hero_selection_range_system = RuntimeEntry._session_bundle.hero_selection_range_system
local session_state_system = RuntimeEntry._session_bundle.session_state_system
local outgame_system = RuntimeEntry._session_bundle.outgame_system
local is_battle_active = RuntimeEntry._session_bundle.is_battle_active
local reset_battle_state = RuntimeEntry._session_bundle.reset_battle_state
local reset_session_state = RuntimeEntry._session_bundle.reset_session_state

BootServices.hero_selection_range_system_setter(hero_selection_range_system)

RuntimeEntry._runtime_bundle = require('runtime.boot_runtime_setup').create({
  RuntimeEntry = RuntimeEntry,
  BootInput = require 'runtime.boot_input',
  BootEvents = require 'runtime.boot_events',
  BootLoops = require 'runtime.boot_loops',
  BootDevCommands = require 'runtime.boot_dev_commands',
  BootBootstrapSequence = require 'runtime.boot_bootstrap_sequence',
  STATE = STATE,
  y3 = y3,
  message = message,
  progression_system = progression_system,
  reward_system = reward_system,
  attr_choice_system = attr_choice_system,
  runtime_ui_helpers = runtime_ui_helpers,
  mainline_task_system = mainline_task_system,
  debug_actions_system = debug_actions_system,
  debug_tools_system = debug_tools_system,
  gm_bond_effects_system = gm_bond_effects_system,
  audio_system = audio_system,
  hero_attr_system = hero_attr_system,
  battle_auto_acceptance_system = battle_auto_acceptance_system,
  battlefield_system = battlefield_system,
  hero_selection_range_system = hero_selection_range_system,
  outgame_system = outgame_system,
  growth_weapon_item_tip_system = growth_weapon_item_tip_system,
  result_panel_system = result_panel_system,
  get_player = get_player,
  is_battle_active = function()
    return is_battle_active()
  end,
  try_bond_draw = try_bond_draw,
  try_skill_draw = try_skill_draw,
  open_bond_card_album = open_bond_card_album,
  show_runtime_attr_dialog = show_runtime_attr_dialog,
  try_start_challenge = try_start_challenge,
  apply_round_choice = apply_round_choice,
  show_runtime_status = show_runtime_status,
  open_runtime_save_panel = open_runtime_save_panel,
  use_attr_diamond = use_attr_diamond,
  show_debug_hotkey_help = show_debug_hotkey_help,
  show_debug_tip_example = runtime_hud_system and runtime_hud_system.show_debug_tip_example,
  update_passive_resources = update_passive_resources,
  update_bond_effects = update_bond_effects,
  update_auto_active_effects = update_auto_active_effects,
  update_effect_debug = update_effect_debug,
  update_enemy_statuses = update_enemy_statuses,
  update_attack_skills = update_attack_skills,
  update_buff_system = update_buff_system,
  is_active_enemy = is_active_enemy,
  get_enemies_in_range = get_enemies_in_range,
  deal_skill_damage = deal_skill_damage,
  emit_damage_debug_visual = emit_damage_debug_visual,
  set_battle_hud_visible = set_battle_hud_visible,
  enforce_runtime_ui_phase = enforce_runtime_ui_phase,
  ensure_helper_signals = ensure_helper_signals,
  reset_session_state = function()
    return reset_session_state()
  end,
})

local input_events_system = RuntimeEntry._runtime_bundle.input_events_system
local runtime_loops_system = RuntimeEntry._runtime_bundle.runtime_loops_system
local register_dev_commands = RuntimeEntry._runtime_bundle.register_dev_commands
RuntimeEntry.register_runtime_events = RuntimeEntry._runtime_bundle.register_runtime_events
RuntimeEntry.start_runtime_loops = RuntimeEntry._runtime_bundle.start_runtime_loops
RuntimeEntry.run_bootstrap_sequence = RuntimeEntry._runtime_bundle.run_bootstrap_sequence

function RuntimeEntry.bootstrap()
  if not RuntimeEntry.validate_config then
    RuntimeEntry.validate_config = function() return true end
  end
  if not RuntimeEntry.validate_config() then
    return
  end
  RuntimeEntry.run_bootstrap_sequence()
end

RuntimeEntry.sync_services = function()
  BootServices.sync_services(RuntimeEntry)
end

return RuntimeEntry

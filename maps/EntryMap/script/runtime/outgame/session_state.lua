local M = {}
local y3 = y3
local CONFIG = require 'config.entry_config'
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers
local ok_gear, GearUpgrades = pcall(require, 'runtime.progression.gear_upgrades')
if not ok_gear then GearUpgrades = {} end

function M.create(env)
  local STATE = env and env.STATE or _G.STATE
  local message = _G.message or function() end
  local make_point = env and env.make_point or (BootHelpers and BootHelpers.make_point or y3.point.create)
  local get_player = function()
    if env and env.get_player then
      return env.get_player()
    elseif y3 and y3.player and y3.player.get_main_player then
      return y3.player.get_main_player()
    elseif _G.get_player then
      return _G.get_player()
    end
    return nil
  end
  local get_enemy_player = env and env.get_enemy_player or BootHelpers.get_enemy_player
  local set_battle_hud_visible = _G.set_battle_hud_visible or function() end
  local enforce_runtime_ui_phase = _G.enforce_runtime_ui_phase or function() end

  local battlefield_system = _G.battlefield_system
  local progression_system = _G.progression_system
  local runtime_ui_helpers = _G.runtime_ui_helpers
  local destroy_choice_panel = runtime_ui_helpers and runtime_ui_helpers.destroy_choice_panel or function() end
  local ensure_runtime_hud = runtime_ui_helpers and runtime_ui_helpers.ensure_runtime_hud or function() end
  local refresh_runtime_hud = runtime_ui_helpers and runtime_ui_helpers.refresh_runtime_hud or function() end
  local initialize_hero_progression = progression_system and progression_system.initialize_hero_progression or function() end

  local function create_battle_event_feed_runtime()
    return require 'runtime.combat.battle_event_feed'.create_runtime()
  end
  local function create_evolution_runtime()
    local rs = _G.reward_system
    return rs and rs.create_evolution_runtime and rs.create_evolution_runtime()
  end
  local function get_outgame_system()
    return _G.outgame_system
  end
  local function enter_battle_audio()
    local as = _G.audio_system
    return as and as.enter_battle and as.enter_battle() or nil
  end
  local function start_wave(index)
    if battlefield_system and battlefield_system.start_wave then
      battlefield_system.start_wave(index)
    end
  end

  local function setup_basic_attack_ability()
    if STATE.basic_attack_ability_bound then return end
    STATE.basic_attack_ability_bound = true
    
    local hero = STATE.hero
    if not hero or not hero:is_exist() then
      print('[session_state] setup_basic_attack_ability: hero not found')
      return
    end
    
    print('[session_state] setup_basic_attack_ability: setting up basic attack')
    
    if _G.sync_basic_attack_ability then
      _G.sync_basic_attack_ability()
    else
      print('[session_state] setup_basic_attack_ability: _G.sync_basic_attack_ability not defined')
    end
  end

  local resource_system = env.resource_system or require('runtime.resources.resource_system').create()
  local get_resource_rules = env.get_resource_rules or function()
    return progression_system and progression_system.get_resource_rules() or {}
  end
  local create_hero = env.create_hero
  local ensure_gear_runtime = env.ensure_gear_runtime or
    function(state, config)
      if GearUpgrades and GearUpgrades.ensure_runtime then
        return GearUpgrades.ensure_runtime(state, config)
      end
    end
  local sync_gear_items_to_hero = env.sync_gear_items_to_hero or
    function(state, hero, config)
      if GearUpgrades and GearUpgrades.sync_items_to_hero then
        return GearUpgrades.sync_items_to_hero(state, hero, config)
      end
    end
  local sync_gear_runtime_effects = env.sync_gear_runtime_effects or
    function(state, hero, config)
      if GearUpgrades and GearUpgrades.sync_runtime_bonuses then
        return GearUpgrades.sync_runtime_bonuses(state, hero, config)
      end
    end

  local function is_battle_active()
    return STATE.session_phase == 'battle'
  end

  local function cleanup_swallow_panel()
    local panel = STATE.swallow_panel
    local root = panel and panel.root or nil
    if root and root.remove and (not root.is_removed or not root:is_removed()) then
      root:remove()
    end
    STATE.swallow_panel = nil
  end

  local function reset_battle_state()
    pcall(destroy_choice_panel)
    cleanup_swallow_panel()
    if battlefield_system and battlefield_system.destroy_debug_spawn_areas then
      battlefield_system.destroy_debug_spawn_areas()
    end
    STATE.hero = nil
    STATE.hero_common_attack = nil
    STATE.hero_spawn_point = make_point(CONFIG.points.hero_spawn)
    STATE.defense_point = make_point(CONFIG.points.defense_point)
    STATE.all_enemies = y3.unit_group.create()
    STATE.total_enemy_alive = 0
    STATE.total_kills = 0
    STATE.current_wave_index = 0
    STATE.started_wave_count = 0
    STATE.active_wave = nil
    resource_system.init_from_rules(get_resource_rules())
    STATE.resources = resource_system.get_state_table()
    _G.resource_system = resource_system
    STATE.resource_income_elapsed = 0
    STATE.battle_event_feed = create_battle_event_feed_runtime()
    STATE.evolution_runtime = create_evolution_runtime()
    STATE.enemy_info_map = {}
    STATE.reward_queue = {}
    STATE.defeated_boss_waves = {}
    STATE.gear_state = nil
    STATE._battle_hud_visible_cached = nil
    
    end

  local function reset_session_state()
    pcall(destroy_choice_panel)
    reset_battle_state()
    STATE.session_phase = 'outgame'
    STATE.outgame_ui = nil
    STATE.events_registered = STATE.events_registered or false
    STATE.dev_commands_registered = STATE.dev_commands_registered or false
    if enforce_runtime_ui_phase then
      enforce_runtime_ui_phase(false)
    end
  end

  local function show_stage_start_error(text)
    message(text)
    local outgame_system = get_outgame_system()
    if outgame_system then
      outgame_system.set_ui_visible(true)
      outgame_system.refresh_ui()
    end
    return false
  end

  local function try_initialize_battle_ui()
    local ok, err = pcall(function()
      ensure_runtime_hud()
      set_battle_hud_visible(true)
      refresh_runtime_hud()
    end)
    if ok then
      STATE.runtime_ui_fault_logged = false
      STATE.runtime_ui_fault_message = nil
      return true
    end

    local err_text = tostring(err)
    if STATE.runtime_ui_fault_logged ~= true or STATE.runtime_ui_fault_message ~= err_text then
      print(string.format('[session_state] battle ui init failed, continue with degraded ui: %s', err_text))
    end
    STATE.runtime_ui_fault_logged = true
    STATE.runtime_ui_fault_message = err_text
    -- 降级策略：UI 初始化异常不再阻断开局，避免事件名字典差异导致无法进入战斗。
    -- 相关点击交互可能失效，但战斗主流程应继续可玩。
    return true
  end

  local function rollback_stage_start(text)
    if set_battle_hud_visible then
      pcall(set_battle_hud_visible, false)
    end
    if battlefield_system and battlefield_system.cleanup_battle_units then
      battlefield_system.cleanup_battle_units()
    end
    reset_battle_state()
    STATE.session_phase = 'outgame'
    STATE.last_battle_result = nil
    if enforce_runtime_ui_phase then
      enforce_runtime_ui_phase(false)
    end
    return show_stage_start_error(text)
  end

  local function try_enter_battle_audio()
    local ok, err = pcall(enter_battle_audio)
    if ok then
      return true
    end

    print(string.format('[session_state] battle audio init failed, continue stage start: %s', tostring(err)))
    return false
  end

  local function start_selected_stage()
    if STATE.session_phase == 'battle' then
      return false
    end

    if battlefield_system and battlefield_system.cleanup_battle_units then
      battlefield_system.cleanup_battle_units()
    end

    reset_battle_state()
    STATE.session_phase = 'battle'
    STATE.last_battle_result = nil
    if enforce_runtime_ui_phase then
      enforce_runtime_ui_phase(true)
    end

    local player = get_player()
    local enemy_player = get_enemy_player()
    if player and enemy_player then
      player:set_hostility(enemy_player, true)
      enemy_player:set_hostility(player, true)
    end

    STATE.hero = create_hero()
    if battlefield_system and battlefield_system.create_debug_spawn_areas then
      battlefield_system.create_debug_spawn_areas()
    end
    if ensure_gear_runtime then
      ensure_gear_runtime(STATE, CONFIG.gear_upgrade_config)
    end
    if sync_gear_items_to_hero and STATE.hero then
      sync_gear_items_to_hero(STATE, STATE.hero, CONFIG.gear_upgrade_config)
    end
    if sync_gear_runtime_effects and STATE.hero then
      sync_gear_runtime_effects(STATE, STATE.hero, CONFIG.gear_upgrade_config)
      if STATE.hero.set_hp then
        local hp = STATE.hero:get_attr('生命')
        if hp and hp > 0 then
          STATE.hero:set_hp(hp)
        end
      end
    end
    -- snapshot 已移除，直接使用原生属性 API
    initialize_hero_progression()
    setup_basic_attack_ability()
    if not try_initialize_battle_ui() then
      return rollback_stage_start('战斗界面初始化失败，请稍后重试。')
    end
    
    try_enter_battle_audio()

    print('[SESSION STATE] 调用 start_wave(1), session_phase=' .. tostring(STATE.session_phase))
    start_wave(1)
    return true
  end

  return {
    is_battle_active = is_battle_active,
    reset_battle_state = reset_battle_state,
    reset_session_state = reset_session_state,
    start_selected_stage = start_selected_stage,
  }
end

return M



local M = {}
local y3 = y3
local CONFIG = require 'config.entry_config'
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers
local GearUpgrades = require 'runtime.progression.gear_upgrades'

function M.create(env)
  local STATE = env and env.STATE or _G.STATE
  local message = _G.message or function() end
  local make_point = env and env.make_point or BootHelpers.make_point
  local get_player = env and env.get_player or BootHelpers.get_player
  local get_enemy_player = env and env.get_enemy_player or BootHelpers.get_enemy_player
  local SkillRuntime = env and env.SkillRuntime
  local SkillState = env and env.SkillState
  local setup_basic_attack_ability = _G.setup_basic_attack_ability or function() end
  local set_battle_hud_visible = _G.set_battle_hud_visible or function() end
  local enforce_runtime_ui_phase = _G.enforce_runtime_ui_phase or function() end

  local battlefield_system = _G.battlefield_system
  local hero_attr_system = _G.hero_attr_system
  local progression_system = _G.progression_system
  local runtime_ui_helpers = _G.runtime_ui_helpers
  local destroy_choice_panel = runtime_ui_helpers and runtime_ui_helpers.destroy_choice_panel or function() end
  local ensure_runtime_hud = runtime_ui_helpers and runtime_ui_helpers.ensure_runtime_hud or function() end
  local refresh_runtime_hud = runtime_ui_helpers and runtime_ui_helpers.refresh_runtime_hud or function() end
  local initialize_hero_progression = progression_system and progression_system.initialize_hero_progression or function() end

  local function create_battle_event_feed_runtime()
    return require 'runtime.combat.battle_event_feed'.create_runtime()
  end
  local function create_effect_debug_runtime()
    return require 'runtime.effects.effect_debug'.create_runtime()
  end
  local function create_evolution_runtime()
    local rs = _G.reward_system
    return rs and rs.create_evolution_runtime and rs.create_evolution_runtime()
  end
  local function reset_skill_framework_runtime()
    local sfs = _G.sample_skills_system
    if sfs and sfs.reset_framework_runtime then return sfs.reset_framework_runtime() end
    local sf = _G.skill_framework_system
    if sf and sf.reset_runtime then return sf.reset_runtime() end
    return false
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

  local resource_system = env.resource_system or require('runtime.resources.resource_system').create()
  local get_resource_rules = env.get_resource_rules or function()
    return progression_system and progression_system.get_resource_rules() or {}
  end
  local create_hero = env.create_hero
  local ensure_gear_runtime = env.ensure_gear_runtime or
    function(state, config) return GearUpgrades.ensure_runtime(state, config) end
  local sync_gear_items_to_hero = env.sync_gear_items_to_hero or
    function(state, hero, config) return GearUpgrades.sync_items_to_hero(state, hero, config) end
  local sync_gear_runtime_effects = env.sync_gear_runtime_effects or
    function(state, hero, config)
      return GearUpgrades.sync_runtime_bonuses(state, hero, config, hero_attr_system)
    end

  local function is_battle_active()
    return STATE.session_phase == 'battle' and STATE.game_finished ~= true
  end

  local function reset_challenge_charge_state()
    STATE.challenge_charge_map = {}
    STATE.challenge_recover_elapsed_map = {}

    local total = 0
    for challenge_id in pairs(CONFIG.challenges or {}) do
      STATE.challenge_charge_map[challenge_id] = CONFIG.challenge_rules.initial_charges
      STATE.challenge_recover_elapsed_map[challenge_id] = 0
      total = total + (CONFIG.challenge_rules.initial_charges or 0)
    end

    STATE.challenge_charges = total
    STATE.challenge_recover_elapsed = 0
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
    STATE.active_challenges = {}
    resource_system.init_from_rules(get_resource_rules())
    STATE.resources = resource_system.get_state_table()
    _G.resource_system = resource_system
    STATE.resource_income_elapsed = 0
    STATE.battle_event_feed = create_battle_event_feed_runtime()
    STATE.effect_debug_runtime = create_effect_debug_runtime()
    STATE.evolution_runtime = create_evolution_runtime()
    STATE.auto_active_effects = nil
    STATE.enemy_info_map = {}
    STATE.hero_progress = nil
    STATE.skill_runtime = SkillRuntime.create()
    STATE.attack_skill_state = SkillState.create()
    STATE.active_skill_runtime = {
      active_ids = {},
      queue = {},
      cursor = 1,
      next_cast_ready_time = 0,
    }
    if reset_skill_framework_runtime then
      reset_skill_framework_runtime()
    end
    STATE.reward_queue = {}
    reset_challenge_charge_state()
    STATE.skill_draw_count = 0
    STATE.defeated_boss_waves = {}
    STATE.basic_attack_ability_bound = false
    STATE.basic_attack_ability_warned = false
    STATE.runtime_elapsed = 0
    STATE.hero_attr_runtime = nil
    STATE.attr_choice_runtime = nil
    STATE.bond_swallow_panel_visible = false
    STATE.bond_swallow_selected_root_index = nil
    STATE.skill_swallow_panel_visible = false
    STATE.skill_swallow_selected_root_index = nil
    STATE.gear_state = nil
    STATE.choice_panel_hidden = false
    STATE.choice_panel = nil
    STATE.game_finished = false
    STATE.runtime_ui_fault_logged = false
    STATE.runtime_ui_fault_message = nil
    STATE._battle_hud_visible_cached = nil
  end

  local function reset_session_state()
    pcall(destroy_choice_panel)
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
    STATE.choice_panel = nil
    STATE.runtime_overview = nil
    STATE.runtime_overview_mode = 'build'
    STATE.gm_ui = nil
    STATE.debug_ctrl_down_count = 0
    STATE.game_finished = true
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
    STATE.current_stage_def = nil
    STATE.current_mode_def = nil
    STATE.last_battle_result = nil
    STATE.game_finished = true
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

  local function start_selected_stage(stage_id, mode_id)
    if STATE.session_phase == 'battle' then
      return false
    end

    local stage_def = CONFIG.stages and CONFIG.stages.by_id and CONFIG.stages.by_id[stage_id] or nil
    local mode_def = CONFIG.stage_modes and CONFIG.stage_modes.by_id and CONFIG.stage_modes.by_id[mode_id] or nil
    local content_source_stage_id = stage_def and (stage_def.content_source_stage_id or stage_def.stage_id) or nil
    local content_source_stage_def = content_source_stage_id
      and CONFIG.stages
      and CONFIG.stages.by_id
      and CONFIG.stages.by_id[content_source_stage_id]
      or nil

    if not stage_def or not mode_def then
      return show_stage_start_error('当前关卡或模式配置无效。')
    end

    local mode_supported = false
    for _, supported_mode_id in ipairs(stage_def.mode_ids or {}) do
      if supported_mode_id == mode_id then
        mode_supported = true
        break
      end
    end
    if not mode_supported then
      return show_stage_start_error('当前章节不支持所选模式。')
    end

    if not content_source_stage_def then
      return show_stage_start_error('当前章节复用源配置无效。')
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
    if enforce_runtime_ui_phase then
      enforce_runtime_ui_phase(true)
    end

    get_player():set_hostility(get_enemy_player(), true)
    get_enemy_player():set_hostility(get_player(), true)

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
      if hero_attr_system and hero_attr_system.get_attr and STATE.hero.set_hp then
        STATE.hero:set_hp(hero_attr_system.get_attr(STATE.hero, '生命结算值'))
      end
    end
    if hero_attr_system and STATE.hero then
      hero_attr_system.snapshot(STATE.hero, STATE)
      if hero_attr_system.log_snapshot then
        hero_attr_system.log_snapshot(
          STATE.hero,
          'start_selected_stage',
          string.format('stage=%s mode=%s hp=%s', tostring(stage_id), tostring(mode_id), tostring(STATE.hero:get_hp())),
          STATE
        )
      end
    end
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



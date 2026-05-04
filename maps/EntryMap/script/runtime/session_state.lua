local EquipmentCatalog = require 'data.tables.economy.equipment_catalog'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local make_point = env.make_point
  local get_resource_rules = env.get_resource_rules
  local create_bond_runtime = env.create_bond_runtime
  local create_battle_event_feed_runtime = env.create_battle_event_feed_runtime
  local create_effect_debug_runtime = env.create_effect_debug_runtime
  local create_mark_runtime = env.create_mark_runtime
  local create_treasure_runtime = env.create_treasure_runtime
  local create_skill_runtime = env.create_skill_runtime
  local create_attack_skill_state = env.create_attack_skill_state
  local reset_skill_framework_runtime = env.reset_skill_framework_runtime
  local ATTACK_SKILL_BLUEPRINTS = env.ATTACK_SKILL_BLUEPRINTS or { list = {} }
  local destroy_choice_panel = env.destroy_choice_panel
  local battlefield_system = env.battlefield_system
  local hero_attr_system = env.hero_attr_system
  local get_player = env.get_player
  local get_enemy_player = env.get_enemy_player
  local create_hero = env.create_hero
  local initialize_hero_progression = env.initialize_hero_progression
  local ensure_gear_runtime = env.ensure_gear_runtime
  local sync_gear_items_to_hero = env.sync_gear_items_to_hero
  local sync_gear_runtime_effects = env.sync_gear_runtime_effects
  local unlock_attack_skill = env.unlock_attack_skill
  local show_attack_skill_loadout = env.show_attack_skill_loadout
  local setup_basic_attack_ability = env.setup_basic_attack_ability
  local ensure_runtime_hud = env.ensure_runtime_hud
  local set_battle_hud_visible = env.set_battle_hud_visible
  local refresh_runtime_hud = env.refresh_runtime_hud
  local enter_battle_audio = env.enter_battle_audio
  local disable_local_attack_preview = env.disable_local_attack_preview

  local function grant_equipment_drag_test_items(hero)
    -- 关闭开局测试武器注入，避免和成长武器并存造成“多余武器槽位”。
    if not hero then
      return false
    end
    if hero.get_bar_cnt and hero.set_bar_cnt then
      local target_bar_cnt = tonumber(EquipmentCatalog.bar_slot_count) or 6
      local current_bar_cnt = tonumber(hero:get_bar_cnt()) or 0
      if current_bar_cnt < target_bar_cnt then
        hero:set_bar_cnt(target_bar_cnt)
      end
    end
    return false
  end

  local function grant_test_attack_skills_on_stage_start()
    return 0
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
    destroy_choice_panel()
    cleanup_swallow_panel()
    if disable_local_attack_preview then
      disable_local_attack_preview()
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
    STATE.resources = {
      gold = get_resource_rules().initial_gold or 0,
      wood = get_resource_rules().initial_wood or 0,
    }
    STATE.resource_income_elapsed = 0
    STATE.bond_runtime = create_bond_runtime()
    STATE.skill_runtime = STATE.bond_runtime
    STATE.battle_event_feed = create_battle_event_feed_runtime()
    STATE.effect_debug_runtime = create_effect_debug_runtime()
    STATE.mark_runtime = create_mark_runtime()
    STATE.treasure_runtime = create_treasure_runtime()
    STATE.auto_active_effects = nil
    STATE.enemy_info_map = {}
    STATE.hero_progress = nil
    STATE.skill_runtime = create_skill_runtime()
    STATE.attack_skill_state = create_attack_skill_state()
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
    STATE.bond_draw_count = 0
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
  end

  local function reset_session_state()
    destroy_choice_panel()
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
  end

  local function show_stage_start_error(text)
    message(text)
    local outgame_system = env.get_outgame_system()
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
    return show_stage_start_error(text)
  end

  local function try_enter_battle_audio()
    if not enter_battle_audio then
      return false
    end

    local ok, err = pcall(enter_battle_audio)
    if ok then
      return true
    end

    print(string.format('[session_state] battle audio init failed, continue stage start: %s', tostring(err)))
    return false
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

    get_player():set_hostility(get_enemy_player(), true)
    get_enemy_player():set_hostility(get_player(), true)

    STATE.hero = create_hero()
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
    if STATE.hero then
      grant_equipment_drag_test_items(STATE.hero)
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
    grant_test_attack_skills_on_stage_start()
    if not try_initialize_battle_ui() then
      return rollback_stage_start('战斗界面初始化失败，请稍后重试。')
    end
    try_enter_battle_audio()

    if stage_def.content_source_stage_id and stage_def.content_source_stage_id ~= stage_def.stage_id then
    end

    env.start_wave(1)
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



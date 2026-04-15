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
  local destroy_choice_panel = env.destroy_choice_panel
  local battlefield_system = env.battlefield_system
  local hero_attr_system = env.hero_attr_system
  local get_player = env.get_player
  local get_enemy_player = env.get_enemy_player
  local create_hero = env.create_hero
  local initialize_hero_progression = env.initialize_hero_progression
  local ensure_gear_runtime = env.ensure_gear_runtime
  local setup_basic_attack_ability = env.setup_basic_attack_ability
  local ensure_runtime_hud = env.ensure_runtime_hud
  local set_battle_hud_visible = env.set_battle_hud_visible
  local refresh_runtime_hud = env.refresh_runtime_hud

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
    STATE.battle_event_feed = create_battle_event_feed_runtime()
    STATE.effect_debug_runtime = create_effect_debug_runtime()
    STATE.mark_runtime = create_mark_runtime()
    STATE.treasure_runtime = create_treasure_runtime()
    STATE.auto_active_effects = nil
    STATE.enemy_info_map = {}
    STATE.skill_points = 0
    STATE.hero_progress = nil
    STATE.awaiting_upgrade = false
    STATE.current_upgrade_choices = nil
    STATE.current_upgrade_round = nil
    STATE.skill_runtime = create_skill_runtime()
    STATE.attack_skill_state = create_attack_skill_state()
    STATE.reward_queue = {}
    reset_challenge_charge_state()
    STATE.bond_draw_count = 0
    STATE.defeated_boss_waves = {}
    STATE.basic_attack_ability_bound = false
    STATE.basic_attack_ability_warned = false
    STATE.runtime_elapsed = 0
    STATE.hero_attr_runtime = nil
    STATE.choice_panel_hidden = false
    STATE.choice_panel = nil
    STATE.game_finished = false
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
    ensure_runtime_hud()
    set_battle_hud_visible(true)
    refresh_runtime_hud()

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

local M = {}

--- 创建初始 STATE
function M.create_initial_state()
  return {
    hero = nil,
    hero_common_attack = nil,
    hero_spawn_point = nil,
    defense_point = nil,
    all_enemies = nil,
    total_enemy_alive = 0,
    total_kills = 0,
    current_wave_index = 0,
    started_wave_count = 0,
    active_wave = nil,
    resources = nil,
    resource_income_elapsed = 0,
    battle_event_feed = nil,
    evolution_runtime = nil,
    enemy_info_map = nil,
    hero_progress = nil,
    reward_queue = nil,
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
    runtime_attr_tab_panel = nil,
    runtime_attr_tab_selected = 'summary',
    hero_attr_runtime = nil,
    attr_choice_runtime = nil,
    gm_ui = nil,
    session_phase = 'outgame',
    outgame_profile = nil,
    last_battle_result = nil,
    outgame_ui = nil,
    outgame_profile_save_enabled = false,
    outgame_profile_save_warned = false,
  }
end

function M.create(args)
  return {
    create_initial_state = M.create_initial_state,
  }
end

return M

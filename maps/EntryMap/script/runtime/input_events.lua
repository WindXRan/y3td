local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local is_battle_active = env.is_battle_active
  local get_hero_max_level = env.get_hero_max_level
  local sync_hero_progress_from_engine = env.sync_hero_progress_from_engine
  local try_queue_mark_node_for_level = env.try_queue_mark_node_for_level
  local grant_attr_diamond = env.grant_attr_diamond
  local try_bond_draw = env.try_bond_draw
  local show_bond_progress = env.show_bond_progress
  local show_runtime_attr_tip_panel = env.show_runtime_attr_tip_panel
  local show_runtime_attr_dialog = env.show_runtime_attr_dialog
  local start_current_task_challenge = env.start_current_task_challenge
  local try_start_challenge = env.try_start_challenge
  local try_evolution_entry = env.try_evolution_entry
  local apply_round_choice = env.apply_round_choice
  local show_runtime_status = env.show_runtime_status
  local show_debug_hotkey_help = env.show_debug_hotkey_help
  local debug_actions_system = env.debug_actions_system
  local gm_bond_effects_system = env.gm_bond_effects_system
  local toggle_talk_input = env.toggle_talk_input
  local toggle_inventory_panel = env.toggle_inventory_panel
  local open_save_panel = env.open_save_panel
  local try_upgrade_growth_weapon = env.try_upgrade_growth_weapon
  local use_attr_diamond = env.use_attr_diamond
  local toggle_fixed_camera = env.toggle_fixed_camera

  local function register_level_sync_event()
    y3.game:event('单位-升级', function(_, data)
      if not is_battle_active() or data.unit ~= STATE.hero or not STATE.hero_progress then
        return
      end

      local previous_level = tonumber(STATE.hero_progress.level) or 1
      local engine_level = math.min(STATE.hero:get_level(), get_hero_max_level())
      if engine_level <= previous_level then
        sync_hero_progress_from_engine()
        STATE.hero:set_ability_point(0)
        return
      end

      sync_hero_progress_from_engine()
      local current_level = tonumber(STATE.hero_progress.level) or engine_level
      if grant_attr_diamond and current_level % 5 == 0 then
        grant_attr_diamond(1, current_level)
      end
      if try_queue_mark_node_for_level then
        try_queue_mark_node_for_level(current_level)
      end
    end)
  end

  local function register_battle_hotkey(key_name, callback)
    local key = y3.const.KeyboardKey[key_name]
    if not key then
      return
    end
    y3.game:event('键盘-按下', key, function()
      if not is_battle_active() then
        return
      end
      callback()
    end)
  end

  local function register_battle_hotkeys()
    register_battle_hotkey('F', function()
      try_bond_draw()
    end)
    register_battle_hotkey('I', function()
      show_bond_progress()
    end)
    register_battle_hotkey('B', function()
      if toggle_inventory_panel then
        toggle_inventory_panel()
      end
    end)
    register_battle_hotkey('P', function()
      if open_save_panel then
        open_save_panel()
      end
    end)
    register_battle_hotkey('TAB', function()
      if show_runtime_attr_dialog then
        show_runtime_attr_dialog()
      end
    end)
    register_battle_hotkey('T', function()
      if show_runtime_attr_dialog then
        show_runtime_attr_dialog()
      elseif show_runtime_attr_tip_panel then
        show_runtime_attr_tip_panel()
      end
    end)
    register_battle_hotkey('C', function()
      if start_current_task_challenge then
        start_current_task_challenge()
      end
    end)
    register_battle_hotkey('Q', function()
      try_start_challenge('gold_trial')
    end)
    register_battle_hotkey('W', function()
      try_start_challenge('wood_trial')
    end)
    register_battle_hotkey('E', function()
      try_start_challenge('exp_trial')
    end)
    register_battle_hotkey('H', function()
      if try_evolution_entry then
        try_evolution_entry()
      end
    end)
    register_battle_hotkey('ENTER', function()
      if toggle_talk_input then
        toggle_talk_input()
      end
    end)
    register_battle_hotkey('RETURN', function()
      if toggle_talk_input then
        toggle_talk_input()
      end
    end)
    register_battle_hotkey('KEY_1', function()
      if apply_round_choice(1) then
        return
      end
      if use_attr_diamond and use_attr_diamond() then
        return
      end
      if try_upgrade_growth_weapon then
        try_upgrade_growth_weapon('hotkey')
      end
    end)
    register_battle_hotkey('KEY_2', function()
      apply_round_choice(2)
    end)
    register_battle_hotkey('KEY_3', function()
      apply_round_choice(3)
    end)
    register_battle_hotkey('KEY_4', function()
      apply_round_choice(4)
    end)
    register_battle_hotkey('SPACE', function()
      show_runtime_status()
    end)
    register_battle_hotkey('F12', function()
      if toggle_fixed_camera then
        toggle_fixed_camera()
      end
    end)
  end

  local function register_debug_hotkeys()
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
        if gm_bond_effects_system then
          gm_bond_effects_system.ensure_board()
          gm_bond_effects_system.toggle_board()
        end
      end)
    end
  end

  local function register_runtime_events()
    if STATE.events_registered then
      return
    end
    STATE.events_registered = true

    register_level_sync_event()
    register_battle_hotkeys()
    register_debug_hotkeys()
  end

  return {
    register_runtime_events = register_runtime_events,
  }
end

return M

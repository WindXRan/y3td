local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local message = env.message
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
  local try_treasure_entry = env.try_treasure_entry
  local apply_round_choice = env.apply_round_choice
  local show_runtime_status = env.show_runtime_status
  local show_debug_hotkey_help = env.show_debug_hotkey_help
  local debug_actions_system = env.debug_actions_system
  local debug_tools_system = env.debug_tools_system
  local gm_bond_effects_system = env.gm_bond_effects_system
  local toggle_talk_input = env.toggle_talk_input
  local toggle_inventory_panel = env.toggle_inventory_panel
  local open_save_panel = env.open_save_panel
  local try_upgrade_growth_weapon = env.try_upgrade_growth_weapon
  local use_attr_diamond = env.use_attr_diamond

  local function register_runtime_events()
    if STATE.events_registered then
      return
    end
    STATE.events_registered = true

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
      show_bond_progress()
    end)
    y3.game:event('键盘-按下', 'B', function()
      if not is_battle_active() or not toggle_inventory_panel then
        return
      end
      toggle_inventory_panel()
    end)
    y3.game:event('键盘-按下', 'P', function()
      if not is_battle_active() or not open_save_panel then
        return
      end
      open_save_panel()
    end)
    y3.game:event('键盘-按下', y3.const.KeyboardKey['TAB'], function()
      if not is_battle_active() then
        return
      end
      if show_runtime_attr_dialog then
        show_runtime_attr_dialog()
      end
    end)
    y3.game:event('键盘-按下', 'T', function()
      if not is_battle_active() then
        return
      end
      if show_runtime_attr_dialog then
        show_runtime_attr_dialog()
      elseif show_runtime_attr_tip_panel then
        show_runtime_attr_tip_panel()
      end
    end)
    y3.game:event('键盘-按下', 'C', function()
      if not is_battle_active() then
        return
      end
      if start_current_task_challenge then
        start_current_task_challenge()
      end
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
    y3.game:event('键盘-按下', 'V', function()
      if not is_battle_active() then
        return
      end
      try_treasure_entry()
    end)
    y3.game:event('键盘-按下', 'H', function()
      if not is_battle_active() or not try_evolution_entry then
        return
      end
      try_evolution_entry()
    end)
    y3.game:event('键盘-按下', y3.const.KeyboardKey['ENTER'], function()
      if not is_battle_active() or not toggle_talk_input then
        return
      end
      toggle_talk_input()
    end)
    if y3.const.KeyboardKey['RETURN'] then
      y3.game:event('键盘-按下', y3.const.KeyboardKey['RETURN'], function()
        if not is_battle_active() or not toggle_talk_input then
          return
        end
        toggle_talk_input()
      end)
    end
    y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_1'], function()
      if not is_battle_active() then
        return
      end
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
    if y3.const.KeyboardKey['KEY_4'] then
      y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_4'], function()
        if not is_battle_active() then
          return
        end
        apply_round_choice(4)
      end)
    end
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

  return {
    register_runtime_events = register_runtime_events,
  }
end

return M

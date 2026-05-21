local M = {}
local y3 = y3
local BootCombat = require 'runtime.core.boot_combat'
function M.create(env)
  local STATE = env and env.STATE or _G.STATE

  -- Input events params
  local get_hero_max_level = env and env.get_hero_max_level or _G.get_hero_max_level or function() return 1 end
  local sync_hero_progress_from_engine = env and env.sync_hero_progress_from_engine or _G.sync_hero_progress_from_engine or function() end
  local grant_attr_diamond = env and env.grant_attr_diamond or _G.grant_attr_diamond or function() end
  local show_runtime_attr_tip_panel = env and env.show_runtime_attr_tip_panel or _G.show_runtime_attr_tip_panel or function() end
  local show_runtime_attr_dialog = env and env.show_runtime_attr_dialog or _G.show_runtime_attr_dialog or function() end
  local start_current_task_challenge = env and env.start_current_task_challenge or _G.start_current_task_challenge or function() end
  local try_start_challenge = env and env.try_start_challenge or _G.try_start_challenge or function() end
  local apply_round_choice = env and env.apply_round_choice or _G.apply_round_choice or function() end
  local show_runtime_status = env and env.show_runtime_status or _G.show_runtime_status or function() end
  local show_debug_hotkey_help = env and env.show_debug_hotkey_help or _G.show_debug_hotkey_help or function() end
  local show_debug_tip_example = env and env.show_debug_tip_example or _G.show_debug_tip_example or function() end
  local debug_actions_system = env and env.debug_actions_system or _G.debug_actions_system
  local toggle_talk_input = env and env.toggle_talk_input or _G.toggle_talk_input or function() end
  local toggle_inventory_panel = env and env.toggle_inventory_panel or _G.toggle_inventory_panel or function() end
  local open_save_panel = env and env.open_save_panel or _G.open_save_panel or function() end
  
  local use_attr_diamond = env and env.use_attr_diamond or _G.use_attr_diamond or function() end
  local toggle_fixed_camera = env and env.toggle_fixed_camera or _G.toggle_fixed_camera or function() end

  -- Loops params
  local is_battle_active = env and env.is_battle_active or _G.is_battle_active or function() return false end
  local update_passive_resources = env and env.update_passive_resources or _G.update_passive_resources or function() end
  local get_battlefield_system = env and env.battlefield_system or function() return _G.battlefield_system end
  local update_bond_effects = env and env.update_bond_effects or _G.update_bond_effects or function() end
  local update_enemy_statuses = env and env.update_enemy_statuses or _G.update_enemy_statuses or function() end
  local update_attack_skills = env and env.update_attack_skills or _G.update_attack_skills or function() end

  local update_battle_auto_acceptance = env and env.update_battle_auto_acceptance or _G.update_battle_auto_acceptance or function() end
  local ensure_runtime_hud = env and env.ensure_runtime_hud or _G.ensure_runtime_hud or function() end
  local ensure_choice_panel = env and env.ensure_choice_panel or _G.ensure_choice_panel or function() end
  local set_battle_hud_visible = env and env.set_battle_hud_visible or _G.set_battle_hud_visible or function() end
  local refresh_runtime_hud = env and env.refresh_runtime_hud or _G.refresh_runtime_hud or function() end
  local refresh_choice_panel = env and env.refresh_choice_panel or _G.refresh_choice_panel or function() end
  local refresh_runtime_overview = env and env.refresh_runtime_overview or _G.refresh_runtime_overview or function() end
  local refresh_inventory_panel = env and env.refresh_inventory_panel or _G.refresh_inventory_panel or function() end
  local outgame_system = env and env.outgame_system or _G.outgame_system
  local hero_attr_system = env and env.hero_attr_system or _G.hero_attr_system
  local debug_tools_system = env and env.debug_tools_system or _G.debug_tools_system

  local skill_damage_api = _G.td_damage_api

  -- ============ Input events ============

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
    end)
  end

  local function register_battle_hotkey(key_name, callback)
    local key = y3.const.KeyboardKey[key_name]
    if not key then return end
    y3.game:event('键盘-按下', key, function()
      if not is_battle_active() then return end
      callback()
    end)
  end

  local function register_battle_hotkeys()
    register_battle_hotkey('B', function()
      if toggle_inventory_panel then toggle_inventory_panel() end
    end)
    register_battle_hotkey('P', function()
      if open_save_panel then open_save_panel() end
    end)
    register_battle_hotkey('TAB', function()
      if show_runtime_attr_dialog then show_runtime_attr_dialog() end
    end)
    register_battle_hotkey('T', function()
      if show_runtime_attr_dialog then show_runtime_attr_dialog()
      elseif show_runtime_attr_tip_panel then show_runtime_attr_tip_panel() end
    end)
    register_battle_hotkey('C', function()
      if start_current_task_challenge then start_current_task_challenge() end
    end)
    register_battle_hotkey('Q', function() try_start_challenge('gold_trial') end)
    register_battle_hotkey('W', function() try_start_challenge('wood_trial') end)
    register_battle_hotkey('E', function() try_start_challenge('exp_trial') end)
    register_battle_hotkey('ENTER', function()
      if toggle_talk_input then toggle_talk_input() end
    end)
    register_battle_hotkey('RETURN', function()
      if toggle_talk_input then toggle_talk_input() end
    end)
    register_battle_hotkey('KEY_1', function()
      if apply_round_choice(1) then return end
      if use_attr_diamond and use_attr_diamond() then return end
    end)
    register_battle_hotkey('KEY_2', function() apply_round_choice(2) end)
    register_battle_hotkey('KEY_3', function() apply_round_choice(3) end)
    register_battle_hotkey('KEY_4', function() apply_round_choice(4) end)
    register_battle_hotkey('SPACE', function() show_runtime_status() end)
    register_battle_hotkey('F12', function()
      if toggle_fixed_camera then toggle_fixed_camera() end
    end)

    local function register_tip_debug_key(key_name, index)
      y3.game:event('键盘-按下', y3.const.KeyboardKey[key_name], function()
        if show_debug_tip_example then show_debug_tip_example(index) end
      end)
    end
    register_tip_debug_key('KEY_1', 1)
    register_tip_debug_key('KEY_2', 2)
    register_tip_debug_key('KEY_3', 3)
    register_tip_debug_key('KEY_4', 4)
    register_tip_debug_key('KEY_5', 5)
  end

  local function register_debug_hotkeys()
    if y3.game.is_debug_mode() then
      local function add_debug_ctrl_state(delta)
        STATE.debug_ctrl_down_count = math.max(0, (STATE.debug_ctrl_down_count or 0) + delta)
      end
      y3.game:event('键盘-按下', y3.const.KeyboardKey['LCTRL'], function() add_debug_ctrl_state(1) end)
      y3.game:event('键盘-按下', y3.const.KeyboardKey['RCTRL'], function() add_debug_ctrl_state(1) end)
      y3.game:event('键盘-抬起', y3.const.KeyboardKey['LCTRL'], function() add_debug_ctrl_state(-1) end)
      y3.game:event('键盘-抬起', y3.const.KeyboardKey['RCTRL'], function() add_debug_ctrl_state(-1) end)

      local function register_debug_hotkey(key_name, callback)
        y3.game:event('键盘-按下', y3.const.KeyboardKey[key_name], function()
          if (STATE.debug_ctrl_down_count or 0) <= 0 then return end
          callback()
        end)
      end

      if not debug_actions_system then return end
      register_debug_hotkey('F1', show_debug_hotkey_help)
      register_debug_hotkey('F2', debug_actions_system.debug_add_test_resources)
      register_debug_hotkey('F3', function() debug_actions_system.debug_grant_levels(3) end)
      register_debug_hotkey('F4', debug_actions_system.debug_unlock_all_attack_skills)
      register_debug_hotkey('F7', debug_actions_system.debug_refill_challenge_charges)
      register_debug_hotkey('F8', debug_actions_system.debug_force_spawn_boss)
      register_debug_hotkey('F9', debug_actions_system.debug_kill_all_active_enemies)
    end
  end

  local function register_runtime_events()
    if STATE.events_registered then return end
    STATE.events_registered = true
    register_level_sync_event()
    register_battle_hotkeys()
    register_debug_hotkeys()
  end

  -- ============ Loops ============

  local function get_hero_attack_value()
    if not STATE.hero or not STATE.hero:is_exist() then return 0 end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, '攻击结算值') or STATE.hero:get_attr('攻击结算值')
    value = y3.helper.tonumber(value) or 0
    if value > 0 then return value end
    return y3.helper.tonumber(hero_attr_system and hero_attr_system.get_attr(STATE.hero, '攻击') or STATE.hero:get_attr('攻击') or STATE.hero:get_attr('物理攻击')) or 0
  end

  local function try_refresh_battle_ui()
    if STATE.runtime_ui_refresh_disabled == true then return false end
    local ok, err = pcall(function()
      if ensure_runtime_hud then ensure_runtime_hud() end
      if ensure_choice_panel then ensure_choice_panel() end
      if set_battle_hud_visible then set_battle_hud_visible(true) end
      if refresh_runtime_hud then refresh_runtime_hud() end
      if refresh_choice_panel then refresh_choice_panel() end
      if refresh_swallow_panel then refresh_swallow_panel() end
      if refresh_inventory_panel then refresh_inventory_panel() end
      if refresh_runtime_overview then refresh_runtime_overview() end
      if debug_tools_system and debug_tools_system.ensure_gm_panel then debug_tools_system.ensure_gm_panel() end
    end)
    if ok then
      STATE.runtime_ui_fault_logged = false
      STATE.runtime_ui_fault_message = nil
      return true
    end
    local err_text = tostring(err)
    local is_event_key_error = err_text:find('KeyError', 1, true) ~= nil
      and (err_text:find('左键', 1, true) ~= nil
        or err_text:find('鼠标', 1, true) ~= nil
        or err_text:find('\\xd7\\xf3\\xbc\\xfc', 1, true) ~= nil
        or err_text:find('\\xca\\xf3\\xb1\\xea', 1, true) ~= nil)
    if is_event_key_error then
      STATE.runtime_ui_refresh_disabled = true
      print(string.format('[runtime.loops] battle ui refresh disabled due to unsupported ui event key: %s', err_text))
      return false
    end
    if STATE.runtime_ui_fault_logged ~= true or STATE.runtime_ui_fault_message ~= err_text then
      print(string.format('[runtime.loops] battle ui refresh failed, gameplay continues: %s', err_text))
    end
    STATE.runtime_ui_fault_logged = true
    STATE.runtime_ui_fault_message = err_text
    return false
  end

  local function start_runtime_loops()
    y3.ltimer.loop(0.25, function()
      if is_battle_active() then
        STATE.runtime_elapsed = (STATE.runtime_elapsed or 0) + 0.25
        update_passive_resources(0.25)
        local bfs = get_battlefield_system()
        if not bfs then return end
        bfs.update_wave(0.25)
        if update_battle_auto_acceptance then update_battle_auto_acceptance(0.25) end
        update_bond_effects(0.25)
        update_enemy_statuses(0.25)
        local update_attack_skills = _G.update_attack_skills or function() end
        update_attack_skills(0.25)

        try_refresh_battle_ui()
        return
      end
      if set_battle_hud_visible then set_battle_hud_visible(false) end
      if outgame_system and outgame_system.refresh_ui then outgame_system.refresh_ui() end
    end)
  end

  return {
    start_runtime_loops = start_runtime_loops,
    register_runtime_events = register_runtime_events,
  }
end

return M
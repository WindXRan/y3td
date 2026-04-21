local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG or {}
  local y3 = env.y3
  local is_battle_active = env.is_battle_active
  local update_passive_resources = env.update_passive_resources
  local battlefield_system = env.battlefield_system
  local update_bond_effects = env.update_bond_effects
  local update_auto_active_effects = env.update_auto_active_effects
  local update_effect_debug = env.update_effect_debug
  local update_enemy_statuses = env.update_enemy_statuses
  local update_attack_skills = env.update_attack_skills
  local update_temporary_treasures = env.update_temporary_treasures
  local update_mainline_task = env.update_mainline_task
  local ensure_runtime_hud = env.ensure_runtime_hud
  local set_battle_hud_visible = env.set_battle_hud_visible
  local refresh_runtime_hud = env.refresh_runtime_hud
  local refresh_choice_panel = env.refresh_choice_panel
  local refresh_swallow_panel = env.refresh_swallow_panel
  local refresh_runtime_overview = env.refresh_runtime_overview
  local refresh_inventory_panel = env.refresh_inventory_panel
  local outgame_system = env.outgame_system
  local debug_tools_system = env.debug_tools_system
  local is_active_enemy = env.is_active_enemy
  local get_enemies_in_range = env.get_enemies_in_range
  local deal_skill_damage = env.deal_skill_damage
  local hero_attr_system = env.hero_attr_system
  local runtime_tick = 0.25
  local battle_ui_refresh_interval = math.max(0.25, tonumber(CONFIG.runtime_ui_refresh_interval) or 0.5)
  local loops_started = false

  local function get_hero_attack_value()
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, '攻击结算值') or STATE.hero:get_attr('攻击结算值')
    value = y3.helper.tonumber(value) or 0
    if value > 0 then
      return value
    end
    return y3.helper.tonumber(hero_attr_system and hero_attr_system.get_attr(STATE.hero, '攻击') or STATE.hero:get_attr('攻击') or STATE.hero:get_attr('物理攻击')) or 0
  end

  local function try_refresh_battle_ui()
    STATE.debug_battle_ui_refresh_count = (STATE.debug_battle_ui_refresh_count or 0) + 1
    if (STATE.debug_battle_ui_refresh_count % 10) == 1 then
      print(string.format(
        '[diag.loops] battle_ui_refresh count=%s phase=%s visible=%s',
        tostring(STATE.debug_battle_ui_refresh_count),
        tostring(STATE.session_phase),
        tostring(STATE.runtime_battle_ui_visible)
      ))
    end
    local ok, err = pcall(function()
      ensure_runtime_hud()
      refresh_runtime_hud()
      refresh_choice_panel()
      if refresh_swallow_panel then
        refresh_swallow_panel()
      end
      if refresh_inventory_panel then
        refresh_inventory_panel()
      end
      refresh_runtime_overview()
    end)
    if ok then
      STATE.runtime_ui_fault_logged = false
      STATE.runtime_ui_fault_message = nil
      return true
    end

    local err_text = tostring(err)
    if STATE.runtime_ui_fault_logged ~= true or STATE.runtime_ui_fault_message ~= err_text then
      print(string.format('[runtime.loops] battle ui refresh failed, gameplay continues: %s', err_text))
    end
    STATE.runtime_ui_fault_logged = true
    STATE.runtime_ui_fault_message = err_text
    return false
  end

  local function refresh_non_battle_ui()
    STATE.runtime_ui_refresh_elapsed = 0
    if STATE.runtime_battle_ui_visible == true then
      set_battle_hud_visible(false)
      STATE.runtime_battle_ui_visible = false
    end
    if outgame_system then
      outgame_system.refresh_ui()
    end
  end

  local function schedule_phase_loop(initial_delay, callback)
    y3.ltimer.wait(math.max(0, initial_delay or 0), function()
      if callback then
        callback()
      end
      y3.ltimer.loop(runtime_tick, function()
        if callback then
          callback()
        end
      end)
    end)
  end

  local function start_runtime_loops()
    if loops_started then
      print('[diag.loops] start_runtime_loops skipped duplicate_start')
      return false
    end
    loops_started = true
    STATE.debug_runtime_loops_start_count = (STATE.debug_runtime_loops_start_count or 0) + 1
    print(string.format('[diag.loops] start_runtime_loops count=%s', tostring(STATE.debug_runtime_loops_start_count)))

    y3.ltimer.loop(runtime_tick, function()
      if is_battle_active() then
        if STATE.runtime_battle_ui_visible ~= true then
          set_battle_hud_visible(true)
          STATE.runtime_battle_ui_visible = true
        end
        STATE.runtime_elapsed = (STATE.runtime_elapsed or 0) + runtime_tick
        update_passive_resources(runtime_tick)
        battlefield_system.update_wave(runtime_tick)
        battlefield_system.update_challenges(runtime_tick)
        battlefield_system.update_challenge_charges(runtime_tick)
        if update_mainline_task then
          update_mainline_task(runtime_tick)
        end
        update_temporary_treasures(runtime_tick)
        return
      end

      refresh_non_battle_ui()
    end)

    schedule_phase_loop(runtime_tick * 0.33, function()
      if not is_battle_active() then
        return
      end

      update_bond_effects(runtime_tick)
      update_auto_active_effects(runtime_tick)
      if update_effect_debug and CONFIG.effect_debug_auto_update_enabled == true then
        update_effect_debug(runtime_tick)
      end
    end)

    schedule_phase_loop(runtime_tick * 0.66, function()
      if not is_battle_active() then
        return
      end

      update_enemy_statuses(runtime_tick)
      update_attack_skills(runtime_tick)
    end)

    schedule_phase_loop(runtime_tick * 0.16, function()
      if not is_battle_active() then
        return
      end

      STATE.runtime_ui_refresh_elapsed = (STATE.runtime_ui_refresh_elapsed or 0) + runtime_tick
      if STATE.runtime_ui_refresh_elapsed >= battle_ui_refresh_interval then
        STATE.runtime_ui_refresh_elapsed = 0
        try_refresh_battle_ui()
      end
    end)

    y3.ltimer.loop(1, function()
      if not is_battle_active() then
        return
      end

      local skill = STATE.skill_runtime
      if skill.artillery_interval <= 0 or skill.artillery_radius <= 0 or skill.artillery_ratio <= 0 then
        return
      end

      skill.artillery_cd = skill.artillery_cd + 1
      if skill.artillery_cd < skill.artillery_interval then
        return
      end
      skill.artillery_cd = 0

      local anchor = STATE.all_enemies:get_random()
      if not is_active_enemy(anchor) then
        return
      end

      local attack_value = get_hero_attack_value()
      local damage = skill.artillery_base + attack_value * skill.artillery_ratio
      for _, unit in ipairs(get_enemies_in_range(anchor, skill.artillery_radius)) do
        deal_skill_damage(unit, damage, '法术')
      end
    end)

    if y3.game.is_debug_mode() and CONFIG.gm_panel_auto_refresh_enabled == true then
      y3.ltimer.loop(runtime_tick, function()
        debug_tools_system.ensure_gm_panel()
        debug_tools_system.refresh_gm_panel()
      end)
    end
  end

  return {
    start_runtime_loops = start_runtime_loops,
  }
end

return M

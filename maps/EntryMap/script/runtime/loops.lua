local M = {}

function M.create(env)
  local STATE = env.STATE
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
  local ensure_choice_panel = env.ensure_choice_panel
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
    local ok, err = pcall(function()
      if ensure_runtime_hud then
        ensure_runtime_hud()
      end
      if ensure_choice_panel then
        ensure_choice_panel()
      end
      if set_battle_hud_visible then
        set_battle_hud_visible(true)
      end
      if refresh_runtime_hud then
        refresh_runtime_hud()
      end
      if refresh_choice_panel then
        refresh_choice_panel()
      end
      if refresh_swallow_panel then
        refresh_swallow_panel()
      end
      if refresh_inventory_panel then
        refresh_inventory_panel()
      end
      if refresh_runtime_overview then
        refresh_runtime_overview()
      end
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

  local function start_runtime_loops()
    y3.ltimer.loop(0.25, function()
      if is_battle_active() then
        STATE.runtime_elapsed = (STATE.runtime_elapsed or 0) + 0.25
        update_passive_resources(0.25)
        battlefield_system.update_wave(0.25)
        battlefield_system.update_challenges(0.25)
        battlefield_system.update_challenge_charges(0.25)
        if update_mainline_task then
          update_mainline_task(0.25)
        end
        update_bond_effects(0.25)
        update_auto_active_effects(0.25)
        if update_effect_debug then
          update_effect_debug(0.25)
        end
        update_enemy_statuses(0.25)
        update_attack_skills(0.25)
        update_temporary_treasures(0.25)
        try_refresh_battle_ui()
        return
      end

      if set_battle_hud_visible then
        set_battle_hud_visible(false)
      end
      if outgame_system then
        outgame_system.refresh_ui()
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

    y3.ltimer.loop(0.25, function()
      debug_tools_system.ensure_gm_panel()
      debug_tools_system.refresh_gm_panel()
    end)
  end

  return {
    start_runtime_loops = start_runtime_loops,
  }
end

return M

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
  local ensure_runtime_hud = env.ensure_runtime_hud
  local ensure_choice_panel = env.ensure_choice_panel
  local set_battle_hud_visible = env.set_battle_hud_visible
  local refresh_runtime_hud = env.refresh_runtime_hud
  local refresh_choice_panel = env.refresh_choice_panel
  local refresh_runtime_overview = env.refresh_runtime_overview
  local outgame_system = env.outgame_system
  local debug_tools_system = env.debug_tools_system
  local is_active_enemy = env.is_active_enemy
  local get_enemies_in_range = env.get_enemies_in_range
  local deal_skill_damage = env.deal_skill_damage

  local function start_runtime_loops()
    y3.ltimer.loop(0.25, function()
      if is_battle_active() then
        STATE.runtime_elapsed = (STATE.runtime_elapsed or 0) + 0.25
        update_passive_resources(0.25)
        battlefield_system.update_wave(0.25)
        battlefield_system.update_challenges(0.25)
        battlefield_system.update_challenge_charges(0.25)
        update_bond_effects(0.25)
        update_auto_active_effects(0.25)
        if update_effect_debug then
          update_effect_debug(0.25)
        end
        update_enemy_statuses(0.25)
        update_attack_skills(0.25)
        update_temporary_treasures(0.25)
        ensure_runtime_hud()
        ensure_choice_panel()
        set_battle_hud_visible(true)
        refresh_runtime_hud()
        refresh_choice_panel()
        refresh_runtime_overview()
        return
      end

      set_battle_hud_visible(false)
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

      local damage = skill.artillery_base + STATE.hero:get_attr('物理攻击') * skill.artillery_ratio
      for _, unit in ipairs(get_enemies_in_range(anchor, skill.artillery_radius)) do
        deal_skill_damage(unit, damage, '法术')
      end
    end)

    if y3.game.is_debug_mode() then
      y3.ltimer.loop(0.25, function()
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

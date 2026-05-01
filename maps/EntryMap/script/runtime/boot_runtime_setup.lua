local M = {}

function M.create(ctx)
  local build_input_events_env = function()
    return {
      STATE = ctx.STATE,
      y3 = ctx.y3,
      message = ctx.message,
      is_battle_active = function()
        return ctx.is_battle_active()
      end,
      get_hero_max_level = ctx.progression_system.get_hero_max_level,
      sync_hero_progress_from_engine = ctx.progression_system.sync_hero_progress_from_engine,
      grant_attr_diamond = function(count, level)
        return ctx.attr_choice_system and ctx.attr_choice_system.grant_diamond and ctx.attr_choice_system.grant_diamond(count, level) or
            nil
      end,
      try_bond_draw = ctx.try_bond_draw,
      show_runtime_attr_overview = function()
        ctx.show_runtime_attr_dialog()
      end,
      show_runtime_attr_tip_panel = function()
        ctx.runtime_ui_helpers.show_runtime_attr_tip_panel(8)
      end,
      show_runtime_attr_dialog = ctx.show_runtime_attr_dialog,
      refresh_runtime_overview = ctx.runtime_ui_helpers.refresh_runtime_overview,
      start_current_task_challenge = function()
        return ctx.mainline_task_system and ctx.mainline_task_system.start_current_task_challenge and
            ctx.mainline_task_system.start_current_task_challenge() or nil
      end,
      try_start_challenge = ctx.try_start_challenge,
      apply_round_choice = ctx.apply_round_choice,
      show_runtime_status = ctx.show_runtime_status,
      toggle_talk_input = ctx.runtime_ui_helpers.toggle_talk_input,
      toggle_inventory_panel = ctx.runtime_ui_helpers.toggle_inventory_panel,
      open_save_panel = function()
        return ctx.open_runtime_save_panel()
      end,
      try_upgrade_growth_weapon = ctx.BattleEventPrompts.try_upgrade_growth_weapon,
      use_attr_diamond = ctx.use_attr_diamond,
      show_debug_hotkey_help = ctx.show_debug_hotkey_help,
      debug_actions_system = ctx.debug_actions_system,
      debug_tools_system = ctx.debug_tools_system,
      gm_bond_effects_system = ctx.gm_bond_effects_system,
      toggle_fixed_camera = ctx.RuntimeEntry.toggle_fixed_camera,
    }
  end

  local input_events_system = ctx.BootInput.create(build_input_events_env())

  local hero_tujian_panel_system = ctx.BootHeroTujian.create({
    STATE = ctx.STATE,
    y3 = ctx.y3,
    get_player = ctx.get_player,
    message = ctx.message,
    get_audio_system = function()
      return ctx.audio_system
    end,
    get_outgame_system = function()
      return ctx.outgame_system
    end,
  })

  local register_runtime_events = function()
    ctx.BootEvents.register({
      input_events_system = input_events_system,
      hero_selection_range_system = ctx.hero_selection_range_system,
    })
  end

  local build_runtime_loops_env = function()
    return {
      STATE = ctx.STATE,
      y3 = ctx.y3,
      hero_attr_system = ctx.hero_attr_system,
      is_battle_active = function()
        return ctx.is_battle_active()
      end,
      update_passive_resources = ctx.update_passive_resources,
      battlefield_system = ctx.battlefield_system,
      update_bond_effects = ctx.update_bond_effects,
      update_auto_active_effects = ctx.update_auto_active_effects,
      update_effect_debug = ctx.update_effect_debug,
      update_enemy_statuses = ctx.update_enemy_statuses,
      update_attack_skills = ctx.update_attack_skills,
      update_mainline_task = function(dt)
        return ctx.mainline_task_system and ctx.mainline_task_system.update and ctx.mainline_task_system.update(dt) or nil
      end,
      update_battle_auto_acceptance = function(dt)
        if ctx.battle_auto_acceptance_system and ctx.battle_auto_acceptance_system.update then
          return ctx.battle_auto_acceptance_system.update(dt)
        end
        return nil
      end,
      ensure_runtime_hud = ctx.runtime_ui_helpers.ensure_runtime_hud,
      ensure_choice_panel = ctx.runtime_ui_helpers.ensure_choice_panel,
      set_battle_hud_visible = ctx.set_battle_hud_visible,
      refresh_runtime_hud = ctx.runtime_ui_helpers.refresh_runtime_hud,
      refresh_choice_panel = ctx.runtime_ui_helpers.refresh_choice_panel,
      refresh_runtime_overview = ctx.runtime_ui_helpers.refresh_runtime_overview,
      refresh_inventory_panel = ctx.runtime_ui_helpers.refresh_inventory_panel,
      outgame_system = ctx.outgame_system,
      gm_bond_effects_system = ctx.gm_bond_effects_system,
      is_active_enemy = ctx.is_active_enemy,
      get_enemies_in_range = ctx.get_enemies_in_range,
      deal_skill_damage = ctx.deal_skill_damage,
      emit_damage_debug = function(visual)
        ctx.emit_damage_debug_visual(visual, nil)
      end,
      hero_tujian_panel_system = hero_tujian_panel_system,
    }
  end

  local runtime_loops_system = ctx.BootLoops.create(build_runtime_loops_env())
  local start_runtime_loops = function()
    return runtime_loops_system.start_runtime_loops()
  end

  local register_dev_commands = ctx.BootDevCommands.create({
    get_debug_tools_system = function()
      return ctx.debug_tools_system
    end,
    get_gm_bond_effects_system = function()
      return ctx.gm_bond_effects_system
    end,
  })

  local run_bootstrap_sequence = ctx.BootBootstrapSequence.create({
    ensure_helper_signals = ctx.ensure_helper_signals,
    reset_session_state = function()
      return ctx.reset_session_state()
    end,
    register_runtime_events = register_runtime_events,
    register_cannon_skill = function()
      return ctx.cannon_skill_134258724_system.register()
    end,
    register_dev_commands = function()
      return register_dev_commands()
    end,
    start_runtime_loops = start_runtime_loops,
    setup_post_bootstrap_ui = function()
      if ctx.gm_bond_effects_system and ctx.gm_bond_effects_system.ensure_board then
        ctx.gm_bond_effects_system.ensure_board()
        ctx.gm_bond_effects_system.refresh_board()
      end
      ctx.outgame_system.load_profile()
      ctx.outgame_system.enter_outgame()
    end,
  })

  return {
    input_events_system = input_events_system,
    hero_tujian_panel_system = hero_tujian_panel_system,
    runtime_loops_system = runtime_loops_system,
    register_runtime_events = register_runtime_events,
    start_runtime_loops = start_runtime_loops,
    register_dev_commands = register_dev_commands,
    run_bootstrap_sequence = run_bootstrap_sequence,
  }
end

return M


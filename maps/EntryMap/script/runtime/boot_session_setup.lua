local M = {}

function M.create(ctx)
  ctx.RuntimeEntry.validate_config = function()
    return ctx.battlefield_system.validate_config()
  end

  local hero_selection_range_system = nil

  local session_state_system = ctx.BootSession.create({
    STATE = ctx.STATE,
    CONFIG = ctx.CONFIG,
    y3 = ctx.y3,
    message = ctx.message,
    hero_attr_system = ctx.hero_attr_system,
    make_point = ctx.make_point,
    get_resource_rules = ctx.get_resource_rules,
    create_bond_runtime = ctx.create_bond_runtime,
    create_battle_event_feed_runtime = ctx.create_battle_event_feed_runtime,
    create_effect_debug_runtime = ctx.create_effect_debug_runtime,
    create_mark_runtime = ctx.reward_system.create_evolution_runtime,
    create_treasure_runtime = ctx.reward_system.create_treasure_runtime,
    create_skill_runtime = ctx.create_skill_runtime,
    create_attack_skill_state = ctx.create_attack_skill_state,
    reset_skill_framework_runtime = ctx.reset_skill_framework_runtime,
    ATTACK_SKILL_BLUEPRINTS = ctx.ATTACK_SKILL_BLUEPRINTS,
    destroy_choice_panel = ctx.runtime_ui_helpers.destroy_choice_panel,
    battlefield_system = ctx.battlefield_system,
    get_player = ctx.get_player,
    get_enemy_player = ctx.get_enemy_player,
    create_hero = function()
      local hero = ctx.battlefield_system.create_hero(ctx.ATTACK_SKILL_DEFS.basic_attack.base_range or 250)
      if ctx.STATE.fixed_camera_enabled == true then
        ctx.RuntimeEntry.sync_fixed_camera_mode()
      end
      return hero
    end,
    initialize_hero_progression = ctx.progression_system.initialize_hero_progression,
    ensure_gear_runtime = function(state, config)
      return ctx.GearUpgrades.ensure_runtime(state, config)
    end,
    sync_gear_items_to_hero = function(state, hero, config)
      return ctx.GearUpgrades.sync_items_to_hero(state, hero, config)
    end,
    sync_gear_runtime_effects = function(state, hero, config)
      return ctx.GearUpgrades.sync_runtime_bonuses(state, hero, config, ctx.hero_attr_system)
    end,
    unlock_attack_skill = ctx.unlock_attack_skill,
    show_attack_skill_loadout = ctx.show_attack_skill_loadout,
    setup_basic_attack_ability = ctx.setup_basic_attack_ability,
    ensure_runtime_hud = ctx.runtime_ui_helpers.ensure_runtime_hud,
    set_battle_hud_visible = function(visible)
      return ctx.set_battle_hud_visible(visible)
    end,
    refresh_runtime_hud = ctx.runtime_ui_helpers.refresh_runtime_hud,
    enter_battle_audio = function()
      return ctx.audio_system and ctx.audio_system.enter_battle and ctx.audio_system.enter_battle() or nil
    end,
    disable_local_attack_preview = function()
      return false
    end,
    get_outgame_system = function()
      return ctx.get_outgame_system()
    end,
    start_wave = function(index)
      return ctx.RuntimeEntry.start_wave(index)
    end,
  })

  local outgame_system = ctx.OutgameSystem.create({
    STATE = ctx.STATE,
    CONFIG = ctx.CONFIG,
    y3 = ctx.y3,
    message = ctx.message,
    round_number = ctx.round_number,
    get_player = ctx.get_player,
    open_hero_tujian = function()
      local hud = ctx.get_runtime_hud_system and ctx.get_runtime_hud_system() or nil
      if hud and hud.toggle_hero_tujian then
        return hud.toggle_hero_tujian()
      end
      return false
    end,
    open_bond_album = function()
      if ctx.open_bond_card_album then
        return ctx.open_bond_card_album()
      end
      return false
    end,
    stage_runtime = {
      get_current_stage_text = function()
        if ctx.STATE.current_stage_def and (ctx.STATE.current_stage_def.display_label or ctx.STATE.current_stage_def.display_name) then
          return ctx.STATE.current_stage_def.display_label or ctx.STATE.current_stage_def.display_name
        end
        return '第1关'
      end,
      start_selected_stage = function(stage_id, mode_id)
        return session_state_system.start_selected_stage(stage_id, mode_id)
      end,
    },
    play_ui_click = function()
      return ctx.audio_system and ctx.audio_system.play_ui_click and ctx.audio_system.play_ui_click() or nil
    end,
    ensure_music_loop = function()
      return ctx.audio_system and ctx.audio_system.ensure_music_loop and ctx.audio_system.ensure_music_loop() or nil
    end,
    set_battle_hud_visible = function(visible)
      return ctx.set_battle_hud_visible(visible)
    end,
  })

  return {
    hero_selection_range_system = hero_selection_range_system,
    session_state_system = session_state_system,
    outgame_system = outgame_system,
    is_battle_active = function()
      return session_state_system.is_battle_active()
    end,
    reset_battle_state = function()
      return session_state_system.reset_battle_state()
    end,
    reset_session_state = function()
      return session_state_system.reset_session_state()
    end,
  }
end

return M


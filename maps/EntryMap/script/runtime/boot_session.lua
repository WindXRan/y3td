local SessionStateSystem = require 'runtime.session_state'

local M = {}

function M.create(args)
  return SessionStateSystem.create({
    STATE = args.STATE,
    CONFIG = args.CONFIG,
    y3 = args.y3,
    message = args.message,
    hero_attr_system = args.hero_attr_system,
    make_point = args.make_point,
    get_resource_rules = args.get_resource_rules,
    create_bond_runtime = args.create_bond_runtime,
    create_battle_event_feed_runtime = args.create_battle_event_feed_runtime,
    create_effect_debug_runtime = args.create_effect_debug_runtime,
    create_mark_runtime = args.create_mark_runtime,
    create_treasure_runtime = args.create_treasure_runtime,
    create_skill_runtime = args.create_skill_runtime,
    create_attack_skill_state = args.create_attack_skill_state,
    ATTACK_SKILL_BLUEPRINTS = args.ATTACK_SKILL_BLUEPRINTS,
    destroy_choice_panel = args.destroy_choice_panel,
    battlefield_system = args.battlefield_system,
    get_player = args.get_player,
    get_enemy_player = args.get_enemy_player,
    create_hero = args.create_hero,
    initialize_hero_progression = args.initialize_hero_progression,
    ensure_gear_runtime = args.ensure_gear_runtime,
    sync_gear_items_to_hero = args.sync_gear_items_to_hero,
    sync_gear_runtime_effects = args.sync_gear_runtime_effects,
    unlock_attack_skill = args.unlock_attack_skill,
    show_attack_skill_loadout = args.show_attack_skill_loadout,
    setup_basic_attack_ability = args.setup_basic_attack_ability,
    ensure_runtime_hud = args.ensure_runtime_hud,
    set_battle_hud_visible = args.set_battle_hud_visible,
    refresh_runtime_hud = args.refresh_runtime_hud,
    enter_battle_audio = args.enter_battle_audio,
    disable_local_attack_preview = args.disable_local_attack_preview,
    get_outgame_system = args.get_outgame_system,
    start_wave = args.start_wave,
  })
end

return M

local InputEventsSystem = require 'runtime.input_events'

local M = {}

function M.create(args)
  return InputEventsSystem.create({
    STATE = args.STATE,
    y3 = args.y3,
    message = args.message,
    is_battle_active = args.is_battle_active,
    get_hero_max_level = args.get_hero_max_level,
    sync_hero_progress_from_engine = args.sync_hero_progress_from_engine,
    try_queue_mark_node_for_level = args.try_queue_mark_node_for_level,
    grant_attr_diamond = args.grant_attr_diamond,
    try_bond_draw = args.try_bond_draw,
    show_bond_progress = args.show_bond_progress,
    show_runtime_attr_overview = args.show_runtime_attr_overview,
    show_runtime_attr_tip_panel = args.show_runtime_attr_tip_panel,
    show_runtime_attr_dialog = args.show_runtime_attr_dialog,
    refresh_runtime_overview = args.refresh_runtime_overview,
    start_current_task_challenge = args.start_current_task_challenge,
    try_start_challenge = args.try_start_challenge,
    try_evolution_entry = args.try_evolution_entry,
    try_treasure_entry = args.try_treasure_entry,
    apply_round_choice = args.apply_round_choice,
    show_runtime_status = args.show_runtime_status,
    toggle_talk_input = args.toggle_talk_input,
    toggle_inventory_panel = args.toggle_inventory_panel,
    open_save_panel = args.open_save_panel,
    try_upgrade_growth_weapon = args.try_upgrade_growth_weapon,
    use_attr_diamond = args.use_attr_diamond,
    show_debug_hotkey_help = args.show_debug_hotkey_help,
    debug_actions_system = args.debug_actions_system,
    debug_tools_system = args.debug_tools_system,
    gm_bond_effects_system = args.gm_bond_effects_system,
  })
end

return M

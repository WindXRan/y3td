local RuntimeLoopsSystem = require 'runtime.loops'

local M = {}

function M.create(args)
  return RuntimeLoopsSystem.create({
    STATE = args.STATE,
    y3 = args.y3,
    hero_attr_system = args.hero_attr_system,
    is_battle_active = args.is_battle_active,
    update_passive_resources = args.update_passive_resources,
    battlefield_system = args.battlefield_system,
    update_bond_effects = args.update_bond_effects,
    update_auto_active_effects = args.update_auto_active_effects,
    update_effect_debug = args.update_effect_debug,
    update_enemy_statuses = args.update_enemy_statuses,
    update_attack_skills = args.update_attack_skills,
    update_buff_system = args.update_buff_system,
    update_mainline_task = args.update_mainline_task,
    update_battle_auto_acceptance = args.update_battle_auto_acceptance,
    ensure_runtime_hud = args.ensure_runtime_hud,
    ensure_choice_panel = args.ensure_choice_panel,
    set_battle_hud_visible = args.set_battle_hud_visible,
    refresh_runtime_hud = args.refresh_runtime_hud,
    refresh_choice_panel = args.refresh_choice_panel,
    refresh_runtime_overview = args.refresh_runtime_overview,
    refresh_inventory_panel = args.refresh_inventory_panel,
    outgame_system = args.outgame_system,
    gm_bond_effects_system = args.gm_bond_effects_system,
    is_active_enemy = args.is_active_enemy,
    get_enemies_in_range = args.get_enemies_in_range,
    deal_skill_damage = args.deal_skill_damage,
  })
end

return M

local RuntimeHudSystem = require 'ui.runtime_hud'
local RuntimeUIHelpers = require 'runtime.runtime_ui_helpers'
local OverviewModelSystem = require 'runtime.overview_model'
local BondSystem = require 'runtime.bonds_chain'
local GearUpgrades = require 'runtime.gear_upgrades'
local BootUIEnhancements = require 'runtime.boot_ui_enhancements'

local M = {}

function M.create_runtime_hud_system(deps)
    return RuntimeHudSystem.create({
        STATE = deps.STATE,
        CONFIG = deps.CONFIG,
        y3 = deps.y3,
        attack_skill_slot_count = deps.ATTACK_SKILL_SLOT_COUNT,
        get_player = deps.get_player,
        hero_attr_system = deps.hero_attr_system,
        hero_model = deps.hero_model,
        mainline_task_system = deps.mainline_task_system,
        message = deps.message,
        try_bond_draw = deps.try_bond_draw,
        try_skill_draw = deps.try_skill_draw,
        try_start_challenge = deps.try_start_challenge,
        open_save_panel = deps.open_runtime_save_panel,
        toggle_gm_panel = deps.toggle_gm_panel,
        try_upgrade_growth_weapon = deps.try_upgrade_growth_weapon,
        use_attr_diamond = deps.use_attr_diamond,
        get_attr_choice_runtime = deps.get_attr_choice_runtime,
        apply_attr_choice = deps.apply_attr_choice,
        show_runtime_status = deps.show_runtime_status,
        build_runtime_attr_dialog_chunks = deps.build_runtime_attr_dialog_chunks,
        build_growth_weapon_tip_payload = function()
            return GearUpgrades.build_tip_payload(deps.STATE, 'weapon', deps.CONFIG.gear_upgrade_config, deps.y3.item)
        end,
        build_bond_slot_tip_payload = function(slot)
            return BondSystem.build_slot_tip_payload(deps.STATE, slot)
        end,
        bond_draw_cost = deps.BondDrawConfig.draw_cost or 100,
        get_bond_slot_icon = function(slot)
            return BondSystem.get_slot_icon(deps.STATE, slot)
        end,
        get_bottom_status_effect_entries = function(max_slots)
            return deps.BootHelpers.get_bottom_status_effect_entries(max_slots, deps.STATE, deps.auto_active_effects_system)
        end,
        play_ui_click = deps.play_ui_click,
        BondSystem = BondSystem,
        create_bond_env = deps.create_bond_env,
        apply_bond_replacement = BondSystem.apply_bond_replacement,
        cancel_bond_replacement = BondSystem.cancel_bond_replacement,
        get_bond_replacement_info = BondSystem.get_bond_replacement_info,
    })
end

function M.create_runtime_ui_helpers(deps)
    local helpers = RuntimeUIHelpers.create({
        STATE = deps.STATE,
        y3 = deps.y3,
        get_player = deps.get_player,
        get_pending_round_choice_kind = deps.get_pending_round_choice_kind,
        refresh_current_choice = deps.refresh_current_choice,
        apply_round_choice = deps.apply_round_choice,
        defer_choice_panel = function()
            deps.STATE.choice_panel_hidden = true
        end,
        get_growth_weapon_item_key = function()
            local slot_cfg = deps.CONFIG.gear_upgrade_config
                and deps.CONFIG.gear_upgrade_config.slots
                and deps.CONFIG.gear_upgrade_config.slots.weapon
                or nil
            return slot_cfg and slot_cfg.item_key or nil
        end,
        get_evolution_quality_label = function(quality)
            return deps.reward_system.get_evolution_quality_label(quality)
        end,
        get_runtime_hud_system = deps.get_runtime_hud_system,
        get_runtime_overview_model = deps.get_runtime_overview_model,
        build_bond_swallow_panel_model = function(state, selected_root_index)
            return BondSystem.build_bond_swallow_panel_model(state, selected_root_index)
        end,
        build_growth_weapon_tip_payload = function()
            return GearUpgrades.build_tip_payload(deps.STATE, 'weapon', deps.CONFIG.gear_upgrade_config, deps.y3.item)
        end,
    })

    helpers.__raw_refresh_choice_panel = helpers.refresh_choice_panel
    helpers.refresh_choice_panel = BootUIEnhancements.refresh_choice_panel
    helpers.install_panel_systems()

    return helpers
end

function M.create_overview_model_system(deps)
    return OverviewModelSystem.create({
        STATE = deps.STATE,
        CONFIG = deps.CONFIG,
        round_number = deps.round_number,
        hero_attr_system = deps.hero_attr_system,
        get_current_wave = deps.get_current_wave,
        get_boss_name = deps.get_boss_name,
        get_pending_round_choice_kind = deps.get_pending_round_choice_kind,
        get_hero_progress_text = deps.get_hero_progress_text,
        get_reward_queue_count = deps.get_reward_queue_count,
        get_reward_queue = deps.get_reward_queue,
        get_evolution_runtime = deps.get_evolution_runtime,
        get_evolution_active_count = deps.get_evolution_active_count,
        build_evolution_slot_text = deps.build_evolution_slot_text,
        get_bond_runtime_bonus = deps.get_bond_runtime_bonus,
        attack_skill_slot_count = deps.ATTACK_SKILL_SLOT_COUNT,
        build_attack_skill_slot_text = deps.build_attack_skill_slot_text,
        build_bond_slot_text = function(slot)
            return BondSystem.build_slot_text(deps.STATE, slot)
        end,
        build_bond_choice_preview_text = function(index, choice)
            return BondSystem.build_choice_preview_text(index, choice)
        end,
    })
end

function M.create_attr_tips_panel_system(deps)
    local system = require('runtime.attr_tips_panel').create({
        STATE = deps.STATE,
        y3 = deps.y3,
        get_player = deps.get_player,
        hero_attr_system = deps.hero_attr_system,
    })
    if system and system.init then
        system.init()
    end
    return system
end

function M.create_growth_weapon_item_tip_system(deps)
    return require('ui.growth_weapon_item_tip').create({
        STATE = deps.STATE,
        y3 = deps.y3,
        get_player = deps.get_player,
        build_growth_weapon_tip_payload = function(slot)
            return GearUpgrades.build_tip_payload(deps.STATE, slot or 'weapon', deps.CONFIG.gear_upgrade_config, deps.y3.item)
        end,
    })
end

function M.create_result_panel_system(deps)
    return require('ui.result_panel').create({
        y3 = deps.y3,
        get_player = deps.get_player,
    })
end

function M.set_ui_enhancements(deps)
    BootUIEnhancements.set_dependencies(deps.STATE, deps.CONFIG)
    BootUIEnhancements.set_apply_round_choice(deps.apply_round_choice)
end

return M
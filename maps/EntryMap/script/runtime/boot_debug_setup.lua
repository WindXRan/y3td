local DebugToolsSystem = require 'runtime.debug_tools'
local DebugActionsSystem = require 'runtime.debug_actions'
local GmBondEffectsSystem = require 'runtime.gm_bond_effects'
local BattleAutoAcceptanceSystem = require 'runtime.battle_auto_acceptance'
local BondSystem = require 'runtime.bonds_chain'
local BondModifierEffects = require 'runtime.bond_modifier_effects'

local M = {}

function M.create_debug_actions_system(deps)
    return DebugActionsSystem.create({
        STATE = deps.STATE,
        CONFIG = deps.CONFIG,
        debug_message = deps.debug_message,
        attack_skill_slot_count = deps.ATTACK_SKILL_SLOT_COUNT,
        is_battle_active = deps.is_battle_active,
        get_hero_max_level = deps.get_hero_max_level,
        sync_hero_progression = deps.sync_hero_progression,
        ATTACK_SKILL_BLUEPRINTS = deps.ATTACK_SKILL_BLUEPRINTS,
        unlock_attack_skill = deps.unlock_attack_skill,
        show_attack_skill_loadout = deps.show_attack_skill_loadout,
        try_bond_draw = deps.try_bond_draw,
        force_spawn_boss = function()
            return deps.battlefield_system.force_spawn_boss()
        end,
        execute_enemy = function(unit)
            return deps.battlefield_system.execute_enemy(unit)
        end,
        grant_bond_card = function(card_id)
            return BondSystem.debug_grant_card(deps.create_bond_env(), card_id)
        end,
        effect_debug_system = deps.effect_debug_system,
        force_trigger_effect = function(effect_id)
            return deps.auto_active_effects_system.force_trigger_effect(effect_id)
        end,
        open_effect_debug_panel_ui = function()
            if not deps.gm_bond_effects_system then
                return
            end
            local gm_ui = deps.gm_bond_effects_system.ensure_board and deps.gm_bond_effects_system.ensure_board() or nil
            if gm_ui and gm_ui.visible ~= true then
                deps.gm_bond_effects_system.toggle_board()
            else
                deps.gm_bond_effects_system.refresh_board()
            end
        end,
        sample_skill_system = deps.sample_skills_system,
    })
end

function M.create_debug_tools_system(deps)
    return DebugToolsSystem.create({
        STATE = deps.STATE,
        CONFIG = deps.CONFIG,
        y3 = deps.y3,
        message = deps.message,
        round_number = deps.round_number,
        make_point = deps.make_point,
        develop_command = require 'y3.develop.command',
        get_player = deps.get_player,
        get_hero_point = deps.get_hero_point,
        get_current_wave = deps.get_current_wave,
        get_boss_name = deps.get_boss_name,
        get_hero_level = deps.get_hero_level,
        get_active_challenge_count = function()
            return deps.battlefield_system.get_active_challenge_count()
        end,
        show_runtime_status = deps.show_runtime_status,
        debug_add_test_resources = function()
            return deps.debug_actions_system.debug_add_test_resources()
        end,
        debug_grant_levels = function(level_count)
            return deps.debug_actions_system.debug_grant_levels(level_count)
        end,
        debug_unlock_all_attack_skills = function()
            return deps.debug_actions_system.debug_unlock_all_attack_skills()
        end,
        debug_trigger_bond_draw = function()
            return deps.debug_actions_system.debug_trigger_bond_draw()
        end,
        debug_refill_challenge_charges = function()
            return deps.debug_actions_system.debug_refill_challenge_charges()
        end,
        debug_force_spawn_boss = function()
            return deps.debug_actions_system.debug_force_spawn_boss()
        end,
        debug_show_attr_tip_panel = deps.show_runtime_attr_dialog,
        debug_grant_bond_card = function(card_id)
            return deps.debug_actions_system.debug_grant_bond_card(card_id)
        end,
        effect_debug_system = deps.effect_debug_system,
        debug_open_effect_debug_panel = function()
            return deps.debug_actions_system.debug_open_effect_debug_panel()
        end,
        debug_select_effect = function(effect_id)
            return deps.debug_actions_system.debug_select_effect(effect_id)
        end,
        debug_mount_effect = function(effect_id)
            return deps.debug_actions_system.debug_mount_effect(effect_id)
        end,
        debug_unmount_effect = function(effect_id)
            return deps.debug_actions_system.debug_unmount_effect(effect_id)
        end,
        debug_clear_mounted_effects = function()
            return deps.debug_actions_system.debug_clear_mounted_effects()
        end,
        debug_trigger_effect = function(effect_id)
            return deps.debug_actions_system.debug_trigger_effect(effect_id)
        end,
        debug_start_effect_observe = function(effect_id)
            return deps.debug_actions_system.debug_start_effect_observe(effect_id)
        end,
        debug_print_effect_logs = function()
            return deps.debug_actions_system.debug_print_effect_logs()
        end,
        debug_list_sample_skills = function()
            return deps.debug_actions_system.debug_list_sample_skills()
        end,
        debug_cast_sample_skill = function(sample_id)
            return deps.debug_actions_system.debug_cast_sample_skill(sample_id)
        end,
        debug_cast_next_sample_skill = function()
            return deps.debug_actions_system.debug_cast_next_sample_skill()
        end,
        debug_print_sample_framework_telemetry = function(sample_id)
            return deps.debug_actions_system.debug_print_sample_framework_telemetry(sample_id)
        end,
        debug_print_sample_framework_report = function()
            return deps.debug_actions_system.debug_print_sample_framework_report()
        end,
        debug_run_framework_tier_suite = function()
            return deps.debug_actions_system.debug_run_framework_tier_suite()
        end,
        debug_print_framework_tier_report = function()
            return deps.debug_actions_system.debug_print_framework_tier_report()
        end,
        debug_set_global_projectile_override = function(projectile_key)
            return deps.debug_actions_system.debug_set_global_projectile_override(projectile_key)
        end,
        debug_clear_global_projectile_override = function()
            return deps.debug_actions_system.debug_clear_global_projectile_override()
        end,
        debug_toggle_global_projectile_override = function(projectile_key)
            return deps.debug_actions_system.debug_toggle_global_projectile_override(projectile_key)
        end,
        debug_get_global_projectile_override = function()
            return deps.debug_actions_system.debug_get_global_projectile_override()
        end,
        sample_skill_system = deps.sample_skills_system,
    })
end

function M.create_gm_bond_effects_system(deps)
    return GmBondEffectsSystem.create({
        STATE = deps.STATE,
        y3 = deps.y3,
        message = deps.message,
        develop_command = require 'y3.develop.command',
        get_player = deps.get_player,
        is_battle_active = function()
            return deps.STATE.session_phase == 'battle' and deps.STATE.game_finished ~= true
        end,
        grant_modifier_card_effect = function(card_ref)
            return BondSystem.debug_grant_modifier_card(deps.create_bond_env(), card_ref)
        end,
        activate_modifier_bond_effect = function(bond_name, grant_missing_cards)
            return BondSystem.debug_activate_modifier_bond(deps.create_bond_env(), bond_name, grant_missing_cards)
        end,
        activate_single_modifier_bond_effect = function(bond_name, grant_missing_cards)
            return BondSystem.debug_activate_single_modifier_bond(deps.create_bond_env(), bond_name, grant_missing_cards)
        end,
        clear_active_modifier_bond_effects = function()
            return BondSystem.debug_clear_active_modifier_bonds(deps.create_bond_env())
        end,
        set_force_special_effects_100 = function(enabled)
            BondModifierEffects.set_force_special_effects_100(enabled)
        end,
        is_force_special_effects_100 = function()
            return BondModifierEffects.is_force_special_effects_100()
        end,
        run_bond_self_test = function()
            return nil
        end,
        list_sample_skills = function()
            if deps.sample_skills_system and deps.sample_skills_system.list_samples then
                return deps.sample_skills_system.list_samples()
            end
            return {}
        end,
        cast_sample_skill = function(sample_id)
            if deps.sample_skills_system and deps.sample_skills_system.cast_sample then
                local ok, msg = deps.sample_skills_system.cast_sample(sample_id)
                if ok then
                    return ok, msg
                end
            end
            if deps.skill_framework_system and deps.skill_framework_system.cast_by_id then
                return deps.skill_framework_system.cast_by_id(sample_id)
            end
            return false, '技能系统未初始化。'
        end,
        cast_next_sample_skill = function()
            if deps.sample_skills_system and deps.sample_skills_system.cast_next_sample then
                return deps.sample_skills_system.cast_next_sample()
            end
            return false, 'sample 技能系统未初始化。'
        end,
        get_sample_skill_defs = function()
            local seen = {}
            local defs = {}
            if deps.sample_skills_system and deps.sample_skills_system.get_sample_defs then
                for _, def in ipairs(deps.sample_skills_system.get_sample_defs()) do
                    if def.id and not seen[def.id] then
                        seen[def.id] = true
                        defs[#defs + 1] = def
                    end
                end
            end
            if deps.skill_framework_system and deps.skill_framework_system.list_registered then
                for _, def in ipairs(deps.skill_framework_system.list_registered()) do
                    if def.id and not seen[def.id] then
                        seen[def.id] = true
                        defs[#defs + 1] = {
                            id = def.id,
                            name = def.name or def.id,
                            desc = string.format('%s/%s·范围%d', def.pattern or '', def.sub_behavior or '',
                                def.hit_model and def.hit_model.radius or 0),
                            pattern = def.pattern,
                            sub_behavior = def.sub_behavior,
                            target_mode = def.target_mode,
                            damage_type = def.damage_type,
                            cooldown = def.resource and def.resource.cooldown or 0,
                            radius = def.hit_model and def.hit_model.radius or 0,
                            range = def.hit_model and def.hit_model.range or 0,
                            attack_ratio = def.scale and (def.scale.attack_ratio or def.scale.tick_ratio) or 0,
                        }
                    end
                end
            end
            return defs
        end,
        cast_basic_attack_ability = function()
            if deps.attack_skills_system and deps.attack_skills_system.debug_cast_basic_attack_once then
                return deps.attack_skills_system.debug_cast_basic_attack_once()
            end
            return false, '普攻能力系统未初始化。'
        end,
        set_n0_activation_mode = function(mode)
            if deps.battle_auto_acceptance_system and deps.battle_auto_acceptance_system.set_activation_mode then
                deps.battle_auto_acceptance_system.set_activation_mode(mode)
                return true
            end
            return false
        end,
        set_n0_single_bond_name = function(bond_name)
            if deps.battle_auto_acceptance_system and deps.battle_auto_acceptance_system.set_single_bond_name then
                deps.battle_auto_acceptance_system.set_single_bond_name(bond_name)
                return true
            end
            return false
        end,
        restart_n0_auto_acceptance = function()
            if deps.battle_auto_acceptance_system and deps.battle_auto_acceptance_system.restart_current_run then
                return deps.battle_auto_acceptance_system.restart_current_run() == true
            end
            return false
        end,
        debug_set_global_projectile_override = function(projectile_key)
            if deps.debug_actions_system and deps.debug_actions_system.debug_set_global_projectile_override then
                return deps.debug_actions_system.debug_set_global_projectile_override(projectile_key)
            end
        end,
        debug_clear_global_projectile_override = function()
            if deps.debug_actions_system and deps.debug_actions_system.debug_clear_global_projectile_override then
                return deps.debug_actions_system.debug_clear_global_projectile_override()
            end
        end,
        debug_toggle_global_projectile_override = function(projectile_key)
            if deps.debug_actions_system and deps.debug_actions_system.debug_toggle_global_projectile_override then
                return deps.debug_actions_system.debug_toggle_global_projectile_override(projectile_key)
            end
        end,
        debug_get_global_projectile_override = function()
            if deps.debug_actions_system and deps.debug_actions_system.debug_get_global_projectile_override then
                return deps.debug_actions_system.debug_get_global_projectile_override()
            end
            return nil
        end,
        set_basic_attack_enabled = function(enabled)
            deps.STATE.basic_attack_enabled = enabled == true
            return true
        end,
        get_basic_attack_enabled = function()
            return deps.STATE.basic_attack_enabled ~= false
        end,
        get_game_time = function()
            if deps.y3 and deps.y3.game and deps.y3.game.current_game_run_time then
                return tonumber(deps.y3.game.current_game_run_time()) or 0
            end
            return 0
        end,
        debug_end_battle_win = deps.debug_end_battle_win,
        debug_end_battle_lose = deps.debug_end_battle_lose,
    })
end

function M.create_battle_auto_acceptance_system(deps)
    return BattleAutoAcceptanceSystem.create({
        STATE = deps.STATE,
        CONFIG = deps.CONFIG,
        y3 = deps.y3,
        message = deps.message,
        auto_start_in_n0 = true,
        is_battle_active = function()
            return deps.STATE.session_phase == 'battle' and deps.STATE.game_finished ~= true
        end,
        get_enemy_player = deps.get_enemy_player,
        has_unit_data = function(unit_id)
            return deps.battlefield_system and deps.battlefield_system.has_unit_data and deps.battlefield_system.has_unit_data(unit_id) or false
        end,
        activate_modifier_bond_effect = function(bond_name, grant_missing_cards)
            return BondSystem.debug_activate_modifier_bond(deps.create_bond_env(), bond_name, grant_missing_cards)
        end,
        activate_single_modifier_bond_effect = function(bond_name, grant_missing_cards)
            return BondSystem.debug_activate_single_modifier_bond(deps.create_bond_env(), bond_name, grant_missing_cards)
        end,
        clear_active_modifier_bond_effects = function()
            return BondSystem.debug_clear_active_modifier_bonds(deps.create_bond_env())
        end,
        set_force_special_effects_100 = function(enabled)
            BondModifierEffects.set_force_special_effects_100(enabled)
        end,
        run_bond_self_test = function()
            return nil
        end,
        get_game_time = function()
            if deps.y3 and deps.y3.game and deps.y3.game.current_game_run_time then
                return tonumber(deps.y3.game.current_game_run_time()) or 0
            end
            return 0
        end,
    })
end

return M
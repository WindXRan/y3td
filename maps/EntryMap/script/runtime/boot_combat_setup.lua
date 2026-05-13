local SkillDamageTemplates = require 'runtime.skill_damage_templates'
local SkillFrameworkSystem = require 'runtime.skill_framework'
local SampleSkillsSystem = require 'runtime.sample_skills'
local GeneratedSkills = require 'runtime.generated_skills'
local AttackSkillsSystem = require 'runtime.attack_skills'
local AutoActiveEffectsSystem = require 'runtime.auto_active_effects'
local EffectDebugSystem = require 'runtime.effect_debug'
local BattlefieldSystem = require 'runtime.battlefield'
local BootCombat = require 'runtime.boot_combat'
local BootHelpers = require 'runtime.boot_helpers'

local M = {}

function M.create_skill_framework_system(deps)
    local y3 = deps.y3
    local get_enemies_in_range = deps.get_enemies_in_range
    local get_current_hero = deps.get_current_hero
    local get_hero_point = deps.get_hero_point
    local get_hero_attack = deps.get_hero_attack
    local get_primary_target = deps.get_primary_target
    local spawn_particle = deps.spawn_particle
    local launch_projectile_from_hero = deps.launch_projectile_from_hero
    local td_damage_api = deps.td_damage_api

    return SkillFrameworkSystem.create({
        y3 = y3,
        skill_damage_api = td_damage_api,
        get_enemies_in_range = get_enemies_in_range,
        get_hero = get_current_hero,
        get_hero_point = get_hero_point,
        get_hero_attack = get_hero_attack,
        get_primary_target = get_primary_target,
        get_hero_facing_towards = function(target)
            local hero = deps.STATE.hero
            if not hero or not hero:is_exist() then
                return 0
            end
            local hero_point = get_hero_point()
            local target_point = target and target.get_point and target:get_point() or nil
            if hero_point and target_point and hero_point.get_angle_with then
                return hero_point:get_angle_with(target_point)
            end
            return hero.get_facing and (tonumber(hero:get_facing()) or 0) or 0
        end,
        create_offset_point = function(_, base_point, angle, distance, z)
            if not base_point then
                return nil
            end
            local dir = tonumber(angle) or 0
            local travel = tonumber(distance) or 0
            if y3 and y3.point and y3.point.get_point_offset_vector then
                local ok, point = pcall(y3.point.get_point_offset_vector, base_point, dir, travel)
                if ok and point then
                    return point
                end
            end
            if y3 and y3.point and y3.point.create and base_point.get_x and base_point.get_y then
                local x = base_point:get_x() + math.cos(dir) * travel
                local y = base_point:get_y() + math.sin(dir) * travel
                local point_z = z or (base_point.get_z and base_point:get_z() or 0)
                return y3.point.create(x, y, point_z)
            end
            return nil
        end,
        spawn_particle = spawn_particle,
        launch_projectile_from_hero = launch_projectile_from_hero,
    })
end

function M.create_sample_skills_system(deps)
    return SampleSkillsSystem.create({
        STATE = deps.STATE,
        y3 = deps.y3,
        message = deps.message,
        hero_attr_system = deps.hero_attr_system,
        skill_framework = deps.skill_framework_system,
        skill_damage_api = deps.td_damage_api,
        get_enemies_in_range = deps.get_enemies_in_range,
        is_active_enemy = deps.is_active_enemy,
        get_hero = deps.get_current_hero,
        get_hero_point = deps.get_hero_point,
        get_hero_attack = deps.get_hero_attack,
        get_primary_target = deps.get_primary_target,
        spawn_particle = deps.spawn_particle,
        launch_projectile_from_hero = deps.launch_projectile_from_hero,
    })
end

function M.create_attack_skills_system(deps)
    return AttackSkillsSystem.create({
        STATE = deps.STATE,
        CONFIG = deps.CONFIG,
        y3 = deps.y3,
        skill_framework = deps.skill_framework_system,
        attack_skill_slot_count = deps.ATTACK_SKILL_SLOT_COUNT,
        round_number = deps.round_number,
        message = deps.message,
        hero_attr_system = deps.hero_attr_system,
        ATTACK_SKILL_DEFS = deps.ATTACK_SKILL_DEFS,
        ATTACK_SKILL_VFX = deps.AttackSkillObjects.vfx_by_id,
        get_player = deps.get_player,
        get_hero_point = deps.get_hero_point,
        get_bond_runtime_bonus = deps.get_bond_runtime_bonus,
        is_active_enemy = deps.is_active_enemy,
        create_attack_skill_instance = deps.create_attack_skill_instance,
        deal_skill_damage = deps.deal_skill_damage,
        emit_damage_debug = deps.emit_damage_debug,
        get_damage_bonus_multiplier = deps.get_damage_bonus_multiplier,
        reserve_formula_damage = BootCombat.reserve_formula_damage,
        get_enemies_in_range = deps.get_enemies_in_range,
        try_trigger_hunter_first_hit = deps.try_trigger_hunter_first_hit,
        notify_bond_attack_skill_cast = deps.notify_bond_attack_skill_cast,
        notify_auto_active_basic_attack = deps.notify_auto_active_basic_attack,
        notify_auto_active_skill_cast = deps.notify_auto_active_skill_cast,
        play_basic_attack_sound = deps.play_basic_attack_sound,
        play_attack_skill_sound = deps.play_attack_skill_sound,
    })
end

function M.create_auto_active_effects_system(deps)
    return AutoActiveEffectsSystem.create({
        STATE = deps.STATE,
        CONFIG = deps.CONFIG,
        y3 = deps.y3,
        attack_skill_slot_count = deps.ATTACK_SKILL_SLOT_COUNT,
        hero_attr_system = deps.hero_attr_system,
        str_to_modifier_key = function(name)
            return deps.y3.game.str_to_modifier_key(name)
        end,
        ATTACK_SKILL_VFX = deps.AttackSkillObjects.vfx_by_id,
        get_player = deps.get_player,
        has_bond_route_tag = deps.has_bond_route_tag,
        is_debug_effect_mounted = deps.is_debug_effect_mounted,
        is_active_enemy = deps.is_active_enemy,
        get_enemies_in_range = deps.get_enemies_in_range,
        deal_skill_damage = deps.deal_skill_damage,
        heal_hero = deps.heal_hero,
    })
end

function M.create_effect_debug_system(deps)
    return EffectDebugSystem.create({
        STATE = deps.STATE,
        message = deps.message,
        get_modifier_name_by_key = function(modifier_key)
            if not modifier_key or modifier_key == 0 then
                return nil
            end
            return deps.y3.buff.get_name_by_key(modifier_key)
        end,
        get_effect_defs = function()
            return deps.auto_active_effects_system.get_effect_defs()
        end,
        get_effect_runtime_snapshot = function(effect_id)
            return deps.auto_active_effects_system.get_effect_runtime_snapshot(effect_id)
        end,
        clear_effect_runtime = function(effect_id)
            return deps.auto_active_effects_system.clear_effect_runtime(effect_id)
        end,
    })
end

function M.create_battlefield_system(deps)
    return BattlefieldSystem.create({
        STATE = deps.STATE,
        CONFIG = deps.CONFIG,
        y3 = deps.y3,
        message = deps.message,
        design_seconds = deps.design_seconds,
        random_point_in_area = deps.random_point_in_area,
        hero_attr_system = deps.hero_attr_system,
        set_attr_pack = deps.set_attr_pack,
        add_attr_pack = deps.add_attr_pack,
        get_player = deps.get_player,
        get_enemy_player = deps.get_enemy_player,
        get_hero_level = deps.get_hero_level,
        award_rewards = deps.award_rewards,
        build_reward_with_bond_bonus = deps.build_reward_with_bond_bonus,
        handle_bond_enemy_kill = deps.handle_bond_enemy_kill,
        heal_hero = deps.heal_hero,
        play_enemy_death_sound = deps.play_enemy_death_sound,
        on_hero_damage = deps.on_hero_damage,
        apply_formula_damage_override = deps.apply_formula_damage_override,
        on_hero_before_hurt = deps.on_hero_before_hurt,
        on_wave_started = deps.on_wave_started,
        on_mainline_task_wave_started = deps.on_mainline_task_wave_started,
        on_mainline_task_enemy_killed = deps.on_mainline_task_enemy_killed,
        on_mainline_task_wave_cleared = deps.on_mainline_task_wave_cleared,
        on_mainline_task_cleared = deps.on_mainline_task_cleared,
        on_boss_spawned = deps.on_boss_spawned,
        on_boss_warning = deps.on_boss_warning,
        on_challenge_started = deps.on_challenge_started,
        on_challenge_finished = deps.on_challenge_finished,
        on_hero_be_hurt = deps.on_hero_be_hurt,
        on_hero_attr_changed = deps.on_hero_attr_changed,
        on_finish_game = deps.on_finish_game,
    })
end

function M.create_damage_templates(deps)
    return SkillDamageTemplates.create({
        y3 = deps.y3,
        deal_skill_damage = function(target, amount, damage_meta, visual)
            return deps.deal_skill_damage(target, amount, damage_meta, visual)
        end,
        emit_damage_debug = function(visual)
            return deps.emit_damage_debug_visual(visual, nil)
        end,
        get_enemies_in_range = deps.get_enemies_in_range,
        get_enemies_on_line = deps.get_enemies_on_line,
        is_active_enemy = deps.is_active_enemy,
    })
end

function M.register_generated_skills(skill_framework_system)
    local generated_api = GeneratedSkills.create(skill_framework_system)
    local count = generated_api.register_all()
    print('[boot] 批量注册技能完成: ' .. tostring(count) .. ' 个')
end

return M
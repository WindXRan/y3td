local AutoActiveEffectsData = require 'data.tables.skill.auto_active_effects'
local RuntimeEditorIds = require 'data.tables.runtime_editor_ids'
local M = {}

local function shallow_copy(tbl)
    local result = {}
    for key, value in pairs(tbl or {}) do
        result[key] = value
    end
    return result
end

function M.create(deps)
    local STATE = deps.STATE
    local y3 = deps.y3
    local attack_skill_slot_count = math.max(1, tonumber(deps.attack_skill_slot_count) or 5)
    local hero_attr_system = deps.hero_attr_system
    local ATTACK_SKILL_VFX = deps.ATTACK_SKILL_VFX
    local has_bond_route_tag = deps.has_bond_route_tag
    local is_debug_effect_mounted = deps.is_debug_effect_mounted
    local is_active_enemy = deps.is_active_enemy
    local get_enemies_in_range = deps.get_enemies_in_range
    local deal_skill_damage = deps.deal_skill_damage
    local heal_hero = deps.heal_hero
    local effect_defs = AutoActiveEffectsData.list
    local visual_speed = 0.5

    local MODIFIER_KEYS = {
        stun = 117,
        fighting_spirit = RuntimeEditorIds.modifier.auto_active_effect.fighting_spirit_field,
        rapid_overdrive = RuntimeEditorIds.modifier.auto_active_effect.rapid_overdrive,
        charge_breaker_rally = RuntimeEditorIds.modifier.auto_active_effect.charge_breaker_rally
    }

    local function scale_visual_duration(duration)
        return math.max(0.05, (duration or 0.30) / visual_speed)
    end

    local function set_particle_speed(particle)
        if not particle or not particle.set_animation_speed then return end
        pcall(function() particle:set_animation_speed(visual_speed) end)
    end

    local function is_hit_effect_hidden()
        return STATE.ui_preferences and STATE.ui_preferences.hide_hit_effects == true or false
    end

    local function get_runtime_state()
        if not STATE.auto_active_effects then
            STATE.auto_active_effects = {
                cooldowns = {},
                counters = {},
                last_trigger_result = {},
                last_modifier_apply = {},
                temp_attr_bonuses = {},
                temp_target_bonuses = {},
                pending_skill_resets = {}
            }
        end
        return STATE.auto_active_effects
    end

    local function record_trigger_result(effect_id, result, reason)
        get_runtime_state().last_trigger_result[effect_id] = { result = result or 'none', reason = reason or '' }
    end

    local function record_modifier_apply(effect_id, modifier_key, success, reason)
        if not effect_id then return end
        get_runtime_state().last_modifier_apply[effect_id] = {
            modifier_key = modifier_key or 0,
            success = success ~= nil,
            reason = reason or (success and 'success' or 'failed')
        }
    end

    local function get_cooldown(effect_id)
        return get_runtime_state().cooldowns[effect_id] or 0
    end

    local function set_cooldown(effect_id, duration)
        get_runtime_state().cooldowns[effect_id] = math.max(0, duration or 0)
    end

    local function add_counter(effect_id, delta)
        local runtime = get_runtime_state()
        runtime.counters[effect_id] = (runtime.counters[effect_id] or 0) + (delta or 0)
        return runtime.counters[effect_id]
    end

    local function set_counter(effect_id, value)
        get_runtime_state().counters[effect_id] = value or 0
    end

    local function reset_counter(effect_id)
        get_runtime_state().counters[effect_id] = 0
    end

    local function is_effect_active(effect_def)
        if effect_def and is_debug_effect_mounted and is_debug_effect_mounted(effect_def.id) then
            return true
        end
        if effect_def.source_type == 'bond' then
            return has_bond_route_tag and has_bond_route_tag(effect_def.source_id) or false
        end
        if effect_def.source_type == 'mark' then
            return STATE.evolution_runtime
                and STATE.evolution_runtime.owned_evolution_ids
                and STATE.evolution_runtime.owned_evolution_ids[effect_def.source_id] == true
                or false
        end
        return false
    end

    local function get_unit_attr(unit, attr_name)
        if not unit or not unit.is_exist or not unit:is_exist() then return 0 end
        if hero_attr_system and unit == STATE.hero then
            return hero_attr_system.get_attr(unit, attr_name)
        end
        return y3.helper.tonumber(unit:get_attr(attr_name)) or 0
    end

    local function get_hero_attack_value()
        local attack_settled = get_unit_attr(STATE.hero, '攻击结算值')
        if attack_settled > 0 then return math.max(1, attack_settled) end
        local attack = get_unit_attr(STATE.hero, '攻击')
        if attack > 0 then return math.max(1, attack) end
        return math.max(1, get_unit_attr(STATE.hero, '物理攻击'))
    end

    local function clone_point(point)
        if not point or not point.move then return nil end
        return point:move()
    end

    local function get_hero_strength()
        return math.max(1, get_unit_attr(STATE.hero, '力量'))
    end

    local function get_hero_intelligence()
        return math.max(1, get_unit_attr(STATE.hero, '智力'))
    end

    local function get_hero_max_hp()
        local settled = get_unit_attr(STATE.hero, '生命结算值')
        if settled > 0 then return math.max(1, settled) end
        local hp = get_unit_attr(STATE.hero, '生命')
        if hp > 0 then return math.max(1, hp) end
        return math.max(1, get_unit_attr(STATE.hero, '最大生命'))
    end

    local function get_hero_hp_ratio()
        if not STATE.hero or not STATE.hero:is_exist() then return 1 end
        local max_hp = get_hero_max_hp()
        return math.max(0, math.min(1, STATE.hero:get_hp() / max_hp))
    end

    local function get_target_hp_ratio(unit)
        if not unit or not unit:is_exist() then return 1 end
        local max_hp = math.max(1, y3.helper.tonumber(unit:get_attr('生命')) or y3.helper.tonumber(unit:get_attr('最大生命')) or 1)
        return math.max(0, unit:get_hp() / max_hp)
    end

    local function get_target_max_hp(unit)
        local hp = y3.helper.tonumber(unit and unit.get_attr and unit:get_attr('生命')) or get_unit_attr(unit, '最大生命')
        return math.max(1, hp)
    end

    local function get_non_basic_skill_count()
        if not STATE.attack_skill_state or not STATE.attack_skill_state.slots then return 0 end
        local count = 0
        for i = 1, attack_skill_slot_count, 1 do
            local slot = STATE.attack_skill_state.slots[i]
            if slot and slot.id ~= 'basic_attack' then
                count = count + 1
            end
        end
        return count
    end

    local function play_particle_on_unit(unit, effect_key, scale, time, socket)
        if is_hit_effect_hidden() or not effect_key or not unit or not unit:is_exist() then return nil end
        local forced_key = tonumber(STATE and STATE.STATE and STATE.STATE.debug_force_projectile_key) or 201392033
        local ok, particle = pcall(y3.projectile.create, {
            key = forced_key,
            target = unit,
            socket = socket or 'origin',
            owner = STATE.hero,
            angle = 0,
            time = scale_visual_duration(time),
            remove_immediately = true
        })
        if ok and particle then
            set_particle_speed(particle)
            return particle
        end
        return nil
    end

    local function play_particle_on_point(point, effect_key, scale, time, socket)
        if is_hit_effect_hidden() or not effect_key or not point then return nil end
        local forced_key = tonumber(STATE and STATE.STATE and STATE.STATE.debug_force_projectile_key) or 201392033
        local ok, particle = pcall(y3.projectile.create, {
            key = forced_key,
            target = point,
            socket = 'origin',
            owner = STATE.hero,
            angle = 0,
            time = scale_visual_duration(time),
            remove_immediately = true
        })
        if ok and particle then
            set_particle_speed(particle)
            return particle
        end
        return nil
    end

    local function play_hero_attack_animation()
        if STATE.hero and STATE.hero:is_exist() then
            STATE.hero:play_animation('attack1', 1.0, nil, nil, false, true)
        end
    end

    local function apply_modifier(effect_id, unit, modifier_key, duration, source)
        if not modifier_key or modifier_key == 0 then
            record_modifier_apply(effect_id, modifier_key, nil, 'invalid_modifier_key')
            return nil
        end
        if not unit or not unit.is_exist or not unit:is_exist() or not unit.add_buff then
            record_modifier_apply(effect_id, modifier_key, nil, 'invalid_target')
            return nil
        end
        local ok, buff = pcall(unit.add_buff, unit, {
            key = modifier_key,
            source = source or STATE.hero,
            time = duration or 0
        })
        if ok then
            record_modifier_apply(effect_id, modifier_key, buff, buff and 'success' or 'nil_buff')
            return buff
        end
        record_modifier_apply(effect_id, modifier_key, nil, 'pcall_failed')
        return nil
    end

    local particle_height = 100

    local function create_projectile_to_target(vfx_config, target, on_finish)
        local angle = nil
        if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and target and target:is_exist() then
            local hero_point = STATE.hero:get_point()
            local target_point = target:get_point()
            if hero_point and target_point and hero_point.get_angle_with then
                angle = hero_point:get_angle_with(target_point)
            end
        end

        if not vfx_config or not vfx_config.projectile_key or not target or not target:is_exist() then
            if on_finish then on_finish(target and target:is_exist() and target:get_point() or nil, false) end
            return false
        end

        local ok, projectile = pcall(y3.projectile.create, {
            key = vfx_config.projectile_key,
            target = STATE.hero,
            socket = 'origin',
            owner = STATE.hero,
            angle = angle,
            time = vfx_config.projectile_time or 3.0,
            remove_immediately = true
        })

        if not ok or not projectile then
            if on_finish then on_finish(target:get_point(), false) end
            return false
        end

        pcall(function() projectile:set_height(particle_height) end)
        set_particle_speed(projectile)
        if angle ~= nil then
            pcall(function() projectile:set_facing(angle) end)
        end

        local finished = false

        local function get_current_point()
            return clone_point(projectile and projectile:is_exist() and projectile:get_point() or nil)
                or (target and target:is_exist() and target:get_point() or nil)
        end

        local function finish_callback(result_point, hit)
            if finished then return end
            finished = true
            local final_point = result_point
            if projectile and projectile:is_exist() then
                final_point = result_point or clone_point(projectile:get_point()) or final_point
                projectile:remove()
            end
            if on_finish then on_finish(final_point, hit == true) end
        end

        local move_ok = pcall(function()
            projectile:mover_target({
                target = target,
                speed = tonumber(vfx_config and vfx_config.projectile_speed) or 1000,
                target_distance = vfx_config.target_distance or 60,
                height = particle_height,
                init_angle = angle,
                rotate_time = 0.0,
                face_angle = true,
                miss_when_target_destroy = false,
                on_finish = function() finish_callback(get_current_point(), target and target:is_exist() or false) end,
                on_break = function() finish_callback(get_current_point(), false) end,
                on_miss = function() finish_callback(get_current_point(), false) end
            })
        end)

        if not move_ok then
            finish_callback(get_current_point(), false)
            return false
        end

        return true
    end

    local function find_closest_enemy(range, except_unit)
        if not STATE.hero or not STATE.hero:is_exist() then return nil end
        for _, unit in ipairs(get_enemies_in_range(STATE.hero, range or 900, except_unit, 10)) do
            if is_active_enemy(unit) then return unit end
        end
        return nil
    end

    local function find_lowest_hp_enemy(range, hp_threshold)
        if not STATE.hero or not STATE.hero:is_exist() then return nil end
        local target = nil
        local min_hp_ratio = 2
        for _, unit in ipairs(get_enemies_in_range(STATE.hero, range or 900, nil, 16)) do
            if is_active_enemy(unit) then
                local hp_ratio = get_target_hp_ratio(unit)
                if hp_ratio <= (hp_threshold or 1) and hp_ratio < min_hp_ratio then
                    min_hp_ratio = hp_ratio
                    target = unit
                end
            end
        end
        return target
    end

    local function deal_area_damage(center, radius, amount, damage_type, particle)
        local hit = false
        
        for _, unit in ipairs(get_enemies_in_range(center, radius or 0, STATE.hero, 24)) do
            local text_type = 'magic'
            if damage_type == '物理' or damage_type == 'weapon' then
                text_type = 'physics'
            end
            
            deal_skill_damage(unit, amount, damage_type, { text_type = text_type, particle = particle })
            hit = true
        end
        
        return hit
    end

    local function apply_temporary_attr_bonus(effect_id, attrs, duration)
        local runtime = get_runtime_state()
        local bonus = runtime.temp_attr_bonuses[effect_id]
        if not bonus then
            bonus = { attr = {}, remaining = 0 }
            runtime.temp_attr_bonuses[effect_id] = bonus
        end

        local hero = STATE.hero
        local applied = {}

        if hero and hero:is_exist() then
            for attr_name, value in pairs(attrs or {}) do
                applied[attr_name] = true
                local current = bonus.attr[attr_name] or 0
                local delta = value - current
                if delta ~= 0 then
                    if hero_attr_system then
                        hero_attr_system.add_attr(hero, attr_name, delta)
                    else
                        hero:add_attr(attr_name, delta)
                    end
                end
                bonus.attr[attr_name] = value
            end

            for attr_name, value in pairs(bonus.attr) do
                if not applied[attr_name] and value ~= 0 then
                    if hero_attr_system then
                        hero_attr_system.add_attr(hero, attr_name, -value)
                    else
                        hero:add_attr(attr_name, -value)
                    end
                    bonus.attr[attr_name] = nil
                end
            end
        else
            bonus.attr = attrs or {}
        end

        bonus.remaining = math.max(bonus.remaining or 0, duration or 0)

        if hero and hero:is_exist() and hero_attr_system then
            hero_attr_system.rebuild_derived_attrs(hero)
        end
    end

    local function remove_temporary_attr_bonus(effect_id)
        local runtime = get_runtime_state()
        local bonus = runtime.temp_attr_bonuses[effect_id]
        if not bonus then return end

        if STATE.hero and STATE.hero:is_exist() then
            for attr_name, value in pairs(bonus.attr or {}) do
                if value ~= 0 then
                    if hero_attr_system then
                        hero_attr_system.add_attr(STATE.hero, attr_name, -value)
                    else
                        STATE.hero:add_attr(attr_name, -value)
                    end
                end
            end
            if hero_attr_system then
                hero_attr_system.rebuild_derived_attrs(STATE.hero)
            end
        end

        runtime.temp_attr_bonuses[effect_id] = nil
    end

    local function apply_temporary_target_bonus(effect_id, unit, attrs, duration)
        if not unit or not unit:is_exist() then return end

        local runtime = get_runtime_state()
        runtime.temp_target_bonuses[effect_id] = runtime.temp_target_bonuses[effect_id] or {}
        local target_bonuses = runtime.temp_target_bonuses[effect_id]
        local bonus = target_bonuses[unit]

        if not bonus then
            bonus = { attr = {}, remaining = 0 }
            target_bonuses[unit] = bonus
        end

        if next(bonus.attr or {}) == nil then
            for attr_name, value in pairs(attrs or {}) do
                if value ~= 0 then
                    unit:add_attr(attr_name, value)
                end
                bonus.attr[attr_name] = value
            end
        end

        bonus.remaining = math.max(bonus.remaining or 0, duration or 0)
    end

    local function remove_temporary_target_bonus(effect_id, unit)
        local runtime = get_runtime_state()
        local target_bonuses = runtime.temp_target_bonuses[effect_id]
        local bonus = target_bonuses and target_bonuses[unit] or nil
        if not bonus then return end

        if unit and unit:is_exist() then
            for attr_name, value in pairs(bonus.attr or {}) do
                if value ~= 0 then
                    unit:add_attr(attr_name, -value)
                end
            end
        end

        target_bonuses[unit] = nil
    end

    local function update_temporary_bonuses(dt)
        local runtime = get_runtime_state()

        for effect_id, bonus in pairs(runtime.temp_attr_bonuses) do
            bonus.remaining = (bonus.remaining or 0) - dt
            if bonus.remaining <= 0 then
                remove_temporary_attr_bonus(effect_id)
            end
        end

        for effect_id, target_bonuses in pairs(runtime.temp_target_bonuses) do
            for unit, bonus in pairs(target_bonuses) do
                bonus.remaining = (bonus.remaining or 0) - dt
                if bonus.remaining <= 0 or not unit or not unit:is_exist() then
                    remove_temporary_target_bonus(effect_id, unit)
                end
            end
            if next(target_bonuses) == nil then
                runtime.temp_target_bonuses[effect_id] = nil
            end
        end
    end

    local function apply_pending_skill_resets()
        local runtime = get_runtime_state()
        if not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then return end

        for skill_id, should_reset in pairs(runtime.pending_skill_resets) do
            if should_reset then
                local skill = STATE.attack_skill_state.by_id[skill_id]
                if skill then
                    skill.cooldown_remaining = 0
                end
            end
            runtime.pending_skill_resets[skill_id] = nil
        end
    end

    local function trigger_spell_burst(effect_def)
        local target = find_closest_enemy(effect_def.range)
        if not target then return false end

        local has_amp = has_bond_route_tag and has_bond_route_tag('auto_spell_burst_amp') or false
        local count = 1 + (has_amp and get_non_basic_skill_count() or 0)
        local radius = (effect_def.radius or 300) + (has_amp and 150 or 0)
        local damage = get_hero_strength() * (effect_def.damage_ratio or 2.0)
        local vfx = ATTACK_SKILL_VFX[effect_def.vfx]

        play_hero_attack_animation()
        play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or nil, vfx and vfx.cast_scale or 1, vfx and vfx.cast_time or 0.2, 'origin')

        for i = 1, count, 1 do
            local current_target = find_closest_enemy(effect_def.range) or target
            if current_target and current_target:is_exist() then
                local point = current_target:get_point()
                play_particle_on_point(point, vfx and vfx.explosion_particle or vfx and vfx.impact_particle or nil, 1.15, 0.35, 12)
                deal_area_damage(point, radius, damage, '物理')
            end
        end

        return true
    end

    local function trigger_haste_reset(effect_def, context)
        local skill = context and context.skill or nil
        if not skill or skill.id == 'basic_attack' then return false end
        if math.random() > math.max(0, math.min(1, effect_def.chance or 0)) then return false end

        get_runtime_state().pending_skill_resets[skill.id] = true

        local vfx = ATTACK_SKILL_VFX[effect_def.vfx]
        play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.0, 0.25, 'origin')

        return true
    end

    local function trigger_fighting_spirit_field(effect_def)
        if not STATE.hero or not STATE.hero:is_exist() then return false end

        local vfx = ATTACK_SKILL_VFX[effect_def.vfx]
        local damage = get_hero_intelligence() * (effect_def.damage_ratio or 0.60)
        local hit = false

        play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.15, 0.30, 'origin')

        for _, unit in ipairs(get_enemies_in_range(STATE.hero, effect_def.radius or 1200, STATE.hero, 30)) do
            if is_active_enemy(unit) then
                local extra_damage = get_target_max_hp(unit) * (effect_def.extra_hp_ratio or 0)
                deal_skill_damage(unit, damage + extra_damage, '物理', { text_type = 'physics' })

                local armor_reduction = -get_unit_attr(unit, '护甲') * (effect_def.armor_reduction_ratio or 0)
                local attack_reduction = -get_unit_attr(unit, '物理攻击') * (effect_def.attack_reduction_ratio or 0)
                apply_temporary_target_bonus(effect_def.id, unit, { ['护甲'] = armor_reduction, ['物理攻击'] = attack_reduction }, 1.25)

                apply_modifier(effect_def.id, unit, effect_def.modifier_key or MODIFIER_KEYS.fighting_spirit, 1.25)
                hit = true
            end
        end

        return hit
    end

    local function trigger_rapid_overdrive(effect_def)
        if math.random() > math.max(0, math.min(1, effect_def.chance or 0)) then return false end

        apply_temporary_attr_bonus(effect_def.id, { ['攻击速度'] = effect_def.attack_speed_bonus or 100 }, effect_def.duration or 5.0)
        apply_modifier(effect_def.id, STATE.hero, effect_def.modifier_key or MODIFIER_KEYS.rapid_overdrive, effect_def.duration or 5.0)

        local vfx = ATTACK_SKILL_VFX[effect_def.vfx]
        play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.05, 0.25, 'origin')

        return true
    end

    local function trigger_blood_demon_burst(effect_def)
        if not STATE.hero or not STATE.hero:is_exist() then return false end

        local threshold_step = math.max(0.01, effect_def.threshold_step or 0.35)
        local missing_hp_ratio = 1 - get_hero_hp_ratio()
        local current_tier = math.floor(missing_hp_ratio / threshold_step)
        local last_tier = get_runtime_state().counters[effect_def.id] or 0

        if current_tier <= last_tier then
            set_counter(effect_def.id, current_tier)
            return false
        end

        local vfx = ATTACK_SKILL_VFX[effect_def.vfx]
        local tier_diff = current_tier - last_tier
        local hit = false

        for i = 1, tier_diff, 1 do
            heal_hero(get_hero_max_hp() * (effect_def.heal_ratio or 0.20))
            play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.2, 0.35, 'origin')

            for _, unit in ipairs(get_enemies_in_range(STATE.hero, effect_def.blast_radius or 320, STATE.hero, 16)) do
                if is_active_enemy(unit) then
                    deal_skill_damage(unit, get_target_max_hp(unit) * (effect_def.damage_ratio or 0.50), '物理', { text_type = 'physics' })
                    apply_modifier(effect_def.id, unit, MODIFIER_KEYS.stun, 1.0)
                    apply_temporary_target_bonus(effect_def.id, unit, { ['攻击速度'] = -500, ['移动速度'] = -500 }, 1.0)
                    hit = true
                end
            end
        end

        set_counter(effect_def.id, current_tier)
        return hit
    end

    local function trigger_charge_breaker_rally(effect_def)
        apply_temporary_attr_bonus(effect_def.id, effect_def.attr or {}, effect_def.duration or 10.0)
        apply_modifier(effect_def.id, STATE.hero, effect_def.modifier_key or MODIFIER_KEYS.charge_breaker_rally, effect_def.duration or 10.0)

        local vfx = ATTACK_SKILL_VFX[effect_def.vfx]
        play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.2, 0.35, 'origin')

        return true
    end

    local function trigger_bloodrage_stomp(effect_def)
        if not STATE.hero or not STATE.hero:is_exist() then return false end

        local vfx = ATTACK_SKILL_VFX[effect_def.vfx]
        local damage = get_hero_attack_value() * (effect_def.damage_ratio or 1)

        play_hero_attack_animation()
        play_particle_on_unit(STATE.hero, vfx and vfx.impact_particle or nil, 1.25, 0.35, 'origin')

        return deal_area_damage(STATE.hero, effect_def.radius or 300, damage, '物理')
    end

    local function trigger_starfire_echo(effect_def, context)
        local target = context and context.target or nil
        if not is_active_enemy(target) then
            target = find_closest_enemy(effect_def.range)
        end
        if not target then return false end

        local vfx = ATTACK_SKILL_VFX[effect_def.vfx]
        local damage = get_hero_attack_value() * (effect_def.damage_ratio or 1)

        create_projectile_to_target(vfx, target, function(point, hit)
            if hit ~= true then return end
            if point and vfx and vfx.impact_particle then
                play_particle_on_point(point, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 18)
            end
            if is_active_enemy(target) then
                deal_skill_damage(target, damage, '物理', { text_type = 'magic' })
            end
        end)

        return true
    end

    local function get_effect_cooldown(effect_def)
        if not effect_def then return 0 end
        if effect_def.id == 'spell_burst' then
            local cooldown = effect_def.cooldown or 0
            if has_bond_route_tag and has_bond_route_tag('auto_spell_burst_amp') then
                cooldown = cooldown - 5
            end
            return math.max(1, cooldown)
        end
        return effect_def.cooldown or 0
    end

    local function trigger_effect(effect_def, context, options)
        options = options or {}
        if not options.ignore_source and not is_effect_active(effect_def) then
            record_trigger_result(effect_def.id, 'failed', 'inactive_source')
            return false
        end
        if not options.ignore_cooldown and get_cooldown(effect_def.id) > 0 then
            record_trigger_result(effect_def.id, 'failed', 'cooldown')
            return false
        end

        local success = false

        if effect_def.id == 'spell_burst' then
            success = trigger_spell_burst(effect_def)
        elseif effect_def.id == 'haste_reset' then
            success = trigger_haste_reset(effect_def, context)
        elseif effect_def.id == 'fighting_spirit_field' then
            success = trigger_fighting_spirit_field(effect_def)
        elseif effect_def.id == 'rapid_overdrive' then
            success = trigger_rapid_overdrive(effect_def)
        elseif effect_def.id == 'blood_demon_burst' then
            success = trigger_blood_demon_burst(effect_def)
        elseif effect_def.id == 'charge_breaker_rally' then
            success = trigger_charge_breaker_rally(effect_def)
        elseif effect_def.id == 'bloodrage_stomp' then
            success = trigger_bloodrage_stomp(effect_def)
        elseif effect_def.id == 'starfire_echo' then
            success = trigger_starfire_echo(effect_def, context)
        end

        if success then
            set_cooldown(effect_def.id, get_effect_cooldown(effect_def))
            record_trigger_result(effect_def.id, 'success', '')
        else
            record_trigger_result(effect_def.id, 'failed', 'no_target_or_condition')
        end

        return success
    end

    local function get_effect_runtime_snapshot(effect_id)
        local runtime = get_runtime_state()
        local effect_def = nil
        for _, def in ipairs(effect_defs) do
            if def.id == effect_id then
                effect_def = def
                break
            end
        end

        local last_result = runtime.last_trigger_result[effect_id] or {}
        local last_modifier = shallow_copy(runtime.last_modifier_apply[effect_id] or {})

        return {
            active = effect_def and is_effect_active(effect_def) or false,
            cooldown = runtime.cooldowns[effect_id] or 0,
            counter = runtime.counters[effect_id] or 0,
            last_result = last_result.result or 'none',
            last_reason = last_reason.reason or '',
            last_modifier_apply = last_modifier
        }
    end

    local function clear_effect_runtime(effect_id)
        local runtime = get_runtime_state()

        runtime.cooldowns[effect_id] = nil
        runtime.counters[effect_id] = nil
        runtime.last_trigger_result[effect_id] = nil
        runtime.last_modifier_apply[effect_id] = nil
        runtime.pending_skill_resets[effect_id] = nil

        remove_temporary_attr_bonus(effect_id)

        local target_bonuses = runtime.temp_target_bonuses[effect_id]
        if target_bonuses then
            for unit, _ in pairs(target_bonuses) do
                remove_temporary_target_bonus(effect_id, unit)
            end
            runtime.temp_target_bonuses[effect_id] = nil
        end
    end

    local function force_trigger_effect(effect_id, context)
        local effect_def = nil
        for _, def in ipairs(effect_defs) do
            if def.id == effect_id then
                effect_def = def
                break
            end
        end

        if not effect_def then return false, 'unknown_effect' end

        local success = trigger_effect(effect_def, context, { ignore_source = true, ignore_cooldown = true })
        local snapshot = get_effect_runtime_snapshot(effect_id)

        if success then return true, snapshot end
        return false, snapshot
    end

    local function update_cooldowns(dt)
        local runtime = get_runtime_state()
        for effect_id, cooldown in pairs(runtime.cooldowns) do
            if cooldown > 0 then
                runtime.cooldowns[effect_id] = math.max(0, cooldown - dt)
            end
        end
    end

    local function update(dt)
        if not STATE.hero or not STATE.hero:is_exist() or STATE.game_finished then return end

        update_cooldowns(dt)
        update_temporary_bonuses(dt)
        apply_pending_skill_resets()

        for _, effect_def in ipairs(effect_defs) do
            if effect_def.trigger_type == 'periodic' then
                trigger_effect(effect_def)
            end
        end
    end

    local function handle_enemy_kill(info)
        for _, effect_def in ipairs(effect_defs) do
            if effect_def.trigger_type == 'on_kill' and is_effect_active(effect_def) then
                if (effect_def.counter_required or 1) > 1 then
                    local count = add_counter(effect_def.id, 1)
                    if count >= (effect_def.counter_required or 1) and trigger_effect(effect_def, { info = info }) then
                        reset_counter(effect_def.id)
                    end
                else
                    trigger_effect(effect_def, { info = info })
                end
            end
        end
    end

    local function handle_basic_attack_cast(target)
        for _, effect_def in ipairs(effect_defs) do
            if effect_def.trigger_type == 'on_basic_attack_count' and is_effect_active(effect_def) then
                if (effect_def.counter_required or 1) > 1 then
                    local count = add_counter(effect_def.id, 1)
                    if count >= (effect_def.counter_required or 1) and trigger_effect(effect_def, { target = target }) then
                        reset_counter(effect_def.id)
                    end
                else
                    trigger_effect(effect_def, { target = target }, { ignore_cooldown = true })
                end
            end
        end
    end

    local function handle_attack_skill_cast(skill, target)
        if not skill or skill.id == 'basic_attack' then return end

        for _, effect_def in ipairs(effect_defs) do
            if effect_def.trigger_type == 'on_attack_skill_cast' then
                trigger_effect(effect_def, { skill = skill, target = target }, { ignore_cooldown = true })
            end
        end
    end

    return {
        update = update,
        handle_enemy_kill = handle_enemy_kill,
        handle_basic_attack_cast = handle_basic_attack_cast,
        handle_attack_skill_cast = handle_attack_skill_cast,
        get_effect_defs = function() return effect_defs end,
        get_effect_runtime_snapshot = get_effect_runtime_snapshot,
        force_trigger_effect = force_trigger_effect,
        clear_effect_runtime = clear_effect_runtime
    }
end

return M
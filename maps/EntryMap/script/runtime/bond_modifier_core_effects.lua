local M = {}

function M.create(deps)
  deps = deps or {}
  local BOND_NAME_ALIASES = {
    ['战法法师'] = '战斗法师',
    ['寒冰法师'] = '冰霜法师',
    ['冰法'] = '冰霜法师',
    ['电法'] = '雷电法王',
    ['雷法'] = '雷电法王',
  }

  local function normalize_bond_name(name)
    local key = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if key == '' then
      return key
    end
    return BOND_NAME_ALIASES[key] or key
  end

  local get_attack_value = deps.get_attack_value
  local get_max_hp_value = deps.get_max_hp_value
  local get_three_attr_value = deps.get_three_attr_value
  local get_hero_attr = deps.get_hero_attr
  local get_visual_config = deps.get_visual_config
  local get_hero = deps.get_hero
  local get_game_time = deps.get_game_time
  local has_card_effect = deps.has_card_effect
  local try_chance = deps.try_chance
  local play_bond_sound = deps.play_bond_sound
  local play_particle_on_unit = deps.play_particle_on_unit
  local play_particle_on_point = deps.play_particle_on_point
  local play_impact_burst = deps.play_impact_burst
  local play_lightning_strike = deps.play_lightning_strike
  local launch_projectile_to_target = deps.launch_projectile_to_target
  local wait_seconds = deps.wait_seconds
  local execute_linear_bond_template = deps.execute_linear_bond_template
  local trigger_dragon_fireball_effect = deps.trigger_dragon_fireball_effect
  local blink_hero_tactical_reposition = deps.blink_hero_tactical_reposition
  local schedule_summon_lifecycle_fx = deps.schedule_summon_lifecycle_fx
  local damage_target = deps.damage_target
  local damage_area = deps.damage_area
  local update_magic_swordsman_runtime_bonus = deps.update_magic_swordsman_runtime_bonus
  local sync_runtime_status_effect = deps.sync_runtime_status_effect
  local runtime_rules = deps.runtime_rules or {}
  local bond_basic_rules = runtime_rules.bond_basic_attack or {}
  local bond_periodic_rules = runtime_rules.bond_periodic or {}
  local presentation_defaults = runtime_rules.presentation_defaults or {}

  local api = {}

  local function rule_number(value, fallback)
    local number_value = tonumber(value)
    if number_value == nil then
      return fallback
    end
    return number_value
  end

  local function rule_integer(value, fallback, min_value)
    local number_value = tonumber(value)
    if number_value == nil then
      return fallback
    end
    local normalized = math.floor(number_value)
    if min_value ~= nil then
      normalized = math.max(min_value, normalized)
    end
    return normalized
  end

  local function rule_optional_max_targets(value)
    if value == nil then
      return nil
    end
    if type(value) == 'string' and string.lower(value) == 'max' then
      return nil
    end
    local normalized = tonumber(value)
    if normalized == nil then
      return nil
    end
    return math.max(1, math.floor(normalized))
  end

  local function get_bond_basic_rule(bond_name)
    return type(bond_basic_rules[bond_name]) == 'table' and bond_basic_rules[bond_name] or {}
  end

  local function get_bond_periodic_rule(bond_name)
    return type(bond_periodic_rules[bond_name]) == 'table' and bond_periodic_rules[bond_name] or {}
  end
  local function calc_area_fx_scale(radius, visual_cfg)
    local base_radius = math.max(80, tonumber(visual_cfg and visual_cfg.area_fx_base_radius) or 360)
    local bias = tonumber(visual_cfg and visual_cfg.area_fx_scale_bias) or 1.0
    local min_scale = tonumber(visual_cfg and visual_cfg.area_fx_min_scale) or 0.80
    local max_scale = tonumber(visual_cfg and visual_cfg.area_fx_max_scale) or 2.40
    local value = math.max(80, tonumber(radius) or base_radius)
    local scale = (value / base_radius) * bias
    return math.max(min_scale, math.min(max_scale, scale))
  end

  local function play_area_hit_fx(env, center, visual_cfg, radius, duration)
    if not visual_cfg or not visual_cfg.particle_key or not center then
      return
    end
    local scale = calc_area_fx_scale(radius, visual_cfg)
    local time = tonumber(duration) or 0.24
    local center_point = center
    if type(center.get_point) == 'function' then
      local ok, point = pcall(center.get_point, center)
      if ok and point then
        center_point = point
      end
    end
    if center_point and play_particle_on_point then
      play_particle_on_point(env, center_point, visual_cfg.particle_key, scale, time, 16)
      return
    end
    if type(center.is_exist) == 'function' then
      local ok, alive = pcall(center.is_exist, center)
      if ok and alive == true and play_particle_on_unit then
        play_particle_on_unit(env, center, visual_cfg.particle_key, scale, time)
        return
      end
    end
  end

  local function get_unit_point_snapshot(unit)
    if not unit or not unit.get_point then
      return nil
    end
    local ok, point = pcall(function()
      return unit:get_point()
    end)
    if ok then
      return point
    end
    return nil
  end

  local function pick_impact_unit(env, anchor_point, fallback_target)
    if fallback_target and fallback_target.is_exist and fallback_target:is_exist() then
      return fallback_target
    end
    if env and env.get_enemies_in_range and anchor_point then
      local ok, arr = pcall(env.get_enemies_in_range, anchor_point, 180, nil, 1)
      if ok and type(arr) == 'table' and arr[1] and arr[1].is_exist and arr[1]:is_exist() then
        return arr[1]
      end
    end
    return nil
  end

  local function create_offset_point(env, base_point, angle, distance)
    if not env or not base_point then
      return nil
    end
    local y3 = env.y3
    if y3 and y3.point and y3.point.get_point_offset_vector then
      local ok, point = pcall(function()
        return y3.point.get_point_offset_vector(base_point, angle, distance or 0)
      end)
      if ok and point then
        return point
      end
    end
    if y3 and y3.point and y3.point.create and base_point.get_x and base_point.get_y then
      local bx = tonumber(base_point:get_x()) or 0
      local by = tonumber(base_point:get_y()) or 0
      local bz = base_point.get_z and (tonumber(base_point:get_z()) or 0) or 0
      local d = tonumber(distance) or 0
      return y3.point.create(
        bx + math.cos(angle or 0) * d,
        by + math.sin(angle or 0) * d,
        bz
      )
    end
    return nil
  end

  local function schedule_projectile_impact(env, visual_cfg, callback)
    local delay = math.max(0.0, rule_number(visual_cfg and visual_cfg.projectile_time, 0))
    wait_seconds(env, delay, callback)
  end

  local function perform_visual_delivery(env, target, visual_cfg, on_impact)
    local mode = tostring(visual_cfg and visual_cfg.delivery_mode or 'projectile')
    if mode == 'projectile' then
      launch_projectile_to_target(env, target, visual_cfg)
      schedule_projectile_impact(env, visual_cfg, on_impact)
      return
    end
    -- instant / persistent_area: 不强塞投射物，按特效类型走短前摇命中。
    local warmup = mode == 'persistent_area'
      and rule_number(presentation_defaults.persistent_area_warmup, 0.10)
      or rule_number(presentation_defaults.instant_warmup, 0.05)
    wait_seconds(env, warmup, on_impact)
  end

  local function trigger_ranger_arrow_rain(env, target, visual_cfg, bond_damage_area, attack, rain_rule)
    if not target then
      return false
    end
    rain_rule = type(rain_rule) == 'table' and rain_rule or {}
    local storm_point = get_unit_point_snapshot(target)
    local storm_center = storm_point or target
        local storm_radius = math.max(80, rule_number(rain_rule.radius, tonumber(visual_cfg and visual_cfg.area_fx_base_radius) or 360))
    local tick_damage = attack * rule_number(rain_rule.tick_damage_attack_ratio, 0.80)
    local tick_count = math.max(1, rule_integer(rain_rule.tick_count, 3, 1))
    local tick_interval = math.max(0.05, rule_number(rain_rule.tick_interval, 1.00))
    local storm_scale = calc_area_fx_scale(storm_radius, visual_cfg)

    if play_particle_on_point and storm_point then
      play_particle_on_point(env, storm_point, visual_cfg.particle_key, storm_scale, tick_count * tick_interval + 0.25, 16)
    else
      play_particle_on_unit(env, target, visual_cfg.particle_key, storm_scale, 0.30)
    end

    local fx_pulse_every = math.max(0, rule_integer(rain_rule.fx_pulse_every, rule_integer(presentation_defaults.default_fx_pulse_every, 0, 0), 0))
    for index = 0, tick_count - 1 do
      wait_seconds(env, index * tick_interval, function()
        if index % 2 == 0 then
          play_bond_sound(env, '游侠', 'impact', storm_center)
        end
        -- 持续区域技能默认走“常驻特效 + 伤害Tick”模型：
        -- 不在每次Tick重复刷新同一特效，避免视觉抖动与逻辑误导。
        if fx_pulse_every > 0 and index > 0 and (index % fx_pulse_every == 0) then
          if play_particle_on_point and storm_point then
            play_particle_on_point(env, storm_point, visual_cfg.particle_key, storm_scale, 0.18, 16)
          else
            play_particle_on_unit(env, target, visual_cfg.particle_key, storm_scale, 0.14)
          end
        end
        bond_damage_area(storm_center, storm_radius, tick_damage, '物理')
      end)
    end
    return true
  end

  function api.trigger_modifier_basic_attack_effect(env, runtime, bond_name, effect_state, target)
    if not runtime or not target then
      return false
    end
    bond_name = normalize_bond_name(bond_name)
    local function report_cast(count)
      if env and env.report_auto_acceptance_event then
        env.report_auto_acceptance_event({
          scope = 'bond',
          key = bond_name,
          cast = tonumber(count) or 1,
        })
      end
    end
    local function bond_damage_target(unit, amount, damage_type)
      return damage_target(env, unit, amount, damage_type, { scope = 'bond', key = bond_name })
    end
    local function bond_damage_area(center, radius, amount, damage_type, except_unit, max_count)
      play_area_hit_fx(env, center, visual_cfg, radius, 0.22)
      return damage_area(env, center, radius, amount, damage_type, except_unit, max_count, { scope = 'bond', key = bond_name })
    end
    local attack = get_attack_value(env)
    local three_attr = get_three_attr_value(env)
    local attack_speed = get_hero_attr(env, '攻击速度')
    local visual_cfg = get_visual_config(bond_name)
    local basic_rule = get_bond_basic_rule(bond_name)
    local is_line_motion = tostring(visual_cfg and visual_cfg.motion_mode or 'target') == 'line'
    local line_aoe_radius = math.max(
      120,
      rule_number(
        basic_rule and basic_rule.line_aoe_radius,
        rule_number(
          basic_rule and basic_rule.line and basic_rule.line.width,
          math.floor(rule_number(visual_cfg and visual_cfg.area_fx_base_radius, 220) * 0.70)
        )
      )
    )
    local line_aoe_ratio = math.max(
      0.35,
      rule_number(
        basic_rule and basic_rule.line_aoe_ratio,
        0.65
      )
    )

    if bond_name == '枪炮师' then
      local trigger_chance = rule_number(basic_rule.chance, 0.08)
      if try_chance(trigger_chance) then
        report_cast(1)
        local hit = false
        local wave_count = has_card_effect(runtime, '战术后撤')
          and rule_integer(basic_rule.wave_count_with_tactical_reposition, 2, 1)
          or rule_integer(basic_rule.wave_count_default, 1, 1)
        local wave_damage = attack * rule_number(basic_rule.wave_damage_attack_ratio, 2.0)
          + three_attr * rule_number(basic_rule.wave_damage_three_attr_ratio, 1.00)
        local line_rule = type(basic_rule.line) == 'table' and basic_rule.line or {}
        for index = 1, wave_count do
          if index > 1 then
            blink_hero_tactical_reposition(env, target, visual_cfg)
          end
          execute_linear_bond_template(env, target, visual_cfg, {
            bond_name = '枪炮师',
            distance = rule_number(line_rule.distance, 1600),
            width = rule_number(line_rule.width, 210),
            max_targets = rule_optional_max_targets(line_rule.max_targets),
            projectile_speed = visual_cfg.projectile_speed,
            instant_hit = line_rule.instant_hit ~= false,
            target_fx_scale = rule_number(line_rule.target_fx_scale, 1.0),
            target_fx_time = rule_number(line_rule.target_fx_time, 0.25),
            hit_fx_scale = rule_number(line_rule.hit_fx_scale, 0.9),
            hit_fx_time = rule_number(line_rule.hit_fx_time, 0.18),
          }, function(unit)
            hit = bond_damage_target(unit, wave_damage, '物理') or hit
          end)
        end
        return hit
      end
    elseif bond_name == '神射手' then
      local trigger_chance = rule_number(basic_rule.chance, 0.08)
      if try_chance(trigger_chance) then
        report_cast(1)
        play_bond_sound(env, '神射手', 'cast', get_hero(env))
        local impact_point = get_unit_point_snapshot(target)
        perform_visual_delivery(env, target, visual_cfg, function()
          local impact_target = pick_impact_unit(env, impact_point, target)
          if not impact_target then
            return
          end
          play_bond_sound(env, '神射手', 'impact', impact_target)
          play_particle_on_unit(env, impact_target, visual_cfg.particle_key, 0.9, 0.25)
          local amount = attack * rule_number(basic_rule.damage_attack_ratio, 1.2)
            + attack_speed * rule_number(basic_rule.damage_attack_speed_ratio, 0.5)
          bond_damage_target(impact_target, amount, '物理')
          if is_line_motion then
            bond_damage_area(impact_target, line_aoe_radius, amount * line_aoe_ratio, '物理', impact_target)
          end
        end)
        return true
      end
    elseif bond_name == '游侠' then
      local trigger_chance = rule_number(basic_rule.chance, 0.08)
      if try_chance(trigger_chance) then
        report_cast(1)
        play_bond_sound(env, '游侠', 'cast', get_hero(env))
        perform_visual_delivery(env, target, visual_cfg, function() end)
        return trigger_ranger_arrow_rain(env, target, visual_cfg, bond_damage_area, attack, basic_rule.arrow_rain)
      end
    elseif bond_name == '狂战士' then
      local trigger_chance = rule_number(basic_rule.chance, 0.30)
      if try_chance(trigger_chance) then
        report_cast(1)
        local current_hp = target.get_hp and (tonumber(target:get_hp()) or 0) or 0
        local target_max_hp = target.get_attr and (tonumber(target:get_attr('生命')) or tonumber(target:get_attr('最大生命')) or current_hp) or current_hp
        play_bond_sound(env, '狂战士', 'cast', get_hero(env))
        play_bond_sound(env, '狂战士', 'impact', target)
        play_particle_on_unit(env, target, visual_cfg.particle_key, 1.1, 0.25)
        local amount = attack * rule_number(basic_rule.damage_attack_ratio, 0.10)
          + math.max(0, target_max_hp - current_hp) * rule_number(basic_rule.damage_missing_hp_ratio, 0.05)
        local hit = bond_damage_target(target, amount, '物理')
        if is_line_motion then
          bond_damage_area(target, line_aoe_radius, amount * math.max(0.35, line_aoe_ratio - 0.05), '物理', target)
        end
        return hit
      end
    elseif bond_name == '剑魂' then
      effect_state.counter = (effect_state.counter or 0) + 1
      local hit_count_trigger = rule_integer(basic_rule.hit_count_trigger, 10, 1)
      if effect_state.counter >= hit_count_trigger then
        report_cast(1)
        effect_state.counter = 0
        play_bond_sound(env, '剑魂', 'cast', get_hero(env))
        local impact_point = get_unit_point_snapshot(target)
        perform_visual_delivery(env, target, visual_cfg, function()
          local impact_target = pick_impact_unit(env, impact_point, target)
          if not impact_target then
            return
          end
          play_bond_sound(env, '剑魂', 'impact', impact_target)
          play_impact_burst(env, impact_target, visual_cfg.particle_key, 1.0)
          local amount = attack * rule_number(basic_rule.damage_attack_ratio, 1.5)
          bond_damage_target(impact_target, amount, '物理')
          if is_line_motion then
            bond_damage_area(impact_target, line_aoe_radius, amount * line_aoe_ratio, '物理', impact_target)
          end
        end)
        return true
      end
    elseif bond_name == '剑宗' then
      local trigger_chance = rule_number(basic_rule.chance, 0.08)
      if try_chance(trigger_chance) then
        report_cast(1)
        local storm_point = get_unit_point_snapshot(target)
        local storm_center = storm_point or target
        local storm_radius = math.max(80, rule_number(basic_rule.storm_radius, tonumber(visual_cfg and visual_cfg.area_fx_base_radius) or 360))
        local tick_count = math.max(1, rule_integer(basic_rule.tick_count, 15, 1))
        local tick_interval = math.max(0.05, rule_number(basic_rule.tick_interval, 0.20))
        local tick_damage = attack * rule_number(basic_rule.tick_damage_attack_ratio, 0.10)
          + get_hero_attr(env, '剑意') * rule_number(basic_rule.tick_damage_sword_intent_ratio, 2.0)
        local storm_scale = calc_area_fx_scale(storm_radius, visual_cfg)
        local edge_scale = math.max(
          rule_number(basic_rule.edge_scale_floor, 0.65),
          storm_scale * rule_number(basic_rule.edge_scale_ratio, 0.72)
        )
        play_bond_sound(env, '剑宗', 'cast', get_hero(env))
        play_impact_burst(env, target, visual_cfg.particle_key, 1.05)
        perform_visual_delivery(env, target, visual_cfg, function() end)
        if play_particle_on_point and storm_point then
          play_particle_on_point(env, storm_point, visual_cfg.particle_key, storm_scale, tick_count * tick_interval + 0.30, 16)
        else
          play_particle_on_unit(env, target, visual_cfg.particle_key, storm_scale, 0.30)
        end
        local fx_pulse_every = math.max(0, rule_integer(basic_rule.fx_pulse_every, rule_integer(presentation_defaults.default_fx_pulse_every, 0, 0), 0))
        for index = 0, tick_count - 1 do
          wait_seconds(env, index * tick_interval, function()
            if index % 2 == 0 then
              play_bond_sound(env, '剑宗', 'impact', storm_center)
            end
            -- 持续区域技能默认不按每个伤害Tick刷新整套视觉，改为可选低频脉冲。
            if fx_pulse_every > 0 and index > 0 and (index % fx_pulse_every == 0) then
              if play_particle_on_point and storm_point then
                play_particle_on_point(env, storm_point, visual_cfg.particle_key, storm_scale, 0.16, 16)
                local spoke_count = math.max(1, rule_integer(basic_rule.spoke_count, 6, 1))
                local spoke_rotation = rule_number(basic_rule.spoke_rotation_delta, 0.24)
                local spoke_radius_ratio = rule_number(basic_rule.spoke_radius_ratio, 0.76)
                for spoke = 1, spoke_count do
                  local angle = (spoke - 1) * (math.pi * 2 / spoke_count) + index * spoke_rotation
                  local edge = create_offset_point(env, storm_point, angle, storm_radius * spoke_radius_ratio)
                  if edge then
                    play_particle_on_point(env, edge, visual_cfg.particle_key, edge_scale, 0.12, 14)
                  end
                end
              else
                play_particle_on_unit(env, target, visual_cfg.particle_key, 0.72, 0.12)
              end
            end
            if index % 4 == 3 then
              play_impact_burst(env, target, visual_cfg.particle_key, 0.90)
            end
            bond_damage_area(storm_center, storm_radius, tick_damage, '物理')
          end)
        end
        return true
      end
    elseif bond_name == '龙骑士' then
      local trigger_floor = has_card_effect(runtime, '致命一击')
        and rule_number(basic_rule.trigger_floor_with_crit_card, 0.15)
        or rule_number(basic_rule.trigger_floor_default, 0.08)
      local dragon_triggered = trigger_dragon_fireball_effect(env, runtime, target, effect_state, trigger_floor, 1.00, 1.00)
      if dragon_triggered then
        report_cast(1)
      end
      return dragon_triggered
    elseif bond_name == '战斗法师' then
      local trigger_chance = rule_number(basic_rule.chance, 0.08)
      if try_chance(trigger_chance) then
        report_cast(1)
        play_bond_sound(env, '战斗法师', 'cast', get_hero(env))
        local impact_point = get_unit_point_snapshot(target)
        local aoe_radius = math.max(80, rule_number(basic_rule.aoe_radius, tonumber(visual_cfg and visual_cfg.area_fx_base_radius) or 320))
        perform_visual_delivery(env, target, visual_cfg, function()
          local impact_anchor = impact_point or target
          local impact_target = pick_impact_unit(env, impact_point, target)
          if impact_target then
            play_bond_sound(env, '战斗法师', 'impact', impact_target)
            play_particle_on_unit(env, impact_target, visual_cfg.particle_key, 1.0, 0.25)
          end
          bond_damage_area(
            impact_anchor,
            aoe_radius,
            attack * rule_number(basic_rule.damage_attack_ratio, 3.0),
            basic_rule.damage_type or '法术'
          )
        end)
        return true
      end
    elseif bond_name == '魔剑士' then
      local now = get_game_time(env)
      if (effect_state.demon_until or 0) > now then
        report_cast(1)
        play_bond_sound(env, '魔剑士', 'cast', get_hero(env))
        local impact_point = get_unit_point_snapshot(target)
        perform_visual_delivery(env, target, visual_cfg, function()
          local impact_target = pick_impact_unit(env, impact_point, target)
          if not impact_target then
            return
          end
          play_bond_sound(env, '魔剑士', 'impact', impact_target)
          play_particle_on_unit(env, impact_target, visual_cfg.particle_key, 0.8, 0.20)
          local amount = attack * rule_number(basic_rule.demon_damage_attack_ratio, 2.0)
          bond_damage_target(impact_target, amount, '法术')
          if is_line_motion then
            bond_damage_area(impact_target, line_aoe_radius, amount * math.max(0.35, line_aoe_ratio - 0.10), '法术', impact_target)
          end
        end)
        return true
      end
    elseif bond_name == '刀锋战士' or bond_name == '全能骑士' then
      -- 纯属性型羁绊：激活后仅提供静态属性加成，不触发额外攻击特效。
      return false
    end

    return false
  end

  function api.trigger_modifier_periodic_effect(env, runtime, bond_name, effect_state, dt)
    bond_name = normalize_bond_name(bond_name)
    local function report_cast(count)
      if env and env.report_auto_acceptance_event then
        env.report_auto_acceptance_event({
          scope = 'bond',
          key = bond_name,
          cast = tonumber(count) or 1,
        })
      end
    end
    local function bond_damage_target(unit, amount, damage_type)
      return damage_target(env, unit, amount, damage_type, { scope = 'bond', key = bond_name })
    end
    local function bond_damage_area(center, radius, amount, damage_type, except_unit, max_count)
      play_area_hit_fx(env, center, visual_cfg, radius, 0.24)
      return damage_area(env, center, radius, amount, damage_type, except_unit, max_count, { scope = 'bond', key = bond_name })
    end
    local periodic_rule = get_bond_periodic_rule(bond_name)
    if effect_state.__periodic_ready_on_gain ~= true then
      local first_interval = math.max(0.05, rule_number(periodic_rule.interval, 5.0))
      effect_state.elapsed = math.max(effect_state.elapsed or 0, first_interval)
      effect_state.__periodic_ready_on_gain = true
    end
    effect_state.elapsed = (effect_state.elapsed or 0) + (dt or 0)
    if (effect_state.cooldown or 0) > 0 then
      effect_state.cooldown = math.max(0, (effect_state.cooldown or 0) - (dt or 0))
    end
    local attack = get_attack_value(env)
    local visual_cfg = get_visual_config(bond_name)
    local now = get_game_time(env)

    local fire_interval = math.max(0.05, rule_number(periodic_rule.interval, 3.5))
    if bond_name == '火法师' and effect_state.elapsed >= fire_interval then
      report_cast(1)
      effect_state.elapsed = effect_state.elapsed - fire_interval
      local target = env.get_enemies_in_range and env.get_enemies_in_range(env.STATE.hero, 1200, nil, 1)[1] or nil
      local impact_point = get_unit_point_snapshot(target)
      if target then
        play_bond_sound(env, '火法师', 'cast', get_hero(env))
        perform_visual_delivery(env, target, visual_cfg, function()
          play_bond_sound(env, '火法师', 'impact', target)
          play_particle_on_unit(env, target, visual_cfg.particle_key, 1.25, 0.30)
          play_impact_burst(env, target, visual_cfg.particle_key, 1.35)
        end)
      end
      local main_damage = attack * rule_number(periodic_rule.damage_attack_ratio, 2.6)
      local splash_radius = math.max(80, rule_number(periodic_rule.splash_radius, 320))
      local splash_damage = attack * rule_number(periodic_rule.splash_damage_attack_ratio, 1.2)
      if target or impact_point then
        perform_visual_delivery(env, target, visual_cfg, function()
          local impact_anchor = impact_point or target
          local impact_target = pick_impact_unit(env, impact_point, target)
          if impact_target then
            bond_damage_target(impact_target, main_damage, periodic_rule.damage_type or '法术')
          end
          bond_damage_area(
            impact_anchor,
            splash_radius,
            splash_damage,
            periodic_rule.damage_type or '法术',
            impact_target,
            rule_optional_max_targets(periodic_rule.splash_max_targets)
          )
        end)
        return true
      end
      return false
    else
      local ice_interval = math.max(0.05, rule_number(periodic_rule.interval, 5))
      if bond_name == '冰霜法师' and effect_state.elapsed >= ice_interval then
      report_cast(1)
      effect_state.elapsed = effect_state.elapsed - ice_interval
      local target = env.get_enemies_in_range and env.get_enemies_in_range(env.STATE.hero, 1200, nil, 1)[1] or nil
      if target then
        play_bond_sound(env, bond_name, 'cast', get_hero(env))
        perform_visual_delivery(env, target, visual_cfg, function() end)
        local storm_point = nil
        if target.get_point then
          local ok, point = pcall(function()
            return target:get_point()
          end)
          if ok and point then
            storm_point = point
          end
        end
        local storm_center = storm_point or target
        local tick_damage = attack * rule_number(periodic_rule.tick_damage_attack_ratio, 0.20)
          + get_max_hp_value(env) * rule_number(periodic_rule.tick_damage_max_hp_ratio, 0.01)
        local storm_radius = math.max(80, rule_number(periodic_rule.storm_radius, 420))
        local tick_count = math.max(1, rule_integer(periodic_rule.tick_count, 6, 1))
        local tick_interval = math.max(0.05, rule_number(periodic_rule.tick_interval, 0.5))
        local storm_scale = calc_area_fx_scale(storm_radius, visual_cfg)
        if play_particle_on_point and storm_point then
          play_particle_on_point(env, storm_point, visual_cfg.particle_key, storm_scale, tick_count * tick_interval + 0.40, 16)
        else
          play_particle_on_unit(env, target, visual_cfg.particle_key, storm_scale, 0.30)
        end
        local fx_pulse_every = math.max(0, rule_integer(periodic_rule.fx_pulse_every, rule_integer(presentation_defaults.default_fx_pulse_every, 0, 0), 0))
        for index = 0, tick_count - 1 do
          wait_seconds(env, index * tick_interval, function()
            if index % 2 == 0 then
              play_bond_sound(env, bond_name, 'impact', storm_center)
            end
            if fx_pulse_every > 0 and index > 0 and (index % fx_pulse_every == 0) then
              if play_particle_on_point and storm_point then
                play_particle_on_point(env, storm_point, visual_cfg.particle_key, storm_scale, 0.18, 16)
              else
                play_particle_on_unit(env, target, visual_cfg.particle_key, storm_scale, 0.14)
              end
            end
            bond_damage_area(storm_center, storm_radius, tick_damage, periodic_rule.damage_type or '法术')
          end)
        end
          return true
        end
      end
    end
    if bond_name == '猎人' and effect_state.elapsed >= math.max(0.05, rule_number(periodic_rule.interval, 30)) then
      local hunter_interval = math.max(0.05, rule_number(periodic_rule.interval, 30))
      effect_state.elapsed = effect_state.elapsed - hunter_interval
      local hero = env and env.STATE and env.STATE.hero
      return schedule_summon_lifecycle_fx(
        env,
        hero,
        visual_cfg,
        rule_number(periodic_rule.summon_duration, 23),
        periodic_rule.summon_kind or 'magic_deer'
      )
    elseif bond_name == '雷电法王' then
      -- 点名链/分叉雷击允许保留目标上限；割草型直线/大范围技能则不在这里裁剪。
      local lightning_interval = math.max(0.05, rule_number(periodic_rule.interval, 1.20))
      if effect_state.elapsed < lightning_interval then
        return false
      end
      local repeat_count = math.floor(effect_state.elapsed / lightning_interval)
      effect_state.elapsed = effect_state.elapsed - repeat_count * lightning_interval

      local target_count = rule_integer(periodic_rule.base_target_count, 2, 1)
      local bonus_pack = runtime and runtime.modifier_pool_active_runtime_bonuses and runtime.modifier_pool_active_runtime_bonuses['initial_bond_set_雷电法王'] or nil
      local runtime_bonus_key = periodic_rule.runtime_bonus_key or 'lightning_target_count'
      if bonus_pack and runtime_bonus_key and bonus_pack[runtime_bonus_key] then
        target_count = math.max(target_count, rule_integer(bonus_pack[runtime_bonus_key], 0, 0))
      end
      if has_card_effect(runtime, '雷元爆发') then
        target_count = math.max(target_count, rule_integer(periodic_rule.card_bonus_target_count, 6, 1))
      end
      target_count = math.max(
        rule_integer(periodic_rule.min_target_count, 1, 1),
        math.min(rule_integer(periodic_rule.max_target_count, 5, 1), target_count)
      )
      local damage_ratio = has_card_effect(runtime, '雷电天赋')
        and rule_number(periodic_rule.damage_ratio_with_talent, 0.90)
        or rule_number(periodic_rule.damage_ratio_default, 0.65)
      local bolts_per_cast = rule_integer(periodic_rule.bolts_per_tick, 2, 1)

      local cast_count = repeat_count * bolts_per_cast
      if cast_count > 0 then
        report_cast(cast_count)
      end
      local hit = false
      for _ = 1, cast_count do
        local hero = env and env.STATE and env.STATE.hero
        local targets = env.get_enemies_in_range and env.get_enemies_in_range(hero, rule_number(periodic_rule.range, 1200), nil, target_count) or {}
        for _, target in ipairs(targets) do
          if target and target.is_exist and target:is_exist() then
            play_bond_sound(env, '雷电法王', 'cast', get_hero(env))
            play_lightning_strike(env, target, visual_cfg)
            play_bond_sound(env, '雷电法王', 'impact', target)
            hit = bond_damage_target(target, attack * damage_ratio, '法术') or hit
          end
        end
      end
      return hit
    elseif bond_name == '骷髅法师' and effect_state.elapsed >= math.max(0.05, rule_number(periodic_rule.interval, 30)) then
      local skeleton_interval = math.max(0.05, rule_number(periodic_rule.interval, 30))
      local repeat_count = math.floor(effect_state.elapsed / skeleton_interval)
      effect_state.elapsed = effect_state.elapsed - repeat_count * skeleton_interval
      for _ = 1, repeat_count do
        local hero = env and env.STATE and env.STATE.hero
        schedule_summon_lifecycle_fx(
          env,
          hero,
          visual_cfg,
          rule_number(periodic_rule.summon_duration, 25),
          periodic_rule.summon_kind or 'skeleton'
        )
      end
      return true
    elseif bond_name == '魔剑士' then
      local demon_active = (effect_state.demon_until or 0) > now
      update_magic_swordsman_runtime_bonus(runtime, demon_active)
      if sync_runtime_status_effect then
        sync_runtime_status_effect(env, runtime, 'magic_swordsman_demon', demon_active)
      end
    elseif bond_name == '刀锋战士' or bond_name == '全能骑士' or bond_name == '神射手'
      or bond_name == '游侠' or bond_name == '枪炮师' or bond_name == '狂战士'
      or bond_name == '剑魂' or bond_name == '剑宗' or bond_name == '龙骑士'
      or bond_name == '战斗法师' then
      -- 非周期羁绊：由普攻触发逻辑驱动。
      return false
    end
    return false
  end

  return api
end

return M

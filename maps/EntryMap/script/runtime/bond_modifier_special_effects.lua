local M = {}

function M.create(deps)
  deps = deps or {}

  local has_card_effect = deps.has_card_effect
  local has_any_card_effect = deps.has_any_card_effect
  local ensure_card_effect_state = deps.ensure_card_effect_state
  local add_hero_attr = deps.add_hero_attr
  local get_hero = deps.get_hero
  local get_hero_attr = deps.get_hero_attr
  local get_attack_value = deps.get_attack_value
  local get_max_hp_value = deps.get_max_hp_value
  local get_game_time = deps.get_game_time
  local get_visual_config = deps.get_visual_config
  local play_particle_on_unit = deps.play_particle_on_unit
  local play_particle_on_point = deps.play_particle_on_point
  local play_lightning_strike = deps.play_lightning_strike
  local launch_projectile_to_target = deps.launch_projectile_to_target
  local wait_seconds = deps.wait_seconds
  local damage_target = deps.damage_target
  local damage_area = deps.damage_area
  local try_chance = deps.try_chance
  local push_stack_expire = deps.push_stack_expire
  local cleanup_stack_expire = deps.cleanup_stack_expire
  local update_card_stack_attr = deps.update_card_stack_attr
  local schedule_summon_lifecycle_fx = deps.schedule_summon_lifecycle_fx
  local update_magic_swordsman_runtime_bonus = deps.update_magic_swordsman_runtime_bonus
  local sync_runtime_status_effect = deps.sync_runtime_status_effect
  local has_active_modifier_bond = deps.has_active_modifier_bond
  local runtime_rules = deps.runtime_rules or {}
  local card_basic_rules = runtime_rules.card_basic_attack or {}
  local card_periodic_rules = runtime_rules.card_periodic or {}
  local card_kill_rules = runtime_rules.card_kill or {}
  local card_arrow_rain_rule = runtime_rules.card_arrow_rain or {}
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

  local function get_card_basic_rule(card_name)
    return type(card_basic_rules[card_name]) == 'table' and card_basic_rules[card_name] or {}
  end

  local function get_card_periodic_rule(card_name)
    return type(card_periodic_rules[card_name]) == 'table' and card_periodic_rules[card_name] or {}
  end

  local function calc_area_fx_scale(radius, visual_cfg)
    local base_radius = math.max(80, tonumber(visual_cfg and visual_cfg.area_fx_base_radius) or 320)
    local bias = tonumber(visual_cfg and visual_cfg.area_fx_scale_bias) or 1.0
    local min_scale = tonumber(visual_cfg and visual_cfg.area_fx_min_scale) or 0.65
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

  local function deal_area_damage(env, center, radius, amount, damage_type, visual_cfg)
    play_area_hit_fx(env, center, visual_cfg, radius, 0.24)
    return damage_area(env, center, radius, amount, damage_type)
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

  local function schedule_wait(env, delay, callback)
    if wait_seconds then
      wait_seconds(env, delay, callback)
      return
    end
    if callback then
      callback()
    end
  end

  local function perform_visual_delivery(env, target, visual_cfg, on_impact)
    local mode = tostring(visual_cfg and visual_cfg.delivery_mode or 'projectile')
    if mode == 'projectile' then
      launch_projectile_to_target(env, target, visual_cfg)
      local delay = math.max(0.0, rule_number(visual_cfg and visual_cfg.projectile_time, 0))
      schedule_wait(env, delay, on_impact)
      return
    end
    local warmup = mode == 'persistent_area'
      and rule_number(presentation_defaults.persistent_area_warmup, 0.10)
      or rule_number(presentation_defaults.instant_warmup, 0.05)
    schedule_wait(env, warmup, on_impact)
  end

  local function trigger_ranger_arrow_rain(env, target, visual_cfg, attack, rain_rule)
    if not target then
      return false
    end
    rain_rule = type(rain_rule) == 'table' and rain_rule or {}
    local storm_point = get_unit_point_snapshot(target)
    local storm_center = storm_point or target
    local storm_radius = math.max(80, rule_number(rain_rule.radius, rule_number(card_arrow_rain_rule.radius, 360)))
    local tick_damage = attack * rule_number(rain_rule.tick_damage_attack_ratio, rule_number(card_arrow_rain_rule.tick_damage_attack_ratio, 0.80))
    local tick_count = math.max(1, rule_integer(rain_rule.tick_count, rule_integer(card_arrow_rain_rule.tick_count, 3, 1), 1))
    local tick_interval = math.max(0.05, rule_number(rain_rule.tick_interval, rule_number(card_arrow_rain_rule.tick_interval, 1.00)))
    local storm_scale = calc_area_fx_scale(storm_radius, visual_cfg)

    if play_particle_on_point and storm_point then
      play_particle_on_point(env, storm_point, visual_cfg.particle_key, storm_scale, tick_count * tick_interval + 0.25, 16)
    else
      play_particle_on_unit(env, target, visual_cfg.particle_key, storm_scale, 0.30)
    end

    local fx_pulse_every = math.max(
      0,
      rule_integer(
        rain_rule.fx_pulse_every,
        rule_integer(card_arrow_rain_rule.fx_pulse_every, rule_integer(presentation_defaults.default_fx_pulse_every, 0, 0), 0),
        0
      )
    )
    for index = 0, tick_count - 1 do
      schedule_wait(env, index * tick_interval, function()
        if fx_pulse_every > 0 and index > 0 and (index % fx_pulse_every == 0) then
          if play_particle_on_point and storm_point then
            play_particle_on_point(env, storm_point, visual_cfg.particle_key, storm_scale, 0.18, 16)
          else
            play_particle_on_unit(env, target, visual_cfg.particle_key, storm_scale, 0.14)
          end
        end
        deal_area_damage(env, storm_center, storm_radius, tick_damage, '物理', visual_cfg)
      end)
    end
    return true
  end

  function api.trigger_modifier_card_basic_attack_effects(env, runtime, target)
    if not runtime or not target then
      return false
    end

    local attack = get_attack_value(env)
    local attack_speed = get_hero_attr(env, '攻击速度')
    local max_hp = get_max_hp_value(env)
    local triggered = false
    local now = get_game_time(env)

    local bbq_rule = get_card_basic_rule('BBQ')
    if has_card_effect(runtime, 'BBQ') and try_chance(rule_number(bbq_rule.chance, 0.08)) then
      local visual_cfg = get_visual_config(bbq_rule.visual_bond or '枪炮师')
      local burst_center = get_unit_point_snapshot(target) or target
      perform_visual_delivery(env, target, visual_cfg, function()
        if burst_center == target then
          play_particle_on_unit(env, target, visual_cfg.particle_key, 1.05, 0.28)
        elseif play_particle_on_point then
          play_particle_on_point(env, burst_center, visual_cfg.particle_key, 1.05, 0.28, 16)
        else
          play_particle_on_unit(env, target, visual_cfg.particle_key, 1.05, 0.28)
        end
        deal_area_damage(
          env,
          burst_center,
          math.max(80, rule_number(bbq_rule.aoe_radius, 320)),
          attack * rule_number(bbq_rule.damage_attack_ratio, 3.0),
          bbq_rule.damage_type or '物理',
          visual_cfg
        )
      end)
      triggered = true
    end

    local sharpshoot_rule = get_card_basic_rule('穿云箭')
    if (has_card_effect(runtime, '穿云箭') or has_card_effect(runtime, '穿甲射击'))
      and try_chance(rule_number(sharpshoot_rule.chance, 0.08)) then
      local visual_cfg = get_visual_config(sharpshoot_rule.visual_bond or '神射手')
      perform_visual_delivery(env, target, visual_cfg, function()
        play_particle_on_unit(env, target, visual_cfg.particle_key, 0.9, 0.20)
        damage_target(
          env,
          target,
          attack * rule_number(sharpshoot_rule.damage_attack_ratio, 1.2)
            + attack_speed * rule_number(sharpshoot_rule.damage_attack_speed_ratio, 0.5),
          sharpshoot_rule.damage_type or '物理'
        )
      end)
      triggered = true
    end

    local leech_rule = get_card_basic_rule('嗜血')
    if has_card_effect(runtime, '嗜血') and env.heal_hero then
      env.heal_hero(max_hp * rule_number(leech_rule.heal_max_hp_ratio, 0.01))
      triggered = true
    end

    local spike_rule = get_card_basic_rule('毒蛇钉刺')
    if has_card_effect(runtime, '毒蛇钉刺') and try_chance(rule_number(spike_rule.chance, 0.08)) then
      local hero = env and env.STATE and env.STATE.hero
      if hero and hero.is_exist and hero:is_exist() then
        local visual_cfg = get_visual_config(spike_rule.visual_bond or '游侠')
        play_particle_on_unit(env, hero, visual_cfg.particle_key, 1.0, 0.20)
        deal_area_damage(
          env,
          hero,
          math.max(80, rule_number(spike_rule.aoe_radius, 320)),
          attack * rule_number(spike_rule.damage_attack_ratio, 2.0),
          spike_rule.damage_type or '物理',
          visual_cfg
        )
        triggered = true
      end
    end

    if has_any_card_effect(runtime, { '毒箭雨', '敏锐', '坚韧', '毒前雨' }) then
      local rain_rule = has_card_effect(runtime, '毒前雨') and get_card_basic_rule('毒前雨') or get_card_basic_rule('毒箭雨')
      local chance = rule_number(rain_rule.chance, has_card_effect(runtime, '毒前雨') and 0.09 or 0.08)
      if try_chance(chance) then
        local visual_cfg = get_visual_config(rain_rule.visual_bond or '游侠')
        triggered = trigger_ranger_arrow_rain(env, target, visual_cfg, attack, rain_rule) or triggered
      end
    end

    if has_card_effect(runtime, '疾风弓') then
      local gale_rule = get_card_basic_rule('疾风弓')
      local state = ensure_card_effect_state(runtime, '疾风弓')
      if state then
        push_stack_expire(state, now + rule_number(gale_rule.stack_duration, 5))
        cleanup_stack_expire(state, now, rule_integer(gale_rule.max_stacks, 10, 1))
        update_card_stack_attr(
          env,
          state,
          rule_number(gale_rule.attack_per_stack, 0),
          rule_number(gale_rule.attack_speed_per_stack, 5)
        )
        triggered = true
      end
    end

    local sword_dance_rule = get_card_basic_rule('幻影剑舞')
    if has_card_effect(runtime, '幻影剑舞') and try_chance(rule_number(sword_dance_rule.chance, 0.30)) then
      local state = ensure_card_effect_state(runtime, '幻影剑舞')
      if state then
        push_stack_expire(state, now + rule_number(sword_dance_rule.stack_duration, 5))
        cleanup_stack_expire(state, now, rule_integer(sword_dance_rule.max_stacks, 10, 1))
        update_card_stack_attr(
          env,
          state,
          rule_number(sword_dance_rule.attack_per_stack, 20),
          rule_number(sword_dance_rule.attack_speed_per_stack, 2)
        )
        triggered = true
      end
    end

    if has_card_effect(runtime, '斩击') or has_card_effect(runtime, '剑魂') then
      local slash_rule = get_card_basic_rule('斩击')
      local state = ensure_card_effect_state(runtime, '斩击')
      if state then
        state.counter = (state.counter or 0) + 1
        if state.counter >= rule_integer(slash_rule.hit_count_trigger, 10, 1) then
          state.counter = 0
          local visual_cfg = get_visual_config(slash_rule.visual_bond or '剑魂')
          local impact_point = get_unit_point_snapshot(target)
          perform_visual_delivery(env, target, visual_cfg, function()
            local impact_target = pick_impact_unit(env, impact_point, target)
            if not impact_target then
              return
            end
            play_particle_on_unit(env, impact_target, visual_cfg.particle_key, 0.9, 0.20)
            damage_target(env, impact_target, attack * rule_number(slash_rule.damage_attack_ratio, 1.5), slash_rule.damage_type or '物理')
          end)
          triggered = true
        end
      end
    end

    local berserk_card_rule = get_card_basic_rule('狂刀斩')
    if has_any_card_effect(runtime, { '狂刀斩', '重甲精通', '力量唤醒' })
      and try_chance(rule_number(berserk_card_rule.chance, 0.30)) then
      local current_hp = target.get_hp and (tonumber(target:get_hp()) or 0) or 0
      local target_max_hp = target.get_attr and (tonumber(target:get_attr('生命')) or tonumber(target:get_attr('最大生命')) or current_hp) or current_hp
      local visual_cfg = get_visual_config(berserk_card_rule.visual_bond or '狂战士')
      local impact_point = get_unit_point_snapshot(target)
      local amount = attack * rule_number(berserk_card_rule.damage_attack_ratio, 0.10)
        + math.max(0, target_max_hp - current_hp) * rule_number(berserk_card_rule.damage_missing_hp_ratio, 0.05)
      perform_visual_delivery(env, target, visual_cfg, function()
        local impact_target = pick_impact_unit(env, impact_point, target)
        if not impact_target then
          return
        end
        play_particle_on_unit(env, impact_target, visual_cfg.particle_key, 1.0, 0.20)
        damage_target(env, impact_target, amount, berserk_card_rule.damage_type or '物理')
      end)
      triggered = true
    end

    return triggered
  end

  function api.trigger_modifier_card_periodic_effects(env, runtime, dt)
    if not runtime then
      return false
    end

    local triggered = false
    if runtime.modifier_card_effect_state then
      for _, state in pairs(runtime.modifier_card_effect_state) do
        if type(state) == 'table' and (state.cooldown or 0) > 0 then
          state.cooldown = math.max(0, (state.cooldown or 0) - (dt or 0))
        end
      end
    end
    if runtime.modifier_card_effect_custom_state then
      for _, state in pairs(runtime.modifier_card_effect_custom_state) do
        if type(state) == 'table' and (state.cooldown or 0) > 0 then
          state.cooldown = math.max(0, (state.cooldown or 0) - (dt or 0))
        end
      end
    end
    local attack = get_attack_value(env)
    local max_hp = get_max_hp_value(env)
    local now = get_game_time(env)

    if has_card_effect(runtime, '连射') then
      local rapid_rule = get_card_periodic_rule('连射')
      local state = ensure_card_effect_state(runtime, '连射')
      if state then
        local target_multishot = rule_integer(rapid_rule.multishot, 1, 0)
        local applied_multishot = state.applied_multishot or 0
        local delta = target_multishot - applied_multishot
        if delta ~= 0 then
          add_hero_attr(env, '多重数量', delta)
          state.applied_multishot = target_multishot
        end
      end
    end

    if has_card_effect(runtime, '火焰炉盾') then
      local furnace_rule = get_card_periodic_rule('火焰炉盾')
      local state = ensure_card_effect_state(runtime, '火焰炉盾')
      if state then
        state.elapsed = (state.elapsed or 0) + (dt or 0)
        local interval = math.max(0.05, rule_number(furnace_rule.interval, 10))
        if state.elapsed >= interval then
          state.elapsed = state.elapsed - interval
          if env.heal_hero then
            env.heal_hero(max_hp * rule_number(furnace_rule.heal_max_hp_ratio, 0.20))
          end
          play_particle_on_unit(env, env and env.STATE and env.STATE.hero, get_visual_config(furnace_rule.visual_bond or '火法师').particle_key, 1.0, 0.25)
          triggered = true
        end
      end
    end

    if has_card_effect(runtime, '引雷咒') then
      local lightning_rule = get_card_periodic_rule('引雷咒')
      local state = ensure_card_effect_state(runtime, '引雷咒')
      if state then
        local lightning_interval = math.max(0.05, rule_number(lightning_rule.interval, 1.20))
        state.elapsed = (state.elapsed or 0) + (dt or 0)
        while state.elapsed >= lightning_interval do
          state.elapsed = state.elapsed - lightning_interval
          local hero = env and env.STATE and env.STATE.hero
          local target_count = has_card_effect(runtime, '雷元爆发')
            and rule_integer(lightning_rule.bonus_target_count, 5, 1)
            or rule_integer(lightning_rule.base_target_count, 2, 1)
          local damage_ratio = has_card_effect(runtime, '雷电天赋')
            and rule_number(lightning_rule.damage_ratio_with_talent, 0.90)
            or rule_number(lightning_rule.damage_ratio_default, 0.65)
          local targets = env.get_enemies_in_range and env.get_enemies_in_range(hero, rule_number(lightning_rule.range, 1200), nil, target_count) or {}
          for _, target in ipairs(targets) do
            play_lightning_strike(env, target, get_visual_config(lightning_rule.visual_bond or '雷电法王'))
            damage_target(env, target, attack * damage_ratio, '法术')
            triggered = true
          end
        end
      end
    end

    local function update_hunter_summon_card(card_name)
      local state = ensure_card_effect_state(runtime, card_name)
      if not state then
        return
      end
      local rule = get_card_periodic_rule(card_name)
      state.elapsed = (state.elapsed or 0) + (dt or 0)
      local interval = math.max(0.05, rule_number(rule.interval, 30))
      while state.elapsed >= interval do
        state.elapsed = state.elapsed - interval
        local hero = get_hero(env)
        local summon_kind = rule.summon_kind or 'magic_bear'
        schedule_summon_lifecycle_fx(
          env,
          hero,
          get_visual_config(rule.visual_bond or '猎人'),
          rule_number(rule.summon_duration, 25),
          summon_kind
        )
        triggered = true
      end
    end
    if has_card_effect(runtime, '自然之体') then
      update_hunter_summon_card('自然之体')
    end
    if has_card_effect(runtime, '猎人') then
      update_hunter_summon_card('猎人')
    end
    if has_card_effect(runtime, '奔袭') then
      update_hunter_summon_card('奔袭')
    end
    if has_card_effect(runtime, '召唤猎鹰') then
      update_hunter_summon_card('召唤猎鹰')
    end

    local function update_skeleton_card(card_name)
      local state = ensure_card_effect_state(runtime, card_name)
      if not state then
        return
      end
      local rule = get_card_periodic_rule(card_name)
      state.elapsed = (state.elapsed or 0) + (dt or 0)
      local interval = math.max(0.05, rule_number(rule.interval, 30))
      while state.elapsed >= interval do
        state.elapsed = state.elapsed - interval
        local hero = get_hero(env)
        schedule_summon_lifecycle_fx(
          env,
          hero,
          get_visual_config(rule.visual_bond or '骷髅法师'),
          rule_number(rule.summon_duration, 25),
          rule.summon_kind or 'skeleton'
        )
        triggered = true
      end
    end
    if has_card_effect(runtime, '骷髅复苏') then
      update_skeleton_card('骷髅复苏')
    end
    if has_card_effect(runtime, '骷髅支配') then
      update_skeleton_card('骷髅支配')
    end
    if has_card_effect(runtime, '骷髅恐惧') then
      update_skeleton_card('骷髅恐惧')
    end
    if has_card_effect(runtime, '骷髅压制') then
      update_skeleton_card('骷髅压制')
    end
    if has_card_effect(runtime, '骷髅审判') then
      update_skeleton_card('骷髅审判')
    end

    if has_card_effect(runtime, '疾风弓') then
      local gale_rule = get_card_basic_rule('疾风弓')
      local state = ensure_card_effect_state(runtime, '疾风弓')
      if state then
        cleanup_stack_expire(state, now, rule_integer(gale_rule.max_stacks, 10, 1))
        update_card_stack_attr(
          env,
          state,
          rule_number(gale_rule.attack_per_stack, 0),
          rule_number(gale_rule.attack_speed_per_stack, 5)
        )
      end
    end
    if has_card_effect(runtime, '幻影剑舞') then
      local sword_dance_rule = get_card_basic_rule('幻影剑舞')
      local state = ensure_card_effect_state(runtime, '幻影剑舞')
      if state then
        cleanup_stack_expire(state, now, rule_integer(sword_dance_rule.max_stacks, 10, 1))
        update_card_stack_attr(
          env,
          state,
          rule_number(sword_dance_rule.attack_per_stack, 20),
          rule_number(sword_dance_rule.attack_speed_per_stack, 2)
        )
      end
    end

    if has_card_effect(runtime, '狂化') then
      local frenzy_rule = get_card_periodic_rule('狂化')
      local state = ensure_card_effect_state(runtime, '狂化')
      if state then
        state.elapsed = (state.elapsed or 0) + (dt or 0)
        local cycle_interval = math.max(0.05, rule_number(frenzy_rule.cycle_interval, 2))
        if state.elapsed >= cycle_interval then
          state.elapsed = state.elapsed - cycle_interval
          state.frenzy_until = now + rule_number(frenzy_rule.frenzy_duration, 5)
        end
        local frenzy_active = (state.frenzy_until or 0) > now
        local target_bonus = frenzy_active and rule_number(frenzy_rule.all_damage_bonus, 1.0) or 0.0
        local applied_bonus = state.applied_all_damage_bonus or 0.0
        if target_bonus ~= applied_bonus then
          local effect_id = '__card_runtime_狂化'
          runtime.modifier_pool_active_runtime_bonuses = runtime.modifier_pool_active_runtime_bonuses or {}
          runtime.modifier_pool_active_runtime_bonuses[effect_id] = runtime.modifier_pool_active_runtime_bonuses[effect_id] or {}
          runtime.modifier_pool_active_runtime_bonuses[effect_id].all_damage_bonus = target_bonus > 0 and target_bonus or nil
          state.applied_all_damage_bonus = target_bonus
        end
        if sync_runtime_status_effect then
          sync_runtime_status_effect(env, runtime, 'berserker_frenzy', frenzy_active)
        end
      end
    elseif sync_runtime_status_effect then
      sync_runtime_status_effect(env, runtime, 'berserker_frenzy', false)
    end

    return triggered
  end

  function api.handle_modifier_card_pre_hurt(env, runtime, data)
    if not runtime or type(data) ~= 'table' then
      return false
    end
    if not has_card_effect(runtime, '狂化') then
      return false
    end

    local state = ensure_card_effect_state(runtime, '狂化')
    if not state then
      return false
    end
    if (state.frenzy_until or 0) <= get_game_time(env) then
      return false
    end

    local damage_instance = data.damage_instance
    if not damage_instance or not damage_instance.get_damage or not damage_instance.set_damage then
      return false
    end

    local current_damage = tonumber(damage_instance:get_damage()) or tonumber(data.damage) or 0
    if current_damage <= 0 then
      return false
    end

    damage_instance:set_damage(current_damage * 2)
    return true
  end

  function api.handle_modifier_enemy_kill(env, runtime, info, get_cards_by_bond)
    if not runtime then
      return false
    end

    local triggered = false
    for _, effect_state in pairs(runtime.modifier_pool_effect_state or {}) do
      local bond_name = effect_state and effect_state.bond_name
      if bond_name and has_active_modifier_bond(runtime, bond_name, get_cards_by_bond) then
        if bond_name == '魔剑士' then
          local effect_id = 'initial_bond_set_魔剑士'
          local can_enter_demon = has_card_effect(runtime, '入魔')
            or (runtime.modifier_pool_active_effects and runtime.modifier_pool_active_effects[effect_id] == true)
          if can_enter_demon then
            local demon_rule = card_kill_rules['入魔'] or {}
            effect_state.kill_counter = (effect_state.kill_counter or 0) + 1
            if effect_state.kill_counter >= rule_integer(demon_rule.kill_threshold, 5, 1) then
              effect_state.kill_counter = 0
              if try_chance(rule_number(demon_rule.trigger_chance, 0.30)) then
                effect_state.demon_until = get_game_time(env) + rule_number(demon_rule.demon_duration, 5)
                update_magic_swordsman_runtime_bonus(runtime, true)
                play_particle_on_unit(
                  env,
                  env and env.STATE and env.STATE.hero,
                  get_visual_config(demon_rule.visual_bond or '魔剑士').particle_key,
                  1.0,
                  0.30
                )
                triggered = true
              end
            end
          end
        elseif bond_name == '骷髅法师' then
          local _ = info
        end
      end
    end

    if has_card_effect(runtime, '中华傲决') then
      local pride_rule = card_kill_rules['中华傲决'] or {}
      local state = ensure_card_effect_state(runtime, '中华傲决')
      if state then
        state.counter = (state.counter or 0) + 1
        local threshold = rule_integer(pride_rule.kill_threshold, 100, 1)
        if state.counter >= threshold then
          state.counter = state.counter - threshold
          add_hero_attr(env, '剑意', rule_number(pride_rule.sword_intent_gain, 1))
          play_particle_on_unit(
            env,
            env and env.STATE and env.STATE.hero,
            get_visual_config(pride_rule.visual_bond or '剑宗').particle_key,
            1.0,
            0.25
          )
          triggered = true
        end
      end
    end

    return triggered
  end

  return api
end

return M

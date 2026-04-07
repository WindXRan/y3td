local EffectObjects = require 'entry_objects.auto_active_effects'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local ATTACK_SKILL_VFX = env.ATTACK_SKILL_VFX
  local get_player = env.get_player
  local is_bond_active = env.is_bond_active
  local is_active_enemy = env.is_active_enemy
  local get_enemies_in_range = env.get_enemies_in_range
  local deal_skill_damage = env.deal_skill_damage
  local heal_hero = env.heal_hero

  local EFFECT_LIST = EffectObjects.list

  local function get_runtime()
    if not STATE.auto_active_effects then
      STATE.auto_active_effects = {
        cooldowns = {},
        counters = {},
      }
    end
    return STATE.auto_active_effects
  end

  local function get_effect_cooldown(effect_id)
    return get_runtime().cooldowns[effect_id] or 0
  end

  local function set_effect_cooldown(effect_id, cooldown)
    get_runtime().cooldowns[effect_id] = math.max(0, cooldown or 0)
  end

  local function add_effect_counter(effect_id, delta)
    local runtime = get_runtime()
    runtime.counters[effect_id] = (runtime.counters[effect_id] or 0) + (delta or 0)
    return runtime.counters[effect_id]
  end

  local function reset_effect_counter(effect_id)
    get_runtime().counters[effect_id] = 0
  end

  local function is_source_active(def)
    if def.source_type == 'bond' then
      return is_bond_active(def.source_id)
    end
    if def.source_type == 'treasure' then
      return STATE.treasure_runtime
        and STATE.treasure_runtime.active_by_id
        and STATE.treasure_runtime.active_by_id[def.source_id] ~= nil
        or false
    end
    if def.source_type == 'mark' then
      return STATE.mark_runtime
        and STATE.mark_runtime.owned_mark_ids
        and STATE.mark_runtime.owned_mark_ids[def.source_id] == true
        or false
    end
    return false
  end

  local function get_attack_damage_base()
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    return math.max(1, y3.helper.tonumber(STATE.hero:get_attr('物理攻击')) or 0)
  end

  local function get_hero_max_hp()
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    return math.max(1, y3.helper.tonumber(STATE.hero:get_attr('最大生命')) or 0)
  end

  local function get_target_hp_ratio(target)
    if not target or not target:is_exist() then
      return 1
    end
    local max_hp = math.max(1, y3.helper.tonumber(target:get_attr('最大生命')) or 1)
    return math.max(0, target:get_hp() / max_hp)
  end

  local function play_particle_on_unit(unit, effect_key, scale, time, socket)
    if not effect_key or not unit or not unit:is_exist() then
      return nil
    end

    local ok, particle = pcall(y3.particle.create, {
      type = effect_key,
      target = unit,
      socket = socket or 'origin',
      scale = scale or 1.0,
      time = time or 0.30,
      immediate = true,
    })
    if ok then
      return particle
    end
    return nil
  end

  local function play_particle_on_point(point, effect_key, scale, time, height)
    if not effect_key or not point then
      return nil
    end

    local ok, particle = pcall(y3.particle.create, {
      type = effect_key,
      target = point,
      scale = scale or 1.0,
      time = time or 0.30,
      height = height or 0,
      immediate = true,
    })
    if ok then
      return particle
    end
    return nil
  end

  local function play_hero_cast_animation()
    if STATE.hero and STATE.hero:is_exist() then
      STATE.hero:play_animation('attack1', 1.0, nil, nil, false, true)
    end
  end

  local function launch_projectile_to_target(vfx, target, on_finish)
    if not vfx or not vfx.projectile_key or not target or not target:is_exist() then
      if on_finish then
        on_finish(target and target:is_exist() and target:get_point() or nil)
      end
      return false
    end

    local ok_create, projectile = pcall(y3.projectile.create, {
      key = vfx.projectile_key,
      target = STATE.hero,
      socket = 'origin',
      owner = STATE.hero,
      time = vfx.projectile_time or 3.0,
      remove_immediately = true,
    })
    if not ok_create or not projectile then
      if on_finish then
        on_finish(target:get_point())
      end
      return false
    end

    local resolved = false
    local function finish(final_point)
      if resolved then
        return
      end
      resolved = true
      if projectile and projectile:is_exist() then
        projectile:remove()
      end
      if on_finish then
        on_finish(final_point)
      end
    end

    local ok_move = pcall(function()
      projectile:mover_target({
        target = target,
        speed = vfx.projectile_speed or 1000,
        target_distance = vfx.target_distance or 60,
        on_finish = function()
          finish(target:get_point())
        end,
        on_break = function()
          finish(target:get_point())
        end,
      })
    end)

    if not ok_move then
      finish(target:get_point())
      return false
    end
    return true
  end

  local function pick_nearest_enemy(range, except_unit)
    if not STATE.hero or not STATE.hero:is_exist() then
      return nil
    end
    for _, unit in ipairs(get_enemies_in_range(STATE.hero, range or 900, except_unit, 10)) do
      if is_active_enemy(unit) then
        return unit
      end
    end
    return nil
  end

  local function pick_low_hp_enemy(range, hp_threshold)
    if not STATE.hero or not STATE.hero:is_exist() then
      return nil
    end

    local best_unit = nil
    local best_ratio = 2
    for _, unit in ipairs(get_enemies_in_range(STATE.hero, range or 900, nil, 16)) do
      if is_active_enemy(unit) then
        local hp_ratio = get_target_hp_ratio(unit)
        if hp_ratio <= (hp_threshold or 1) and hp_ratio < best_ratio then
          best_ratio = hp_ratio
          best_unit = unit
        end
      end
    end
    return best_unit
  end

  local function damage_enemies_in_radius(center, radius, amount, damage_type, particle)
    local hit_any = false
    for _, unit in ipairs(get_enemies_in_range(center, radius or 0, nil, 24)) do
      deal_skill_damage(unit, amount, damage_type, {
        text_type = damage_type == '物理' and 'physics' or 'magic',
        particle = particle,
      })
      hit_any = true
    end
    return hit_any
  end

  local function trigger_chain_pulse(def)
    local target = pick_nearest_enemy(def.range)
    if not target then
      return false
    end

    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local damage = get_attack_damage_base() * (def.primary_ratio or 1)
    play_hero_cast_animation()
    play_particle_on_point(target:get_point(), vfx and vfx.charge_particle or nil, vfx and vfx.charge_scale or 1, vfx and vfx.charge_time or 0.2, 160)
    y3.ltimer.wait(vfx and vfx.strike_delay or 0.12, function()
      if not STATE.hero or not STATE.hero:is_exist() then
        return
      end
      play_particle_on_point(target:get_point(), vfx and vfx.impact_particle or nil, vfx and vfx.impact_scale or 1, vfx and vfx.impact_time or 0.35, 0)
      if is_active_enemy(target) then
        deal_skill_damage(target, damage, '法术', {
          text_type = 'magic',
        })
      end
      local bounced = 0
      for _, unit in ipairs(get_enemies_in_range(target, def.chain_radius or 420, target, def.chain_bounces or 0)) do
        play_particle_on_point(unit:get_point(), vfx and vfx.chain_particle or nil, vfx and vfx.chain_scale or 1, vfx and vfx.chain_time or 0.25, 0)
        deal_skill_damage(unit, damage * (def.chain_ratio or 0.7), '法术', {
          text_type = 'magic',
        })
        bounced = bounced + 1
        if bounced >= (def.chain_bounces or 0) then
          break
        end
      end
    end)
    return true
  end

  local function trigger_frost_ring(def)
    if not STATE.hero or not STATE.hero:is_exist() then
      return false
    end

    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local damage = get_attack_damage_base() * (def.damage_ratio or 1)
    play_hero_cast_animation()
    play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.1, 0.35, 'origin')
    local hit_any = false
    for _, unit in ipairs(get_enemies_in_range(STATE.hero, def.radius or 260, nil, 18)) do
      play_particle_on_unit(unit, vfx and vfx.impact_particle or nil, 1.0, 0.30, 'origin')
      deal_skill_damage(unit, damage, '法术', {
        text_type = 'magic',
      })
      hit_any = true
    end
    return hit_any
  end

  local function trigger_ember_volley(def)
    if not STATE.hero or not STATE.hero:is_exist() then
      return false
    end

    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local targets = get_enemies_in_range(STATE.hero, def.range or 900, nil, def.volley_count or 3)
    if #targets == 0 then
      return false
    end

    local damage = get_attack_damage_base() * (def.damage_ratio or 1)
    play_hero_cast_animation()
    play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or nil, vfx and vfx.cast_scale or 1, vfx and vfx.cast_time or 0.2, 'origin')
    for _, target in ipairs(targets) do
      launch_projectile_to_target(vfx, target, function(impact_point)
        local center = impact_point or (target and target:is_exist() and target:get_point() or nil)
        if center and vfx and vfx.explosion_particle then
          play_particle_on_point(center, vfx.explosion_particle, vfx.explosion_scale, vfx.explosion_time, 10)
        elseif center and vfx and vfx.impact_particle then
          play_particle_on_point(center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 10)
        end
        if is_active_enemy(target) then
          deal_skill_damage(target, damage, '物理', {
            text_type = 'physics',
          })
        end
        if center and (def.splash_radius or 0) > 0 and (def.splash_ratio or 0) > 0 then
          damage_enemies_in_radius(center, def.splash_radius, damage * def.splash_ratio, '物理')
        end
      end)
    end
    return true
  end

  local function trigger_guardian_pulse(def)
    if not STATE.hero or not STATE.hero:is_exist() then
      return false
    end
    local vfx = ATTACK_SKILL_VFX[def.vfx]
    play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.15, 0.40, 'origin')
    heal_hero(get_hero_max_hp() * (def.heal_ratio or 0.08))
    return true
  end

  local function trigger_harvest_blade(def)
    local target = pick_nearest_enemy(def.range)
    if not target then
      return false
    end

    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local damage = get_attack_damage_base() * (def.damage_ratio or 1)
    launch_projectile_to_target(vfx, target, function(impact_point)
      if impact_point and vfx and vfx.impact_particle then
        play_particle_on_point(impact_point, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 18)
      end
      if is_active_enemy(target) then
        deal_skill_damage(target, damage, '法术', {
          text_type = 'magic',
        })
      end
    end)
    return true
  end

  local function trigger_coin_burst(def)
    local target = pick_low_hp_enemy(def.range, def.hp_threshold) or pick_nearest_enemy(def.range)
    if not target then
      return false
    end

    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local center = target:get_point()
    local damage = get_attack_damage_base() * (def.damage_ratio or 1)
    play_particle_on_point(center, vfx and vfx.explosion_particle or vfx and vfx.impact_particle or nil, 1.1, 0.40, 12)
    damage_enemies_in_radius(center, def.radius or 220, damage, '物理')
    return true
  end

  local function trigger_bloodrage_stomp(def)
    if not STATE.hero or not STATE.hero:is_exist() then
      return false
    end
    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local damage = get_attack_damage_base() * (def.damage_ratio or 1)
    play_hero_cast_animation()
    play_particle_on_unit(STATE.hero, vfx and vfx.impact_particle or nil, 1.25, 0.35, 'origin')
    return damage_enemies_in_radius(STATE.hero, def.radius or 300, damage, '物理')
  end

  local function trigger_starfire_echo(def, target)
    local resolved_target = target
    if not is_active_enemy(resolved_target) then
      resolved_target = pick_nearest_enemy(def.range)
    end
    if not resolved_target then
      return false
    end

    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local damage = get_attack_damage_base() * (def.damage_ratio or 1)
    launch_projectile_to_target(vfx, resolved_target, function(impact_point)
      if impact_point and vfx and vfx.impact_particle then
        play_particle_on_point(impact_point, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 18)
      end
      if is_active_enemy(resolved_target) then
        deal_skill_damage(resolved_target, damage, '法术', {
          text_type = 'magic',
        })
      end
    end)
    return true
  end

  local function try_trigger_effect(def, context)
    if not def or not is_source_active(def) or get_effect_cooldown(def.id) > 0 then
      return false
    end

    local triggered = false
    if def.id == 'chain_pulse' then
      triggered = trigger_chain_pulse(def)
    elseif def.id == 'frost_ring' then
      triggered = trigger_frost_ring(def)
    elseif def.id == 'ember_volley' then
      triggered = trigger_ember_volley(def)
    elseif def.id == 'guardian_pulse' then
      triggered = trigger_guardian_pulse(def)
    elseif def.id == 'harvest_blade' then
      triggered = trigger_harvest_blade(def)
    elseif def.id == 'coin_burst' then
      triggered = trigger_coin_burst(def)
    elseif def.id == 'bloodrage_stomp' then
      triggered = trigger_bloodrage_stomp(def)
    elseif def.id == 'starfire_echo' then
      triggered = trigger_starfire_echo(def, context and context.target or nil)
    end

    if triggered then
      set_effect_cooldown(def.id, def.cooldown or 0)
    end
    return triggered
  end

  local function tick_cooldowns(dt)
    local runtime = get_runtime()
    for effect_id, remain in pairs(runtime.cooldowns) do
      if remain > 0 then
        runtime.cooldowns[effect_id] = math.max(0, remain - dt)
      end
    end
  end

  local function update(dt)
    if not STATE.hero or not STATE.hero:is_exist() or STATE.game_finished then
      return
    end

    tick_cooldowns(dt)
    for _, def in ipairs(EFFECT_LIST) do
      if def.trigger_type == 'periodic' then
        try_trigger_effect(def)
      end
    end
  end

  local function handle_enemy_kill(info)
    for _, def in ipairs(EFFECT_LIST) do
      if def.trigger_type == 'on_kill' then
        try_trigger_effect(def, {
          info = info,
        })
      end
    end
  end

  local function handle_basic_attack_cast(target)
    for _, def in ipairs(EFFECT_LIST) do
      if def.trigger_type == 'on_basic_attack_count' and is_source_active(def) then
        local count = add_effect_counter(def.id, 1)
        if count >= (def.counter_required or 1) and try_trigger_effect(def, {
          target = target,
        }) then
          reset_effect_counter(def.id)
        end
      end
    end
  end

  local function handle_attack_skill_cast(skill, target)
    if not skill or skill.id == 'basic_attack' then
      return
    end
    for _, def in ipairs(EFFECT_LIST) do
      if def.trigger_type == 'on_attack_skill_cast' then
        try_trigger_effect(def, {
          skill = skill,
          target = target,
        })
      end
    end
  end

  return {
    update = update,
    handle_enemy_kill = handle_enemy_kill,
    handle_basic_attack_cast = handle_basic_attack_cast,
    handle_attack_skill_cast = handle_attack_skill_cast,
  }
end

return M

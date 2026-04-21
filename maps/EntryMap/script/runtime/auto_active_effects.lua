local EffectObjects = require 'entry_objects.auto_active_effects'
local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local hero_attr_system = env.hero_attr_system
  local ATTACK_SKILL_VFX = env.ATTACK_SKILL_VFX
  local has_bond_route_tag = env.has_bond_route_tag
  local is_debug_effect_mounted = env.is_debug_effect_mounted
  local is_active_enemy = env.is_active_enemy
  local get_enemies_in_range = env.get_enemies_in_range
  local deal_skill_damage = env.deal_skill_damage
  local heal_hero = env.heal_hero
  local EFFECT_LIST = EffectObjects.list
  local VISUAL_ANIMATION_SPEED = 0.5
  local MODIFIER_KEYS = {
    stun = 117,
    fighting_spirit = RuntimeEditorIds.modifier.auto_active_effect.fighting_spirit_field,
    rapid_overdrive = RuntimeEditorIds.modifier.auto_active_effect.rapid_overdrive,
    charge_breaker_rally = RuntimeEditorIds.modifier.auto_active_effect.charge_breaker_rally,
  }

  local function scale_visual_duration(seconds)
    return math.max(0.05, (seconds or 0.30) / VISUAL_ANIMATION_SPEED)
  end

  local function apply_visual_animation_speed(target, animation_speed)
    if not target or not target.set_animation_speed then
      return
    end
    pcall(function()
      target:set_animation_speed(animation_speed or VISUAL_ANIMATION_SPEED)
    end)
  end

  local function get_runtime()
    if not STATE.auto_active_effects then
      STATE.auto_active_effects = {
        cooldowns = {},
        counters = {},
        last_trigger_result = {},
        last_modifier_apply = {},
        temp_attr_bonuses = {},
        temp_target_bonuses = {},
        pending_skill_resets = {},
      }
    end
    return STATE.auto_active_effects
  end

  local function set_last_trigger_result(effect_id, result, reason)
    get_runtime().last_trigger_result[effect_id] = {
      result = result or 'none',
      reason = reason or '',
    }
  end

  local function record_modifier_apply(effect_id, buff_key, buff, reason)
    if not effect_id then
      return
    end
    get_runtime().last_modifier_apply[effect_id] = {
      modifier_key = buff_key or 0,
      success = buff ~= nil,
      reason = reason or (buff and 'success' or 'failed'),
    }
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

  local function set_effect_counter(effect_id, value)
    get_runtime().counters[effect_id] = value or 0
  end

  local function reset_effect_counter(effect_id)
    get_runtime().counters[effect_id] = 0
  end

  local function is_source_active(def)
    if def and is_debug_effect_mounted and is_debug_effect_mounted(def.id) then
      return true
    end
    if def.source_type == 'bond' then
      return has_bond_route_tag and has_bond_route_tag(def.source_id) or false
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

  local function get_unit_attr(unit, attr_name)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return 0
    end
    if hero_attr_system and unit == STATE.hero then
      return hero_attr_system.get_attr(unit, attr_name)
    end
    return y3.helper.tonumber(unit:get_attr(attr_name)) or 0
  end

  local function get_attack_damage_base()
    local final_attack = get_unit_attr(STATE.hero, '攻击结算值')
    if final_attack > 0 then
      return math.max(1, final_attack)
    end
    local base_attack = get_unit_attr(STATE.hero, '攻击')
    if base_attack > 0 then
      return math.max(1, base_attack)
    end
    return math.max(1, get_unit_attr(STATE.hero, '物理攻击'))
  end

  local function clone_point(point)
    if not point or not point.move then
      return nil
    end
    return point:move()
  end

  local function get_intelligence()
    return math.max(1, get_unit_attr(STATE.hero, '智力'))
  end

  local function get_strength()
    return math.max(1, get_unit_attr(STATE.hero, '力量'))
  end

  local function get_hero_max_hp()
    local final_hp = get_unit_attr(STATE.hero, '生命结算值')
    if final_hp > 0 then
      return math.max(1, final_hp)
    end
    local base_hp = get_unit_attr(STATE.hero, '生命')
    if base_hp > 0 then
      return math.max(1, base_hp)
    end
    return math.max(1, get_unit_attr(STATE.hero, '最大生命'))
  end

  local function get_hero_hp_ratio()
    if not STATE.hero or not STATE.hero:is_exist() then
      return 1
    end
    local max_hp = get_hero_max_hp()
    return math.max(0, math.min(1, STATE.hero:get_hp() / max_hp))
  end

  local function get_target_hp_ratio(target)
    if not target or not target:is_exist() then
      return 1
    end
    local max_hp = math.max(1, y3.helper.tonumber(target:get_attr('生命')) or y3.helper.tonumber(target:get_attr('最大生命')) or 1)
    return math.max(0, target:get_hp() / max_hp)
  end

  local function get_target_max_hp(target)
    local max_hp = y3.helper.tonumber(target and target.get_attr and target:get_attr('生命')) or get_unit_attr(target, '最大生命')
    return math.max(1, max_hp)
  end

  local function get_initial_skill_count()
    if not STATE.attack_skill_state or not STATE.attack_skill_state.slots then
      return 0
    end
    local count = 0
    for slot = 1, 4, 1 do
      local skill = STATE.attack_skill_state.slots[slot]
      if skill and skill.id ~= 'basic_attack' then
        count = count + 1
      end
    end
    return count
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
      time = scale_visual_duration(time),
      immediate = true,
    })
    if ok and particle then
      apply_visual_animation_speed(particle)
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
      time = scale_visual_duration(time),
      height = height or 0,
      immediate = true,
    })
    if ok and particle then
      apply_visual_animation_speed(particle)
      return particle
    end
    return nil
  end

  local function play_hero_cast_animation()
    if STATE.hero and STATE.hero:is_exist() then
      STATE.hero:play_animation('attack1', 1.0, nil, nil, false, true)
    end
  end

  local function try_add_buff(effect_id, unit, buff_key, duration, source)
    if not buff_key or buff_key == 0 then
      record_modifier_apply(effect_id, buff_key, nil, 'invalid_modifier_key')
      return nil
    end
    if not unit or not unit.is_exist or not unit:is_exist() or not unit.add_buff then
      record_modifier_apply(effect_id, buff_key, nil, 'invalid_target')
      return nil
    end
    local ok, buff = pcall(unit.add_buff, unit, {
      key = buff_key,
      source = source or STATE.hero,
      time = duration or 0,
    })
    if ok then
      record_modifier_apply(effect_id, buff_key, buff, buff and 'success' or 'nil_buff')
      return buff
    end
    record_modifier_apply(effect_id, buff_key, nil, 'pcall_failed')
    return nil
  end

  local PROJECTILE_FLIGHT_HEIGHT = 100

  local function launch_projectile_to_target(vfx, target, on_finish)
    local launch_angle
    if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and target and target:is_exist() then
      local source_point = STATE.hero:get_point()
      local target_point = target:get_point()
      if source_point and target_point and source_point.get_angle_with then
        launch_angle = source_point:get_angle_with(target_point)
      end
    end
    if not vfx or not vfx.projectile_key or not target or not target:is_exist() then
      if on_finish then
        on_finish(target and target:is_exist() and target:get_point() or nil, false)
      end
      return false
    end

    local ok_create, projectile = pcall(y3.projectile.create, {
      key = vfx.projectile_key,
      target = STATE.hero,
      socket = 'origin',
      owner = STATE.hero,
      angle = launch_angle,
      time = vfx.projectile_time or 3.0,
      remove_immediately = true,
    })
    if not ok_create or not projectile then
      if on_finish then
        on_finish(target:get_point(), false)
      end
      return false
    end

    pcall(function()
      projectile:set_height(PROJECTILE_FLIGHT_HEIGHT)
    end)
    apply_visual_animation_speed(projectile, 1.0)

    if launch_angle ~= nil then
      pcall(function()
        projectile:set_facing(launch_angle)
      end)
    end
	
    local resolved = false
    local function get_projectile_point_snapshot()
      return clone_point(projectile and projectile:is_exist() and projectile:get_point() or nil)
        or (target and target:is_exist() and target:get_point() or nil)
    end

    local function finish(final_point, did_hit)
      if resolved then
        return
      end
      resolved = true
      local resolved_point = final_point
      if projectile and projectile:is_exist() then
        resolved_point = final_point or clone_point(projectile:get_point()) or resolved_point
      end
      if projectile and projectile:is_exist() then
        projectile:remove()
      end
      if on_finish then
        on_finish(resolved_point, did_hit == true)
      end
    end

    local ok_move = pcall(function()
      projectile:mover_target({
        target = target,
        speed = tonumber(vfx and vfx.projectile_speed) or 1000,
        target_distance = vfx.target_distance or 60,
        height = PROJECTILE_FLIGHT_HEIGHT,
        init_angle = launch_angle,
        rotate_time = 0.0,
        face_angle = true,
        miss_when_target_destroy = false,
        on_finish = function()
          finish(get_projectile_point_snapshot(), target and target:is_exist() or false)
        end,
        on_break = function()
          finish(get_projectile_point_snapshot(), false)
        end,
        on_miss = function()
          finish(get_projectile_point_snapshot(), false)
        end,
      })
    end)

    if not ok_move then
      finish(get_projectile_point_snapshot(), false)
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
      local text_type = 'magic'
      if damage_type == '物理' or damage_type == 'weapon' then
        text_type = 'physics'
      end
      deal_skill_damage(unit, amount, damage_type, {
        text_type = text_type,
        particle = particle,
      })
      hit_any = true
    end
    return hit_any
  end

  local function sync_temp_attr_bonus(effect_id, attr_pack, duration)
    local runtime = get_runtime()
    local active = runtime.temp_attr_bonuses[effect_id]
    if not active then
      active = {
        attr = {},
        remaining = 0,
      }
      runtime.temp_attr_bonuses[effect_id] = active
    end

    local hero = STATE.hero
    local seen = {}
    if hero and hero:is_exist() then
      for attr_name, value in pairs(attr_pack or {}) do
        seen[attr_name] = true
        local previous = active.attr[attr_name] or 0
        local delta = value - previous
        if delta ~= 0 then
          if hero_attr_system then
            hero_attr_system.add_attr(hero, attr_name, delta)
          else
            hero:add_attr(attr_name, delta)
          end
        end
        active.attr[attr_name] = value
      end
      for attr_name, previous in pairs(active.attr) do
        if not seen[attr_name] and previous ~= 0 then
          if hero_attr_system then
            hero_attr_system.add_attr(hero, attr_name, -previous)
          else
            hero:add_attr(attr_name, -previous)
          end
          active.attr[attr_name] = nil
        end
      end
    else
      active.attr = attr_pack or {}
    end
    active.remaining = math.max(active.remaining or 0, duration or 0)
    if hero and hero:is_exist() and hero_attr_system then
      hero_attr_system.rebuild_derived_attrs(hero)
    end
  end

  local function clear_temp_attr_bonus(effect_id)
    local runtime = get_runtime()
    local active = runtime.temp_attr_bonuses[effect_id]
    if not active then
      return
    end

    if STATE.hero and STATE.hero:is_exist() then
      for attr_name, value in pairs(active.attr or {}) do
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

  local function apply_target_attr_bonus(effect_id, unit, attr_pack, duration)
    if not unit or not unit:is_exist() then
      return
    end
    local runtime = get_runtime()
    runtime.temp_target_bonuses[effect_id] = runtime.temp_target_bonuses[effect_id] or {}
    local effect_bonuses = runtime.temp_target_bonuses[effect_id]
    local active = effect_bonuses[unit]
    if not active then
      active = {
        attr = {},
        remaining = 0,
      }
      effect_bonuses[unit] = active
    end

    if next(active.attr or {}) == nil then
      for attr_name, value in pairs(attr_pack or {}) do
        if value ~= 0 then
          unit:add_attr(attr_name, value)
        end
        active.attr[attr_name] = value
      end
    end
    active.remaining = math.max(active.remaining or 0, duration or 0)
  end

  local function clear_target_attr_bonus(effect_id, unit)
    local runtime = get_runtime()
    local effect_bonuses = runtime.temp_target_bonuses[effect_id]
    local active = effect_bonuses and effect_bonuses[unit] or nil
    if not active then
      return
    end
    if unit and unit:is_exist() then
      for attr_name, value in pairs(active.attr or {}) do
        if value ~= 0 then
          unit:add_attr(attr_name, -value)
        end
      end
    end
    effect_bonuses[unit] = nil
  end

  local function tick_temp_bonuses(dt)
    local runtime = get_runtime()

    for effect_id, active in pairs(runtime.temp_attr_bonuses) do
      active.remaining = (active.remaining or 0) - dt
      if active.remaining <= 0 then
        clear_temp_attr_bonus(effect_id)
      end
    end

    for effect_id, effect_bonuses in pairs(runtime.temp_target_bonuses) do
      for unit, active in pairs(effect_bonuses) do
        active.remaining = (active.remaining or 0) - dt
        if active.remaining <= 0 or not unit or not unit:is_exist() then
          clear_target_attr_bonus(effect_id, unit)
        end
      end
      if next(effect_bonuses) == nil then
        runtime.temp_target_bonuses[effect_id] = nil
      end
    end
  end

  local function tick_pending_skill_resets()
    local runtime = get_runtime()
    if not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
      return
    end
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

  local function trigger_spell_burst(def)
    local target = pick_nearest_enemy(def.range)
    if not target then
      return false
    end

    local is_amp_active = has_bond_route_tag and has_bond_route_tag('auto_spell_burst_amp') or false
    local burst_count = 1 + (is_amp_active and get_initial_skill_count() or 0)
    local radius = (def.radius or 300) + (is_amp_active and 150 or 0)
    local damage = get_intelligence() * (def.damage_ratio or 2.0)
    local vfx = ATTACK_SKILL_VFX[def.vfx]

    play_hero_cast_animation()
    play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or nil, vfx and vfx.cast_scale or 1, vfx and vfx.cast_time or 0.2, 'origin')
    for _ = 1, burst_count, 1 do
      local resolved_target = pick_nearest_enemy(def.range) or target
      if resolved_target and resolved_target:is_exist() then
        local center = resolved_target:get_point()
        play_particle_on_point(center, vfx and vfx.explosion_particle or vfx and vfx.impact_particle or nil, 1.15, 0.35, 12)
        damage_enemies_in_radius(center, radius, damage, '魔法')
      end
    end
    return true
  end

  local function trigger_haste_reset(def, context)
    local skill = context and context.skill or nil
    if not skill or skill.id == 'basic_attack' then
      return false
    end
    if math.random() > math.max(0, math.min(1, def.chance or 0)) then
      return false
    end
    get_runtime().pending_skill_resets[skill.id] = true
    local vfx = ATTACK_SKILL_VFX[def.vfx]
    play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.0, 0.25, 'origin')
    return true
  end

  local function trigger_fighting_spirit_field(def)
    if not STATE.hero or not STATE.hero:is_exist() then
      return false
    end

    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local base_damage = get_strength() * (def.damage_ratio or 0.60)
    local hit_any = false
    play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.15, 0.30, 'origin')

    for _, unit in ipairs(get_enemies_in_range(STATE.hero, def.radius or 1200, nil, 30)) do
      if is_active_enemy(unit) then
        local extra_damage = get_target_max_hp(unit) * (def.extra_hp_ratio or 0)
        deal_skill_damage(unit, base_damage + extra_damage, '物理', {
          text_type = 'physics',
        })

        local armor_delta = -get_unit_attr(unit, '护甲') * (def.armor_reduction_ratio or 0)
        local attack_delta = -get_unit_attr(unit, '物理攻击') * (def.attack_reduction_ratio or 0)
        apply_target_attr_bonus(def.id, unit, {
          ['护甲'] = armor_delta,
          ['物理攻击'] = attack_delta,
        }, 1.25)
        try_add_buff(def.id, unit, def.modifier_key or MODIFIER_KEYS.fighting_spirit, 1.25)
        hit_any = true
      end
    end
    return hit_any
  end

  local function trigger_rapid_overdrive(def)
    if math.random() > math.max(0, math.min(1, def.chance or 0)) then
      return false
    end
    sync_temp_attr_bonus(def.id, {
      ['攻击速度'] = def.attack_speed_bonus or 100,
    }, def.duration or 5.0)
    try_add_buff(def.id, STATE.hero, def.modifier_key or MODIFIER_KEYS.rapid_overdrive, def.duration or 5.0)
    local vfx = ATTACK_SKILL_VFX[def.vfx]
    play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.05, 0.25, 'origin')
    return true
  end

  local function trigger_blood_demon_burst(def)
    if not STATE.hero or not STATE.hero:is_exist() then
      return false
    end

    local threshold_step = math.max(0.01, def.threshold_step or 0.35)
    local missing_ratio = 1 - get_hero_hp_ratio()
    local reached_bucket = math.floor(missing_ratio / threshold_step)
    local last_bucket = get_runtime().counters[def.id] or 0
    if reached_bucket <= last_bucket then
      set_effect_counter(def.id, reached_bucket)
      return false
    end

    local vfx = ATTACK_SKILL_VFX[def.vfx]
    local burst_times = reached_bucket - last_bucket
    local hit_any = false
    for _ = 1, burst_times, 1 do
      heal_hero(get_hero_max_hp() * (def.heal_ratio or 0.20))
      play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.2, 0.35, 'origin')
      for _, unit in ipairs(get_enemies_in_range(STATE.hero, def.blast_radius or 320, nil, 16)) do
        if is_active_enemy(unit) then
          deal_skill_damage(unit, get_target_max_hp(unit) * (def.damage_ratio or 0.50), '物理', {
            text_type = 'physics',
          })
          try_add_buff(def.id, unit, MODIFIER_KEYS.stun, 1.0)
          apply_target_attr_bonus(def.id, unit, {
            ['攻击速度'] = -500,
            ['移动速度'] = -500,
          }, 1.0)
          hit_any = true
        end
      end
    end
    set_effect_counter(def.id, reached_bucket)
    return hit_any
  end

  local function trigger_charge_breaker_rally(def)
    sync_temp_attr_bonus(def.id, def.attr or {}, def.duration or 10.0)
    try_add_buff(def.id, STATE.hero, def.modifier_key or MODIFIER_KEYS.charge_breaker_rally, def.duration or 10.0)
    local vfx = ATTACK_SKILL_VFX[def.vfx]
    play_particle_on_unit(STATE.hero, vfx and vfx.cast_particle or vfx and vfx.impact_particle or nil, 1.2, 0.35, 'origin')
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
    launch_projectile_to_target(vfx, resolved_target, function(impact_point, did_hit)
      if did_hit ~= true then
        return
      end
      if impact_point and vfx and vfx.impact_particle then
        play_particle_on_point(impact_point, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 18)
      end
      if is_active_enemy(resolved_target) then
        deal_skill_damage(resolved_target, damage, '魔法', {
          text_type = 'magic',
        })
      end
    end)
    return true
  end

  local function get_effect_trigger_cooldown(def)
    if not def then
      return 0
    end
    if def.id == 'spell_burst' then
      local cooldown = def.cooldown or 0
      if has_bond_route_tag and has_bond_route_tag('auto_spell_burst_amp') then
        cooldown = cooldown - 5
      end
      return math.max(1, cooldown)
    end
    return def.cooldown or 0
  end

  local function try_trigger_effect(def, context, options)
    options = options or {}
    if not def then
      return false
    end
    if not options.ignore_source and not is_source_active(def) then
      set_last_trigger_result(def.id, 'failed', 'inactive_source')
      return false
    end
    if not options.ignore_cooldown and get_effect_cooldown(def.id) > 0 then
      set_last_trigger_result(def.id, 'failed', 'cooldown')
      return false
    end

    local triggered = false
    if def.id == 'spell_burst' then
      triggered = trigger_spell_burst(def)
    elseif def.id == 'haste_reset' then
      triggered = trigger_haste_reset(def, context)
    elseif def.id == 'fighting_spirit_field' then
      triggered = trigger_fighting_spirit_field(def)
    elseif def.id == 'rapid_overdrive' then
      triggered = trigger_rapid_overdrive(def)
    elseif def.id == 'blood_demon_burst' then
      triggered = trigger_blood_demon_burst(def)
    elseif def.id == 'charge_breaker_rally' then
      triggered = trigger_charge_breaker_rally(def)
    elseif def.id == 'bloodrage_stomp' then
      triggered = trigger_bloodrage_stomp(def)
    elseif def.id == 'starfire_echo' then
      triggered = trigger_starfire_echo(def, context and context.target or nil)
    end

    if triggered then
      set_effect_cooldown(def.id, get_effect_trigger_cooldown(def))
      set_last_trigger_result(def.id, 'success', '')
    else
      set_last_trigger_result(def.id, 'failed', 'no_target_or_condition')
    end
    return triggered
  end

  local function get_effect_runtime_snapshot(effect_id)
    local runtime = get_runtime()
    local def
    for _, effect_def in ipairs(EFFECT_LIST) do
      if effect_def.id == effect_id then
        def = effect_def
        break
      end
    end
    local last = runtime.last_trigger_result[effect_id] or {}
    local last_modifier_apply = clone_table(runtime.last_modifier_apply[effect_id] or {})
    return {
      active = def and is_source_active(def) or false,
      cooldown = runtime.cooldowns[effect_id] or 0,
      counter = runtime.counters[effect_id] or 0,
      last_result = last.result or 'none',
      last_reason = last.reason or '',
      last_modifier_apply = last_modifier_apply,
    }
  end

  local function clear_effect_runtime(effect_id)
    local runtime = get_runtime()
    runtime.cooldowns[effect_id] = nil
    runtime.counters[effect_id] = nil
    runtime.last_trigger_result[effect_id] = nil
    runtime.last_modifier_apply[effect_id] = nil
    runtime.pending_skill_resets[effect_id] = nil
    clear_temp_attr_bonus(effect_id)
    local target_bonuses = runtime.temp_target_bonuses[effect_id]
    if target_bonuses then
      for unit, _ in pairs(target_bonuses) do
        clear_target_attr_bonus(effect_id, unit)
      end
      runtime.temp_target_bonuses[effect_id] = nil
    end
  end

  local function force_trigger_effect(effect_id, context)
    local def
    for _, effect_def in ipairs(EFFECT_LIST) do
      if effect_def.id == effect_id then
        def = effect_def
        break
      end
    end
    if not def then
      return false, 'unknown_effect'
    end
    local triggered = try_trigger_effect(def, context, {
      ignore_source = true,
      ignore_cooldown = true,
    })
    local snapshot = get_effect_runtime_snapshot(effect_id)
    if triggered then
      return true, snapshot
    end
    return false, snapshot
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
    tick_temp_bonuses(dt)
    tick_pending_skill_resets()
    for _, def in ipairs(EFFECT_LIST) do
      if def.trigger_type == 'periodic' then
        try_trigger_effect(def)
      end
    end
  end

  local function handle_enemy_kill(info)
    for _, def in ipairs(EFFECT_LIST) do
      if def.trigger_type == 'on_kill' and is_source_active(def) then
        if (def.counter_required or 1) > 1 then
          local count = add_effect_counter(def.id, 1)
          if count >= (def.counter_required or 1) and try_trigger_effect(def, {
            info = info,
          }) then
            reset_effect_counter(def.id)
          end
        else
          try_trigger_effect(def, {
            info = info,
          })
        end
      end
    end
  end

  local function handle_basic_attack_cast(target)
    for _, def in ipairs(EFFECT_LIST) do
      if def.trigger_type == 'on_basic_attack_count' and is_source_active(def) then
        if (def.counter_required or 1) > 1 then
          local count = add_effect_counter(def.id, 1)
          if count >= (def.counter_required or 1) and try_trigger_effect(def, {
            target = target,
          }) then
            reset_effect_counter(def.id)
          end
        else
          try_trigger_effect(def, {
            target = target,
          }, {
            ignore_cooldown = true,
          })
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
        }, {
          ignore_cooldown = true,
        })
      end
    end
  end

  return {
    update = update,
    handle_enemy_kill = handle_enemy_kill,
    handle_basic_attack_cast = handle_basic_attack_cast,
    handle_attack_skill_cast = handle_attack_skill_cast,
    get_effect_defs = function()
      return EFFECT_LIST
    end,
    get_effect_runtime_snapshot = get_effect_runtime_snapshot,
    force_trigger_effect = force_trigger_effect,
    clear_effect_runtime = clear_effect_runtime,
  }
end

return M

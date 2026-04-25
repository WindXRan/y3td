local HeroRoster = require 'data.object_tables.hero_roster'
local HeroFormSkills = require 'data.object_tables.hero_form_skills'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local message = env.message or function() end
  local round_number = env.round_number or function(value)
    return math.floor((value or 0) + 0.5)
  end
  local hero_attr_system = env.hero_attr_system
  local is_active_enemy = env.is_active_enemy
  local get_enemies_in_range = env.get_enemies_in_range
  local get_enemy_runtime_info = env.get_enemy_runtime_info
  local is_boss_runtime_enemy = env.is_boss_runtime_enemy
  local is_elite_runtime_enemy = env.is_elite_runtime_enemy
  local deal_skill_damage = env.deal_skill_damage
  local heal_hero = env.heal_hero
  local play_skill_sound = env.play_skill_sound or function() end

  local api = {}

  local function get_runtime()
    if not STATE.hero_form_skill_runtime then
      STATE.hero_form_skill_runtime = {
        cooldowns = {},
        counters = {},
        active_hero_id = nil,
        active_skill_id = nil,
        announced_hero_id = nil,
      }
    end
    return STATE.hero_form_skill_runtime
  end

  local function clear_runtime_state(runtime)
    runtime.cooldowns = {}
    runtime.counters = {}
  end

  local function clone_point(point)
    if not point or not point.move then
      return nil
    end
    return point:move()
  end

  local function get_unit_point_snapshot(unit)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return nil
    end
    return clone_point(unit:get_point())
  end

  local function get_corpse_point(info)
    local unit = info and info.unit or nil
    if unit and unit.is_exist and unit:is_exist() then
      return clone_point(unit:get_point())
    end
    return nil
  end

  local function resolve_current_unit_id()
    local evolution_runtime = STATE.evolution_runtime or STATE.mark_runtime
    if evolution_runtime and evolution_runtime.active_form_unit_id then
      return tonumber(evolution_runtime.active_form_unit_id)
    end
    if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and STATE.hero.get_key then
      return tonumber(STATE.hero:get_key())
    end
    return nil
  end

  local function get_active_entry()
    local unit_id = resolve_current_unit_id()
    if not unit_id then
      return nil
    end
    return HeroRoster.by_unit_id[unit_id]
  end

  local function get_active_skill()
    local entry = get_active_entry()
    if not entry then
      return nil, nil
    end
    return HeroFormSkills.by_hero_id[entry.id], entry
  end

  local function announce_active_skill(entry, skill)
    if not entry or not skill then
      return
    end
    message(string.format(
      '当前真身：[%s] %s，神通「%s」已生效。',
      tostring(entry.rarity or '?'),
      tostring(entry.name or entry.id),
      tostring(skill.name or skill.id)
    ))
  end

  local function get_skill_cooldown(skill)
    return get_runtime().cooldowns[skill.id] or 0
  end

  local function set_skill_cooldown(skill, cooldown)
    get_runtime().cooldowns[skill.id] = math.max(0, cooldown or 0)
  end

  local function add_skill_counter(skill, delta)
    local runtime = get_runtime()
    runtime.counters[skill.id] = (runtime.counters[skill.id] or 0) + (delta or 0)
    return runtime.counters[skill.id]
  end

  local function reset_skill_counter(skill)
    get_runtime().counters[skill.id] = 0
  end

  local function tick_cooldowns(dt)
    local runtime = get_runtime()
    for skill_id, remain in pairs(runtime.cooldowns) do
      runtime.cooldowns[skill_id] = math.max(0, (remain or 0) - dt)
    end
  end

  local function get_hero_attr(name, fallback_name)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
      return 0
    end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name) or STATE.hero:get_attr(name)
    value = y3.helper.tonumber(value) or 0
    if value > 0 or not fallback_name then
      return value
    end
    local fallback = hero_attr_system and hero_attr_system.get_attr(STATE.hero, fallback_name) or STATE.hero:get_attr(fallback_name)
    return y3.helper.tonumber(fallback) or 0
  end

  local function get_attack_base()
    return math.max(1, get_hero_attr('攻击结算值', '攻击'))
  end

  local function get_hero_max_hp()
    local value = get_hero_attr('生命结算值', '生命')
    if value > 0 then
      return value
    end
    return math.max(1, get_hero_attr('最大生命'))
  end

  local function get_target_hp_ratio(target)
    if not target or not target.is_exist or not target:is_exist() then
      return 1
    end
    local max_hp = y3.helper.tonumber(target:get_attr('生命')) or y3.helper.tonumber(target:get_attr('最大生命')) or 0
    if max_hp <= 0 then
      return 1
    end
    return math.max(0, (target:get_hp() or 0) / max_hp)
  end

  local function is_boss_or_elite(target)
    if not target or not get_enemy_runtime_info then
      return false
    end
    local info = get_enemy_runtime_info(target)
    return (is_boss_runtime_enemy and is_boss_runtime_enemy(info))
      or (is_elite_runtime_enemy and is_elite_runtime_enemy(info))
      or false
  end

  local function build_damage_meta(skill)
    return {
      damage_type = skill.damage_type or '法术',
      damage_form = skill.damage_form or 'spell',
      element = skill.element or 'none',
      damage_label = skill.damage_label or '神通伤害',
    }
  end

  local function compute_damage_amount(skill, ratio, target)
    local amount = get_attack_base() * math.max(0, ratio or 0)
    if (skill.boss_bonus_ratio or 0) > 0 and is_boss_or_elite(target) then
      amount = amount * (1 + (skill.boss_bonus_ratio or 0))
    end
    return math.max(0, amount)
  end

  local function damage_unit(skill, target, ratio)
    if not target or not is_active_enemy(target) then
      return false
    end
    local amount = compute_damage_amount(skill, ratio or skill.damage_ratio, target)
    if amount <= 0 then
      return false
    end
    deal_skill_damage(target, amount, build_damage_meta(skill))
    return true
  end

  local function get_units_around(center, radius, except_unit, max_count)
    if not center or not radius or radius <= 0 then
      return {}
    end
    return get_enemies_in_range(center, radius, except_unit, max_count)
  end

  local function pick_primary_target(skill, ctx)
    if ctx and ctx.target and is_active_enemy(ctx.target) then
      return ctx.target
    end
    local radius = math.max(320, skill.radius or 0, 960)
    return get_units_around(STATE.hero, radius, nil, 1)[1]
  end

  local function burst_on_point(skill, point, ratio)
    if not point then
      return false
    end
    local hit = false
    for _, unit in ipairs(get_units_around(point, skill.radius or 220, nil, nil)) do
      hit = damage_unit(skill, unit, ratio) or hit
    end
    return hit
  end

  local function trigger_hero_pulse(skill)
    local hit = false
    for _, unit in ipairs(get_units_around(STATE.hero, skill.radius or 240, nil, nil)) do
      hit = damage_unit(skill, unit, skill.damage_ratio) or hit
    end
    return hit
  end

  local function trigger_healing_wave(skill)
    local did_heal = false
    if (skill.heal_ratio or 0) > 0 then
      heal_hero(round_number(get_hero_max_hp() * (skill.heal_ratio or 0)))
      did_heal = true
    end
    return trigger_hero_pulse(skill) or did_heal
  end

  local function trigger_cleave_target(skill, ctx)
    local target = pick_primary_target(skill, ctx)
    if not target then
      return false
    end

    local hit = damage_unit(skill, target, skill.damage_ratio)
    local splash_ratio = (skill.splash_ratio and skill.splash_ratio > 0) and skill.splash_ratio or (skill.damage_ratio or 0)
    for _, unit in ipairs(get_units_around(target, skill.radius or 220, target, nil)) do
      hit = damage_unit(skill, unit, splash_ratio) or hit
    end
    return hit
  end

  local function trigger_target_burst(skill, ctx)
    local target = pick_primary_target(skill, ctx)
    if not target then
      return false
    end

    local hit = damage_unit(skill, target, skill.damage_ratio)
    local splash_ratio = (skill.splash_ratio and skill.splash_ratio > 0) and skill.splash_ratio or 0
    if splash_ratio > 0 then
      for _, unit in ipairs(get_units_around(target, skill.radius or 180, target, nil)) do
        hit = damage_unit(skill, unit, splash_ratio) or hit
      end
    end
    return hit
  end

  local function trigger_fan_volley(skill, ctx)
    local target = pick_primary_target(skill, ctx)
    if not target then
      return false
    end

    local hit = damage_unit(skill, target, skill.damage_ratio)
    local extra_count = math.max(0, round_number(skill.target_count or 0))
    local splash_ratio = (skill.splash_ratio and skill.splash_ratio > 0) and skill.splash_ratio or skill.damage_ratio
    for _, unit in ipairs(get_units_around(target, skill.radius or 420, target, extra_count)) do
      hit = damage_unit(skill, unit, splash_ratio) or hit
    end
    return hit
  end

  local function trigger_chain_bolt(skill, ctx)
    local current = pick_primary_target(skill, ctx)
    if not current then
      return false
    end

    local hit = damage_unit(skill, current, skill.damage_ratio)
    local bounce_ratio = (skill.splash_ratio and skill.splash_ratio > 0) and skill.splash_ratio or skill.damage_ratio
    local bounce_count = math.max(0, round_number(skill.bounce_count or 0))
    local visited = {
      [current] = true,
    }

    for _ = 1, bounce_count, 1 do
      local next_target = nil
      for _, unit in ipairs(get_units_around(current, skill.radius or 420, nil, 8)) do
        if not visited[unit] then
          next_target = unit
          break
        end
      end
      if not next_target then
        break
      end
      visited[next_target] = true
      current = next_target
      hit = damage_unit(skill, current, bounce_ratio) or hit
    end

    return hit
  end

  local function trigger_repeat_strikes(skill, ctx)
    local focus_target = pick_primary_target(skill, ctx)
    local focus_point = ctx and ctx.point or nil
    local repeat_count = math.max(1, round_number(skill.repeat_count or 1))
    local max_targets = math.max(1, round_number(skill.target_count or 1))
    local interval = math.max(0.05, skill.repeat_interval or 0.18)

    for wave = 1, repeat_count, 1 do
      y3.ltimer.wait((wave - 1) * interval, function()
        if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() or STATE.game_finished then
          return
        end

        local center = focus_point
        if not center and focus_target and focus_target.is_exist and focus_target:is_exist() then
          center = focus_target
        end
        center = center or STATE.hero

        for _, unit in ipairs(get_units_around(center, skill.radius or 320, nil, max_targets)) do
          damage_unit(skill, unit, skill.damage_ratio)
        end
      end)
    end

    return true
  end

  local function trigger_meteor_zone(skill, ctx)
    local point = ctx and ctx.point or nil
    if not point then
      local target = pick_primary_target(skill, ctx)
      point = get_unit_point_snapshot(target)
    end
    point = point or get_unit_point_snapshot(STATE.hero)
    if not point then
      return false
    end

    local first_point = clone_point(point)
    local second_point = clone_point(point)
    local delay = math.max(0, skill.delay or 0)

    y3.ltimer.wait(delay, function()
      if STATE.game_finished then
        return
      end
      burst_on_point(skill, first_point, skill.damage_ratio)
      if (skill.splash_ratio or 0) > 0 then
        y3.ltimer.wait(0.15, function()
          if STATE.game_finished then
            return
          end
          burst_on_point(skill, second_point, skill.splash_ratio)
        end)
      end
    end)

    return true
  end

  local function trigger_corpse_burst(skill, ctx)
    if (skill.gold_gain or 0) > 0 and STATE.resources then
      STATE.resources.gold = (STATE.resources.gold or 0) + round_number(skill.gold_gain or 0)
    end

    local point = ctx and ctx.point or nil
    if not point then
      point = get_corpse_point(ctx and ctx.info or nil)
    end
    if not point then
      return false
    end

    local hit = burst_on_point(skill, clone_point(point), skill.damage_ratio)
    if (skill.splash_ratio or 0) > 0 then
      y3.ltimer.wait(0.12, function()
        if STATE.game_finished then
          return
        end
        burst_on_point(skill, clone_point(point), skill.splash_ratio)
      end)
    end
    return hit or true
  end

  local function trigger_execute_burst(skill, ctx)
    local target = pick_primary_target(skill, ctx)
    if not target then
      return false
    end

    local hit = damage_unit(skill, target, skill.damage_ratio)
    if (skill.hp_threshold or 0) > 0 and get_target_hp_ratio(target) <= (skill.hp_threshold or 0) then
      local lethal_amount = y3.helper.tonumber(target:get_hp()) or 0
      if lethal_amount > 0 then
        deal_skill_damage(target, lethal_amount + compute_damage_amount(skill, 0.15, target), build_damage_meta(skill))
        hit = true
      end
    end

    if (skill.splash_ratio or 0) > 0 then
      for _, unit in ipairs(get_units_around(target, skill.radius or 180, target, nil)) do
        hit = damage_unit(skill, unit, skill.splash_ratio) or hit
      end
    end

    return hit
  end

  local PATTERN_HANDLERS = {
    hero_pulse = trigger_hero_pulse,
    healing_wave = trigger_healing_wave,
    cleave_target = trigger_cleave_target,
    target_burst = trigger_target_burst,
    fan_volley = trigger_fan_volley,
    chain_bolt = trigger_chain_bolt,
    repeat_strikes = trigger_repeat_strikes,
    meteor_zone = trigger_meteor_zone,
    corpse_burst = trigger_corpse_burst,
    execute_burst = trigger_execute_burst,
  }

  local function trigger_skill(skill, ctx)
    if not skill or not PATTERN_HANDLERS[skill.pattern] then
      return false
    end
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() or STATE.game_finished then
      return false
    end
    if get_skill_cooldown(skill) > 0 then
      return false
    end

    local ok, triggered = pcall(PATTERN_HANDLERS[skill.pattern], skill, ctx or {})
    if not ok or not triggered then
      return false
    end

    set_skill_cooldown(skill, skill.cooldown or 0)
    play_skill_sound(skill)
    return true
  end

  local function refresh_active_form_state()
    local runtime = get_runtime()
    local skill, entry = get_active_skill()
    local hero_id = entry and entry.id or nil
    local skill_id = skill and skill.id or nil

    if runtime.active_hero_id ~= hero_id or runtime.active_skill_id ~= skill_id then
      runtime.active_hero_id = hero_id
      runtime.active_skill_id = skill_id
      clear_runtime_state(runtime)
    end

    if runtime.announced_hero_id ~= hero_id then
      runtime.announced_hero_id = hero_id
      if entry and skill then
        announce_active_skill(entry, skill)
      end
    end

    return skill, entry
  end

  function api.update(dt)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() or STATE.game_finished then
      return
    end

    tick_cooldowns(dt)
    local skill = refresh_active_form_state()
    if not skill then
      return
    end

    if skill.trigger_type == 'interval' then
      trigger_skill(skill, {})
      return
    end

    if skill.trigger_type == 'low_hp_interval' then
      local hp_ratio = get_target_hp_ratio(STATE.hero)
      if hp_ratio <= (skill.hp_threshold or 0) then
        trigger_skill(skill, {})
      end
    end
  end

  function api.handle_basic_attack_cast(target)
    local skill = refresh_active_form_state()
    if not skill or skill.trigger_type ~= 'basic_attack' then
      return
    end

    local required = math.max(1, round_number(skill.trigger_value or 1))
    if add_skill_counter(skill, 1) >= required and trigger_skill(skill, {
      target = target,
    }) then
      reset_skill_counter(skill)
    end
  end

  function api.handle_attack_skill_cast(attack_skill, target)
    if not attack_skill or attack_skill.id == 'basic_attack' then
      return
    end

    local skill = refresh_active_form_state()
    if not skill or skill.trigger_type ~= 'attack_skill' then
      return
    end

    local required = math.max(1, round_number(skill.trigger_value or 1))
    if add_skill_counter(skill, 1) >= required and trigger_skill(skill, {
      target = target,
    }) then
      reset_skill_counter(skill)
    end
  end

  function api.handle_enemy_kill(info)
    local skill = refresh_active_form_state()
    if not skill or skill.trigger_type ~= 'enemy_kill' then
      return
    end

    local required = math.max(1, round_number(skill.trigger_value or 1))
    if add_skill_counter(skill, 1) >= required and trigger_skill(skill, {
      info = info,
      point = get_corpse_point(info),
    }) then
      reset_skill_counter(skill)
    end
  end

  function api.get_active_entry()
    local _, entry = get_active_skill()
    return entry
  end

  function api.get_active_skill()
    local skill = get_active_skill()
    return skill
  end

  function api.get_roster()
    return HeroRoster
  end

  function api.get_skill_defs()
    return HeroFormSkills
  end

  return api
end

return M

local M = {}
local Registry = require 'runtime.skill_framework_registry'

local VALID_DAMAGE_TYPE = { ['物理'] = true, ['法术'] = true, ['真实'] = true }
local VALID_PATTERN = { line_pierce = true, area_burst = true, area_tick = true, chain_bounce = true }
local VALID_TARGET_MODE = { unit = true, point = true, self = true, none = true }
local GLOBAL_CAST_GCD = 0.06

local PRODUCTION_LIMITS = {
  cast_point_min = 0.00,
  cast_point_max = 0.35,
  impact_delay_min = 0.06,
  impact_delay_max = 0.80,
  duration_min = 0.20,
  duration_max = 8.00,
  tick_interval_min = 0.18,
  tick_interval_max = 1.20,
  range_min = 80,
  range_max = 2800,
  width_min = 30,
  width_max = 520,
  radius_min = 40,
  radius_max = 900,
  cooldown_min = 0.00,
  cooldown_max = 15.00,
}

local function normalize_damage_type(value)
  if value == '物理' then
    return '物理'
  end
  if value == '真实' then
    return '真实'
  end
  return '法术'
end

local function normalize_number(value, fallback, min)
  local n = tonumber(value)
  if n == nil then
    n = fallback
  end
  if min ~= nil and n < min then
    return min
  end
  return n
end

local function safe_id(value, fallback)
  local text = tostring(value or fallback or 'skill')
  if text == '' then
    return tostring(fallback or 'skill')
  end
  return text
end

local function normalize_skill(def)
  local cfg = def or {}
  local pattern = tostring(cfg.pattern or 'line_pierce')
  if not VALID_PATTERN[pattern] then
    pattern = 'line_pierce'
  end

  local target_mode = tostring(cfg.target_mode or '')
  if target_mode == '' then
    if pattern == 'area_tick' then
      target_mode = 'point'
    elseif pattern == 'chain_bounce' or pattern == 'line_pierce' then
      target_mode = 'unit'
    else
      target_mode = 'point'
    end
  end
  if not VALID_TARGET_MODE[target_mode] then
    target_mode = 'unit'
  end

  local out = {
    id = safe_id(cfg.id, pattern),
    name = safe_id(cfg.name, cfg.id or pattern),
    pattern = pattern,
    target_mode = target_mode,
    damage_type = normalize_damage_type(cfg.damage_type),
    timeline = {
      cast_point = normalize_number(cfg.timeline and cfg.timeline.cast_point, 0.15, 0),
      impact_delay = normalize_number(cfg.timeline and cfg.timeline.impact_delay, 0.2, 0),
      backswing = normalize_number(cfg.timeline and cfg.timeline.backswing, 0.12, 0),
      duration = normalize_number(cfg.timeline and cfg.timeline.duration, 1.0, 0.05),
      tick_interval = normalize_number(cfg.timeline and cfg.timeline.tick_interval, 0.2, 0.03),
    },
    hit_model = {
      range = normalize_number(cfg.hit_model and cfg.hit_model.range, 1200, 80),
      width = normalize_number(cfg.hit_model and cfg.hit_model.width, 180, 30),
      radius = normalize_number(cfg.hit_model and cfg.hit_model.radius, 260, 40),
      max_hits = math.floor(normalize_number(cfg.hit_model and cfg.hit_model.max_hits, 0, 0) + 0.5),
      bounce = math.floor(normalize_number(cfg.hit_model and cfg.hit_model.bounce, 4, 1) + 0.5),
    },
    scale = {
      attack_ratio = normalize_number(cfg.scale and cfg.scale.attack_ratio, 1.8, 0.01),
      splash_ratio = normalize_number(cfg.scale and cfg.scale.splash_ratio, 0.6, 0),
      tick_ratio = normalize_number(cfg.scale and cfg.scale.tick_ratio, 0.4, 0),
      bounce_ratio = normalize_number(cfg.scale and cfg.scale.bounce_ratio, 0.75, 0.01),
    },
    resource = {
      mana_cost = normalize_number(cfg.resource and cfg.resource.mana_cost, 0, 0),
      cooldown = normalize_number(cfg.resource and cfg.resource.cooldown, 0, 0),
      charges = math.floor(normalize_number(cfg.resource and cfg.resource.charges, 0, 0) + 0.5),
    },
    behavior = {
      no_target = target_mode == 'none' or target_mode == 'self',
      point_target = target_mode == 'point',
      unit_target = target_mode == 'unit',
      is_channeled = cfg.behavior and cfg.behavior.is_channeled == true or false,
    },
    visual = cfg.visual or {},
    hooks = cfg.hooks or {},
  }
  return out
end

local function validate_visual_config(skill)
  local visual = skill and skill.visual or nil
  if type(visual) ~= 'table' then
    return false, string.format('[%s] visual 缺失', tostring(skill and skill.id or 'unknown'))
  end
  local required_particles = { 'cast', 'impact', 'hit' }
  for _, key in ipairs(required_particles) do
    local value = tonumber(visual[key]) or 0
    if value <= 0 then
      return false, string.format('[%s] visual.%s 非法: %s', tostring(skill.id), key, tostring(visual[key]))
    end
  end
  if skill.pattern == 'line_pierce' or skill.pattern == 'chain_bounce' then
    local projectile_key = tonumber(visual.projectile_key) or 0
    if projectile_key <= 0 then
      return false, string.format('[%s] projectile_key 非法: %s', tostring(skill.id), tostring(visual.projectile_key))
    end
  end
  return true
end

local function clamp(value, min_value, max_value)
  if value < min_value then
    return min_value
  end
  if value > max_value then
    return max_value
  end
  return value
end

local function clamp_number(value, min_value, max_value, fallback)
  local n = tonumber(value)
  if n == nil then
    n = fallback
  end
  if min_value ~= nil and n < min_value then
    n = min_value
  end
  if max_value ~= nil and n > max_value then
    n = max_value
  end
  return n
end

local function apply_production_limits(skill)
  skill.timeline.cast_point = clamp_number(skill.timeline.cast_point, PRODUCTION_LIMITS.cast_point_min, PRODUCTION_LIMITS.cast_point_max, 0.10)
  skill.timeline.impact_delay = clamp_number(skill.timeline.impact_delay, PRODUCTION_LIMITS.impact_delay_min, PRODUCTION_LIMITS.impact_delay_max, 0.20)
  skill.timeline.duration = clamp_number(skill.timeline.duration, PRODUCTION_LIMITS.duration_min, PRODUCTION_LIMITS.duration_max, 1.0)
  skill.timeline.tick_interval = clamp_number(skill.timeline.tick_interval, PRODUCTION_LIMITS.tick_interval_min, PRODUCTION_LIMITS.tick_interval_max, 0.22)
  skill.hit_model.range = clamp_number(skill.hit_model.range, PRODUCTION_LIMITS.range_min, PRODUCTION_LIMITS.range_max, 1200)
  skill.hit_model.width = clamp_number(skill.hit_model.width, PRODUCTION_LIMITS.width_min, PRODUCTION_LIMITS.width_max, 180)
  skill.hit_model.radius = clamp_number(skill.hit_model.radius, PRODUCTION_LIMITS.radius_min, PRODUCTION_LIMITS.radius_max, 260)
  skill.resource.cooldown = clamp_number(skill.resource.cooldown, PRODUCTION_LIMITS.cooldown_min, PRODUCTION_LIMITS.cooldown_max, 0)
  if skill.pattern == 'area_tick' then
    skill.timeline.tick_interval = math.max(skill.timeline.tick_interval, 0.18)
    local min_duration = math.max(0.36, skill.timeline.tick_interval * 2)
    skill.timeline.duration = math.max(skill.timeline.duration, min_duration)
  end
  return skill
end

local function dedupe_units(units)
  if type(units) ~= 'table' then
    return {}
  end
  local result = {}
  local seen = {}
  for _, unit in ipairs(units) do
    if unit and not seen[unit] then
      seen[unit] = true
      result[#result + 1] = unit
    end
  end
  return result
end

local function area_fx_scale(radius)
  local r = tonumber(radius) or 260
  -- 基准半径 260 -> scale 1.0，控制在可接受区间避免夸张穿帮。
  return clamp(r / 260, 0.75, 2.20)
end

local function line_fx_scale(width, range)
  local w = tonumber(width) or 180
  local r = tonumber(range) or 1200
  -- 宽度决定主视觉，距离只做轻微修正。
  local scale = (w / 180) * clamp(r / 1200, 0.85, 1.20)
  return clamp(scale, 0.80, 2.10)
end

local function impact_fx_scale(skill)
  if skill.pattern == 'area_burst' or skill.pattern == 'area_tick' then
    return area_fx_scale(skill.hit_model.radius)
  end
  if skill.pattern == 'line_pierce' then
    return line_fx_scale(skill.hit_model.width, skill.hit_model.range)
  end
  if skill.pattern == 'chain_bounce' then
    return clamp((tonumber(skill.hit_model.bounce) or 4) / 4, 0.90, 1.50)
  end
  return 1.0
end

function M.create(env)
  env = env or {}
  local y3 = env.y3
  local skill_damage_api = env.skill_damage_api
  local get_primary_target = env.get_primary_target
  local get_enemies_in_range = env.get_enemies_in_range
  local get_hero = env.get_hero
  local get_hero_point = env.get_hero_point
  local get_hero_attack = env.get_hero_attack
  local get_hero_facing_towards = env.get_hero_facing_towards
  local create_offset_point = env.create_offset_point
  local launch_projectile_from_hero = env.launch_projectile_from_hero
  local spawn_particle = env.spawn_particle

  local api = {}
  local registry = Registry.create()
  local runtime = {
    by_skill_id = {},
    active_casts = {},
    telemetry = {},
    global_last_cast_time = 0,
  }

  local function fire_hook(skill, hook_name, ctx)
    local hooks = skill.hooks or {}
    local hook = hooks[hook_name]
    if type(hook) == 'function' then
      local ok, result = pcall(hook, ctx)
      if ok then
        return result
      end
    end
    return nil
  end

  local function state_of(skill_id)
    runtime.by_skill_id[skill_id] = runtime.by_skill_id[skill_id] or {
      cooldown_end = 0,
      charges = 0,
      max_charges = 0,
      last_cast_time = 0,
    }
    return runtime.by_skill_id[skill_id]
  end

  local function telemetry_of(skill_id)
    runtime.telemetry[skill_id] = runtime.telemetry[skill_id] or {
      cast_count = 0,
      success_count = 0,
      fail_count = 0,
      total_hits = 0,
      empty_cast_count = 0,
      total_damage = 0,
      timing_drift_ms_total = 0,
      timing_sample_count = 0,
      first_cast_time = 0,
      last_reason = '',
      last_cast_time = 0,
    }
    return runtime.telemetry[skill_id]
  end

  local function now()
    if y3 and y3.game and y3.game.current_game_run_time then
      return tonumber(y3.game.current_game_run_time()) or 0
    end
    return 0
  end

  local function in_cooldown(st)
    return st.cooldown_end > now()
  end

  local function ensure_charges(skill, st)
    if skill.resource.charges <= 0 then
      return
    end
    if st.max_charges ~= skill.resource.charges then
      st.max_charges = skill.resource.charges
      st.charges = skill.resource.charges
    end
  end

  local function consume_charge_or_cooldown(skill, st)
    ensure_charges(skill, st)
    if skill.resource.charges > 0 then
      if st.charges <= 0 then
        return false
      end
      st.charges = st.charges - 1
      if skill.resource.cooldown > 0 then
        y3.ltimer.wait(skill.resource.cooldown, function()
          st.charges = math.min(st.max_charges, st.charges + 1)
        end)
      end
      return true
    end
    if skill.resource.cooldown > 0 then
      st.cooldown_end = now() + skill.resource.cooldown
    end
    return true
  end

  local function resolve_target(skill, caster, hero_point, cast_params)
    cast_params = cast_params or {}
    if skill.behavior.no_target then
      return caster, hero_point
    end
    if skill.behavior.point_target then
      local point = cast_params.point
      if point then
        return nil, point
      end
      local target = cast_params.target or (get_primary_target and get_primary_target(skill.hit_model.range))
      if target and target.get_point then
        return target, target:get_point()
      end
      return nil, hero_point
    end
    local target = cast_params.target or (get_primary_target and get_primary_target(skill.hit_model.range))
    if target and target.get_point then
      return target, target:get_point()
    end
    return nil, nil
  end

  local function damage_amount(skill, ratio_key)
    local ratio = skill.scale[ratio_key] or 1
    return (get_hero_attack() or 0) * ratio
  end

  local function visual_key(skill, key)
    return skill.visual and skill.visual[key] or nil
  end

  local function resolve_impact_delay(skill)
    local base = tonumber(skill and skill.timeline and skill.timeline.impact_delay) or 0
    local projectile_time = tonumber(skill and skill.visual and skill.visual.projectile_time) or 0
    return math.max(0, base, projectile_time)
  end

  local function mark_visual_impact(cast_ctx)
    cast_ctx.visual_impact_time = now()
  end

  local function mark_damage_impact(cast_ctx)
    cast_ctx.damage_time = now()
    local v = tonumber(cast_ctx.visual_impact_time) or 0
    local d = tonumber(cast_ctx.damage_time) or 0
    cast_ctx.timing_drift_ms = math.abs(d - v) * 1000
  end

  local function execute_pattern(cast_ctx)
    local skill = cast_ctx.skill
    local hero_point = cast_ctx.origin_point
    local target = cast_ctx.target
    local impact_point = cast_ctx.impact_point

    if skill.pattern == 'line_pierce' then
      local angle = 0
      if target then
        angle = get_hero_facing_towards and get_hero_facing_towards(target) or 0
      elseif cast_ctx.caster and cast_ctx.caster.get_facing then
        angle = tonumber(cast_ctx.caster:get_facing()) or 0
      end
      local end_point = create_offset_point and create_offset_point(y3, hero_point, angle, skill.hit_model.range, 0) or impact_point
      if not end_point then
        return false, '直线终点创建失败。'
      end
      local impact_delay = resolve_impact_delay(skill)
      if visual_key(skill, 'projectile_key') then
        launch_projectile_from_hero(
          visual_key(skill, 'projectile_key'),
          target,
          end_point,
          angle,
          impact_delay,
          visual_key(skill, 'projectile_height')
        )
      end
      local fx_scale = impact_fx_scale(skill)
      spawn_particle(y3, cast_ctx.caster, visual_key(skill, 'cast'), fx_scale * 0.95, 0.20, 24)
      fire_hook(skill, 'OnSpellStart', cast_ctx)
      y3.ltimer.wait(impact_delay, function()
        mark_visual_impact(cast_ctx)
        spawn_particle(y3, end_point, visual_key(skill, 'impact') or visual_key(skill, 'hit'), fx_scale * 1.02, 0.16, 24)
        local hits = skill_damage_api.line(hero_point, end_point, damage_amount(skill, 'attack_ratio'), skill.damage_type, {
          max_distance = skill.hit_model.range,
          line_width = skill.hit_model.width,
          max_hits = skill.hit_model.max_hits > 0 and skill.hit_model.max_hits or nil,
          visual = {
            particle = visual_key(skill, 'hit'),
            metric_scope = 'skill_framework',
            metric_key = skill.id,
          },
        })
        cast_ctx.hits = hits
        cast_ctx.hit_count = #hits
        cast_ctx.total_damage = (damage_amount(skill, 'attack_ratio') or 0) * cast_ctx.hit_count
        mark_damage_impact(cast_ctx)
        fire_hook(skill, 'OnProjectileHit', cast_ctx)
        fire_hook(skill, 'OnFinish', cast_ctx)
      end)
      return true, string.format('[%s] line_pierce 触发', skill.id)
    end

    if skill.pattern == 'area_burst' then
      local center = impact_point or hero_point
      local fx_scale = impact_fx_scale(skill)
      spawn_particle(y3, center, visual_key(skill, 'warning') or visual_key(skill, 'cast'), fx_scale, skill.timeline.impact_delay, 24)
      fire_hook(skill, 'OnSpellStart', cast_ctx)
      y3.ltimer.wait(skill.timeline.impact_delay, function()
        mark_visual_impact(cast_ctx)
        spawn_particle(y3, center, visual_key(skill, 'impact'), fx_scale * 1.08, 0.18, 28)
        cast_ctx.hits = skill_damage_api.area(center, skill.hit_model.radius, damage_amount(skill, 'attack_ratio'), skill.damage_type, {
          max_count = skill.hit_model.max_hits > 0 and skill.hit_model.max_hits or nil,
          visual = {
            particle = visual_key(skill, 'hit'),
            metric_scope = 'skill_framework',
            metric_key = skill.id,
          },
        })
        cast_ctx.hit_count = #(cast_ctx.hits or {})
        cast_ctx.total_damage = (damage_amount(skill, 'attack_ratio') or 0) * cast_ctx.hit_count
        mark_damage_impact(cast_ctx)
        fire_hook(skill, 'OnProjectileHit', cast_ctx)
        fire_hook(skill, 'OnFinish', cast_ctx)
      end)
      return true, string.format('[%s] area_burst 触发', skill.id)
    end

    if skill.pattern == 'area_tick' then
      local center = impact_point or hero_point
      local tick_count = math.max(1, math.floor(skill.timeline.duration / skill.timeline.tick_interval + 0.5))
      local fx_scale = impact_fx_scale(skill)
      spawn_particle(y3, center, visual_key(skill, 'warning') or visual_key(skill, 'cast'), fx_scale, skill.timeline.duration, 20)
      fire_hook(skill, 'OnSpellStart', cast_ctx)
      cast_ctx.hit_count = 0
      cast_ctx.total_damage = 0
      skill_damage_api.area_ticks(skill.timeline.tick_interval, tick_count, skill.damage_type, {
        center = center,
        radius = skill.hit_model.radius,
        amount = damage_amount(skill, 'tick_ratio'),
        max_count = skill.hit_model.max_hits > 0 and skill.hit_model.max_hits or nil,
        visual = {
          particle = visual_key(skill, 'hit'),
          metric_scope = 'skill_framework',
          metric_key = skill.id,
        },
        after_tick = function(ctx)
          cast_ctx.tick = ctx.current
          cast_ctx.hits = ctx.hits
          local one_tick_hits = #(ctx.hits or {})
          cast_ctx.hit_count = cast_ctx.hit_count + one_tick_hits
          cast_ctx.total_damage = cast_ctx.total_damage + ((damage_amount(skill, 'tick_ratio') or 0) * one_tick_hits)
          fire_hook(skill, 'OnTick', cast_ctx)
        end,
      })
      y3.ltimer.wait(skill.timeline.duration, function()
        fire_hook(skill, 'OnFinish', cast_ctx)
      end)
      return true, string.format('[%s] area_tick %d tick', skill.id, tick_count)
    end

    if skill.pattern == 'chain_bounce' then
      if not target then
        return false, '附近没有可攻击目标。'
      end
      local chain_targets = { target }
      local extra = get_enemies_in_range and get_enemies_in_range(target, skill.hit_model.radius, target, skill.hit_model.bounce) or {}
      for _, unit in ipairs(extra) do
        chain_targets[#chain_targets + 1] = unit
      end
      chain_targets = dedupe_units(chain_targets)
      local base = damage_amount(skill, 'attack_ratio')
      local fx_scale = impact_fx_scale(skill)
      fire_hook(skill, 'OnSpellStart', cast_ctx)
      spawn_particle(y3, target, visual_key(skill, 'cast'), fx_scale, 0.20, 28)
      -- 投射物仅作视觉装饰，伤害立即结算，避免目标在飞行期间被击杀导致落空。
      launch_projectile_from_hero(
        visual_key(skill, 'projectile_key'),
        target,
        nil,
        nil,
        resolve_impact_delay(skill),
        visual_key(skill, 'projectile_height')
      )
      mark_visual_impact(cast_ctx)
      local total_damage = 0
      cast_ctx.hits = skill_damage_api.chain(chain_targets, base, skill.damage_type, {
        amount = function(context)
          local idx = context.index or 1
          local amount = base * math.pow(skill.scale.bounce_ratio, math.max(0, idx - 1))
          total_damage = total_damage + math.max(0, tonumber(amount) or 0)
          return amount
        end,
        visual = function()
          return {
            particle = visual_key(skill, 'hit'),
            metric_scope = 'skill_framework',
            metric_key = skill.id,
          }
        end,
        on_hit = function(context)
          cast_ctx.bounce_index = context.index
          cast_ctx.hit_unit = context.target
          if context.target then
            spawn_particle(y3, context.target, visual_key(skill, 'impact') or visual_key(skill, 'hit'), fx_scale, 0.16, 26)
          end
          fire_hook(skill, 'OnProjectileHit', cast_ctx)
        end,
      })
      cast_ctx.hit_count = #(cast_ctx.hits or {})
      cast_ctx.total_damage = total_damage
      mark_damage_impact(cast_ctx)
      fire_hook(skill, 'OnFinish', cast_ctx)
      return true, string.format('[%s] chain_bounce 触发', skill.id)
    end

    return false, '不支持的技能 pattern。'
  end

  local function validate_cast(skill, caster, hero_point)
    if not caster or not hero_point then
      return false, '英雄不存在。'
    end
    if not VALID_DAMAGE_TYPE[skill.damage_type] then
      return false, string.format('[%s] damage_type 非法', skill.id)
    end
    if skill.hit_model.range <= 0 then
      return false, string.format('[%s] range 非法', skill.id)
    end
    return true
  end

  function api.cast(def, cast_params)
    if not skill_damage_api then
      return false, 'skill_damage_api 未初始化。'
    end
    local caster = get_hero and get_hero()
    local hero_point = get_hero_point and get_hero_point()
    if not caster or not hero_point then
      return false, '英雄不存在。'
    end
    local skill = normalize_skill(def)
    apply_production_limits(skill)
    local visual_ok, visual_reason = validate_visual_config(skill)
    if not visual_ok then
      return false, visual_reason
    end
    local telemetry = telemetry_of(skill.id)
    telemetry.cast_count = telemetry.cast_count + 1
    telemetry.last_cast_time = now()
    if (tonumber(telemetry.first_cast_time) or 0) <= 0 then
      telemetry.first_cast_time = telemetry.last_cast_time
    end
    if (telemetry.last_cast_time - (runtime.global_last_cast_time or 0)) < GLOBAL_CAST_GCD then
      telemetry.fail_count = telemetry.fail_count + 1
      telemetry.last_reason = 'global_cast_gcd'
      return false, string.format('[%s] 施法过快', skill.id)
    end
    local valid, reason = validate_cast(skill, caster, hero_point)
    if not valid then
      telemetry.fail_count = telemetry.fail_count + 1
      telemetry.last_reason = reason or 'validate_failed'
      return false, reason
    end
    local st = state_of(skill.id)
    ensure_charges(skill, st)
    if in_cooldown(st) and skill.resource.charges <= 0 then
      telemetry.fail_count = telemetry.fail_count + 1
      telemetry.last_reason = 'cooldown'
      return false, string.format('[%s] 冷却中', skill.id)
    end
    if not consume_charge_or_cooldown(skill, st) then
      telemetry.fail_count = telemetry.fail_count + 1
      telemetry.last_reason = 'no_charge'
      return false, string.format('[%s] 充能不足', skill.id)
    end

    local target, impact_point = resolve_target(skill, caster, hero_point, cast_params)
    if skill.behavior.unit_target and skill.pattern ~= 'line_pierce' and not target then
      telemetry.fail_count = telemetry.fail_count + 1
      telemetry.last_reason = 'no_target'
      return false, string.format('[%s] 没有可用目标', skill.id)
    end

    local cast_ctx = {
      skill = skill,
      caster = caster,
      origin_point = hero_point,
      target = target,
      impact_point = impact_point or hero_point,
      cast_time = now(),
    }
    runtime.global_last_cast_time = cast_ctx.cast_time
    st.last_cast_time = cast_ctx.cast_time
    runtime.active_casts[#runtime.active_casts + 1] = cast_ctx

    if skill.timeline.cast_point > 0 then
      y3.ltimer.wait(skill.timeline.cast_point, function()
        local ok, msg = execute_pattern(cast_ctx)
        if ok then
          telemetry.success_count = telemetry.success_count + 1
          telemetry.total_hits = telemetry.total_hits + (cast_ctx.hit_count or 0)
          telemetry.total_damage = telemetry.total_damage + (cast_ctx.total_damage or 0)
          telemetry.timing_drift_ms_total = (tonumber(telemetry.timing_drift_ms_total) or 0) + (tonumber(cast_ctx.timing_drift_ms) or 0)
          telemetry.timing_sample_count = (tonumber(telemetry.timing_sample_count) or 0) + (((tonumber(cast_ctx.timing_drift_ms) or 0) > 0) and 1 or 0)
          if (cast_ctx.hit_count or 0) <= 0 then
            telemetry.empty_cast_count = telemetry.empty_cast_count + 1
          end
          telemetry.last_reason = msg or 'ok'
        else
          telemetry.fail_count = telemetry.fail_count + 1
          telemetry.last_reason = msg or 'execute_failed'
        end
      end)
      return true, string.format('[%s] 开始施法 cast_point=%.2f', skill.id, skill.timeline.cast_point)
    end
    local ok, msg = execute_pattern(cast_ctx)
    if ok then
      telemetry.success_count = telemetry.success_count + 1
      telemetry.total_hits = telemetry.total_hits + (cast_ctx.hit_count or 0)
      telemetry.total_damage = telemetry.total_damage + (cast_ctx.total_damage or 0)
      telemetry.timing_drift_ms_total = (tonumber(telemetry.timing_drift_ms_total) or 0) + (tonumber(cast_ctx.timing_drift_ms) or 0)
      telemetry.timing_sample_count = (tonumber(telemetry.timing_sample_count) or 0) + (((tonumber(cast_ctx.timing_drift_ms) or 0) > 0) and 1 or 0)
      if (cast_ctx.hit_count or 0) <= 0 then
        telemetry.empty_cast_count = telemetry.empty_cast_count + 1
      end
      telemetry.last_reason = msg or 'ok'
    else
      telemetry.fail_count = telemetry.fail_count + 1
      telemetry.last_reason = msg or 'execute_failed'
    end
    return ok, msg
  end

  function api.register(def)
    local skill = normalize_skill(def)
    apply_production_limits(skill)
    local visual_ok, visual_reason = validate_visual_config(skill)
    if not visual_ok then
      return false, visual_reason
    end
    return registry.register(skill)
  end

  function api.cast_by_id(skill_id, cast_params)
    local def = registry.get(skill_id)
    if not def then
      return false, string.format('未注册技能：%s', tostring(skill_id))
    end
    return api.cast(def, cast_params)
  end

  function api.list_registered()
    return registry.list()
  end

  function api.get_skill_state(skill_id)
    local st = state_of(skill_id)
    return {
      cooldown_left = math.max(0, (st.cooldown_end or 0) - now()),
      charges = st.charges or 0,
      max_charges = st.max_charges or 0,
      last_cast_time = st.last_cast_time or 0,
    }
  end

  function api.get_telemetry(skill_id)
    local t = telemetry_of(skill_id)
    local cast_count = math.max(1, t.cast_count)
    local first_cast_time = tonumber(t.first_cast_time) or 0
    local last_cast_time = tonumber(t.last_cast_time) or 0
    local active_span = math.max(0.01, last_cast_time - first_cast_time)
    local success_count = tonumber(t.success_count) or 0
    local total_hits = tonumber(t.total_hits) or 0
    local total_damage = tonumber(t.total_damage) or 0
    local timing_samples = math.max(0, tonumber(t.timing_sample_count) or 0)
    local timing_drift_ms_avg = timing_samples > 0 and ((tonumber(t.timing_drift_ms_total) or 0) / timing_samples) or 0
    return {
      cast_count = t.cast_count,
      success_count = t.success_count,
      fail_count = t.fail_count,
      total_hits = t.total_hits,
      empty_cast_count = t.empty_cast_count,
      total_damage = t.total_damage,
      avg_hits_per_cast = t.total_hits / cast_count,
      empty_cast_rate = t.empty_cast_count / cast_count,
      last_reason = t.last_reason,
      first_cast_time = t.first_cast_time,
      last_cast_time = t.last_cast_time,
      active_span = active_span,
      casts_per_sec = success_count / active_span,
      hits_per_sec = total_hits / active_span,
      dmg_per_sec = total_damage / active_span,
      timing_drift_ms_avg = timing_drift_ms_avg,
    }
  end

  function api.get_all_telemetry()
    local result = {}
    for skill_id, _ in pairs(runtime.telemetry or {}) do
      result[#result + 1] = api.get_telemetry(skill_id)
      result[#result].skill_id = skill_id
    end
    table.sort(result, function(a, b)
      local aid = tostring(a and a.skill_id or '')
      local bid = tostring(b and b.skill_id or '')
      return aid < bid
    end)
    return result
  end

  function api.reset_telemetry(skill_id)
    if skill_id and skill_id ~= '' then
      runtime.telemetry[tostring(skill_id)] = nil
      return
    end
    runtime.telemetry = {}
  end

  function api.normalize_skill(def)
    return normalize_skill(def)
  end

  function api.validate_damage_type(value)
    return VALID_DAMAGE_TYPE[value] == true
  end

  return api
end

return M


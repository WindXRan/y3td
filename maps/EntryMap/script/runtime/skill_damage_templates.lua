local M = {}

local function default_is_enemy(unit)
  return unit and unit.is_exist and unit:is_exist()
end

local function shallow_copy_table(source)
  local result = {}
  for key, value in pairs(source or {}) do
    result[key] = value
  end
  return result
end

local function with_visual_debug(raw_visual, patch)
  local visual = shallow_copy_table(raw_visual)
  for key, value in pairs(patch or {}) do
    visual[key] = value
  end
  return visual
end

local function resolve_value(value, context, ...)
  if type(value) == 'function' then
    return value(context, ...)
  end
  return value
end

function M.create(env)
  env = env or {}
  local y3 = env.y3
  local deal_skill_damage = env.deal_skill_damage or function() end
  local get_enemies_in_range = env.get_enemies_in_range or function()
    return {}
  end
  local get_enemies_on_line = env.get_enemies_on_line
  local is_active_enemy = env.is_active_enemy or default_is_enemy
  local emit_damage_debug = env.emit_damage_debug

  local api = {}
  local debug_event_seq = 0

  local function next_debug_uid(prefix)
    debug_event_seq = debug_event_seq + 1
    return string.format('%s_%d', prefix or 'skill', debug_event_seq)
  end

  function api.single(target, amount, damage_meta, visual)
    if not target or not target.is_exist or not target:is_exist() then
      return false
    end
    if env and env.STATE and env.STATE.hero and env.STATE.hero.is_exist and env.STATE.hero:is_exist()
      and target == env.STATE.hero then
      return false
    end
    local enemy_ok = is_active_enemy(target)
    if not enemy_ok and env and env.STATE and env.STATE.hero and env.STATE.hero.is_exist and env.STATE.hero:is_exist()
      and env.STATE.hero.is_enemy then
      local ok, is_enemy_to_hero = pcall(env.STATE.hero.is_enemy, env.STATE.hero, target)
      enemy_ok = ok and is_enemy_to_hero == true
    end
    if not enemy_ok then
      return false
    end
    deal_skill_damage(target, amount, damage_meta, visual)
    return true
  end

  function api.area(center, radius, amount, damage_meta, options)
    if not center or (tonumber(radius) or 0) <= 0 then
      return {}
    end
    options = options or {}
    local hits = {}
    local normalized_radius = math.max(1, tonumber(radius) or 0)
    local debug_uid = tostring(options.debug_uid or next_debug_uid('area'))
    local area_visual = with_visual_debug(options.visual, {
      debug_kind = 'area',
      debug_uid = debug_uid,
      debug_center = center,
      debug_radius = normalized_radius,
      debug_hit_radius = tonumber(options.debug_hit_radius) or 70,
    })
    if type(emit_damage_debug) == 'function' then
      emit_damage_debug(area_visual)
    end
    local units = get_enemies_in_range(center, radius, options.except_unit, options.max_count) or {}
    for _, unit in ipairs(units) do
      local hit_visual = with_visual_debug(area_visual)
      if api.single(unit, amount, damage_meta, hit_visual) then
        hits[#hits + 1] = unit
      end
    end
    return hits
  end

  function api.chain(targets, amount, damage_meta, options)
    options = options or {}
    local source = targets
    if source == nil then
      source = options.targets
    end
    if type(source) == 'function' then
      source = source()
    end
    if type(source) ~= 'table' then
      return {}
    end

    local hits = {}
    local total = #source
    for index, target in ipairs(source) do
      local context = {
        index = index,
        total = total,
        target = target,
        amount = amount,
        damage_meta = damage_meta,
      }
      local resolved_amount = resolve_value(options.amount, context)
      if resolved_amount == nil then
        resolved_amount = amount
      end
      context.amount = resolved_amount
      context.visual = resolve_value(options.visual, context)

      if not options.before_hit or options.before_hit(context) ~= false then
        if api.single(target, resolved_amount, damage_meta, context.visual) then
          hits[#hits + 1] = target
          context.hit_count = #hits
          if options.on_hit then
            options.on_hit(context)
          end
        end
      end
      if options.should_stop and options.should_stop(context) then
        break
      end
    end
    return hits
  end

  function api.line(origin_point, impact_point, amount, damage_meta, options)
    if not origin_point or not impact_point then
      return {}
    end
    options = options or {}
    local line_width = math.max(40, tonumber(options.line_width) or 95)
    local debug_uid = tostring(options.debug_uid or next_debug_uid('line'))
    local line_visual = with_visual_debug(options.visual, {
      debug_kind = 'line',
      debug_uid = debug_uid,
      debug_line_origin = origin_point,
      debug_line_impact = impact_point,
      debug_line_width = line_width,
      debug_hit_radius = tonumber(options.debug_hit_radius) or math.max(70, math.floor(line_width * 0.55)),
    })
    if type(emit_damage_debug) == 'function' then
      emit_damage_debug(line_visual)
    end
    local units = {}
    if type(options.collect_units) == 'function' then
      units = options.collect_units(
        origin_point,
        impact_point,
        options.max_distance,
        options.line_width,
        options.max_hits,
        options.except_unit
      ) or {}
    elseif type(get_enemies_on_line) == 'function' then
      units = get_enemies_on_line(
        origin_point,
        impact_point,
        options.max_distance,
        options.line_width,
        options.max_hits,
        options.except_unit
      ) or {}
    end

    local hits = {}
    for _, unit in ipairs(units) do
      local hit_visual = with_visual_debug(line_visual)
      if api.single(unit, amount, damage_meta, hit_visual) then
        hits[#hits + 1] = unit
      end
    end
    return hits
  end

  function api.ticks(interval, tick_count, callback)
    local count = math.max(1, math.floor(tonumber(tick_count) or 1))
    local dt = math.max(0.01, tonumber(interval) or 0.1)
    if y3 and y3.ltimer and y3.ltimer.loop_count then
      y3.ltimer.loop_count(dt, count, function(_, current)
        callback(current, count)
      end)
      return
    end
    for current = 1, count do
      callback(current, count)
    end
  end

  function api.area_ticks(interval, tick_count, damage_meta, options)
    options = options or {}
    api.ticks(interval, tick_count, function(current, total)
      local context = {
        current = current,
        total = total,
        damage_meta = damage_meta,
      }
      context.center = resolve_value(options.center, context)
      context.radius = resolve_value(options.radius, context)
      context.amount = resolve_value(options.amount, context)
      context.except_unit = resolve_value(options.except_unit, context)
      context.max_count = resolve_value(options.max_count, context)
      context.visual = resolve_value(options.visual, context)

      if options.before_tick and options.before_tick(context) == false then
        return
      end

      context.hits = api.area(context.center, context.radius, context.amount, damage_meta, {
        except_unit = context.except_unit,
        max_count = context.max_count,
        visual = context.visual,
      })

      if options.on_hit then
        for hit_index, unit in ipairs(context.hits) do
          context.hit_index = hit_index
          context.hit_unit = unit
          options.on_hit(context)
        end
      end

      if options.after_tick then
        options.after_tick(context)
      end
    end)
    return true
  end

  function api.line_ticks(interval, tick_count, damage_meta, options)
    options = options or {}
    api.ticks(interval, tick_count, function(current, total)
      local context = {
        current = current,
        total = total,
        damage_meta = damage_meta,
      }
      context.origin_point = resolve_value(options.origin, context)
      context.impact_point = resolve_value(options.impact, context)
      context.amount = resolve_value(options.amount, context)
      context.max_distance = resolve_value(options.max_distance, context)
      context.line_width = resolve_value(options.line_width, context)
      context.max_hits = resolve_value(options.max_hits, context)
      context.except_unit = resolve_value(options.except_unit, context)
      context.collect_units = resolve_value(options.collect_units, context)
      context.visual = resolve_value(options.visual, context)

      if options.before_tick and options.before_tick(context) == false then
        return
      end

      context.hits = api.line(context.origin_point, context.impact_point, context.amount, damage_meta, {
        max_distance = context.max_distance,
        line_width = context.line_width,
        max_hits = context.max_hits,
        except_unit = context.except_unit,
        collect_units = context.collect_units,
        visual = context.visual,
      })

      if options.on_hit then
        for hit_index, unit in ipairs(context.hits) do
          context.hit_index = hit_index
          context.hit_unit = unit
          options.on_hit(context)
        end
      end

      if options.after_tick then
        options.after_tick(context)
      end
    end)
    return true
  end

  return api
end

return M

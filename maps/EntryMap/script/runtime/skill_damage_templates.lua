local M = {}

local function default_is_enemy(unit)
  return unit and unit.is_exist and unit:is_exist()
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

  local api = {}

  function api.single(target, amount, damage_meta, visual)
    if not target or not target.is_exist or not target:is_exist() then
      return false
    end
    if not is_active_enemy(target) then
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
    local units = get_enemies_in_range(center, radius, options.except_unit, options.max_count) or {}
    for _, unit in ipairs(units) do
      if api.single(unit, amount, damage_meta, options.visual) then
        hits[#hits + 1] = unit
      end
    end
    return hits
  end

  function api.line(origin_point, impact_point, amount, damage_meta, options)
    if not origin_point or not impact_point then
      return {}
    end
    options = options or {}
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
      if api.single(unit, amount, damage_meta, options.visual) then
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

  return api
end

return M

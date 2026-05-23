local CONFIG = _G.CONFIG
pcall(require, 'runtime.core.boot_utils')
local BootHelpers = _G.BootHelpers or {}

local M = {}

function M.get_enemies_in_range(center, radius, except_unit, max_count)
  local result = {}
  local selector = y3.selector.create()
      :is_enemy(y3.player.get_main_player())
      :in_range(center, radius)
      :sort_type('由近到远')

  if max_count and max_count > 0 then
    selector:count(max_count + (except_unit and 1 or 0))
  end

  local picked = selector:pick()

  for _, unit in ipairs(picked) do
    if unit ~= except_unit and unit ~= STATE.hero and M.is_active_enemy(unit) then
      result[#result + 1] = unit
    end
  end

  return result
end

function M.get_enemies_on_line(origin_point, impact_point, max_distance, line_width, max_hits, except_unit)
  local result = {}
  if not origin_point or not impact_point then
    return result
  end
  local normalized_max_hits = nil
  if type(max_hits) == 'string' then
    local lowered = string.lower(max_hits)
    if lowered ~= 'max' and lowered ~= 'all' and lowered ~= '' then
      normalized_max_hits = tonumber(max_hits)
    end
  else
    normalized_max_hits = tonumber(max_hits)
  end
  if normalized_max_hits and normalized_max_hits <= 0 then
    return result
  end

  local ox = origin_point:get_x()
  local oy = origin_point:get_y()
  local tx = impact_point:get_x()
  local ty = impact_point:get_y()
  local dir_x = tx - ox
  local dir_y = ty - oy
  local length = origin_point:get_distance_with(impact_point)
  if length < 1 then
    return result
  end

  local reach = math.max(length, max_distance or length)
  local width = math.max(40, line_width or 95)
  local start_projection = math.max(0, length - width)
  local segment_length = reach - start_projection
  if segment_length <= 0 then
    return result
  end

  local direction = origin_point:get_angle_with(impact_point)
  local segment_center = y3.point.get_point_offset_vector(
    origin_point,
    direction,
    start_projection + segment_length / 2
  )
  local line_shape = y3.shape.create_rectangle_shape(width * 2, segment_length, direction)
  local candidates = {}
  local picked = y3.selector.create()
      :is_enemy(y3.player.get_main_player())
      :in_shape(segment_center, line_shape)
      :pick()

  for _, unit in ipairs(picked) do
    if unit ~= except_unit and M.is_active_enemy(unit) then
      local point = unit:get_point()
      candidates[#candidates + 1] = {
        unit = unit,
        projection = ((point:get_x() - ox) * dir_x + (point:get_y() - oy) * dir_y) / length,
      }
    end
  end

  table.sort(candidates, function(a, b)
    return a.projection < b.projection
  end)

  local limit = normalized_max_hits and math.min(math.max(1, math.floor(normalized_max_hits)), #candidates) or
      #candidates
  for index = 1, limit, 1 do
    result[#result + 1] = candidates[index].unit
  end

  return result
end

function M.get_ui_preferences()
  return STATE and STATE.ui_preferences or {}
end

function M.is_hit_effect_hidden()
  return M.get_ui_preferences().hide_hit_effects == true
end

function M.get_target_hp_ratio(target)
  if not target or not target:is_exist() then
    return 1
  end
  local max_hp = y3.helper.tonumber(target:get_attr('生命')) or y3.helper.tonumber(target:get_attr('hp_max')) or 0
  if max_hp <= 0 then
    return 1
  end
  return math.max(0, (target:get_hp() or 0) / max_hp)
end

function M.get_unit_point_snapshot(unit)
  if not unit or not unit.is_exist or not unit:is_exist() then
    return nil
  end
  local point = unit:get_point()
  if not point or not point.move then
    return nil
  end
  return point:move()
end

function M.get_unit_max_hp(unit)
  if not unit or not unit.is_exist or not unit:is_exist() then
    return 0
  end
  return y3.helper.tonumber(unit:get_attr('生命')) or y3.helper.tonumber(unit:get_attr('hp_max')) or 0
end

function M.normalize_ratio(value)
  local number = y3.helper.tonumber(value) or 0
  if math.abs(number) > 1 then
    return number / 100
  end
  return number
end

function M.get_hero_attr_value(name)
  if not STATE or not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
    return 0
  end
  return y3.helper.tonumber(STATE.hero:get_attr(name)) or 0
end

function M.get_hero_attr_ratio(name)
  return M.normalize_ratio(M.get_hero_attr_value(name))
end

function M.is_active_enemy(unit)
  return battlefield_system and battlefield_system.is_active_enemy and battlefield_system.is_active_enemy(unit) or false
end

function M.get_enemy_runtime_info(unit)
  return battlefield_system and battlefield_system.get_enemy_runtime_info and battlefield_system.get_enemy_runtime_info(unit) or nil
end

function M.is_boss_runtime_enemy(info)
  return battlefield_system and battlefield_system.is_boss_runtime_enemy and battlefield_system.is_boss_runtime_enemy(info) or false
end

function M.is_elite_runtime_enemy(info)
  return battlefield_system and battlefield_system.is_elite_runtime_enemy and battlefield_system.is_elite_runtime_enemy(info) or false
end

function M.get_combat_bonus(key)
  local evolution_runtime = STATE and STATE.evolution_runtime
  local evolution_bonus = 0
  if evolution_runtime and evolution_runtime.applied and evolution_runtime.applied.runtime then
    evolution_bonus = evolution_runtime.applied.runtime[key] or 0
  end
  return evolution_bonus
end

function M.try_trigger_hunter_first_hit(target)
  local bonus = M.get_combat_bonus('hunter_first_hit')
  return bonus and bonus > 0 or false
end

function M.get_target_point(unit)
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

function M.get_hero_attack()
  if not STATE.hero or not STATE.hero:is_exist() then
    return 0
  end
  return STATE.hero:get_attr('攻击') or 0
end

function M.get_current_hero()
  if STATE.hero and STATE.hero:is_exist() then
    return STATE.hero
  end
  return nil
end

function M.get_hero_point()
  if not STATE.hero or not STATE.hero:is_exist() then
    return nil
  end
  return STATE.hero:get_point()
end

function M.get_primary_target(range)
  local units = M.get_enemies_in_range(STATE.hero, range or 1200, nil, 1)
  return units and units[1] or nil
end

function M.spawn_particle(_, point, effect_id, scale, duration, height)
  if not effect_id or not point then
    return nil
  end
  local ok, particle = pcall(y3.particle.create, {
    type = effect_id,
    target = point,
    angle = 0,
    scale = scale or 1.0,
    time = duration or 0.3,
    height = height or 0,
  })
  if ok and particle then
    return particle
  end
  return nil
end

function M.launch_projectile_from_hero(projectile_key, target, end_point, angle, time, height, on_finish)
  if projectile_key == 134232384 then
    print('[DEBUG] launch_projectile_from_hero called for ice_bird: projectile_key=', projectile_key, 'time=', time, 'height=', height, 'target exists:', target and target.is_exist and target:is_exist(), 'STATE.hero exists:', STATE.hero and STATE.hero:is_exist())
  end
  if not projectile_key or not STATE.hero or not STATE.hero:is_exist() then
    if on_finish then on_finish(nil) end
    return nil
  end
  local ok, proj = pcall(y3.projectile.create, {
    key = projectile_key,
    target = STATE.hero,
    socket = 'origin',
    owner = STATE.hero,
    angle = angle or 0,
    time = time or 0.92,
    remove_immediately = true,
  })
  if projectile_key == 134232384 then
    print('[DEBUG] ice_bird projectile create result: ok=', ok, 'proj=', proj)
  end
  if not ok or not proj then
    if on_finish then on_finish(nil) end
    return nil
  end
  if height then
    pcall(proj.set_height, proj, height)
  end
  local dest = (target and target:is_exist() and target) or end_point
  if projectile_key == 134232384 then
    print('[DEBUG] ice_bird dest: ', dest, 'is unit:', dest and dest.is_exist ~= nil, 'is point:', dest and type(dest) == 'table' and dest.x)
  end
  if dest then
    local mover_ok, mover_err = pcall(proj.mover_target, proj, {
      target = dest,
      speed = 1500,
      target_distance = 36,
      height = height or 100,
      face_angle = true,
      on_finish = function()
        local impact_pt = proj and proj:is_exist() and proj:get_point()
        if projectile_key == 134232384 then
          print('[DEBUG] ice_bird projectile on_finish called: impact_pt=', impact_pt)
        end
        if proj and proj:is_exist() then
          proj:remove()
        end
        if on_finish then on_finish(impact_pt) end
      end,
    })
    if projectile_key == 134232384 then
      print('[DEBUG] ice_bird mover_target result: ok=', mover_ok, 'err=', mover_err)
    end
  elseif on_finish then
    on_finish(nil)
  end
  return proj
end

local heal_hero_func = nil
local sync_basic_attack_ability_func = nil
local get_enemies_in_range_func = nil

function M.set_heal_hero(func)
  heal_hero_func = func
end

function M.set_sync_basic_attack_ability(func)
  sync_basic_attack_ability_func = func
end

function M.set_get_enemies_in_range(func)
  get_enemies_in_range_func = func
end

return M

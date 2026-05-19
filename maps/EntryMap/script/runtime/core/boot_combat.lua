local CONFIG = require 'config.entry_config'
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers

local M = {}

local DAMAGE_AREA_DEBUG_EFFECT_ID = 101492
local DAMAGE_AREA_DEBUG_SCALE_BASE = 110
local DAMAGE_AREA_DEBUG_HEIGHT = 8
local DAMAGE_DEBUG_UID_WINDOW = 0.08
local SKILL_DAMAGE_REENTRANT_GUARD_LIMIT = 96

function M.get_enemies_in_range(center, radius, except_unit, max_count)
  local result = {}
  local selector = y3.selector.create()
      :is_enemy(BootHelpers.get_player())
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
      :is_enemy(BootHelpers.get_player())
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

function M.is_damage_text_hidden()
  return M.get_ui_preferences().hide_damage_text == true
end

function M.is_hit_effect_hidden()
  return M.get_ui_preferences().hide_hit_effects == true
end

function M.resolve_runtime_text_type(text_type)
  if M.is_damage_text_hidden() then
    return nil
  end
  return text_type
end

function M.resolve_damage_text_type(damage_form, visual)
  if visual and visual.text_type then
    return visual.text_type
  end

  if damage_form == 'weapon' then
    return 'physics'
  end

  return 'magic'
end

function M.resolve_damage_text_track(damage_type, is_critical, fallback_track)
  if M.is_damage_text_hidden() then
    return nil
  end

  if is_critical then
    if damage_type == 'physics' or damage_type == '物理伤害' then
      return y3.const.FloatTextJumpType["物理暴击_中上"] or fallback_track or 934300033
    elseif damage_type == 'magic' or damage_type == '魔法伤害' then
      return y3.const.FloatTextJumpType["魔法暴击_中上"] or fallback_track or 934500033
    end
  else
    if damage_type == 'physics' or damage_type == '物理伤害' then
      return y3.const.FloatTextJumpType["伤害_中上"] or fallback_track or 934269508
    elseif damage_type == 'magic' or damage_type == '魔法伤害' then
      return y3.const.FloatTextJumpType["魔法伤害_中上"] or fallback_track or 934400033
    end
  end

  return fallback_track or 934269508
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
  local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name) or STATE.hero:get_attr(name)
  return y3.helper.tonumber(value) or 0
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

function M.get_bond_runtime_bonus(key)
  local evolution_runtime = STATE and STATE.evolution_runtime
  local evolution_bonus = 0
  if evolution_runtime and evolution_runtime.applied and evolution_runtime.applied.runtime then
    evolution_bonus = evolution_runtime.applied.runtime[key] or 0
  end
  return evolution_bonus
end

M.get_combat_bonus = M.get_bond_runtime_bonus

function M.try_trigger_hunter_first_hit(target)
  local bonus = M.get_combat_bonus('hunter_first_hit')
  return bonus and bonus > 0 or false
end

function M.get_damage_bonus_multiplier(target, context)
  local multiplier = 1
  multiplier = multiplier * (1 + M.get_combat_bonus('all_damage_bonus'))

  if context and context.is_skill then
    multiplier = multiplier * (1 + M.get_combat_bonus('skill_damage_bonus'))
  end
  if context and context.is_basic_attack then
    multiplier = multiplier * (1 + M.get_combat_bonus('normal_attack_damage_bonus'))
  end

  local info = M.get_enemy_runtime_info(target)
  if M.is_boss_runtime_enemy(info) then
    multiplier = multiplier * (1 + M.get_combat_bonus('boss_damage_bonus'))
  end
  if M.is_elite_runtime_enemy(info) then
    multiplier = multiplier * (1 + M.get_combat_bonus('elite_damage_bonus'))
  end
  if info and info.kind == 'challenge' then
    multiplier = multiplier * (1 + M.get_combat_bonus('challenge_damage_bonus'))
  end

  local execute_threshold = M.get_combat_bonus('execute_threshold')
  if execute_threshold > 0 and M.get_target_hp_ratio(target) <= execute_threshold then
    multiplier = multiplier * (1 + M.get_combat_bonus('execute_damage_bonus'))
  end

  if info and info.status then
    local armor_break = info.status.armor_break
    if armor_break and (armor_break.stacks or 0) > 0 and (armor_break.ratio or 0) > 0 then
      multiplier = multiplier * (1 + armor_break.ratio * armor_break.stacks)
    end

    local shock = info.status.shock
    if shock and (shock.bonus or 0) > 0 then
      multiplier = multiplier * (1 + shock.bonus)
    end
  end

  return multiplier
end

function M.should_show_damage_area_debug()
  if STATE and STATE.debug_show_damage_area == true then
    return true
  end
  return y3 and y3.game and y3.game.is_debug_mode and y3.game.is_debug_mode() or false
end

function M.show_damage_area_indicator(center, radius, duration)
  if not M.should_show_damage_area_debug() or not center or (tonumber(radius) or 0) <= 0 then
    return
  end
  local scale = math.max(0.6, (tonumber(radius) or 0) / DAMAGE_AREA_DEBUG_SCALE_BASE)
  local forced = tonumber(STATE and STATE.debug_force_projectile_key) or 0
  local key = forced > 0 and math.floor(forced) or 201392033
  pcall(y3.projectile.create, {
    key = key,
    target = center,
    socket = 'origin',
    owner = STATE and STATE.hero or nil,
    angle = 0,
    time = duration or 0.30,
    remove_immediately = true,
  })
end

function M.get_damage_debug_time()
  if y3 and y3.game and y3.game.current_game_run_time then
    return tonumber(y3.game.current_game_run_time()) or 0
  end
  return os.clock and os.clock() or 0
end

function M.should_emit_damage_debug_uid(uid)
  if not uid or uid == '' then
    return true
  end
  STATE.damage_debug_uid_time = STATE.damage_debug_uid_time or {}
  local now = M.get_damage_debug_time()
  local last = tonumber(STATE.damage_debug_uid_time[uid]) or -1
  if last >= 0 and (now - last) < DAMAGE_DEBUG_UID_WINDOW then
    return false
  end
  STATE.damage_debug_uid_time[uid] = now
  return true
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

function M.resolve_debug_point(anchor)
  if not anchor then
    return nil
  end
  if anchor.get_x and anchor.get_y then
    return anchor
  end
  if anchor.get_point then
    local ok, point = pcall(function()
      return anchor:get_point()
    end)
    if ok then
      return point
    end
  end
  return nil
end

function M.show_damage_line_indicator(origin, impact, width, duration)
  if not M.should_show_damage_area_debug() then
    return
  end
  local origin_point = M.resolve_debug_point(origin)
  local impact_point = M.resolve_debug_point(impact)
  local line_width = math.max(50, tonumber(width) or 120)
  if not origin_point or not impact_point then
    M.show_damage_area_indicator(impact_point or origin_point, line_width, duration or 0.18)
    return
  end

  local distance = origin_point.get_distance_with and origin_point:get_distance_with(impact_point) or 0
  if distance <= 0 then
    M.show_damage_area_indicator(impact_point, line_width, duration or 0.18)
    return
  end
  local angle = origin_point.get_angle_with and origin_point:get_angle_with(impact_point) or 0
  local marker_step = math.max(130, math.min(320, line_width * 1.7))
  local marker_count = math.max(2, math.min(8, math.floor(distance / marker_step) + 1))

  for index = 0, marker_count, 1 do
    local travel = distance * (index / marker_count)
    local marker = nil
    if y3 and y3.point and y3.point.get_point_offset_vector then
      marker = y3.point.get_point_offset_vector(origin_point, angle, travel)
    end
    if not marker and y3 and y3.point and y3.point.create and origin_point.get_x and origin_point.get_y then
      local ox = origin_point:get_x()
      local oy = origin_point:get_y()
      local oz = origin_point.get_z and origin_point:get_z() or 0
      marker = y3.point.create(ox + math.cos(angle) * travel, oy + math.sin(angle) * travel, oz)
    end
    M.show_damage_area_indicator(marker, line_width, duration or 0.18)
  end
end

function M.emit_damage_debug_visual(visual, fallback_target)
  if not visual or not visual.debug_kind then
    return
  end
  local debug_uid = tostring(visual.debug_uid or '')
  if visual.debug_kind == 'area' then
    local center = M.resolve_debug_point(visual.debug_center) or
        (fallback_target and M.get_target_point(fallback_target) or nil)
    local radius = math.max(50, tonumber(visual.debug_radius) or 70)
    local area_uid = debug_uid ~= '' and ('area:' .. debug_uid) or nil
    if M.should_emit_damage_debug_uid(area_uid) then
      M.show_damage_area_indicator(center, radius, tonumber(visual.debug_duration) or 0.20)
    end
  elseif visual.debug_kind == 'line' then
    local line_uid = debug_uid ~= '' and ('line:' .. debug_uid) or nil
    if M.should_emit_damage_debug_uid(line_uid) then
      M.show_damage_line_indicator(
        visual.debug_line_origin,
        visual.debug_line_impact,
        tonumber(visual.debug_line_width) or 120,
        tonumber(visual.debug_duration) or 0.20
      )
    end
  end
end

function M.show_damage_debug_indicator(target, visual)
  local hit_radius = tonumber(visual and visual.debug_hit_radius)
  if not hit_radius or hit_radius <= 0 then
    hit_radius = (visual and visual.debug_kind) and 70 or (tonumber(visual and visual.debug_radius) or 70)
  end
  M.show_damage_area_indicator(M.get_target_point(target), hit_radius, 0.24)
  M.emit_damage_debug_visual(visual, target)
end

function M.emit_skill_hit_feedback(target, final_damage, hp_before)
  if not target then
    return
  end
  local now = M.get_damage_debug_time()
  STATE.skill_hit_feedback = STATE.skill_hit_feedback or {
    combo = 0,
    combo_window_end = 0,
    next_prompt_time = 0,
    next_heavy_fx_time = 0,
  }
  local stat = STATE.skill_hit_feedback
  if now <= (stat.combo_window_end or 0) then
    stat.combo = (stat.combo or 0) + 1
  else
    stat.combo = 1
  end
  stat.combo_window_end = now + 0.45

  local killed = (tonumber(hp_before) or 0) > 0 and (tonumber(final_damage) or 0) >= (tonumber(hp_before) or 0)
  local heavy = (tonumber(final_damage) or 0) >= math.max(120, (tonumber(hp_before) or 0) * 0.35)
  if heavy and now >= (stat.next_heavy_fx_time or 0) then
    local hit_point = M.get_target_point(target)
    if hit_point then
      local forced = tonumber(STATE and STATE.debug_force_projectile_key) or 0
      local key = forced > 0 and math.floor(forced) or 201392033
      pcall(y3.projectile.create, {
        key = key,
        target = hit_point,
        socket = 'origin',
        owner = STATE and STATE.hero or nil,
        angle = 0,
        time = 0.08,
        remove_immediately = true,
      })
    end
    stat.next_heavy_fx_time = now + 0.12
  end

  if now < (stat.next_prompt_time or 0) then
    return
  end
  if killed then
    if BattleEventPrompts and BattleEventPrompts.push_battle_event then
      BattleEventPrompts.push_battle_event('斩杀!', 'good', 0.45)
    end
    stat.next_prompt_time = now + 0.28
    return
  end
  if (stat.combo or 0) >= 8 and ((stat.combo or 0) % 4 == 0) then
    if BattleEventPrompts and BattleEventPrompts.push_battle_event then
      BattleEventPrompts.push_battle_event(string.format('连击 x%d', stat.combo), '普通', 0.45)
    end
    stat.next_prompt_time = now + 0.28
  end
end

local deal_skill_damage_func = nil

function M.set_deal_skill_damage(func)
  deal_skill_damage_func = func
end

function M.deal_skill_damage(target, amount, damage, visual)
  if deal_skill_damage_func then
    return deal_skill_damage_func(target, amount, damage, visual)
  end

  local call_depth = (STATE.__skill_damage_call_depth or 0) + 1
  STATE.__skill_damage_call_depth = call_depth
  if call_depth > SKILL_DAMAGE_REENTRANT_GUARD_LIMIT then
    STATE.__skill_damage_guard_drop = (STATE.__skill_damage_guard_drop or 0) + 1
    STATE.__skill_damage_call_depth = call_depth - 1
    return
  end

  local ok, err = pcall(function()
    if not STATE.hero or not STATE.hero:is_exist() then
      return
    end
    if target == STATE.hero then
      if log and log.info then
        log.info('[entry_runtime] deal_skill_damage: 跳过对英雄自身的伤害')
      end
      return
    end
    if not M.can_receive_skill_damage(target) then
      return
    end

    local hit_effect_enabled = CONFIG.damage_hit_effect_enabled ~= false and not M.is_hit_effect_hidden()
    local damage_meta = BootHelpers.resolve_damage_meta(damage)
    local target_multiplier = M.get_damage_bonus_multiplier(target, {
      is_skill = true,
    })
    local final_damage
    if hero_attr_system and hero_attr_system.compute_damage then
      final_damage = hero_attr_system.compute_damage(STATE.hero, amount, damage_meta, {
        damage_kind = 'skill',
        target_multiplier = target_multiplier,
      })
    else
      local hero_multiplier = 1
      if hero_attr_system and hero_attr_system.get_damage_multiplier then
        hero_multiplier = hero_attr_system.get_damage_multiplier(STATE.hero, damage_meta and damage_meta.damage_form, 'skill') or 1
      end
      final_damage = amount * hero_multiplier * target_multiplier
    end
    if final_damage <= 0 then
      return
    end
    M.show_damage_debug_indicator(target, visual)

    local hp_before = target.get_hp and target:get_hp() or 0
    M.reserve_formula_damage(target, final_damage, {
      source = 'skill',
      damage_meta = damage_meta,
    })
    local damage_type_str = M.resolve_damage_text_type(damage_meta.damage_form, visual)
    local is_crit = STATE.current_damage_is_critical or false
    STATE.current_damage_is_critical = nil
    local text_track = M.resolve_damage_text_track(damage_type_str, is_crit, 934269508)
    STATE.hero:damage({
      target = target,
      damage = final_damage,
      type = damage_meta.damage_type or '法术',
      source_unit = STATE.hero,
      text_type = M.resolve_runtime_text_type(damage_type_str),
      text_track = text_track,
      particle = hit_effect_enabled and visual and visual.particle or nil,
      socket = hit_effect_enabled and visual and visual.socket or '',
      pos_socket = hit_effect_enabled and visual and visual.pos_socket or '',
      common_attack = false,
      no_miss = true,
    })
    M.emit_skill_hit_feedback(target, final_damage, hp_before)

  end)

  STATE.__skill_damage_call_depth = call_depth - 1
  if not ok then
    error(err)
  end
end

function M.can_receive_skill_damage(target)
  if not target or not target.is_exist or not target:is_exist() then
    return false
  end
  
  if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and target == STATE.hero then
    return false
  end
  
  if M.is_active_enemy(target) then
    return true
  end
  
  if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and STATE.hero.is_enemy then
    local ok, is_enemy_to_hero = pcall(STATE.hero.is_enemy, STATE.hero, target)
    if ok and is_enemy_to_hero == true then
      return true
    end
  end
  
  return false
end

function M.get_hero_attack()
  if not STATE.hero or not STATE.hero:is_exist() then
    return 0
  end
  if hero_attr_system and hero_attr_system.get_attr then
    return hero_attr_system.get_attr(STATE.hero, '攻击') or STATE.hero:get_attr('攻击') or 0
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


function M.get_formula_damage_runtime()
  local runtime = STATE.formula_damage_runtime
  if not runtime then
    runtime = {
      by_target = setmetatable({}, { __mode = 'k' }),
    }
    STATE.formula_damage_runtime = runtime
  end
  if not runtime.by_target then
    runtime.by_target = setmetatable({}, { __mode = 'k' })
  end
  return runtime
end

function M.get_runtime_seconds()
  if y3 and y3.game and y3.game.current_game_run_time then
    return y3.game.current_game_run_time()
  end
  return 0
end

function M.reserve_formula_damage(target, amount, meta)
  amount = math.max(0, tonumber(amount) or 0)
  if amount <= 0 or not target or not M.is_active_enemy(target) then
    return false
  end

  local runtime = M.get_formula_damage_runtime()
  local queue = runtime.by_target[target]
  if not queue then
    queue = {}
    runtime.by_target[target] = queue
  end

  queue[#queue + 1] = {
    damage = amount,
    source = STATE.hero,
    created_at = M.get_runtime_seconds(),
    meta = meta,
  }

  while #queue > 8 do
    table.remove(queue, 1)
  end
  return true
end

function M.consume_formula_damage(target, source)
  if not target or not M.is_active_enemy(target) then
    return nil
  end
  if source and STATE.hero and source ~= STATE.hero then
    return nil
  end

  local runtime = M.get_formula_damage_runtime()
  local queue = runtime.by_target[target]
  if not queue or #queue <= 0 then
    return nil
  end

  local now = M.get_runtime_seconds()
  while #queue > 0 do
    local item = table.remove(queue, 1)
    if item and (now <= 0 or (now - (item.created_at or now)) <= 2.0) then
      if not item.source or not source or item.source == source then
        if #queue <= 0 then
          runtime.by_target[target] = nil
        end
        return item.damage
      end
    end
  end

  runtime.by_target[target] = nil
  return nil
end

function M.apply_formula_damage_override(data)
  local damage_instance = data and data.damage_instance or nil
  if not damage_instance or not damage_instance.set_damage then
    return false
  end

  local target = data.target_unit or data.unit
  local final_damage = M.consume_formula_damage(target, data.source_unit)
  if not final_damage or final_damage <= 0 then
    return false
  end

  local source_unit = data.source_unit
  local is_from_hero = source_unit and STATE.hero and source_unit == STATE.hero
  local is_critical = false

  if is_from_hero and hero_attr_system then
    local crit_chance = hero_attr_system.get_attr(source_unit, '物理暴击') or 0
    crit_chance = crit_chance / 100
    if crit_chance > 0 and math.random() < crit_chance then
      is_critical = true
      local crit_damage_bonus = hero_attr_system.get_attr(source_unit, '物理暴伤') or 0
      final_damage = final_damage * (1 + crit_damage_bonus / 100)
    end
  end

  if is_critical then
    STATE.current_damage_is_critical = true
  end

  local ok = pcall(function()
    damage_instance:set_damage(final_damage)
    if is_critical and damage_instance.set_critical then
      damage_instance:set_critical(true)
    end
  end)
  return ok == true
end

function M.handle_bond_enemy_kill(info, auto_active_effects_system)
  if auto_active_effects_system then
    auto_active_effects_system.handle_enemy_kill(info)
  end
end

function M.handle_bond_hero_pre_hurt(data)
  if not data or not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  local source_unit = data.source_unit
  local damage_instance = data.damage_instance
  local target_unit = data.target_unit or data.unit

  if target_unit ~= STATE.hero then
    return
  end

  if source_unit and source_unit == STATE.hero then
    if damage_instance and damage_instance.set_damage then
      pcall(function()
        damage_instance:set_damage(0)
      end)
    end
    if log and log.info then
      log.info('[entry_runtime] 拦截主角自伤 - source_unit匹配')
    end
    return
  end

  local source_is_enemy = false
  if source_unit and M.is_active_enemy(source_unit) then
    source_is_enemy = true
  end

  if not source_is_enemy then
    if damage_instance and damage_instance.set_damage then
      pcall(function()
        damage_instance:set_damage(0)
      end)
    end
    if log and log.info then
      log.info('[entry_runtime] 拦截主角自伤 - source_unit不是敌人')
    end
    return
  end
end

local ATTACK_SKILL_DEFS = nil
local AttackSkillObjects = nil
local CONFIG = nil

function M.set_attack_skill_defs(defs)
  ATTACK_SKILL_DEFS = defs
end

function M.set_attack_skill_objects(objects)
  AttackSkillObjects = objects
end

function M.set_config(config)
  CONFIG = config
end

function M.trigger_td_skills_on_hit(data)
  if STATE.game_finished or not data.is_normal_hit or data.source_unit ~= STATE.hero then
    return
  end

  local skill = STATE.skill_runtime
  if not skill then
    return
  end
  local target = data.target_unit
  if not M.is_active_enemy(target) then
    return
  end
  local chain_center = M.get_unit_point_snapshot(target) or target
  local basic_attack_def = (ATTACK_SKILL_DEFS and ATTACK_SKILL_DEFS.basic_attack) or (STATE and STATE.ATTACK_SKILL_DEFS and STATE.ATTACK_SKILL_DEFS.basic_attack) or {
    damage_type = '物理',
    damage_form = 'weapon',
    element = 'none',
    damage_label = '兵刃伤害',
  }
  local basic_attack_vfx = AttackSkillObjects and AttackSkillObjects.vfx_by_id and AttackSkillObjects.vfx_by_id.basic_attack or {}
  local basic_chain_particle = basic_attack_vfx.chain_particle
      or basic_attack_vfx.impact_particle
  if CONFIG and CONFIG.damage_hit_effect_enabled == false or M.is_hit_effect_hidden() then
    basic_chain_particle = nil
  end

  local bonus_ratio = skill:get('normal_attack_bonus_ratio')
  if bonus_ratio > 0 then
    M.deal_skill_damage(target, data.damage * bonus_ratio, { damage_type = '物理', text_type = 'physics' })
  end

  local splash_ratio = skill:get('splash_ratio')
  local splash_radius = skill:get('splash_radius')
  if splash_ratio > 0 and splash_radius > 0 then
    local enemies = M.get_enemies_in_range(target, splash_radius, target)
    for _, enemy in ipairs(enemies) do
      if enemy ~= STATE.hero then
        M.deal_skill_damage(enemy, data.damage * splash_ratio, { damage_type = '物理', text_type = 'physics' })
      end
    end
  end

  local chain_bounces = skill:get('chain_bounces')
  local chain_chance = skill:get('chain_chance')
  local chain_radius = skill:get('chain_radius')
  local chain_ratio = skill:get('chain_ratio')
  if chain_bounces > 0 and chain_chance > 0 and math.random() <= chain_chance then
    local chain_enemies = M.get_enemies_in_range(chain_center, chain_radius, target, chain_bounces)
    for _, enemy in ipairs(chain_enemies) do
      if enemy ~= STATE.hero then
        M.deal_skill_damage(enemy, data.damage * chain_ratio, basic_attack_def)
      end
    end
  end


  local execute_threshold = skill:get('execute_threshold')
  if execute_threshold > 0 and target:is_exist() and target:get_hp() > 0 then
    local max_hp = M.get_unit_max_hp(target)
    if max_hp > 0 and target:get_hp() / max_hp <= execute_threshold then
      target:kill_by(STATE.hero)
    end
  end
end

return M
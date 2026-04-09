local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local round_number = env.round_number
  local message = env.message
  local ATTACK_SKILL_DEFS = env.ATTACK_SKILL_DEFS
  local ATTACK_SKILL_VFX = env.ATTACK_SKILL_VFX
  local get_player = env.get_player
  local get_hero_point = env.get_hero_point
  local get_bond_runtime_bonus = env.get_bond_runtime_bonus
  local is_active_enemy = env.is_active_enemy
  local create_attack_skill_instance = env.create_attack_skill_instance
  local deal_skill_damage = env.deal_skill_damage
  local get_damage_bonus_multiplier = env.get_damage_bonus_multiplier
  local get_enemies_in_range = env.get_enemies_in_range
  local try_trigger_hunter_first_hit = env.try_trigger_hunter_first_hit
  local notify_bond_attack_skill_cast = env.notify_bond_attack_skill_cast
  local notify_auto_active_basic_attack = env.notify_auto_active_basic_attack
  local notify_auto_active_skill_cast = env.notify_auto_active_skill_cast

  local function get_basic_attack_skill()
    if not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
      return nil
    end
    return STATE.attack_skill_state.by_id.basic_attack
  end

  local function get_global_skill_bonus(field)
    local state_bonus = STATE.skill_runtime and STATE.skill_runtime[field] or 0
    return state_bonus + get_bond_runtime_bonus(field)
  end

  local function get_effective_skill_value(skill, field)
    return math.max(0, (skill and skill[field] or 0) + get_global_skill_bonus(field))
  end
  
  local function get_current_basic_attack_range()
    if not STATE.hero or not STATE.hero:is_exist() then
      return ATTACK_SKILL_DEFS.basic_attack.base_range or 0
    end
    local range = y3.helper.tonumber(STATE.hero:get_attr('攻击范围'))
      or y3.helper.tonumber(STATE.hero:get_attr('attack_range'))
      or ATTACK_SKILL_DEFS.basic_attack.base_range
      or 0
    return math.max(1, round_number(range))
  end
  
  local function get_basic_attack_animation_names()
    if STATE.basic_attack_animation_names then
      return STATE.basic_attack_animation_names
    end

    local names = {}
    if STATE.hero and STATE.hero:is_exist() then
      local hero_key = STATE.hero:get_key()
      local editor_unit = hero_key and y3.object.unit[hero_key] or nil
      local animation_items = editor_unit
        and editor_unit.data
        and editor_unit.data.simple_common_atk
        and editor_unit.data.simple_common_atk.ability_animations
        and editor_unit.data.simple_common_atk.ability_animations.items
        or nil
      if type(animation_items) == 'table' then
        for _, name in ipairs(animation_items) do
          if type(name) == 'string' and name ~= '' then
            names[#names + 1] = name
          end
        end
      end
    end

    if #names == 0 then
      names[1] = 'attack1'
    end

    STATE.basic_attack_animation_names = names
    return names
  end

  local function play_basic_attack_animation()
    if not STATE.hero or not STATE.hero:is_exist() then
      return
    end

    local names = get_basic_attack_animation_names()
    if #names == 0 then
      return
    end

    STATE.basic_attack_animation_index = (STATE.basic_attack_animation_index or 0) + 1
    local index = ((STATE.basic_attack_animation_index - 1) % #names) + 1
    local animation_name = names[index]
    if animation_name and animation_name ~= '' then
      STATE.hero:play_animation(animation_name, 1.0, nil, nil, false, true)
    end
  end

  local function build_basic_attack_ability_description(skill)
    if not skill then
      return '当前普攻技能。'
    end
  
    local lines = {
      string.format('当前普攻：造成 %.0f%% 攻击的物理伤害。', (skill.damage_ratio or 0) * 100),
      string.format('当前射程：%d。', get_current_basic_attack_range()),
    }
  
    if STATE.skill_runtime and STATE.skill_runtime.normal_attack_bonus_ratio > 0 then
      lines[#lines + 1] = string.format(
        '额外追伤：%.0f%% 攻击。',
        STATE.skill_runtime.normal_attack_bonus_ratio * 100
      )
    end
  
    if STATE.skill_runtime and STATE.skill_runtime.splash_ratio > 0 then
      lines[#lines + 1] = string.format(
        '溅射：%.0f%% 攻击，半径 %d。',
        STATE.skill_runtime.splash_ratio * 100,
        round_number(STATE.skill_runtime.splash_radius)
      )
    end
  
    if STATE.skill_runtime and STATE.skill_runtime.chain_bounces > 0 and STATE.skill_runtime.chain_chance > 0 then
      lines[#lines + 1] = string.format(
        '弹射：%.0f%% 概率弹射 %d 个目标，造成 %.0f%% 法术伤害。',
        STATE.skill_runtime.chain_chance * 100,
        STATE.skill_runtime.chain_bounces,
        STATE.skill_runtime.chain_ratio * 100
      )
    end
  
    if STATE.skill_runtime and STATE.skill_runtime.execute_threshold > 0 then
      lines[#lines + 1] = string.format(
        '处决：目标生命低于 %.0f%% 时立即击杀。',
        STATE.skill_runtime.execute_threshold * 100
      )
    end

    if get_effective_skill_value(skill, 'split_count') > 0 then
      lines[#lines + 1] = string.format(
        '分裂：额外命中 %d 个目标，造成 %.0f%% 伤害。',
        round_number(get_effective_skill_value(skill, 'split_count')),
        get_effective_skill_value(skill, 'split_ratio') * 100
      )
    end

    if get_effective_skill_value(skill, 'armor_break_ratio') > 0 then
      lines[#lines + 1] = string.format(
        '破甲：命中附加 %.0f%% 破甲，持续 %.1f 秒。',
        get_effective_skill_value(skill, 'armor_break_ratio') * 100,
        get_effective_skill_value(skill, 'armor_break_duration')
      )
    end
  
    return table.concat(lines, '\n')
  end
  
  local function sync_basic_attack_ability()
    if not STATE.hero or not STATE.hero:is_exist() then
      return nil
    end
  
    local ability = STATE.hero_common_attack
    if not ability or not ability:is_exist() then
      ability = STATE.hero:get_common_attack()
      STATE.hero_common_attack = ability
    end
  
    if not ability or not ability:is_exist() then
      if not STATE.basic_attack_ability_warned then
        STATE.basic_attack_ability_warned = true
        message('警告：未找到英雄普攻技能对象，无法通过 Ability API 同步普攻参数。')
      end
      return nil
    end
  
    local skill = get_basic_attack_skill()
    ability:set_range(get_current_basic_attack_range())
  
    if skill then
      ability:set_name(skill.name)
      ability:set_description(build_basic_attack_ability_description(skill))
    end
  
    return ability
  end
  
  local function bind_basic_attack_ability_events(ability)
    if not ability or not ability:is_exist() or STATE.basic_attack_ability_bound then
      return
    end
  
    ability:event('施法-出手', function(_, data)
      if STATE.game_finished or data.unit ~= STATE.hero then
        return
      end
      sync_basic_attack_ability()
    end)
  
    STATE.basic_attack_ability_bound = true
  end
  
  local function setup_basic_attack_ability()
    local ability = sync_basic_attack_ability()
    if not ability then
      return
    end
    bind_basic_attack_ability_events(ability)
  end

  local function get_attack_skill(skill_id)
    return STATE.attack_skill_state and STATE.attack_skill_state.by_id[skill_id] or nil
  end
  
  local function get_attack_skill_slot(slot)
    return STATE.attack_skill_state and STATE.attack_skill_state.slots[slot] or nil
  end
  
  local function get_empty_attack_skill_slot()
    if not STATE.attack_skill_state then
      return nil
    end
    for slot = 1, 4, 1 do
      if not STATE.attack_skill_state.slots[slot] then
        return slot
      end
    end
    return nil
  end
  
  local function get_unlocked_attack_skill_count()
    if not STATE.attack_skill_state then
      return 0
    end
  
    local count = 0
    for slot = 1, 4, 1 do
      if STATE.attack_skill_state.slots[slot] then
        count = count + 1
      end
    end
    return count
  end
  
  local function get_upgrade_pick_count(upgrade_key)
    if not STATE.attack_skill_state then
      return 0
    end
    return STATE.attack_skill_state.upgrade_counts[upgrade_key] or 0
  end
  
  local function record_upgrade_pick(upgrade_key)
    if not STATE.attack_skill_state then
      return
    end
    STATE.attack_skill_state.upgrade_counts[upgrade_key] = get_upgrade_pick_count(upgrade_key) + 1
  end
  
  local function get_skill_current_cooldown(skill)
    if not skill or skill.base_cooldown <= 0 then
      return 0
    end
    return math.max(0.4, skill.base_cooldown * (1 - skill.cooldown_reduction))
  end
  
  local function get_basic_attack_interval(skill)
    if not skill then
      return 0.6
    end
  
    if STATE.hero and STATE.hero:is_exist() then
      local interval = y3.helper.tonumber(STATE.hero:get_attr('攻击间隔')) or 0
      if interval > 0 then
        return math.max(0.15, interval)
      end
  
      local attack_speed = math.max(20, STATE.hero:get_attr('攻击速度'))
      local base_interval = math.max(0.15, skill.base_cooldown or 1.7)
      return math.max(0.15, base_interval * 100 / attack_speed)
    end
  
    return math.max(0.15, get_skill_current_cooldown(skill))
  end
  
  local function build_attack_skill_slot_text(slot)
    local skill = get_attack_skill_slot(slot)
    if not skill then
      return string.format('%d号位 空', slot)
    end
  
    local parts = {
      string.format('%d号位 %s Lv%d', slot, skill.name, skill.level),
      string.format('%.0f%%攻击', skill.damage_ratio * 100),
    }
  
    if skill.id == 'basic_attack' then
      parts[#parts + 1] = string.format('间隔 %.2fs', get_basic_attack_interval(skill))
    elseif skill.base_cooldown > 0 then
      parts[#parts + 1] = string.format('CD %.1fs', get_skill_current_cooldown(skill))
    end
    if skill.pierce and skill.pierce > 0 and skill.id ~= 'basic_attack' then
      parts[#parts + 1] = '穿透+' .. tostring(skill.pierce)
    end
    if skill.extra_targets and skill.extra_targets > 0 then
      parts[#parts + 1] = '扩散+' .. tostring(skill.extra_targets)
    end
    if skill.repeat_count and skill.repeat_count > 1 then
      parts[#parts + 1] = '连发x' .. tostring(skill.repeat_count)
    end
    if skill.id == 'arcane_arrow' and get_effective_skill_value(skill, 'secondary_targets') > 0 then
      parts[#parts + 1] = '次级+' .. tostring(round_number(get_effective_skill_value(skill, 'secondary_targets')))
    end
    if skill.id == 'flame_arrow' and get_effective_skill_value(skill, 'ignite_duration') > 0 then
      parts[#parts + 1] = '点燃'
    end
    if skill.id == 'frost_arrow' and get_effective_skill_value(skill, 'shard_count') > 0 then
      parts[#parts + 1] = '冰片+' .. tostring(round_number(get_effective_skill_value(skill, 'shard_count')))
    end
    if skill.id == 'thunder' and get_effective_skill_value(skill, 'shock_duration') > 0 then
      parts[#parts + 1] = '感电'
    end
  
    return table.concat(parts, ' | ')
  end
  
  local function show_attack_skill_loadout()
    message('攻击技能栏：')
    for slot = 1, 4, 1 do
      message(build_attack_skill_slot_text(slot))
    end
  end
  
  local function unlock_attack_skill(skill_id)
    local existing = get_attack_skill(skill_id)
    if existing then
      return existing, existing.slot, false
    end
  
    local empty_slot = get_empty_attack_skill_slot()
    if not empty_slot then
      return nil
    end
  
    local skill = create_attack_skill_instance(skill_id, empty_slot)
    STATE.attack_skill_state.slots[empty_slot] = skill
    STATE.attack_skill_state.by_id[skill_id] = skill
    STATE.attack_skill_state.new_skill_feed[skill_id] = 2
    return skill, empty_slot, true
  end
  
  local function get_skill_damage(skill, ratio_override)
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    return STATE.hero:get_attr('物理攻击') * (ratio_override or skill.damage_ratio or 0)
  end
  
  local function clone_point(point)
    if not point then
      return nil
    end
    return point:move()
  end
  
  local function get_unit_point_snapshot(unit)
    if not unit or not unit:is_exist() then
      return nil
    end
    return clone_point(unit:get_point())
  end
  
  local function get_enemies_on_line(origin_point, impact_point, max_distance, line_width, max_hits, except_unit)
    local result = {}
    if not origin_point or not impact_point or max_hits <= 0 then
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
      :is_enemy(get_player())
      :in_shape(segment_center, line_shape)
      :pick()
  
    for _, unit in ipairs(picked) do
      if unit ~= except_unit and is_active_enemy(unit) then
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
  
    for index = 1, math.min(max_hits, #candidates), 1 do
      result[#result + 1] = candidates[index].unit
    end
  
    return result
  end
  
  local function resume_enemy_path(unit)
    if is_active_enemy(unit) and STATE.defense_point then
      unit:attack_move(STATE.defense_point)
    end
  end

  local function get_enemy_status_bucket(unit)
    local info = STATE.enemy_info_map and STATE.enemy_info_map[unit] or nil
    if not info then
      return nil
    end
    info.status = info.status or {}
    return info.status
  end

  local function apply_enemy_status(unit, status_id, values)
    local bucket = get_enemy_status_bucket(unit)
    if not bucket then
      return nil
    end
    bucket[status_id] = bucket[status_id] or {}
    for key, value in pairs(values or {}) do
      bucket[status_id][key] = value
    end
    return bucket[status_id]
  end

  local function get_enemy_status(unit, status_id)
    local bucket = get_enemy_status_bucket(unit)
    return bucket and bucket[status_id] or nil
  end
  
  local function apply_frost_arrow_control(skill, unit)
    if not unit or not is_active_enemy(unit) then
      return
    end
  
    local control_lock_time = math.max(0, (skill.control_lock_time or 0) + get_effective_skill_value(skill, 'frost_control_bonus'))
    local knockback_distance = math.max(0, skill.knockback_distance or 0)

    if control_lock_time > 0 then
      apply_enemy_status(unit, 'frost_lock', {
        remaining = control_lock_time,
      })
    end
  
    unit:stop()
  
    if control_lock_time > 0 then
      unit:add_state('禁止移动')
      unit:add_state('禁止转向')
      y3.ltimer.wait(control_lock_time, function()
        if not unit or not unit:is_exist() then
          return
        end
        unit:remove_state('禁止移动')
        unit:remove_state('禁止转向')
        resume_enemy_path(unit)
      end)
    end
  
    if knockback_distance <= 0 or not STATE.hero or not STATE.hero:is_exist() then
      return
    end
  
    local hero_point = get_hero_point()
    local unit_point = get_unit_point_snapshot(unit)
    if not hero_point or not unit_point then
      return
    end
  
    pcall(function()
      unit:mover_line({
        angle = hero_point:get_angle_with(unit_point),
        distance = knockback_distance,
        speed = skill.knockback_speed or 900,
        terrain_block = false,
        on_finish = function()
          if control_lock_time <= 0 then
            resume_enemy_path(unit)
          end
        end,
        on_break = function()
          if control_lock_time <= 0 then
            resume_enemy_path(unit)
          end
        end,
      })
    end)
  end

  local function update_enemy_statuses(dt)
    if not STATE.enemy_info_map or not STATE.hero or not STATE.hero:is_exist() then
      return
    end

    for unit, info in pairs(STATE.enemy_info_map) do
      if info and info.status then
        local ignite = info.status.ignite
        if ignite then
          ignite.remaining = math.max(0, (ignite.remaining or 0) - dt)
          ignite.tick_cd = (ignite.tick_cd or 1) - dt
          if ignite.remaining <= 0 then
            info.status.ignite = nil
          elseif ignite.tick_cd <= 0 and is_active_enemy(unit) then
            ignite.tick_cd = 1
            deal_skill_damage(unit, STATE.hero:get_attr('物理攻击') * (ignite.tick_ratio or 0), '物理', {
              text_type = 'physics',
            })
          end
        end

        for _, status_id in ipairs({ 'armor_break', 'shock', 'frost_lock' }) do
          local entry = info.status[status_id]
          if entry then
            entry.remaining = math.max(0, (entry.remaining or 0) - dt)
            if entry.remaining <= 0 then
              info.status[status_id] = nil
            end
          end
        end
      end
    end
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
  
  local function launch_projectile_to_target(vfx, target, on_finish, ability)
    local impact_point = get_unit_point_snapshot(target)
    if not vfx or not vfx.projectile_key or not STATE.hero or not STATE.hero:is_exist() then
      if on_finish then
        on_finish(impact_point)
      end
      return false
    end
  
    local ok_create, projectile = pcall(y3.projectile.create, {
      key = vfx.projectile_key,
      target = STATE.hero,
      socket = 'origin',
      owner = STATE.hero,
      ability = ability,
      time = vfx.projectile_time or 3.0,
      remove_immediately = true,
    })
    if not ok_create or not projectile then
      if on_finish then
        on_finish(impact_point)
      end
      return false
    end
  
    local resolved = false
  
    local function finish()
      if resolved then
        return
      end
      resolved = true
      local final_point = impact_point
      if projectile and projectile:is_exist() then
        final_point = clone_point(projectile:get_point()) or final_point
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
        on_finish = finish,
        on_break = function()
          if resolved then
            return
          end
          resolved = true
          if projectile and projectile:is_exist() then
            projectile:remove()
          end
          if on_finish then
            on_finish(impact_point)
          end
        end,
      })
    end)
  
    if not ok_move then
      if resolved then
        return false
      end
      resolved = true
      if projectile and projectile:is_exist() then
        projectile:remove()
      end
      if on_finish then
        on_finish(impact_point)
      end
      return false
    end
  
    return true
  end
  
  local function pick_skill_target(skill)
    if not STATE.hero or not STATE.hero:is_exist() then
      return nil
    end
  
    local range
    if skill and skill.id == 'basic_attack' then
      range = get_current_basic_attack_range()
    else
      range = math.max(1, (skill.cast_range or 0) + (skill.range_bonus or 0))
    end
    local picked = y3.selector.create()
      :is_enemy(get_player())
      :in_range(STATE.hero:get_point(), range)
      :sort_type('由近到远')
      :pick()
  
    for _, unit in ipairs(picked) do
      if is_active_enemy(unit) then
        return unit
      end
    end
  
    return nil
  end

  local function get_basic_attack_bonus_multiplier(skill, target)
    local multiplier = 1
    if target and is_active_enemy(target) then
      multiplier = multiplier * get_damage_bonus_multiplier(target, {
        is_basic_attack = true,
      })
      local info = STATE.enemy_info_map and STATE.enemy_info_map[target] or nil
      if info and (info.is_elite == true or info.kind == 'boss' or info.is_boss == true) then
        multiplier = multiplier * (1 + get_effective_skill_value(skill, 'boss_bonus_ratio'))
      end
    end
    return multiplier
  end

  local function deal_basic_attack_damage(skill, target, amount, options)
    if not STATE.hero or not STATE.hero:is_exist() or not target or not is_active_enemy(target) then
      return
    end

    STATE.hero:damage({
      target = target,
      damage = round_number((amount or 0) * get_basic_attack_bonus_multiplier(skill, target)),
      type = skill.damage_type,
      ability = STATE.hero_common_attack and STATE.hero_common_attack:is_exist() and STATE.hero_common_attack or nil,
      text_type = options and options.text_type or 'physics',
      text_track = 934269508,
      common_attack = options and options.common_attack == true or false,
      no_miss = true,
    })
  end

  local function apply_armor_break_on_hit(target)
    local skill = get_basic_attack_skill()
    local ratio = get_effective_skill_value(skill, 'armor_break_ratio')
    local duration = get_effective_skill_value(skill, 'armor_break_duration')
    local max_stacks = math.max(1, round_number(get_effective_skill_value(skill, 'armor_break_max_stacks')))
    if ratio <= 0 or duration <= 0 or not is_active_enemy(target) then
      return
    end

    local status = get_enemy_status(target, 'armor_break') or { stacks = 0 }
    status.stacks = math.min(max_stacks, (status.stacks or 0) + 1)
    status.remaining = duration
    status.ratio = ratio
    apply_enemy_status(target, 'armor_break', status)
  end

  local function cast_arcane_arrow(skill, target)
    local vfx = ATTACK_SKILL_VFX.arcane_arrow
    local damage = get_skill_damage(skill)
    local remaining_hits = 1 + math.max(0, skill.pierce or 0)
    local secondary_targets = math.max(0, round_number(get_effective_skill_value(skill, 'secondary_targets')))
    local burst_radius = get_effective_skill_value(skill, 'burst_radius')
    local burst_ratio = get_effective_skill_value(skill, 'burst_ratio')
    play_particle_on_unit(STATE.hero, vfx.cast_particle, vfx.cast_scale, vfx.cast_time)
  
    launch_projectile_to_target(vfx, target, function(impact_point)
      local function trigger_arcane_burst(center)
        if not center or burst_radius <= 0 or burst_ratio <= 0 then
          return
        end
        for _, unit in ipairs(get_enemies_in_range(center, burst_radius)) do
          deal_skill_damage(unit, damage * burst_ratio, skill.damage_type, {
            particle = vfx.impact_particle,
          })
        end
      end

      local center = impact_point or get_unit_point_snapshot(target)
      if center then
        play_particle_on_point(center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 20)
      end
  
      if is_active_enemy(target) then
        deal_skill_damage(target, damage, skill.damage_type)
        trigger_arcane_burst(center or target)
        remaining_hits = remaining_hits - 1
      end
  
      if remaining_hits <= 0 then
        remaining_hits = 0
      end
  
      for _, unit in ipairs(get_enemies_in_range(center or target, 320, target, remaining_hits)) do
        deal_skill_damage(unit, damage, skill.damage_type, {
          particle = vfx.impact_particle,
        })
        trigger_arcane_burst(unit:get_point())
        remaining_hits = remaining_hits - 1
        if remaining_hits <= 0 then
          break
        end
      end

      if secondary_targets > 0 then
        local hit_count = 0
        for _, unit in ipairs(get_enemies_in_range(center or target, 360, target, secondary_targets)) do
          deal_skill_damage(unit, damage, skill.damage_type, {
            particle = vfx.impact_particle,
          })
          trigger_arcane_burst(unit:get_point())
          hit_count = hit_count + 1
          if hit_count >= secondary_targets then
            break
          end
        end
      end
    end)
  end

  local function cast_flame_arrow(skill, target)
    local vfx = ATTACK_SKILL_VFX.flame_arrow
    local explosion_damage = get_skill_damage(skill, skill.explosion_ratio)
    local ignite_duration = get_effective_skill_value(skill, 'ignite_duration')
    local ignite_tick_ratio = get_effective_skill_value(skill, 'ignite_tick_ratio')
    local ignite_spread_radius = get_effective_skill_value(skill, 'ignite_spread_radius')
    play_particle_on_unit(STATE.hero, vfx.cast_particle, vfx.cast_scale, vfx.cast_time)
  
    launch_projectile_to_target(vfx, target, function(impact_point)
      local function apply_ignite(unit)
        if ignite_duration <= 0 or ignite_tick_ratio <= 0 or not is_active_enemy(unit) then
          return
        end
        apply_enemy_status(unit, 'ignite', {
          remaining = ignite_duration,
          tick_cd = 1,
          tick_ratio = ignite_tick_ratio,
        })
      end

      local center = impact_point or get_unit_point_snapshot(target)
      if center then
        play_particle_on_point(center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 20)
      end
  
      if is_active_enemy(target) then
        deal_skill_damage(target, get_skill_damage(skill), skill.damage_type)
        apply_ignite(target)
      end
  
      if skill.explosion_ratio <= 0 or skill.explosion_radius <= 0 then
        return
      end
  
      if center then
        play_particle_on_point(center, vfx.explosion_particle, vfx.explosion_scale, vfx.explosion_time, 10)
      end
  
      for _, unit in ipairs(get_enemies_in_range(center or target, skill.explosion_radius)) do
        deal_skill_damage(unit, explosion_damage, skill.damage_type, {
          particle = vfx.explosion_particle,
        })
        apply_ignite(unit)
      end

      if ignite_spread_radius > 0 then
        for _, unit in ipairs(get_enemies_in_range(center or target, ignite_spread_radius)) do
          if not get_enemy_status(unit, 'ignite') then
            apply_ignite(unit)
          end
        end
      end
    end)
  end

  local function cast_frost_arrow(skill, target)
    local vfx = ATTACK_SKILL_VFX.frost_arrow
    local damage = get_skill_damage(skill)
    local remaining_hits = 1 + math.max(0, skill.pierce or 0)
    local origin_point = get_hero_point()
    local shatter_bonus = get_effective_skill_value(skill, 'shatter_bonus')
    local shard_count = math.max(0, round_number(get_effective_skill_value(skill, 'shard_count')))
    local shard_ratio = get_effective_skill_value(skill, 'shard_ratio')
    play_particle_on_unit(STATE.hero, vfx.cast_particle, vfx.cast_scale, vfx.cast_time)
  
    launch_projectile_to_target(vfx, target, function(impact_point)
      local center = impact_point or get_unit_point_snapshot(target)
      if center then
        play_particle_on_point(center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 20)
      end
  
      if is_active_enemy(target) then
        local damage_multiplier = get_enemy_status(target, 'frost_lock') and (1 + shatter_bonus) or 1
        deal_skill_damage(target, damage * damage_multiplier, skill.damage_type)
        apply_frost_arrow_control(skill, target)
        remaining_hits = remaining_hits - 1
      end
  
      if remaining_hits <= 0 then
        return
      end
  
      for _, unit in ipairs(get_enemies_on_line(
        origin_point,
        center or get_unit_point_snapshot(target),
        math.max(1, (skill.cast_range or 0) + (skill.range_bonus or 0)),
        skill.pierce_width or 95,
        remaining_hits,
        target
      )) do
        local damage_multiplier = get_enemy_status(unit, 'frost_lock') and (1 + shatter_bonus) or 1
        deal_skill_damage(unit, damage * damage_multiplier, skill.damage_type, {
          particle = vfx.impact_particle,
        })
        apply_frost_arrow_control(skill, unit)
        remaining_hits = remaining_hits - 1
        if remaining_hits <= 0 then
          break
        end
      end

      if shard_count > 0 and shard_ratio > 0 then
        local hit_count = 0
        for _, unit in ipairs(get_enemies_in_range(center or target, 300, target, shard_count)) do
          deal_skill_damage(unit, damage * shard_ratio, skill.damage_type, {
            particle = vfx.impact_particle,
          })
          hit_count = hit_count + 1
          if hit_count >= shard_count then
            break
          end
        end
      end
    end)
  end

  local function cast_thunder(skill, target)
    local vfx = ATTACK_SKILL_VFX.thunder
    local damage = get_skill_damage(skill)
    local locked_point = get_unit_point_snapshot(target)
    local shock_duration = get_effective_skill_value(skill, 'shock_duration')
    local shock_bonus = get_effective_skill_value(skill, 'shock_bonus')
    local field_radius = get_effective_skill_value(skill, 'field_radius')
    local field_ratio = get_effective_skill_value(skill, 'field_ratio')
    if locked_point then
      play_particle_on_point(locked_point, vfx.charge_particle, vfx.charge_scale, vfx.charge_time, 200)
    end
  
    y3.ltimer.wait(vfx.strike_delay or 0.12, function()
      if STATE.game_finished then
        return
      end
  
      local strike_center = get_unit_point_snapshot(target) or locked_point
      if not strike_center then
        return
      end
  
      play_particle_on_point(strike_center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 0)

      local function apply_shock(unit)
        if shock_duration <= 0 or not is_active_enemy(unit) then
          return
        end
        apply_enemy_status(unit, 'shock', {
          remaining = shock_duration,
          bonus = shock_bonus,
        })
      end

      local function get_shock_multiplier(unit)
        return get_enemy_status(unit, 'shock') and (1 + shock_bonus) or 1
      end

      local function trigger_field(center)
        if field_radius <= 0 or field_ratio <= 0 then
          return
        end
        for _, unit in ipairs(get_enemies_in_range(center, field_radius)) do
          deal_skill_damage(unit, damage * field_ratio, skill.damage_type, {
            particle = vfx.chain_particle,
          })
        end
      end

      if is_active_enemy(target) then
        deal_skill_damage(target, damage * get_shock_multiplier(target), skill.damage_type, {
          particle = vfx.impact_particle,
        })
        apply_shock(target)
      end
  
      local extra_targets = math.max(0, skill.extra_targets or 0)
      if extra_targets <= 0 then
        return
      end
  
      local hit_count = 0
      for _, unit in ipairs(get_enemies_in_range(strike_center, 420, target, extra_targets)) do
        play_particle_on_point(unit:get_point(), vfx.chain_particle, vfx.chain_scale, vfx.chain_time, 0)
        deal_skill_damage(unit, damage * get_shock_multiplier(unit), skill.damage_type, {
          particle = vfx.chain_particle,
        })
        apply_shock(unit)
        hit_count = hit_count + 1
        if hit_count >= extra_targets then
          break
        end
      end

      trigger_field(strike_center)
    end)
  end
  
  local function cast_attack_skill_once(skill, target)
    if skill.id == 'basic_attack' then
      local vfx = ATTACK_SKILL_VFX.basic_attack
      local damage = get_skill_damage(skill)
      local multishot_count = math.max(0, round_number(get_bond_runtime_bonus('multishot_count')))
      local multishot_ratio = math.max(0, get_bond_runtime_bonus('multishot_ratio'))
      local split_count = math.max(0, round_number(get_effective_skill_value(skill, 'split_count')))
      local split_ratio = get_effective_skill_value(skill, 'split_ratio')
      local hero_point = get_hero_point()
      play_basic_attack_animation()
      if notify_auto_active_basic_attack then
        notify_auto_active_basic_attack(target)
      end
      if hero_point and target and target:is_exist() and not STATE.hero:has_state('禁止转向') then
        STATE.hero:set_facing(hero_point:get_angle_with(target:get_point()), 0.08)
      end
  
      launch_projectile_to_target(vfx, target, function(impact_point)
        if STATE.game_finished or not STATE.hero or not STATE.hero:is_exist() then
          return
        end
  
        if impact_point and vfx.impact_particle then
          play_particle_on_point(impact_point, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 18)
        end
  
        if is_active_enemy(target) then
          deal_basic_attack_damage(skill, target, damage, {
            common_attack = true,
          })
          try_trigger_hunter_first_hit(target)
          apply_armor_break_on_hit(target)
        end
  
        if multishot_count > 0 and multishot_ratio > 0 then
          local hit_count = 0
          for _, unit in ipairs(get_enemies_in_range(
            target,
            math.max(260, get_current_basic_attack_range() * 0.45),
            target,
            multishot_count
          )) do
            deal_skill_damage(unit, damage * multishot_ratio, skill.damage_type, {
              text_type = 'physics',
              skip_hunter_first_hit = true,
            })
            hit_count = hit_count + 1
            if hit_count >= multishot_count then
              break
            end
          end
        end

        if split_count > 0 and split_ratio > 0 then
          local split_hits = 0
          for _, unit in ipairs(get_enemies_in_range(
            target,
            math.max(260, get_current_basic_attack_range() * 0.45),
            target,
            split_count
          )) do
            deal_basic_attack_damage(skill, unit, damage * split_ratio)
            apply_armor_break_on_hit(unit)
            split_hits = split_hits + 1
            if split_hits >= split_count then
              break
            end
          end
        end
      end, STATE.hero_common_attack and STATE.hero_common_attack:is_exist() and STATE.hero_common_attack or nil)
      return
    end
  
    if notify_bond_attack_skill_cast then
      notify_bond_attack_skill_cast(skill, target)
    end
    if notify_auto_active_skill_cast then
      notify_auto_active_skill_cast(skill, target)
    end
  
    if skill.id == 'arcane_arrow' then
      cast_arcane_arrow(skill, target)
      return
    end
    if skill.id == 'flame_arrow' then
      cast_flame_arrow(skill, target)
      return
    end
    if skill.id == 'frost_arrow' then
      cast_frost_arrow(skill, target)
      return
    end
    if skill.id == 'thunder' then
      cast_thunder(skill, target)
    end
  end
  
  local function try_cast_attack_skill(skill)
    if not skill or skill.id == 'basic_attack' then
      return
    end
  
    local first_target = pick_skill_target(skill)
    if not first_target then
      return
    end
  
    local cast_times = math.max(1, skill.repeat_count or 1)
    local skill_echo_chance = math.max(0, get_bond_runtime_bonus('skill_echo_chance') or 0)
    if skill_echo_chance > 0 and math.random() <= math.min(1, skill_echo_chance) then
      cast_times = cast_times + 1
    end
    for cast_index = 1, cast_times, 1 do
      local target = cast_index == 1 and first_target or pick_skill_target(skill)
      if not target then
        break
      end
      cast_attack_skill_once(skill, target)
    end
  
    skill.cooldown_remaining = get_skill_current_cooldown(skill)
  end
  
  local function update_basic_attack(dt)
    local skill = get_basic_attack_skill()
    if not skill or not STATE.hero or not STATE.hero:is_exist() then
      return
    end
  
    skill.cooldown_remaining = math.max(0, (skill.cooldown_remaining or 0) - dt)
    if skill.cooldown_remaining > 0 then
      return
    end
  
    local target = pick_skill_target(skill)
    if not target then
      return
    end
  
    cast_attack_skill_once(skill, target)
    skill.cooldown_remaining = get_basic_attack_interval(skill)
  end
  
  local function update_attack_skills(dt)
    if not STATE.attack_skill_state or not STATE.hero or not STATE.hero:is_exist() then
      return
    end
  
    update_basic_attack(dt)
  
    for slot = 1, 4, 1 do
      local skill = STATE.attack_skill_state.slots[slot]
      if skill and skill.id ~= 'basic_attack' then
        skill.cooldown_remaining = math.max(0, (skill.cooldown_remaining or 0) - dt)
        if skill.cooldown_remaining <= 0 then
          try_cast_attack_skill(skill)
        end
      end
    end
  end

  return {
    get_basic_attack_skill = get_basic_attack_skill,
    get_current_basic_attack_range = get_current_basic_attack_range,
    sync_basic_attack_ability = sync_basic_attack_ability,
    setup_basic_attack_ability = setup_basic_attack_ability,
    get_attack_skill = get_attack_skill,
    get_attack_skill_slot = get_attack_skill_slot,
    get_empty_attack_skill_slot = get_empty_attack_skill_slot,
    get_unlocked_attack_skill_count = get_unlocked_attack_skill_count,
    get_upgrade_pick_count = get_upgrade_pick_count,
    record_upgrade_pick = record_upgrade_pick,
    build_attack_skill_slot_text = build_attack_skill_slot_text,
    show_attack_skill_loadout = show_attack_skill_loadout,
    unlock_attack_skill = unlock_attack_skill,
    update_enemy_statuses = update_enemy_statuses,
    update_attack_skills = update_attack_skills,
  }
end

return M

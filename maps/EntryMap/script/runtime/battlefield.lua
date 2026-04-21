local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local design_seconds = env.design_seconds
  local random_point_in_area = env.random_point_in_area
  local hero_attr_system = env.hero_attr_system
  local set_attr_pack = env.set_attr_pack
  local add_attr_pack = env.add_attr_pack
  local play_enemy_death_sound = env.play_enemy_death_sound

  local api = {}
  local VISUAL_ANIMATION_SPEED = 0.5
  local HERO_RUNTIME_FALLBACK_UNIT_ID = 134274912
  local ENEMY_BASE_SPEED_FACTORS = {
    main = 0.76,
    boss = 0.82,
    challenge = 0.76,
  }

  local function scale_visual_duration(seconds)
    return math.max(0.05, (seconds or 0.30) / VISUAL_ANIMATION_SPEED)
  end

  local function resolve_visual_animation_speed(base_speed)
    return math.max(0.05, (tonumber(base_speed) or 1.0) * VISUAL_ANIMATION_SPEED)
  end

  local function get_challenge_recover_sec(challenge_id)
    local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
    local recover_sec = def and tonumber(def.recover_sec)
    if recover_sec and recover_sec > 0 then
      return recover_sec
    end
    return CONFIG.challenge_rules.recover_sec or 0
  end

  local function try_create_player_unit(player, unit_id, point, facing)
    if not player or not player.create_unit or unit_id == nil then
      return nil, 'invalid_player_or_unit_id'
    end
    local ok, unit_or_err = pcall(player.create_unit, player, unit_id, point, facing or 0)
    if ok and unit_or_err then
      return unit_or_err, nil
    end
    return nil, unit_or_err
  end

  local function refresh_legacy_challenge_summary()
    local total_charges = 0
    local min_remain = nil
    local has_partial = false
    local max_charges = CONFIG.challenge_rules.max_charges or 0

    for challenge_id in pairs(CONFIG.challenges or {}) do
      local charges = STATE.challenge_charge_map and STATE.challenge_charge_map[challenge_id]
      charges = tonumber(charges) or 0
      total_charges = total_charges + charges

      if charges < max_charges then
        has_partial = true
        local recover_sec = get_challenge_recover_sec(challenge_id)
        local elapsed = STATE.challenge_recover_elapsed_map and STATE.challenge_recover_elapsed_map[challenge_id] or 0
        local remain = math.max(0, recover_sec - (tonumber(elapsed) or 0))
        if min_remain == nil or remain < min_remain then
          min_remain = remain
        end
      end
    end

    STATE.challenge_charges = total_charges
    STATE.challenge_recover_elapsed = has_partial and (min_remain or 0) or 0
  end

  local function get_challenge_charge_count(challenge_id)
    if STATE.challenge_charge_map and STATE.challenge_charge_map[challenge_id] ~= nil then
      return tonumber(STATE.challenge_charge_map[challenge_id]) or 0
    end
    return tonumber(STATE.challenge_charges) or 0
  end

  local function set_challenge_charge_count(challenge_id, value)
    STATE.challenge_charge_map = STATE.challenge_charge_map or {}
    STATE.challenge_charge_map[challenge_id] = math.max(0, tonumber(value) or 0)
    refresh_legacy_challenge_summary()
  end

  local function get_challenge_recover_elapsed(challenge_id)
    if STATE.challenge_recover_elapsed_map and STATE.challenge_recover_elapsed_map[challenge_id] ~= nil then
      return tonumber(STATE.challenge_recover_elapsed_map[challenge_id]) or 0
    end
    return tonumber(STATE.challenge_recover_elapsed) or 0
  end

  local function set_challenge_recover_elapsed(challenge_id, value)
    STATE.challenge_recover_elapsed_map = STATE.challenge_recover_elapsed_map or {}
    STATE.challenge_recover_elapsed_map[challenge_id] = math.max(0, tonumber(value) or 0)
    refresh_legacy_challenge_summary()
  end

  local function has_unit_data(unit_id)
    return unit_id ~= nil and y3.object.unit[unit_id] and y3.object.unit[unit_id].data ~= nil
  end

  local function is_active_enemy(unit)
    return unit
      and unit:is_exist()
      and STATE.all_enemies
      and unit:is_in_group(STATE.all_enemies)
  end

  local function get_enemy_runtime_info(unit)
    if not STATE.enemy_info_map or not unit then
      return nil
    end
    return STATE.enemy_info_map[unit]
  end

  local function is_point_in_area(point, area)
    if not point or not area then
      return false
    end
    local x = point:get_x()
    local y = point:get_y()
    return x >= area.x_min and x <= area.x_max and y >= area.y_min and y <= area.y_max
  end

  local function is_boss_runtime_enemy(info)
    return info and (info.kind == 'boss' or info.is_boss == true) or false
  end

  local function is_elite_runtime_enemy(info)
    return info and (info.is_elite == true or is_boss_runtime_enemy(info)) or false
  end

  local function scale_enemy_count(value, scale_value)
    local number = tonumber(value) or 0
    if number <= 0 then
      return 0
    end
    local scale_number = tonumber(scale_value) or 1.0
    if scale_number <= 0 then
      scale_number = 1.0
    end
    return math.max(1, math.floor(number * scale_number + 0.5))
  end

  local function get_enemy_batch_scale()
    return tonumber(CONFIG.enemy_spawn_batch_scale) or 1.0
  end

  local function get_enemy_alive_cap_scale()
    return tonumber(CONFIG.enemy_alive_cap_scale) or 1.0
  end

  local function get_wave_batch_bounds(wave)
    local scaled_min = scale_enemy_count(wave and wave.batch_min, get_enemy_batch_scale())
    local scaled_max = scale_enemy_count(wave and wave.batch_max, get_enemy_batch_scale())
    if scaled_min <= 0 then
      scaled_min = math.max(1, tonumber(wave and wave.batch_min) or 1)
    end
    if scaled_max < scaled_min then
      scaled_max = scaled_min
    end
    return scaled_min, scaled_max
  end

  local function get_wave_max_alive(wave)
    local base_max_alive = tonumber(wave and wave.max_alive) or 0
    if base_max_alive <= 0 then
      return 0
    end
    return scale_enemy_count(base_max_alive, get_enemy_alive_cap_scale())
  end

  local function get_scaled_challenge_batch_count(instance, batch)
    local base_count = tonumber(batch and batch.count) or 0
    if base_count <= 0 then
      return 0
    end
    if instance and instance.mainline_task_id then
      return math.max(1, base_count)
    end
    return scale_enemy_count(base_count, get_enemy_batch_scale())
  end

  local function get_enemy_spawn_speed_factor(info)
    local kind = info and info.kind or 'main'
    local factor = ENEMY_BASE_SPEED_FACTORS[kind]
    if factor == nil then
      factor = ENEMY_BASE_SPEED_FACTORS.main
    end
    factor = factor * (tonumber(CONFIG.enemy_move_speed_scale) or 1.0)
    return math.max(0.05, tonumber(factor) or 1)
  end

  local function apply_spawn_enemy_speed_tuning(unit, info)
    if not unit then
      return nil
    end

    local base_move_speed = tonumber(unit:get_attr('移动速度')) or 0
    if base_move_speed <= 0 then
      return nil
    end

    local factor = get_enemy_spawn_speed_factor(info)
    local tuned_move_speed = math.max(1, base_move_speed * factor)
    if math.abs(tuned_move_speed - base_move_speed) > 0.001 then
      unit:set_attr('移动速度', tuned_move_speed)
    end

    if info then
      info.original_move_speed = base_move_speed
      info.base_move_speed = tuned_move_speed
      info.spawn_move_speed_factor = factor
    end
    return tuned_move_speed
  end

  local function get_current_wave()
    return CONFIG.waves[STATE.current_wave_index]
  end

  local function get_boss_name(wave)
    return string.format('第%d波Boss', wave.index)
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

  local function create_point_particle(effect_key, point, angle, scale, time, height, color, anim_speed)
    if not effect_key or not point then
      return nil
    end

    local ok, particle = pcall(y3.particle.create, {
      type = effect_key,
      target = point,
      angle = angle or 0,
      scale = scale or 1.0,
      time = scale_visual_duration(time),
      height = height or 0,
      immediate = true,
    })
    if not ok or not particle then
      return nil
    end

    particle:set_facing(angle or 0)
    if color then
      particle:set_color(color[1], color[2], color[3], color[4])
    end
    particle:set_animation_speed(resolve_visual_animation_speed(anim_speed))
    return particle
  end

  local function spray_particle_line(particle, angle, distance, speed)
    if not particle or not particle.mover_line then
      return
    end

    pcall(function()
      particle:mover_line({
        angle = angle,
        distance = distance,
        speed = speed,
        terrain_block = false,
        face_angle = true,
      })
    end)
  end

  local function get_unit_max_hp(unit)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return 0
    end
    return y3.helper.tonumber(unit:get_attr('生命')) or y3.helper.tonumber(unit:get_attr('最大生命')) or 0
  end

  local function get_enemy_hit_reaction_snapshot(unit, data)
    local damage = tonumber(data and data.damage) or 0
    local is_critical = false
    local is_missed = false
    local damage_instance = data and data.damage_instance or nil

    if damage_instance then
      local ok_damage, damage_from_instance = pcall(function()
        return damage_instance:get_damage()
      end)
      if ok_damage and damage_from_instance ~= nil then
        damage = tonumber(damage_from_instance) or damage
      end

      local ok_critical, critical = pcall(function()
        return damage_instance:is_critical()
      end)
      if ok_critical then
        is_critical = critical == true
      end

      local ok_missed, missed = pcall(function()
        return damage_instance:is_missed()
      end)
      if ok_missed then
        is_missed = missed == true
      end
    end

    local max_hp = get_unit_max_hp(unit)
    return {
      damage = math.max(0, damage),
      damage_ratio = max_hp > 0 and math.max(0, damage) / max_hp or 0,
      is_critical = is_critical,
      is_missed = is_missed,
    }
  end

  local function resolve_enemy_hit_reaction_profile(info, hit)
    local is_boss = is_boss_runtime_enemy(info)
    local is_elite = is_elite_runtime_enemy(info)
    local damage = hit and hit.damage or 0
    local damage_ratio = hit and hit.damage_ratio or 0

    if (hit and hit.is_critical)
      or damage_ratio >= (is_boss and 0.08 or 0.12)
      or damage >= (is_boss and 120 or 80)
    then
      return {
        hit_kind = 'heavy',
        min_interval = is_boss and 0.09 or 0.07,
        burst_effect = 102702,
        burst_scale = is_boss and 0.90 or (is_elite and 0.82 or 0.72),
        burst_time = is_boss and 0.26 or 0.22,
        burst_height = is_boss and 32 or 26,
        burst_color = is_boss and { 255, 52, 42, 228 } or { 255, 42, 30, 220 },
        burst_anim_speed = 1.22,
        shock_scale = is_boss and 0.76 or 0.68,
        shock_time = is_boss and 0.30 or 0.24,
        mist_scale = is_boss and 0.72 or 0.60,
        mist_time = is_boss and 0.36 or 0.28,
        mist_distance = is_boss and 76 or 62,
        mist_speed = is_boss and 760 or 680,
        trail_scale = is_boss and 0.56 or 0.46,
        trail_time = is_boss and 0.34 or 0.28,
        trail_distance = is_boss and 88 or 72,
        trail_speed = is_boss and 880 or 760,
        shove_distance = is_boss and 0 or (is_elite and 18 or 26),
        shove_speed = is_elite and 940 or 1080,
        shove_interval = 0.18,
      }
    end

    if is_elite
      or damage_ratio >= (is_boss and 0.025 or 0.04)
      or damage >= (is_boss and 42 or 22)
    then
      return {
        hit_kind = 'medium',
        min_interval = is_boss and 0.075 or 0.055,
        burst_effect = 102706,
        burst_scale = is_boss and 0.72 or (is_elite and 0.62 or 0.54),
        burst_time = is_boss and 0.22 or 0.18,
        burst_height = is_boss and 24 or 20,
        burst_color = is_boss and { 228, 40, 34, 212 } or { 212, 30, 28, 196 },
        burst_anim_speed = 1.18,
        mist_scale = is_boss and 0.56 or 0.44,
        mist_time = is_boss and 0.28 or 0.22,
        mist_distance = is_boss and 52 or 42,
        mist_speed = is_boss and 620 or 520,
        trail_scale = is_boss and 0.40 or 0.32,
        trail_time = is_boss and 0.24 or 0.20,
        trail_distance = is_boss and 54 or 46,
        trail_speed = is_boss and 620 or 560,
        shove_distance = is_boss and 0 or (is_elite and 10 or 16),
        shove_speed = 820,
        shove_interval = 0.14,
      }
    end

    return {
      hit_kind = 'light',
      min_interval = 0.04,
      burst_effect = 102706,
      burst_scale = is_boss and 0.48 or (is_elite and 0.42 or 0.34),
      burst_time = is_boss and 0.16 or 0.12,
      burst_height = is_boss and 18 or 14,
      burst_color = { 182, 24, 24, 172 },
      burst_anim_speed = 1.10,
      mist_scale = is_boss and 0.34 or 0.26,
      mist_time = 0.14,
      mist_distance = is_boss and 30 or 24,
      mist_speed = 380,
      shove_distance = 0,
      shove_speed = 0,
      shove_interval = 0.10,
    }
  end

  local function play_enemy_hit_reaction(unit, info, data)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return
    end
    if not info or not info.alive then
      return
    end
    if (unit:get_hp() or 0) <= 0 then
      return
    end

    local hit = get_enemy_hit_reaction_snapshot(unit, data)
    if hit.is_missed or hit.damage <= 0 then
      return
    end

    local profile = resolve_enemy_hit_reaction_profile(info, hit)
    local now = y3.game.current_game_run_time()
    local since_last_feedback = now - (tonumber(info.last_hit_feedback_time) or -10)
    -- DOT 和多段攻击会非常密，这里做轻度节流，保留爽感但避免特效糊成一团。
    if since_last_feedback < (profile.min_interval or 0) then
      if not hit.is_critical or since_last_feedback < 0.03 then
        return
      end
    end
    info.last_hit_feedback_time = now

    local hit_point = get_unit_point_snapshot(unit)
    if not hit_point then
      return
    end

    local hit_angle = unit:get_facing()
    local source_unit = data and data.source_unit or nil
    if source_unit and source_unit.is_exist and source_unit:is_exist() then
      local source_point = get_unit_point_snapshot(source_unit)
      if source_point then
        hit_angle = source_point:get_angle_with(hit_point)
      end
    end

    local burst = create_point_particle(
      profile.burst_effect,
      hit_point,
      hit_angle,
      profile.burst_scale,
      profile.burst_time,
      profile.burst_height,
      profile.burst_color,
      profile.burst_anim_speed
    )
    if burst then
      burst:set_rotate(0, 0, hit_angle)
    end

    local mist = create_point_particle(
      102877,
      hit_point,
      hit_angle,
      profile.mist_scale,
      profile.mist_time,
      profile.burst_height + 6,
      { 110, 8, 8, 166 },
      1.08
    )
    if mist then
      spray_particle_line(mist, hit_angle, profile.mist_distance, profile.mist_speed)
    end

    if profile.hit_kind == 'medium' or profile.hit_kind == 'heavy' then
      local trail = create_point_particle(
        102820,
        hit_point,
        hit_angle,
        profile.trail_scale,
        profile.trail_time,
        profile.burst_height + 14,
        { 210, 20, 20, 190 },
        1.20
      )
      if trail then
        spray_particle_line(trail, hit_angle, profile.trail_distance, profile.trail_speed)
      end
    end

    if profile.hit_kind == 'heavy' then
      for _, angle_offset in ipairs({ -12, 10 }) do
        local extra_trail = create_point_particle(
          102820,
          hit_point,
          hit_angle + angle_offset,
          profile.trail_scale * 0.78,
          profile.trail_time,
          profile.burst_height + 18,
          { 228, 28, 24, 210 },
          1.28
        )
        if extra_trail then
          spray_particle_line(
            extra_trail,
            hit_angle + angle_offset,
            math.max(24, profile.trail_distance * 0.72),
            math.max(360, profile.trail_speed * 0.88)
          )
        end
      end

      local shock = create_point_particle(
        102706,
        hit_point,
        hit_angle,
        profile.shock_scale,
        profile.shock_time,
        profile.burst_height - 8,
        { 190, 20, 20, 196 },
        1.12
      )
      if shock then
        shock:set_rotate(0, 0, hit_angle)
      end
    end

    if (profile.shove_distance or 0) > 0 then
      local since_last_shove = now - (tonumber(info.last_hit_shove_time) or -10)
      if since_last_shove >= (profile.shove_interval or 0) then
        info.last_hit_shove_time = now
        pcall(function()
          unit:mover_line({
            angle = hit_angle,
            distance = profile.shove_distance,
            speed = profile.shove_speed,
            terrain_block = false,
            face_angle = false,
          })
        end)
      end
    end
  end

  local function resolve_enemy_death_reaction_profile(info)
    if info and info.kind == 'boss' then
      return {
        corpse_distance = 110,
        corpse_speed = 720,
        remove_delay = 1.35,
        burst_scale = 1.28,
        burst_time = 0.48,
        mist_scale = 1.02,
        mist_time = 0.78,
        trail_scale = 0.78,
        trail_time = 0.86,
        trail_distance = 140,
        trail_speed = 760,
        pool_scale = 1.12,
        pool_time = 1.18,
        shock_scale = 0.96,
        shock_time = 0.92,
      }
    end

    return {
      corpse_distance = 180,
      corpse_speed = 980,
      remove_delay = 1.05,
      burst_scale = 0.98,
      burst_time = 0.40,
      mist_scale = 0.78,
      mist_time = 0.62,
      trail_scale = 0.62,
      trail_time = 0.72,
      trail_distance = 185,
      trail_speed = 980,
      pool_scale = 0.86,
      pool_time = 0.96,
      shock_scale = 0.76,
      shock_time = 0.72,
    }
  end

  local function play_enemy_death_reaction(unit, info, data)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return 0.30
    end

    local death_point = get_unit_point_snapshot(unit)
    if not death_point then
      return 0.30
    end

    local profile = resolve_enemy_death_reaction_profile(info)
    local death_angle = unit:get_facing()
    local source_unit = data and data.source_unit or nil
    if source_unit and source_unit.is_exist and source_unit:is_exist() then
      local source_point = get_unit_point_snapshot(source_unit)
      if source_point then
        death_angle = source_point:get_angle_with(death_point)
      end
    end

    if play_enemy_death_sound then
      play_enemy_death_sound(unit, info)
    end

    -- 默认关闭死亡粒子反馈，只保留音效与后续结算。
    if CONFIG.enemy_death_reaction_enabled ~= true then
      return 0.30
    end

    unit:stop()
    pcall(function()
      unit:mover_line({
        angle = death_angle,
        distance = profile.corpse_distance,
        speed = profile.corpse_speed,
        terrain_block = false,
        face_angle = false,
      })
    end)

    local blood_burst = create_point_particle(
      102702,
      death_point,
      death_angle,
      profile.burst_scale,
      profile.burst_time,
      26,
      { 255, 32, 24, 220 },
      1.28
    )
    if blood_burst then
      blood_burst:set_rotate(0, 0, death_angle)
    end

    local blood_shock = create_point_particle(
      102706,
      death_point,
      death_angle,
      profile.shock_scale,
      profile.shock_time,
      12,
      { 190, 18, 18, 200 },
      1.12
    )
    if blood_shock then
      blood_shock:set_rotate(0, 0, death_angle)
    end

    local blood_mist = create_point_particle(
      102877,
      death_point,
      death_angle,
      profile.mist_scale,
      profile.mist_time,
      20,
      { 110, 8, 8, 190 },
      1.12
    )
    if blood_mist then
      spray_particle_line(blood_mist, death_angle, math.max(50, profile.trail_distance * 0.55), math.max(320, profile.trail_speed * 0.55))
    end

    local blood_pool = create_point_particle(
      102705,
      death_point,
      death_angle,
      profile.pool_scale,
      profile.pool_time,
      8,
      { 148, 12, 12, 190 },
      0.96
    )
    if blood_pool then
      blood_pool:set_rotate(0, 0, death_angle)
    end

    for _, spray in ipairs({
      { angle = death_angle - 18, scale = profile.trail_scale * 0.72, distance = profile.trail_distance * 0.76, speed = profile.trail_speed * 0.82 },
      { angle = death_angle - 7, scale = profile.trail_scale * 0.90, distance = profile.trail_distance * 0.92, speed = profile.trail_speed * 0.94 },
      { angle = death_angle + 5, scale = profile.trail_scale, distance = profile.trail_distance, speed = profile.trail_speed },
      { angle = death_angle + 17, scale = profile.trail_scale * 0.82, distance = profile.trail_distance * 0.88, speed = profile.trail_speed * 0.88 },
    }) do
      local blood_trail = create_point_particle(
        102820,
        death_point,
        spray.angle,
        spray.scale,
        profile.trail_time,
        52,
        { 205, 18, 18, 220 },
        1.36
      )
      if blood_trail then
        spray_particle_line(blood_trail, spray.angle, spray.distance, spray.speed)
      end
    end

    return profile.remove_delay or 0.55
  end

  local function finish_game(is_win, reason)
    if STATE.game_finished then
      return
    end

    STATE.game_finished = true
    local result = {
      stage_id = STATE.current_stage_def and STATE.current_stage_def.stage_id or nil,
      mode_id = STATE.current_mode_def and STATE.current_mode_def.mode_id or nil,
      is_win = is_win == true,
      reached_wave_index = math.max(0, STATE.current_wave_index or 0),
      reason = reason,
    }
    STATE.last_battle_result = result
    message((is_win and '游戏胜利：' or '游戏失败：') .. (reason and (' ' .. reason) or ''))
    message(string.format(
      '结算：波次 %d/%d，金币 %d，木材 %d，英雄剩余生命 %.0f。',
      STATE.current_wave_index,
      #CONFIG.waves,
      STATE.resources.gold,
      STATE.resources.wood,
      STATE.hero and STATE.hero:is_exist() and STATE.hero:get_hp() or 0
    ))

    if env.on_finish_game then
      y3.ltimer.wait(0, function()
        env.on_finish_game(result)
      end)
    end
  end

  local function create_enemy_info(unit, info)
    info.unit = unit
    info.alive = true
    info.owner = info.owner or nil
    info.status = info.status or {}
    info.base_move_speed = tonumber(info.base_move_speed) or tonumber(unit:get_attr('移动速度')) or 0
    info.lane_slow_applied = false
    info.lane_slow_factor = 1
    info.last_hit_feedback_time = info.last_hit_feedback_time or -10
    info.last_hit_shove_time = info.last_hit_shove_time or -10

    STATE.enemy_info_map = STATE.enemy_info_map or {}
    STATE.enemy_info_map[unit] = info
    STATE.all_enemies:add_unit(unit)
    STATE.total_enemy_alive = STATE.total_enemy_alive + 1

    if info.owner then
      info.owner.alive_count = (info.owner.alive_count or 0) + 1
    end

    function info.remove_runtime(grant_death_rewards)
      if not info.alive then
        return false
      end

      info.alive = false
      if STATE.all_enemies and unit then
        STATE.all_enemies:remove_unit(unit)
      end
      if STATE.enemy_info_map and unit then
        STATE.enemy_info_map[unit] = nil
      end
      if STATE.total_enemy_alive > 0 then
        STATE.total_enemy_alive = STATE.total_enemy_alive - 1
      end
      if info.owner and info.owner.alive_count and info.owner.alive_count > 0 then
        info.owner.alive_count = info.owner.alive_count - 1
      end
      if info.owner and info.owner.infos then
        info.owner.dead_count = (info.owner.dead_count or 0) + 1
      end

      if grant_death_rewards then
        if info.kind == 'main' then
          env.award_rewards(env.build_reward_with_bond_bonus(info.reward), nil, true)
          if STATE.skill_runtime.medbot_every > 0 and STATE.skill_runtime.medbot_heal > 0 then
            STATE.skill_runtime.medbot_kills = STATE.skill_runtime.medbot_kills + 1
            if STATE.skill_runtime.medbot_kills >= STATE.skill_runtime.medbot_every then
              STATE.skill_runtime.medbot_kills = STATE.skill_runtime.medbot_kills - STATE.skill_runtime.medbot_every
              env.heal_hero(STATE.skill_runtime.medbot_heal)
            end
          end
        elseif info.kind == 'boss' then
          env.award_rewards(env.build_reward_with_bond_bonus(info.reward), get_boss_name(info.wave), false)
        elseif info.kind == 'challenge' and info.reward then
          env.award_rewards(env.build_reward_with_bond_bonus(info.reward), nil, true)
        end
      end

      return true
    end

    if CONFIG.enemy_hit_reaction_enabled ~= false then
      unit:event('单位-受到伤害后', function(_, data)
        play_enemy_hit_reaction(unit, info, data)
      end)
    end

    unit:event('单位-死亡', function(_, data)
      if not info.remove_runtime(true) then
        return
      end

      local corpse_remove_delay = play_enemy_death_reaction(unit, info, data)

      STATE.total_kills = (STATE.total_kills or 0) + 1

      if info.kind == 'boss' then
        if env.on_mainline_task_cleared then
          env.on_mainline_task_cleared()
        end
        STATE.defeated_boss_waves[info.wave.index] = true
        if info.wave.index >= #CONFIG.waves then
          finish_game(true, '击败最终 Boss。')
        else
          local next_wave = CONFIG.waves[info.wave.index + 1]
          message(string.format('%s 被击败，立即切换到 %s。', get_boss_name(info.wave), next_wave.name))
          STATE.active_wave = nil
          STATE.current_wave_index = next_wave.index
          api.start_wave(next_wave.index)
        end
      elseif info.kind == 'challenge' then
        local instance = info.owner
        if instance and instance.active and instance.alive_count <= 0 and instance.all_batches_spawned then
          api.finish_challenge(instance, true)
        end
      end

      if info.kind == 'main' and STATE.skill_runtime.bonus_gold_on_kill > 0 then
        STATE.resources.gold = STATE.resources.gold + STATE.skill_runtime.bonus_gold_on_kill
      end

      env.handle_bond_enemy_kill(info)

      y3.ltimer.wait(corpse_remove_delay, function()
        if unit and unit:is_exist() then
          unit:remove()
        end
      end)
    end)

    return info
  end

  local function get_main_enemy_slow_factor(info)
    if not info or not info.alive or info.kind ~= 'main' or not info.unit or not info.unit:is_exist() then
      return 1
    end

    local rules = CONFIG.main_enemy_slow_zones
    if not rules then
      return 1
    end

    local point = info.unit:get_point()
    local slow_factor = 1
    for _, rule in ipairs(rules) do
      local area = rule and CONFIG.areas and CONFIG.areas[rule.area_id] or nil
      if area and rule.speed_factor and is_point_in_area(point, area) then
        slow_factor = math.min(slow_factor, rule.speed_factor)
      end
    end

    return slow_factor
  end

  local function apply_main_enemy_lane_slow(info)
    if not info or not info.alive or info.kind ~= 'main' or not info.unit or not info.unit:is_exist() then
      return
    end

    local base_move_speed = info.base_move_speed or info.unit:get_attr('移动速度')
    if not base_move_speed or base_move_speed <= 0 then
      return
    end

    local slow_factor = get_main_enemy_slow_factor(info)
    local target_speed = math.max(1, base_move_speed * slow_factor)

    if slow_factor < 1 then
      if not info.lane_slow_applied or info.lane_slow_factor ~= slow_factor then
        info.unit:set_attr('移动速度', target_speed)
        info.lane_slow_applied = true
        info.lane_slow_factor = slow_factor
      end
      return
    end

    if info.lane_slow_applied then
      info.unit:set_attr('移动速度', base_move_speed)
      info.lane_slow_applied = false
      info.lane_slow_factor = 1
    end
  end

  local function spawn_enemy(unit_id, area_id, facing, info)
    info = info or {}
    local spawn_point = random_point_in_area(area_id)
    local ok, unit_or_err = pcall(y3.unit.create_unit, env.get_enemy_player(), unit_id, spawn_point, facing or 180.0)
    if not ok or not unit_or_err then
      if message then
        message(string.format('刷怪失败：单位 %s 创建失败，请检查物编/模型资源是否已加载。', tostring(unit_id)))
      end
      return nil
    end
    local unit = unit_or_err
    if info and info.attr_overrides then
      set_attr_pack(unit, info.attr_overrides)
    end
    if info and info.spawn_hp ~= nil then
      unit:set_hp(info.spawn_hp)
    elseif info and info.attr_overrides and info.attr_overrides['生命'] ~= nil then
      unit:set_hp(info.attr_overrides['生命'])
    elseif info and info.attr_overrides and info.attr_overrides['最大生命'] ~= nil then
      unit:set_hp(info.attr_overrides['最大生命'])
    end
    apply_spawn_enemy_speed_tuning(unit, info)
    unit:set_reward_exp(0)
    unit:attack_move(STATE.defense_point)
    return create_enemy_info(unit, info)
  end

  local function get_spawn_interval(wave, elapsed, boss_spawned)
    if boss_spawned then
      return wave.post_boss_interval_sec
    end

    local current = wave.spawn_segments[1]
    for _, segment_data in ipairs(wave.spawn_segments) do
      if elapsed >= segment_data.start_sec then
        current = segment_data
      end
    end
    return current.interval_sec
  end

  local function can_spawn_main_batch(runner)
    if not runner or not runner.active then
      return false
    end
    local max_alive = get_wave_max_alive(runner.wave)
    if max_alive > 0 and runner.alive_count >= max_alive then
      return false
    end
    if STATE.total_enemy_alive >= CONFIG.total_enemy_soft_cap then
      return false
    end
    return true
  end

  local function spawn_main_batch(runner)
    if not can_spawn_main_batch(runner) then
      return
    end

    local wave = runner.wave
    local scaled_batch_min, scaled_batch_max = get_wave_batch_bounds(wave)
    local batch_count = math.random(scaled_batch_min, scaled_batch_max)
    local soft_cap_left = CONFIG.total_enemy_soft_cap - STATE.total_enemy_alive
    local wave_cap_left = get_wave_max_alive(wave) - runner.alive_count
    batch_count = math.min(batch_count, soft_cap_left, wave_cap_left)

    for _ = 1, batch_count, 1 do
      local info = spawn_enemy(wave.main_unit_id, wave.spawn_area_id, 180.0, {
        kind = 'main',
        owner = runner,
        wave = wave,
        attr_overrides = wave.main_attr_overrides,
        spawn_hp = wave.main_spawn_hp,
        reward = wave.main_kill_reward,
      })
      if not info then
        break
      end
    end
  end

  local function spawn_boss(runner)
    if not runner or runner.boss_spawned or STATE.game_finished then
      return
    end

    runner.boss_spawned = true
    message(string.format('%s 登场。', get_boss_name(runner.wave)))

    runner.boss_info = spawn_enemy(runner.wave.boss_unit_id, runner.wave.boss_spawn_area_id, 180.0, {
      kind = 'boss',
      owner = runner,
      wave = runner.wave,
      reward = runner.wave.boss_kill_reward,
    })
    if not runner.boss_info then
      runner.boss_spawned = false
      return
    end
    if env.on_boss_spawned then
      env.on_boss_spawned(runner.boss_info)
    end
  end

  local function cleanup_challenge_units(instance)
    for _, info in ipairs(instance.infos) do
      if info.alive and info.unit and info.unit:is_exist() then
        info.remove_runtime(false)
        info.unit:remove()
      end
    end
  end

  local function create_challenge_instance(def, instance_id)
    local instance = {
      id = instance_id or def.id,
      def = def,
      elapsed = 0,
      active = true,
      alive_count = 0,
      dead_count = 0,
      infos = {},
      spawned_batches = {},
      all_batches_spawned = false,
      spawn_failed = false,
      mainline_task_id = def.mainline_task_id,
    }
    STATE.active_challenges[instance.id] = instance

    message(string.format('%s 开始，持续 %.0f 秒。', def.name, design_seconds(def.duration_sec)))
    if env.on_challenge_started then
      env.on_challenge_started(instance)
    end
    return instance
  end

  function api.start_wave(index)
    local wave = CONFIG.waves[index]
    if not wave or STATE.game_finished or STATE.session_phase ~= 'battle' then
      return
    end

    STATE.current_wave_index = index
    STATE.started_wave_count = math.max(STATE.started_wave_count, index)
    STATE.active_wave = {
      wave = wave,
      elapsed = 0,
      active = true,
      boss_spawned = false,
      boss_warning_sent = false,
      boss_info = nil,
      alive_count = 0,
      next_spawn_sec = 0,
    }

    message(string.format(
      '%s 开始，%s 将在 %.0f 秒后登场。',
      wave.name or string.format('第 %d 波', index),
      get_boss_name(wave),
      design_seconds(wave.boss_spawn_sec or 0)
    ))

    if env.on_wave_started then
      env.on_wave_started(index)
    end
  end

  function api.finish_challenge(instance, is_success)
    if not instance or not instance.active then
      return
    end

    instance.active = false
    STATE.active_challenges[instance.id] = nil

    if is_success then
      message(instance.def.name .. ' 成功。')
      local handled = false
      if env.handle_challenge_success then
        handled = env.handle_challenge_success(instance) == true
      end
      if not handled then
        env.award_rewards(instance.def.reward, instance.def.name .. ' 成功', false)
      end
    else
      cleanup_challenge_units(instance)
      message(instance.def.name .. ' 失败。')
    end

    if env.on_challenge_finished then
      env.on_challenge_finished(instance, is_success)
    end
  end

  local function spawn_challenge_batch(instance, batch_index, batch)
    if instance.spawned_batches[batch_index] then
      return
    end
    instance.spawned_batches[batch_index] = true
    local spawned_any = false
    local batch_count = get_scaled_challenge_batch_count(instance, batch)

    if instance.def.id == 'treasure_trial' then
      if batch_index == 1 then
        local boss_info = spawn_enemy(instance.def.boss_unit_id, instance.def.spawn_area_id, 180.0, {
          kind = 'challenge',
          owner = instance,
          is_boss = true,
          is_elite = true,
          reward = instance.def.kill_reward,
        })
        if boss_info then
          instance.infos[#instance.infos + 1] = boss_info
          spawned_any = true
        end
        for _ = 1, math.max(0, batch_count - 1), 1 do
          local info = spawn_enemy(instance.def.guard_unit_id, instance.def.spawn_area_id, 180.0, {
            kind = 'challenge',
            owner = instance,
            is_elite = true,
            reward = instance.def.kill_reward,
          })
          if info then
            instance.infos[#instance.infos + 1] = info
            spawned_any = true
          end
        end
      else
        for _ = 1, batch_count, 1 do
          local info = spawn_enemy(instance.def.guard_unit_id, instance.def.spawn_area_id, 180.0, {
            kind = 'challenge',
            owner = instance,
            is_elite = true,
            reward = instance.def.kill_reward,
          })
          if info then
            instance.infos[#instance.infos + 1] = info
            spawned_any = true
          end
        end
      end
    else
      for _ = 1, batch_count, 1 do
        local info = spawn_enemy(instance.def.unit_id, instance.def.spawn_area_id, 180.0, {
          kind = 'challenge',
          owner = instance,
          reward = instance.def.kill_reward,
        })
        if info then
          instance.infos[#instance.infos + 1] = info
          spawned_any = true
        end
      end
    end

    if not spawned_any then
      instance.spawn_failed = true
      api.finish_challenge(instance, false)
      return
    end

    if batch_index >= #instance.def.batches then
      instance.all_batches_spawned = true
    end
  end

  function api.try_start_challenge(challenge_id)
    if STATE.game_finished or STATE.session_phase ~= 'battle' then
      return
    end
    if STATE.awaiting_upgrade then
      message('请先完成当前 G 三选一。')
      return
    end

    local def = CONFIG.challenges[challenge_id]
    if not def then
      return
    end

    if STATE.active_challenges[challenge_id] then
      message(def.name .. ' 进行中。')
      return
    end

    if get_challenge_charge_count(challenge_id) < def.cost_charge then
      message('挑战次数不足。')
      return
    end

    local current_charges = get_challenge_charge_count(challenge_id)
    local recharge_was_full = current_charges >= (CONFIG.challenge_rules.max_charges or 0)
    set_challenge_charge_count(challenge_id, current_charges - def.cost_charge)
    if recharge_was_full then
      set_challenge_recover_elapsed(challenge_id, 0)
    end

    create_challenge_instance(def, challenge_id)
  end

  function api.start_mainline_task_challenge(task)
    if STATE.game_finished or STATE.session_phase ~= 'battle' then
      return nil
    end
    if not task or not task.id then
      return nil
    end

    if not task.spawn_unit_id or not task.spawn_area_id then
      return nil
    end

    local instance_id = 'mainline_task:' .. tostring(task.id)
    if STATE.active_challenges[instance_id] then
      return nil
    end

    local target_count = math.max(1, tonumber(task.target_count) or 1)
    local def = {
      id = instance_id,
      mainline_task_id = task.id,
      name = task.title_text or task.id,
      duration_sec = tonumber(task.time_limit) or 60,
      spawn_area_id = task.spawn_area_id,
      reward = { gold = 0, wood = 0, exp = 0, special = nil },
      kill_reward = { gold = 0, wood = 0, exp = 0, special = nil },
      unit_id = task.spawn_unit_id,
      boss_unit_id = nil,
      guard_unit_id = nil,
      batches = {
        {
          time_sec = 0,
          count = target_count,
        },
      },
    }
    return create_challenge_instance(def, instance_id)
  end

  function api.update_wave(dt)
    local runner = STATE.active_wave
    if not runner or not runner.active or STATE.game_finished or STATE.session_phase ~= 'battle' then
      return
    end

    runner.elapsed = runner.elapsed + dt

    while runner.next_spawn_sec <= runner.elapsed do
      if can_spawn_main_batch(runner) then
        spawn_main_batch(runner)
      end

      local interval = get_spawn_interval(runner.wave, runner.elapsed, runner.boss_spawned)
      interval = math.max(interval, 0.2)
      runner.next_spawn_sec = runner.next_spawn_sec + interval
    end

    if not runner.boss_spawned and runner.boss_warning_sent ~= true then
      local remain = math.max(0, (runner.wave.boss_spawn_sec or 0) - (runner.elapsed or 0))
      if remain <= 6 then
        runner.boss_warning_sent = true
        message(string.format('警告：%s 将在 %.0f 秒后登场。', get_boss_name(runner.wave), design_seconds(remain)))
        if env.on_boss_warning then
          env.on_boss_warning(runner.wave, remain)
        end
      end
    end

    if not runner.boss_spawned and runner.elapsed >= runner.wave.boss_spawn_sec then
      spawn_boss(runner)
    end

    if STATE.enemy_info_map then
      for _, info in pairs(STATE.enemy_info_map) do
        apply_main_enemy_lane_slow(info)
      end
    end
  end

  function api.update_challenges(dt)
    if STATE.session_phase ~= 'battle' then
      return
    end

    local instances = {}
    for _, instance in pairs(STATE.active_challenges) do
      instances[#instances + 1] = instance
    end

    for _, instance in ipairs(instances) do
      if instance.active then
        instance.elapsed = instance.elapsed + dt

        for batch_index, batch in ipairs(instance.def.batches) do
          if not instance.spawned_batches[batch_index] and instance.elapsed >= batch.time_sec then
            spawn_challenge_batch(instance, batch_index, batch)
          end
        end

        if instance.active and not instance.spawn_failed and instance.all_batches_spawned and instance.alive_count <= 0 then
          api.finish_challenge(instance, true)
        elseif instance.active and instance.elapsed >= instance.def.duration_sec then
          api.finish_challenge(instance, false)
        end
      end
    end
  end

  function api.update_challenge_charges(dt)
    if STATE.session_phase ~= 'battle' then
      return
    end

    local max_charges = CONFIG.challenge_rules.max_charges or 0

    for challenge_id, def in pairs(CONFIG.challenges or {}) do
      local recover_sec = get_challenge_recover_sec(challenge_id)
      local current = get_challenge_charge_count(challenge_id)
      if current >= max_charges then
        set_challenge_recover_elapsed(challenge_id, 0)
      else
        local elapsed = get_challenge_recover_elapsed(challenge_id) + dt
        while current < max_charges and elapsed >= recover_sec do
          elapsed = elapsed - recover_sec
          current = current + 1
          set_challenge_charge_count(challenge_id, current)
          message(string.format('%s 次数 +1，当前 %d/%d。', def.name or challenge_id, current, max_charges))
        end
        set_challenge_recover_elapsed(challenge_id, elapsed)
      end
    end
  end

  function api.force_spawn_boss()
    local runner = STATE.active_wave
    if not runner or not runner.active then
      return false, '当前没有进行中的主线波次。'
    end
    if runner.boss_spawned then
      return false, '当前波 Boss 已经登场。'
    end

    runner.elapsed = math.max(runner.elapsed, runner.wave.boss_spawn_sec)
    spawn_boss(runner)
    return true
  end

  local function resolve_hero_spawn_hp(hero)
    if not hero then
      return 1
    end

    local hp = hero_attr_system and hero_attr_system.get_attr(hero, '生命结算值') or 0
    hp = tonumber(hp) or 0
    if hp > 0 then
      return hp
    end

    hp = hero_attr_system and hero_attr_system.get_attr(hero, '生命') or 0
    hp = tonumber(hp) or 0
    if hp > 0 then
      return hp
    end

    if hero.get_attr then
      hp = tonumber(hero:get_attr('生命')) or tonumber(hero:get_attr('最大生命')) or 0
      if hp > 0 then
        return hp
      end
    end

    return 1
  end

  local function build_hero_entry_stats()
    local result = {}

    for attr_name, value in pairs(CONFIG.hero_init_stats or {}) do
      result[attr_name] = value
    end

    local profile = STATE.outgame_profile
    local bonus_stats = profile and profile.hero_attr_bonus_stats or nil
    for attr_name, value in pairs(bonus_stats or {}) do
      local base_value = tonumber(result[attr_name]) or 0
      local bonus_value = tonumber(value) or 0
      result[attr_name] = base_value + bonus_value
    end

    return result
  end

  local function schedule_hero_spawn_attr_logs(hero)
    if not hero_attr_system or not hero_attr_system.log_snapshot or not y3 or not y3.ltimer then
      return
    end

    local checkpoints = { 0.1, 0.5, 1.0 }
    for _, delay in ipairs(checkpoints) do
      y3.ltimer.wait(delay, function()
        if not hero or not hero.is_exist or not hero:is_exist() then
          return
        end
        hero_attr_system.log_snapshot(
          hero,
          'create_hero_delayed_snapshot',
          string.format('delay=%.1fs hp=%s', delay, tostring(hero:get_hp()))
        )
      end)
    end
  end

  function api.create_hero(basic_attack_range)
    local player = env.get_player()
    local preferred_unit_id = CONFIG.unit_ids.hero
    local hero, hero_create_err = try_create_player_unit(player, preferred_unit_id, STATE.hero_spawn_point, 0)
    if not hero and preferred_unit_id ~= HERO_RUNTIME_FALLBACK_UNIT_ID then
      hero, hero_create_err = try_create_player_unit(player, HERO_RUNTIME_FALLBACK_UNIT_ID, STATE.hero_spawn_point, 0)
    end
    if not hero then
      error(string.format(
        'failed to create hero unit id=%s fallback=%s err=%s',
        tostring(preferred_unit_id),
        tostring(HERO_RUNTIME_FALLBACK_UNIT_ID),
        tostring(hero_create_err)
      ))
    end
    if player and player.select_unit then
      player:select_unit(hero)
    end
    local hero_entry_stats = build_hero_entry_stats()

    hero:set_name('守关英雄')
    if hero_attr_system and hero_attr_system.log_snapshot then
      hero_attr_system.log_snapshot(hero, 'create_hero_before_init', string.format('basic_attack_range=%s', tostring(basic_attack_range or 250)))
    end
    hero_attr_system.init_hero_attrs(hero, hero_entry_stats)
    hero_attr_system.set_attr(hero, '攻击范围', tonumber(hero_entry_stats['攻击范围']) or basic_attack_range or 2000)
    hero:add_state('禁止普攻')

    hero:add_state('禁止移动')
    hero:stop()

    if CONFIG.debug_time_scale < 1 and CONFIG.debug_apply_hero_bonus_on_spawn == true then
      for attr_name, value in pairs(CONFIG.debug_hero_bonus_stats) do
        hero_attr_system.add_attr(hero, attr_name, value)
      end
      if hero_attr_system and hero_attr_system.log_snapshot then
        hero_attr_system.log_snapshot(hero, 'create_hero_after_debug_bonus')
      end
    end

    hero_attr_system.rebuild_derived_attrs(hero)
    if hero_attr_system and hero_attr_system.log_snapshot then
      hero_attr_system.log_snapshot(hero, 'create_hero_after_rebuild')
    end
    hero:set_hp(hero_attr_system.get_attr(hero, '生命结算值'))
    STATE.hero_common_attack = hero:get_common_attack()
    local spawn_hp = resolve_hero_spawn_hp(hero)
    hero:set_hp(spawn_hp)
    if hero_attr_system and hero_attr_system.log_snapshot then
      hero_attr_system.log_snapshot(hero, 'create_hero_after_set_hp', string.format('spawn_hp=%s current_hp=%s', tostring(spawn_hp), tostring(hero:get_hp())))
    end

    hero:event('单位-死亡', function()
      if hero_attr_system and hero_attr_system.log_snapshot then
        hero_attr_system.log_snapshot(
          hero,
          'hero_dead',
          string.format('hp=%s reason=%s', tostring(hero:get_hp()), tostring('英雄倒下。'))
        )
      end
      finish_game(false, '英雄倒下。')
    end)

    hero:event('单位-造成伤害后', function(_, data)
      env.on_hero_damage(data)
    end)

    hero:event('单位-受到伤害后', function()
      if hero_attr_system and hero_attr_system.log_snapshot then
        hero_attr_system.log_snapshot(hero, 'hero_be_hurt', string.format('hp=%s', tostring(hero:get_hp())))
      end
      if env.on_hero_be_hurt then
        env.on_hero_be_hurt()
      end
    end)

    if env.on_hero_attr_changed then
      env.on_hero_attr_changed()
    end

    schedule_hero_spawn_attr_logs(hero)

    return hero
  end

  function api.cleanup_battle_units()
    local infos = {}
    if STATE.enemy_info_map then
      for _, info in pairs(STATE.enemy_info_map) do
        infos[#infos + 1] = info
      end
    end

    for _, info in ipairs(infos) do
      if info.alive and info.unit and info.unit:is_exist() then
        info.remove_runtime(false)
        info.unit:remove()
      end
    end

    if STATE.hero and STATE.hero:is_exist() then
      STATE.hero:remove()
    end
  end

  function api.validate_config()
    local missing = {}
    local checked = {}

    local function check_unit(name, unit_id)
      if unit_id == nil then
        missing[#missing + 1] = string.format('%s: 未配置', name)
        return
      end
      if checked[unit_id] then
        return
      end
      checked[unit_id] = true
      if not has_unit_data(unit_id) then
        missing[#missing + 1] = string.format('%s: %d', name, unit_id)
      end
    end

    check_unit('hero', CONFIG.unit_ids.hero)
    for id, wave in ipairs(CONFIG.waves) do
      check_unit('wave[' .. tostring(id) .. '].main_unit_id', wave.main_unit_id)
      check_unit('wave[' .. tostring(id) .. '].boss_unit_id', wave.boss_unit_id)
    end
    for key, challenge in pairs(CONFIG.challenges) do
      if challenge.unit_id then
        check_unit('challenge.' .. key .. '.unit_id', challenge.unit_id)
      end
      if challenge.boss_unit_id then
        check_unit('challenge.' .. key .. '.boss_unit_id', challenge.boss_unit_id)
      end
      if challenge.guard_unit_id then
        check_unit('challenge.' .. key .. '.guard_unit_id', challenge.guard_unit_id)
      end
    end
    for _, task in ipairs(CONFIG.mainline_task_rewards and CONFIG.mainline_task_rewards.list or {}) do
      if task.spawn_unit_id ~= nil then
        check_unit('mainline_task[' .. tostring(task.id) .. '].spawn_unit_id', task.spawn_unit_id)
      else
        missing[#missing + 1] = string.format('mainline_task[%s].spawn_unit_id: 未配置', tostring(task.id))
      end
      if not task.spawn_area_id or not (CONFIG.areas and CONFIG.areas[task.spawn_area_id]) then
        missing[#missing + 1] = string.format('mainline_task[%s].spawn_area_id: %s', tostring(task.id), tostring(task.spawn_area_id))
      end
    end

    if #missing == 0 then
      return true
    end

    message('主循环骨架未启动：以下单位物编 ID 不存在，请先替换 entry_config.lua 中的配置。')
    for _, line in ipairs(missing) do
      message(line)
    end
    return false
  end

  function api.get_active_challenge_count()
    local count = 0
    if not STATE.active_challenges then
      return count
    end
    for _ in pairs(STATE.active_challenges) do
      count = count + 1
    end
    return count
  end

  function api.execute_enemy(unit)
    if not STATE.hero or not STATE.hero:is_exist() or not is_active_enemy(unit) then
      return false
    end

    STATE.hero:damage({
      target = unit,
      damage = 99999999,
      type = '真实伤害',
      text_type = 'magic',
      text_track = 934269508,
      common_attack = false,
      no_miss = true,
    })
    return true
  end

  api.has_unit_data = has_unit_data
  api.is_active_enemy = is_active_enemy
  api.get_enemy_runtime_info = get_enemy_runtime_info
  api.is_boss_runtime_enemy = is_boss_runtime_enemy
  api.is_elite_runtime_enemy = is_elite_runtime_enemy
  api.get_current_wave = get_current_wave
  api.get_boss_name = get_boss_name
  api.finish_game = finish_game

  return api
end

return M

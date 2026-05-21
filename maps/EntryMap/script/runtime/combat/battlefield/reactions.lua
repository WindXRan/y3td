return function(ctx)
  local STATE = ctx.STATE
  local CONFIG = ctx.CONFIG
  local y3 = ctx.y3
  local env = ctx.env
  local play_enemy_death_sound = ctx.play_enemy_death_sound

  local get_unit_max_hp = ctx.get_unit_max_hp
  local get_unit_point_snapshot = ctx.get_unit_point_snapshot
  local create_point_particle = ctx.create_point_particle
  local spray_particle_line = ctx.spray_particle_line
  local is_boss_runtime_enemy = ctx.is_boss_runtime_enemy
  local is_elite_runtime_enemy = ctx.is_elite_runtime_enemy
  local get_monster_type_config = ctx.get_monster_type_config

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
    local type_config = get_monster_type_config(info)
    local hit_config = type_config and type_config.hit_reaction

    local heavy_threshold = hit_config and hit_config.heavy_hit_threshold or (is_boss and 0.08 or 0.12)
    local medium_threshold = hit_config and hit_config.medium_hit_threshold or (is_boss and 0.025 or 0.04)
    local effect_scale = type_config and type_config.visual and type_config.visual.effect_scale or 1.0

    local damage = hit and hit.damage or 0
    local damage_ratio = hit and hit.damage_ratio or 0

    if (hit and hit.is_critical)
      or damage_ratio >= heavy_threshold
      or damage >= (is_boss and 120 or 80)
    then
      local shove_dist = hit_config and hit_config.shove_distance
      if shove_dist == nil then
        shove_dist = is_boss and 0 or (is_elite and 18 or 26)
      end
      return {
        hit_kind = 'heavy',
        min_interval = is_boss and 0.09 or 0.07,
        burst_effect = 102702,
        burst_scale = (is_boss and 0.90 or (is_elite and 0.82 or 0.72)) * effect_scale,
        burst_time = is_boss and 0.26 or 0.22,
        burst_height = is_boss and 32 or 26,
        burst_color = is_boss and { 255, 52, 42, 228 } or { 255, 42, 30, 220 },
        burst_anim_speed = 1.22,
        shock_scale = (is_boss and 0.76 or 0.68) * effect_scale,
        shock_time = is_boss and 0.30 or 0.24,
        mist_scale = (is_boss and 0.72 or 0.60) * effect_scale,
        mist_time = is_boss and 0.36 or 0.28,
        mist_distance = is_boss and 76 or 62,
        mist_speed = is_boss and 760 or 680,
        trail_scale = (is_boss and 0.56 or 0.46) * effect_scale,
        trail_time = is_boss and 0.34 or 0.28,
        trail_distance = is_boss and 88 or 72,
        trail_speed = is_boss and 880 or 760,
        shove_distance = shove_dist,
        shove_speed = is_elite and 940 or 1080,
        shove_interval = 0.18,
      }
    end

    if is_elite
      or damage_ratio >= medium_threshold
      or damage >= (is_boss and 42 or 22)
    then
      local shove_dist = hit_config and hit_config.shove_distance
      if shove_dist == nil then
        shove_dist = is_boss and 0 or (is_elite and 10 or 16)
      end
      return {
        hit_kind = 'medium',
        min_interval = is_boss and 0.075 or 0.055,
        burst_effect = 102706,
        burst_scale = (is_boss and 0.72 or (is_elite and 0.62 or 0.54)) * effect_scale,
        burst_time = is_boss and 0.22 or 0.18,
        burst_height = is_boss and 24 or 20,
        burst_color = is_boss and { 228, 40, 34, 212 } or { 212, 30, 28, 196 },
        burst_anim_speed = 1.18,
        mist_scale = (is_boss and 0.56 or 0.44) * effect_scale,
        mist_time = is_boss and 0.28 or 0.22,
        mist_distance = is_boss and 52 or 42,
        mist_speed = is_boss and 620 or 520,
        trail_scale = (is_boss and 0.40 or 0.32) * effect_scale,
        trail_time = is_boss and 0.24 or 0.20,
        trail_distance = is_boss and 54 or 46,
        trail_speed = is_boss and 620 or 560,
        shove_distance = shove_dist,
        shove_speed = 820,
        shove_interval = 0.14,
      }
    end

    return {
      hit_kind = 'light',
      min_interval = 0.04,
      burst_effect = 102706,
      burst_scale = (is_boss and 0.48 or (is_elite and 0.42 or 0.34)) * effect_scale,
      burst_time = is_boss and 0.16 or 0.12,
      burst_height = is_boss and 18 or 14,
      burst_color = { 182, 24, 24, 172 },
      burst_anim_speed = 1.10,
      mist_scale = (is_boss and 0.34 or 0.26) * effect_scale,
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
    if burst and burst.set_rotate then
      pcall(function()
        burst:set_rotate(0, 0, hit_angle)
      end)
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
      if shock and shock.set_rotate then
        pcall(function()
          shock:set_rotate(0, 0, hit_angle)
        end)
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
    local type_config = get_monster_type_config(info)
    local death_config = type_config and type_config.death_reaction
    local is_boss = is_boss_runtime_enemy(info)

    local effect_scale = 1.0
    if type_config and type_config.visual then
      effect_scale = type_config.visual.effect_scale or 1.0
    end

    if death_config then
      return {
        corpse_distance = death_config.corpse_distance or (is_boss and 96 or 160),
        corpse_speed = death_config.corpse_speed or (is_boss and 680 or 920),
        remove_delay = death_config.remove_delay or (is_boss and 1.30 or 1.00),
        effect_id = 100031,
        effect_scale = (death_config.effect_scale or (is_boss and 1.26 or 0.96)) * effect_scale,
        effect_time = is_boss and 0.72 or 0.56,
        effect_height = is_boss and 18 or 14,
        effect_anim_speed = is_boss and 1.18 or 1.10,
        effect_color = is_boss and { 232, 36, 32, 224 } or { 220, 30, 26, 210 },
      }
    end

    if is_boss then
      return {
        corpse_distance = 96,
        corpse_speed = 680,
        remove_delay = 1.30,
        effect_id = 100031,
        effect_scale = 1.26 * effect_scale,
        effect_time = 0.72,
        effect_height = 18,
        effect_anim_speed = 1.18,
        effect_color = { 232, 36, 32, 224 },
      }
    end

    return {
      corpse_distance = 160,
      corpse_speed = 920,
      remove_delay = 1.00,
      effect_id = 100031,
      effect_scale = 0.96 * effect_scale,
      effect_time = 0.56,
      effect_height = 14,
      effect_anim_speed = 1.10,
      effect_color = { 220, 30, 26, 210 },
    }
  end

  local function play_enemy_death_reaction(unit, info, data)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return 0.30
    end
    local is_main_enemy = info and info.kind == 'main'

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

    local death_sound_enabled = true
    if is_main_enemy then
      death_sound_enabled = CONFIG.enemy_main_death_sound_enabled ~= false
    end
    if play_enemy_death_sound and death_sound_enabled then
      play_enemy_death_sound(unit, info, death_point)
    end

    local death_reaction_enabled = CONFIG.enemy_death_reaction_enabled == true
    if is_main_enemy then
      death_reaction_enabled = CONFIG.enemy_main_death_reaction_enabled ~= false
    end
    if not death_reaction_enabled then
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

    local blood_fx = create_point_particle(
      profile.effect_id or 100031,
      death_point,
      death_angle,
      profile.effect_scale or 1.0,
      profile.effect_time or 0.56,
      profile.effect_height or 14,
      profile.effect_color or { 220, 30, 26, 210 },
      profile.effect_anim_speed or 1.10
    )
    if blood_fx and blood_fx.set_rotate then
      pcall(function()
        blood_fx:set_rotate(0, 0, death_angle)
      end)
    end

    if y3 and y3.particle then
      pcall(y3.particle.create, {
        type = 104062,
        target = death_point,
        angle = death_angle,
        scale = 1.0,
        time = 0.6,
        height = 0,
      })
    end

    return profile.remove_delay or 0.55
  end

  ctx.play_enemy_hit_reaction = play_enemy_hit_reaction
  ctx.play_enemy_death_reaction = play_enemy_death_reaction

  ctx.api.execute_enemy = function(unit)
    if not STATE.hero or not STATE.hero:is_exist() or not ctx.is_active_enemy(unit) then
      return false
    end

    y3.game:event_notify('reserve_formula_damage', unit, 99999999, {
      source = 'execute_enemy',
    })
    STATE.hero:damage({
      target = unit,
      damage = 99999999,
      type = '真实伤害',
      source_unit = STATE.hero,
      text_type = ctx.is_damage_text_hidden() and nil or '法术',
      text_track = 934269508,
      common_attack = false,
      no_miss = true,
    })
    return true
  end
end

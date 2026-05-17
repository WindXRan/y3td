return function(ctx)
  local STATE = ctx.STATE
  local CONFIG = ctx.CONFIG
  local y3 = ctx.y3
  local env = ctx.env
  local api = ctx.api
  local VISUAL_ANIMATION_SPEED = ctx.VISUAL_ANIMATION_SPEED
  local ENEMY_RUNTIME_FALLBACK_UNIT_ID = ctx.ENEMY_RUNTIME_FALLBACK_UNIT_ID
  local ENEMY_BASE_SPEED_FACTORS = ctx.ENEMY_BASE_SPEED_FACTORS

  -- 工具函数
  local function scale_visual_duration(seconds)
    return math.max(0.05, (seconds or 0.30) / VISUAL_ANIMATION_SPEED)
  end
  ctx.scale_visual_duration = scale_visual_duration

  local function resolve_visual_animation_speed(base_speed)
    return math.max(0.05, (tonumber(base_speed) or 1.0) * VISUAL_ANIMATION_SPEED)
  end
  ctx.resolve_visual_animation_speed = resolve_visual_animation_speed

  local function is_damage_text_hidden()
    return STATE.ui_preferences and STATE.ui_preferences.hide_damage_text == true or false
  end
  ctx.is_damage_text_hidden = is_damage_text_hidden

  local function is_hit_effect_hidden()
    return STATE.ui_preferences and STATE.ui_preferences.hide_hit_effects == true or false
  end
  ctx.is_hit_effect_hidden = is_hit_effect_hidden

  local function get_challenge_recover_sec(challenge_id)
    local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
    local recover_sec = def and tonumber(def.recover_sec)
    if recover_sec and recover_sec > 0 then
      return recover_sec
    end
    return CONFIG.challenge_rules.recover_sec or 0
  end
  ctx.get_challenge_recover_sec = get_challenge_recover_sec

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
  ctx.try_create_player_unit = try_create_player_unit

  local function sync_challenge_summary_cache()
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
  ctx.sync_challenge_summary_cache = sync_challenge_summary_cache

  local function get_challenge_charge_count(challenge_id)
    if STATE.challenge_charge_map and STATE.challenge_charge_map[challenge_id] ~= nil then
      return tonumber(STATE.challenge_charge_map[challenge_id]) or 0
    end
    return tonumber(STATE.challenge_charges) or 0
  end
  ctx.get_challenge_charge_count = get_challenge_charge_count

  local function set_challenge_charge_count(challenge_id, value)
    STATE.challenge_charge_map = STATE.challenge_charge_map or {}
    STATE.challenge_charge_map[challenge_id] = math.max(0, tonumber(value) or 0)
    sync_challenge_summary_cache()
  end
  ctx.set_challenge_charge_count = set_challenge_charge_count

  local function get_challenge_recover_elapsed(challenge_id)
    if STATE.challenge_recover_elapsed_map and STATE.challenge_recover_elapsed_map[challenge_id] ~= nil then
      return tonumber(STATE.challenge_recover_elapsed_map[challenge_id]) or 0
    end
    return tonumber(STATE.challenge_recover_elapsed) or 0
  end
  ctx.get_challenge_recover_elapsed = get_challenge_recover_elapsed

  local function set_challenge_recover_elapsed(challenge_id, value)
    STATE.challenge_recover_elapsed_map = STATE.challenge_recover_elapsed_map or {}
    STATE.challenge_recover_elapsed_map[challenge_id] = math.max(0, tonumber(value) or 0)
    sync_challenge_summary_cache()
  end
  ctx.set_challenge_recover_elapsed = set_challenge_recover_elapsed

  local function has_unit_data(unit_id)
    return unit_id ~= nil and y3.object.unit[unit_id] and y3.object.unit[unit_id].data ~= nil
  end
  ctx.has_unit_data = has_unit_data

  local function resolve_runtime_enemy_unit_id(unit_id)
    if has_unit_data(unit_id) then
      return unit_id
    end
    if has_unit_data(ENEMY_RUNTIME_FALLBACK_UNIT_ID) then
      return ENEMY_RUNTIME_FALLBACK_UNIT_ID
    end
    return unit_id
  end
  ctx.resolve_runtime_enemy_unit_id = resolve_runtime_enemy_unit_id

  local MODEL_DRIVEN_ATTR_KEYS = {
    '生命',
    'hp_max',
    '攻击',
    '物理攻击',
    '护甲',
    '移动速度',
    '攻击速度',
  }

  local MODEL_DRIVEN_ABILITY_TYPES = {
    y3.const.AbilityType.HIDE,
    y3.const.AbilityType.NORMAL,
    y3.const.AbilityType.COMMON,
    y3.const.AbilityType.HERO,
  }

  local function build_enemy_spawn_spec(unit_id, info)
    local spec = {
      create_unit_id = nil,
      model_id = info and tonumber(info.model_id) or nil,
      extra_ability_ids = info and info.extra_ability_ids or nil,
    }
    spec.create_unit_id = resolve_runtime_enemy_unit_id(unit_id)
    spec.profile_unit_id = spec.create_unit_id
    return spec
  end
  ctx.build_enemy_spawn_spec = build_enemy_spawn_spec

  local function apply_enemy_model_profile(unit, spec)
    if not unit or not spec then
      return
    end
    local invalid_model_ids = {
      [134278989] = true,
      [134245850] = true,
    }
    if spec.model_id and unit.replace_model and not invalid_model_ids[spec.model_id] then
      pcall(unit.replace_model, unit, spec.model_id)
    end

    local profile_unit_id = spec.profile_unit_id
    if not profile_unit_id or not has_unit_data(profile_unit_id) then
      return
    end

    local unit_point = unit.get_point and unit:get_point() or STATE.defense_point
    local ok_proxy, proxy_or_err = pcall(y3.unit.create_unit, env.get_enemy_player(), profile_unit_id, unit_point, 180.0)
    if not ok_proxy or not proxy_or_err then
      return
    end
    local proxy = proxy_or_err

    for _, attr_key in ipairs(MODEL_DRIVEN_ATTR_KEYS) do
      local value = tonumber(proxy:get_attr(attr_key))
      if value and value > 0 then
        unit:set_attr(attr_key, value)
      end
    end

    local max_hp = tonumber(unit:get_attr('生命')) or tonumber(unit:get_attr('最大生命'))
    if max_hp and max_hp > 0 then
      unit:set_hp(max_hp)
    end

    for _, ability_type in ipairs(MODEL_DRIVEN_ABILITY_TYPES) do
      for slot = 0, 24 do
        local ok_ability, ability_key = pcall(GameAPI.api_get_abilityKey_by_unitkey, profile_unit_id, ability_type, slot)
        if not ok_ability or type(ability_key) ~= 'number' or ability_key <= 0 then
          break
        end
        if unit.find_ability and unit.add_ability then
          local exists = unit:find_ability(ability_type, ability_key)
          if not exists then
            unit:add_ability(ability_type, ability_key, slot, 1)
          end
        end
      end
    end

    for _, ability_id in ipairs(spec.extra_ability_ids or {}) do
      if ability_id and ability_id > 0 and unit.find_ability and unit.add_ability then
        local exists = unit:find_ability(y3.const.AbilityType.HERO, ability_id)
        if not exists then
          unit:add_ability(y3.const.AbilityType.HERO, ability_id, -1, 1)
        end
      end
    end

    if proxy and proxy.is_exist and proxy:is_exist() then
      proxy:remove()
    end
  end
  ctx.apply_enemy_model_profile = apply_enemy_model_profile

  local function is_active_enemy(unit)
    return unit
      and unit:is_exist()
      and unit ~= STATE.hero
      and STATE.all_enemies
      and unit:is_in_group(STATE.all_enemies)
  end
  ctx.is_active_enemy = is_active_enemy

  local function get_enemy_runtime_info(unit)
    if not STATE.enemy_info_map or not unit then
      return nil
    end
    return STATE.enemy_info_map[unit]
  end
  ctx.get_enemy_runtime_info = get_enemy_runtime_info

  local function is_point_in_area(point, area)
    if not point or not area then
      return false
    end
    local x = point:get_x()
    local y = point:get_y()
    return x >= area.x_min and x <= area.x_max and y >= area.y_min and y <= area.y_max
  end
  ctx.is_point_in_area = is_point_in_area

  local function is_boss_runtime_enemy(info)
    return info and (info.kind == 'boss' or info.is_boss == true) or false
  end
  ctx.is_boss_runtime_enemy = is_boss_runtime_enemy

  local function is_elite_runtime_enemy(info)
    return info and (info.is_elite == true or is_boss_runtime_enemy(info)) or false
  end
  ctx.is_elite_runtime_enemy = is_elite_runtime_enemy

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
  ctx.scale_enemy_count = scale_enemy_count

  local function get_enemy_batch_scale()
    return tonumber(CONFIG.enemy_spawn_batch_scale) or 1.0
  end
  ctx.get_enemy_batch_scale = get_enemy_batch_scale

  local function get_enemy_alive_cap_scale()
    return tonumber(CONFIG.enemy_alive_cap_scale) or 1.0
  end
  ctx.get_enemy_alive_cap_scale = get_enemy_alive_cap_scale

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
  ctx.get_wave_batch_bounds = get_wave_batch_bounds

  local function get_wave_max_alive(wave)
    local base_max_alive = tonumber(wave and wave.max_alive) or 0
    if base_max_alive <= 0 then
      return 0
    end
    return scale_enemy_count(base_max_alive, get_enemy_alive_cap_scale())
  end
  ctx.get_wave_max_alive = get_wave_max_alive

  local function get_scaled_challenge_batch_count(batch)
    local base_count = tonumber(batch and batch.count) or 0
    if base_count <= 0 then
      return 0
    end
    return scale_enemy_count(base_count, get_enemy_batch_scale())
  end
  ctx.get_scaled_challenge_batch_count = get_scaled_challenge_batch_count

  local function get_monster_type_config(info)
    if CONFIG and CONFIG.monster_type_config then
      local monster_type = CONFIG.monster_type_config.resolve_type(info)
      return CONFIG.monster_type_config.get_config(monster_type)
    end
    return nil
  end
  ctx.get_monster_type_config = get_monster_type_config

  local function get_enemy_spawn_speed_factor(info)
    local kind = info and info.kind or 'main'
    local factor = ENEMY_BASE_SPEED_FACTORS[kind]
    if factor == nil then
      factor = ENEMY_BASE_SPEED_FACTORS.main
    end
    local type_config = get_monster_type_config(info)
    if type_config and type_config.move_speed_scale then
      factor = factor * type_config.move_speed_scale
    end
    factor = factor * (tonumber(CONFIG.enemy_move_speed_scale) or 1.0)
    return math.max(0.05, tonumber(factor) or 1)
  end
  ctx.get_enemy_spawn_speed_factor = get_enemy_spawn_speed_factor

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
  ctx.apply_spawn_enemy_speed_tuning = apply_spawn_enemy_speed_tuning

  local function get_current_wave()
    return CONFIG.waves[STATE.current_wave_index]
  end
  ctx.get_current_wave = get_current_wave

  local function is_n0_stage_active()
    local stage_def = STATE and STATE.current_stage_def or nil
    local stage_id = tostring(stage_def and stage_def.stage_id or '')
    if stage_id:match('%-0$') then
      return true
    end
    local display_name = tostring(stage_def and stage_def.display_name or '')
    if display_name:find('N0', 1, true) then
      return true
    end
    return false
  end
  ctx.is_n0_stage_active = is_n0_stage_active

  local function get_boss_name(wave)
    return string.format('第%d波Boss', wave.index)
  end
  ctx.get_boss_name = get_boss_name

  local function clone_point(point)
    if not point or not point.move then
      return nil
    end
    return point:move()
  end
  ctx.clone_point = clone_point

  local function get_unit_point_snapshot(unit)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return nil
    end
    return clone_point(unit:get_point())
  end
  ctx.get_unit_point_snapshot = get_unit_point_snapshot

  local function create_point_particle(effect_key, point, angle, scale, time, height, color, anim_speed)
    if is_hit_effect_hidden() or not effect_key or not point then
      return nil
    end

    local forced = tonumber(STATE and STATE.debug_force_projectile_key) or 0
    local key = forced > 0 and math.floor(forced) or 201392033
    local ok, particle = pcall(y3.projectile.create, {
      key = key,
      target = point,
      socket = 'origin',
      owner = STATE and STATE.hero or nil,
      angle = angle or 0,
      time = scale_visual_duration(time),
      remove_immediately = true,
    })
    if not ok or not particle then
      return nil
    end

    pcall(function()
      particle:set_facing(angle or 0)
    end)
    return particle
  end
  ctx.create_point_particle = create_point_particle

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
  ctx.spray_particle_line = spray_particle_line

  local function get_unit_max_hp(unit)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return 0
    end
    return y3.helper.tonumber(unit:get_attr('生命')) or y3.helper.tonumber(unit:get_attr('最大生命')) or 0
  end
  ctx.get_unit_max_hp = get_unit_max_hp
end

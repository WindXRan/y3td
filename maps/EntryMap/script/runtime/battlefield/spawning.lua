return function(ctx)
  local EventBus = require 'runtime.event_bus'
  local STATE = ctx.STATE
  local CONFIG = ctx.CONFIG
  local y3 = ctx.y3
  local message = ctx.message
  local env = ctx.env
  local api = ctx.api
  local set_attr_pack = ctx.set_attr_pack
  local random_point_in_area = ctx.random_point_in_area
  local ENEMY_RUNTIME_FALLBACK_UNIT_ID = ctx.ENEMY_RUNTIME_FALLBACK_UNIT_ID

  local has_unit_data = ctx.has_unit_data
  local get_boss_name = ctx.get_boss_name
  local is_n0_stage_active = ctx.is_n0_stage_active
  local build_enemy_spawn_spec = ctx.build_enemy_spawn_spec
  local apply_enemy_model_profile = ctx.apply_enemy_model_profile
  local get_wave_batch_bounds = ctx.get_wave_batch_bounds
  local get_wave_max_alive = ctx.get_wave_max_alive
  local get_scaled_challenge_batch_count = ctx.get_scaled_challenge_batch_count
  local is_point_in_area = ctx.is_point_in_area
  local apply_spawn_enemy_speed_tuning = ctx.apply_spawn_enemy_speed_tuning
  local play_enemy_hit_reaction = ctx.play_enemy_hit_reaction
  local play_enemy_death_reaction = ctx.play_enemy_death_reaction

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

    EventBus.fire('finish_game', result)
  end
  ctx.finish_game = finish_game

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
    STATE.total_enemy_alive = (STATE.total_enemy_alive or 0) + 1

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
      if STATE.basic_attack_pending_damage and unit then
        STATE.basic_attack_pending_damage[unit] = nil
      end
      if STATE.total_enemy_alive and STATE.total_enemy_alive > 0 then
        STATE.total_enemy_alive = STATE.total_enemy_alive - 1
      end
      if info.owner and info.owner.alive_count and info.owner.alive_count > 0 then
        info.owner.alive_count = info.owner.alive_count - 1
      end
      if info.owner and info.owner.infos then
        info.owner.dead_count = (info.owner.dead_count or 0) + 1
      end

      if grant_death_rewards then
        local scaled_reward = info.reward
        if scaled_reward and CONFIG and CONFIG.monster_type_config then
          local monster_type = CONFIG.monster_type_config.resolve_type(info)
          scaled_reward = CONFIG.monster_type_config.apply_reward_scaling(scaled_reward, monster_type)
        end

        if info.kind == 'main' then
          env.award_rewards(scaled_reward, nil, true)
        elseif info.kind == 'boss' then
          env.award_rewards(scaled_reward, get_boss_name(info.wave), false)
        elseif info.kind == 'challenge' and scaled_reward then
          env.award_rewards(scaled_reward, nil, true)
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
        STATE.defeated_boss_waves[info.wave.index] = true
        if info.wave.index >= #CONFIG.waves then
          finish_game(true, '击败最终 Boss。')
        else
          local next_wave = CONFIG.waves[info.wave.index + 1]
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

      if info.kind == 'main' and STATE.skill_runtime then
        local bonus = STATE.skill_runtime:get('bonus_gold_on_kill') or 0
        if bonus > 0 then
          ctx.resource_system.add_gold(bonus)
        end
      end

      y3.ltimer.wait(corpse_remove_delay, function()
        if unit and unit:is_exist() then
          unit:remove()
        end
      end)
    end)

    return info
  end
  ctx.create_enemy_info = create_enemy_info

  local function get_main_enemy_slow_factor(info)
    if not info or not info.unit or not info.unit.is_exist or not info.unit:is_exist() then
      return 1
    end
    local unit_point = info.unit:get_point()
    if not unit_point then
      return 1
    end
    local slow_zones = CONFIG.main_enemy_slow_zones
    if not slow_zones then
      return 1
    end
    for _, zone in ipairs(slow_zones) do
      local area = CONFIG.areas and CONFIG.areas[zone.area_id]
      if area and is_point_in_area(unit_point, area) then
        return zone.speed_factor or 1
      end
    end
    return 1
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
    local spawn_spec = build_enemy_spawn_spec(unit_id, info)
    local runtime_unit_id = spawn_spec.create_unit_id
    local spawn_point = random_point_in_area(area_id)
    
    print(string.format('[SPAWN DEBUG] spawn_enemy: area_id=%s, unit_id=%s, spawn_point=%s',
      tostring(area_id), tostring(runtime_unit_id),
      spawn_point and string.format('(%.0f,%.0f)', spawn_point.x, spawn_point.y) or 'nil'))
    
    local ok, unit_or_err = pcall(y3.unit.create_unit, env.get_enemy_player(), runtime_unit_id, spawn_point, facing or 180.0)
    if (not ok or not unit_or_err) and runtime_unit_id ~= ENEMY_RUNTIME_FALLBACK_UNIT_ID then
      ok, unit_or_err = pcall(y3.unit.create_unit, env.get_enemy_player(), ENEMY_RUNTIME_FALLBACK_UNIT_ID, spawn_point, facing or 180.0)
      if ok and unit_or_err and message then
        message(string.format(
          '刷怪降级：单位 %s(解析后:%s) 创建失败，已自动回退到 %s。',
          tostring(unit_id),
          tostring(runtime_unit_id),
          tostring(ENEMY_RUNTIME_FALLBACK_UNIT_ID)
        ))
      end
    end
    if not ok or not unit_or_err then
      if message then
        message(string.format('刷怪失败：单位 %s(解析后:%s) 创建失败，请检查物编/模型资源是否已加载。', tostring(unit_id), tostring(runtime_unit_id)))
      end
      return nil
    end
    local unit = unit_or_err
    print('[SPAWN DEBUG] spawn_enemy 成功: unit=' .. tostring(unit and unit:get_name()))
    apply_enemy_model_profile(unit, spawn_spec)

    local scaled_attrs = info and info.attr_overrides
    if scaled_attrs and CONFIG and CONFIG.monster_type_config then
      local monster_type = CONFIG.monster_type_config.resolve_type(info)
      scaled_attrs = CONFIG.monster_type_config.apply_attr_scaling(scaled_attrs, monster_type)
    end

    if scaled_attrs then
      set_attr_pack(unit, scaled_attrs)
    elseif info and info.attr_overrides then
      set_attr_pack(unit, info.attr_overrides)
    end

    print('[HP DEBUG] pre-set_attr: max_life=' .. tostring(unit:get_attr('hp_max')) .. ' spawn_hp=' .. tostring(info and info.spawn_hp))
    if info and info.spawn_hp ~= nil and info.spawn_hp > 1 then
      unit:set_attr('hp_max', info.spawn_hp)
      print('[HP DEBUG] spawn_hp分支: after set_attr max=' .. tostring(unit:get_attr('hp_max')) .. ' after set_hp=' .. tostring(unit:get_hp()) .. ' expected=' .. tostring(info.spawn_hp))
      unit:set_hp(info.spawn_hp)
      info.max_hp = info.spawn_hp
    else
      local max_hp = nil
      if scaled_attrs then
        max_hp = tonumber(scaled_attrs['hp_max'])
      end
      if not max_hp or max_hp <= 0 then
        max_hp = tonumber(unit:get_attr('hp_max')) or 1500
      end
      unit:set_attr('hp_max', max_hp)
      print('[HP DEBUG] 回退分支: after set_attr max=' .. tostring(unit:get_attr('hp_max')) .. ' after set_hp=' .. tostring(unit:get_hp()) .. ' expected=' .. tostring(max_hp))
      unit:set_hp(max_hp)
      info.max_hp = max_hp
    end
    apply_spawn_enemy_speed_tuning(unit, info)
    unit:set_reward_exp(0)
    unit:attack_move(STATE.defense_point)
    return create_enemy_info(unit, info)
  end
  ctx.spawn_enemy = spawn_enemy

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
      print('[SPAWN DEBUG] can_spawn_main_batch=false: alive_count=' .. runner.alive_count .. ' >= max_alive=' .. max_alive)
      return false
    end
    local soft_cap = CONFIG.total_enemy_soft_cap or 40
    if STATE.total_enemy_alive >= soft_cap then
      print('[SPAWN DEBUG] can_spawn_main_batch=false: total_enemy_alive=' .. STATE.total_enemy_alive .. ' >= soft_cap=' .. soft_cap)
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
      local spawn_info = spawn_enemy(nil, wave.spawn_area_id, 180.0, {
        kind = 'main',
        owner = runner,
        wave = wave,
        model_id = wave.main_model_id,
        template_unit_id = wave.main_template_unit_id,
        extra_ability_ids = wave.main_extra_ability_ids,
        attr_overrides = wave.main_attr_overrides,
        spawn_hp = wave.main_spawn_hp,
        reward = wave.main_kill_reward,
      })
      if not spawn_info then
        break
      end
    end
  end

  local function spawn_boss(runner)
    if not runner or runner.boss_spawned or STATE.game_finished then
      return
    end
    runner.boss_spawned = true
    runner.boss_info = spawn_enemy(nil, runner.wave.boss_spawn_area_id, 180.0, {
      kind = 'boss',
      owner = runner,
      wave = runner.wave,
      model_id = runner.wave.boss_model_id,
      template_unit_id = runner.wave.boss_template_unit_id,
      extra_ability_ids = runner.wave.boss_extra_ability_ids,
      attr_overrides = runner.wave.boss_attr_overrides,
      spawn_hp = runner.wave.boss_spawn_hp,
      reward = runner.wave.boss_kill_reward,
    })
    if not runner.boss_info then
      runner.boss_spawned = false
      return
    end
    EventBus.fire('boss_spawned', runner.boss_info)
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
    }
    STATE.active_challenges[instance.id] = instance

    EventBus.fire('challenge_started', instance)
    return instance
  end
  ctx.create_challenge_instance = create_challenge_instance

  local function spawn_n0_debug_dummies()
    if not is_n0_stage_active() then
      return
    end
    if STATE.n0_dummies_spawned then
      return
    end
    STATE.n0_dummies_spawned = true
    STATE.n0_dummy_units = {}

    local spawn_area_id = 'main_spawn'
    local area_def = CONFIG.areas and CONFIG.areas[spawn_area_id]
    if not area_def then
      return
    end

    local cx = math.floor((area_def.x_min + area_def.x_max) / 2)
    local cy = math.floor((area_def.y_min + area_def.y_max) / 2)
    local z = area_def.z or 0
    local player = env.get_enemy_player()
    local fallback_id = ENEMY_RUNTIME_FALLBACK_UNIT_ID

    local dummy_specs = {
      { kind = 'main',      name = '普通靶子', offset_y = -150, is_elite = false },
      { kind = 'main',      name = '精英靶子', offset_y = -50,  is_elite = true  },
      { kind = 'boss',      name = 'Boss靶子', offset_y = 50,   is_elite = false },
      { kind = 'challenge', name = '挑战靶子', offset_y = 150,  is_elite = false },
    }

    for _, spec in ipairs(dummy_specs) do
      local point = y3.point.create(cx, cy + spec.offset_y, z)
      local ok, unit = pcall(y3.unit.create_unit, player, fallback_id, point, 180.0)
      if ok and unit then
        local wave_1 = CONFIG.waves and CONFIG.waves[1]
        local dummy_hp = 1200
        if wave_1 then
            if spec.kind == 'boss' and wave_1.boss_attr_overrides then
                dummy_hp = tonumber(wave_1.boss_attr_overrides['hp_max']) or dummy_hp
            elseif wave_1.main_attr_overrides then
                dummy_hp = tonumber(wave_1.main_attr_overrides['hp_max']) or dummy_hp
            end
            if spec.is_elite then dummy_hp = dummy_hp * 3 end
        end
        unit:set_hp(dummy_hp)
        unit:set_attr('移动速度', 0)
        STATE.n0_dummy_units[#STATE.n0_dummy_units + 1] = unit
      end
    end
  end
  ctx.spawn_n0_debug_dummies = spawn_n0_debug_dummies

  ctx.can_spawn_main_batch = can_spawn_main_batch
  ctx.spawn_main_batch = spawn_main_batch
  ctx.get_spawn_interval = get_spawn_interval
  ctx.spawn_boss = spawn_boss
  ctx.apply_main_enemy_lane_slow = apply_main_enemy_lane_slow
  ctx.cleanup_challenge_units = cleanup_challenge_units
end

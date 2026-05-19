return function(ctx)
  local EventBus = require 'runtime.core.event_bus'
  local STATE = ctx.STATE
  local CONFIG = ctx.CONFIG
  local y3 = ctx.y3
  local message = ctx.message
  local env = ctx.env
  local api = ctx.api
  local hero_attr_system = ctx.hero_attr_system
  local hero_model = ctx.hero_model
  local HERO_RUNTIME_FALLBACK_UNIT_ID = ctx.HERO_RUNTIME_FALLBACK_UNIT_ID

  local try_create_player_unit = ctx.try_create_player_unit
  local has_unit_data = ctx.has_unit_data
  local resolve_runtime_enemy_unit_id = ctx.resolve_runtime_enemy_unit_id
  local get_challenge_charge_count = ctx.get_challenge_charge_count
  local set_challenge_charge_count = ctx.set_challenge_charge_count
  local get_challenge_recover_elapsed = ctx.get_challenge_recover_elapsed
  local set_challenge_recover_elapsed = ctx.set_challenge_recover_elapsed
  local get_challenge_recover_sec = ctx.get_challenge_recover_sec
  local get_scaled_challenge_batch_count = ctx.get_scaled_challenge_batch_count

  local create_challenge_instance = ctx.create_challenge_instance
  local cleanup_challenge_units = ctx.cleanup_challenge_units
  local spawn_enemy = ctx.spawn_enemy
  local can_spawn_main_batch = ctx.can_spawn_main_batch
  local spawn_main_batch = ctx.spawn_main_batch
  local get_spawn_interval = ctx.get_spawn_interval
  local spawn_boss = ctx.spawn_boss
  local apply_main_enemy_lane_slow = ctx.apply_main_enemy_lane_slow
  local finish_game = ctx.finish_game
  function api.start_wave(index)
    local wave = CONFIG.waves[index]
    if not wave then
      print('[SPAWN DEBUG] start_wave 失败: wave not found, index=' .. tostring(index))
      return
    end
    if STATE.game_finished then
      print('[SPAWN DEBUG] start_wave 跳过: game_finished=true')
      return
    end
    if STATE.session_phase ~= 'battle' then
      print('[SPAWN DEBUG] start_wave 跳过: session_phase=' .. tostring(STATE.session_phase))
      return
    end
    print('[SPAWN DEBUG] start_wave 成功: index=' .. tostring(index) .. ', wave=' .. tostring(wave.name) .. ', spawn_area=' .. tostring(wave.spawn_area_id))

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

    EventBus.fire('wave_started', index)
  end

  function api.finish_challenge(instance, is_success)
    if not instance or not instance.active then
      return
    end

    instance.active = false
    STATE.active_challenges[instance.id] = nil

    if is_success then
      message(instance.def.name .. ' 成功。')
      env.award_rewards(instance.def.reward, instance.def.name .. ' 成功', false)
    else
      cleanup_challenge_units(instance)
      message(instance.def.name .. ' 失败。')
    end

    EventBus.fire('challenge_finished', instance, is_success)
  end

  local function spawn_challenge_batch(instance, batch_index, batch)
    if instance.spawned_batches[batch_index] then
      return
    end
    instance.spawned_batches[batch_index] = true
    local spawned_any = false
    local batch_count = get_scaled_challenge_batch_count(batch)

    for _ = 1, batch_count, 1 do
      local info = spawn_enemy(instance.def.unit_id, instance.def.spawn_area_id, 180.0, {
        kind = 'challenge',
        owner = instance,
        attr_overrides = instance.def.attr_overrides,
        reward = instance.def.kill_reward,
      })
      if info then
        instance.infos[#instance.infos + 1] = info
        spawned_any = true
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

  function api.update_wave(dt)
    local runner = STATE.active_wave
    if not runner then
      return
    end
    if not runner.active then
      return
    end
    if STATE.game_finished then
      return
    end
    if STATE.session_phase ~= 'battle' then
      return
    end

    runner.elapsed = runner.elapsed + dt

    if runner.elapsed < 10 and math.floor(runner.elapsed * 2) ~= math.floor((runner.elapsed - dt) * 2) then
      local should_spawn = can_spawn_main_batch(runner)
      print(string.format('[SPAWN DEBUG] update_wave: elapsed=%.1f, alive=%d, next_spawn=%.1f, should_spawn=%s',
        runner.elapsed, runner.alive_count, runner.next_spawn_sec, tostring(should_spawn)))
    end

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
        EventBus.fire('boss_warning', runner.wave, remain)
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

    for challenge_id in pairs(CONFIG.challenges or {}) do
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
      hp = tonumber(hero:get_attr('生命')) or tonumber(hero:get_attr('hp_max')) or 0
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
    local hero, hero_create_err = try_create_player_unit(player, HERO_RUNTIME_FALLBACK_UNIT_ID, STATE.hero_spawn_point, 0)
    if not hero then
      error(string.format(
        'failed to create hero unit id=%s err=%s',
        tostring(HERO_RUNTIME_FALLBACK_UNIT_ID),
        tostring(hero_create_err)
      ))
    end
    if hero_model then
      local initial_hero = (CONFIG.GameTables and CONFIG.GameTables.hero_roster and CONFIG.GameTables.hero_roster.initial_hero)
      local hero_name = initial_hero and initial_hero.name or nil
      local hero_id = initial_hero and initial_hero.id or nil
      local ok = hero_model.apply_hero_model(hero, { hero_name = hero_name, hero_id = hero_id })
      if ok then
        local model_id = hero_model.resolve_model_id({ hero_name = hero_name, hero_id = hero_id, unit = hero })
        print('[Battlefield] Hero model applied: ' .. tostring(model_id))
      else
        print('[Battlefield] Hero model application failed, using template default')
      end
    else
      print('[Battlefield] hero_model module not available')
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
    local initial_attack_range = tonumber(hero_entry_stats['攻击范围']) or basic_attack_range or 2000
    hero_attr_system.set_attr(hero, '攻击范围', math.max(80, math.floor(initial_attack_range)))

    do
      local BuffSystem = require 'runtime.effects.buff_system'
      BuffSystem.apply_buff(hero, 'immobilize', -1, 1, nil)
    end
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
      EventBus.fire('hero_damage', data)
    end)

    hero:event('单位-造成伤害时', function(_, data)
      EventBus.fire('formula_damage_override', data)
    end)

    hero:event('单位-受到伤害前', function(_, data)
      local source_unit = data.source_unit
      local damage_instance = data.damage_instance

      if source_unit and source_unit == hero then
        if damage_instance and damage_instance.set_damage then
          pcall(function() damage_instance:set_damage(0) end)
        end
        if log and log.info then
          log.info('[battlefield] 拦截英雄自伤')
        end
        return
      end

      local is_enemy = false
      if source_unit then
        local ok, result = pcall(function()
          return source_unit:is_enemy(BootHelpers.get_player())
        end)
        if ok and result then
          is_enemy = true
        end
      end

      if not is_enemy then
        if damage_instance and damage_instance.set_damage then
          pcall(function() damage_instance:set_damage(0) end)
        end
        if log and log.info then
          log.info('[battlefield] 拦截非敌人来源伤害')
        end
        return
      end

      EventBus.fire('hero_before_hurt', data)
    end)

    hero:event('单位-受到伤害后', function()
      if hero_attr_system and hero_attr_system.log_snapshot then
        hero_attr_system.log_snapshot(hero, 'hero_be_hurt', string.format('hp=%s', tostring(hero:get_hp())))
      end
      EventBus.fire('hero_be_hurt')
    end)

    EventBus.fire('hero_attr_changed')

    schedule_hero_spawn_attr_logs(hero)

    return hero
  end

  function api.cleanup_battle_units()
    api.destroy_debug_spawn_areas()
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

    if STATE.n0_dummy_units then
      for _, unit in ipairs(STATE.n0_dummy_units) do
        pcall(unit.remove, unit)
      end
      STATE.n0_dummy_units = nil
    end
    STATE.n0_dummies_spawned = nil
  end

  function api.validate_config()
    local missing = {}
    local checked = {}
    local fallback_lines = {}

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
        local fallback_id = resolve_runtime_enemy_unit_id(unit_id)
        fallback_lines[#fallback_lines + 1] = string.format('%s: %d -> fallback:%s', name, unit_id, tostring(fallback_id))
      end
    end

    check_unit('hero', CONFIG.unit_ids.hero)
    for id, wave in ipairs(CONFIG.waves) do
      check_unit('wave[' .. tostring(id) .. '].main_template_unit_id', wave.main_template_unit_id)
      check_unit('wave[' .. tostring(id) .. '].boss_template_unit_id', wave.boss_template_unit_id)
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
    if #fallback_lines > 0 then
      message('检测到缺失单位物编 ID，主循环将继续并使用 fallback 单位：')
      for _, line in ipairs(fallback_lines) do
        message(line)
      end
    end

    if #missing > 0 then
      message('配置存在缺失项（非单位物编），主循环骨架未启动：')
      for _, line in ipairs(missing) do
        message(line)
      end
      return false
    end

    return true
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

  local debug_spawn_areas = {}

  function api.create_debug_spawn_areas()
    if not y3 or not y3.area or not y3.point then
      return
    end
    api.destroy_debug_spawn_areas()
    local spawn_keys = {
      'main_spawn',
      'boss_spawn',
      'challenge_spawn_top', 'challenge_spawn_mid', 'challenge_spawn_bottom',
    }
    local player = env.get_player and env.get_player()
    for _, key in ipairs(spawn_keys) do
      local area_def = CONFIG.areas and CONFIG.areas[key]
      if area_def then
        local cx = (area_def.x_min + area_def.x_max) / 2
        local cy = (area_def.y_min + area_def.y_max) / 2
        local w = area_def.x_max - area_def.x_min
        local h = area_def.y_max - area_def.y_min
        local ok, area = pcall(y3.area.create_rectangle_area, y3.point.create(cx, cy, area_def.z or 0), w, h)
        if ok and area then
          pcall(area.set_collision, area, true, true, true)
          if player then
            pcall(area.set_visible, area, player, true, true)
          end
          debug_spawn_areas[#debug_spawn_areas + 1] = area
        end
      end
    end
  end

  function api.destroy_debug_spawn_areas()
    for _, area in ipairs(debug_spawn_areas) do
      pcall(area.remove, area)
    end
    debug_spawn_areas = {}
  end
end

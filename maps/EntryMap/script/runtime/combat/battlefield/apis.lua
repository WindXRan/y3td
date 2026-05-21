return function(ctx)
  local GameEvents = require 'runtime.events.game_events'
  local STATE = ctx.STATE
  local CONFIG = ctx.CONFIG
  local y3 = ctx.y3
  local message = ctx.message
  local env = ctx.env
  local api = ctx.api
  local HERO_RUNTIME_FALLBACK_UNIT_ID = ctx.HERO_RUNTIME_FALLBACK_UNIT_ID

  local try_create_player_unit = ctx.try_create_player_unit
  local has_unit_data = ctx.has_unit_data
  local resolve_runtime_enemy_unit_id = ctx.resolve_runtime_enemy_unit_id
  local spawn_enemy = ctx.spawn_enemy
  local can_spawn_main_batch = ctx.can_spawn_main_batch
  local spawn_main_batch = ctx.spawn_main_batch
  local get_spawn_interval = ctx.get_spawn_interval
  local spawn_boss = ctx.spawn_boss
  local apply_main_enemy_lane_slow = ctx.apply_main_enemy_lane_slow
  function api.start_wave(index)
    local wave = CONFIG.waves[index]
    if not wave then
      print('[SPAWN DEBUG] start_wave 失败: wave not found, index=' .. tostring(index))
      return
    end
    STATE.game_finished = false
    STATE.session_phase = 'battle'
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

    y3.game:event_notify(GameEvents.BATTLE_WAVE_STARTED, index)
  end

  function api.update_wave(dt)
    local runner = STATE.active_wave
    if not runner then
      return
    end
    if not runner.active then
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
        y3.game:event_notify(GameEvents.BATTLE_BOSS_WARNING, runner.wave, remain)
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

    local hero_init_stats = CONFIG and CONFIG.hero_init_stats or {}
    for attr_name, value in pairs(hero_init_stats) do
      local num_value = tonumber(value)
      if num_value then
        result[attr_name] = num_value
      end
    end

    local profile = STATE.outgame_profile
    local bonus_stats = profile and profile.hero_attr_bonus_stats or {}
    for attr_name, value in pairs(bonus_stats) do
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
    local player
    if env and env.get_player then
      player = env.get_player()
    elseif _G.get_player then
      player = _G.get_player()
    elseif y3 and y3.player and y3.player.get_main_player then
      player = y3.player.get_main_player()
    end
    local hero, hero_create_err = try_create_player_unit(player, HERO_RUNTIME_FALLBACK_UNIT_ID, STATE.hero_spawn_point, 0)
    if not hero then
      error(string.format(
        'failed to create hero unit id=%s err=%s',
        tostring(HERO_RUNTIME_FALLBACK_UNIT_ID),
        tostring(hero_create_err)
      ))
    end

    hero:set_name('守关英雄')

    if player and player.select_unit then
      player:select_unit(hero)
    end

    STATE.hero_common_attack = hero:get_common_attack()

    hero:event('单位-死亡', function()
    end)

    hero:event('单位-受到伤害后', function()
      y3.game:event_notify(GameEvents.BATTLE_HERO_HURT)
    end)

    y3.game:event_notify(GameEvents.HERO_ATTR_CHANGED)

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

  local debug_spawn_areas = {}

  function api.create_debug_spawn_areas()
    if not y3 or not y3.area or not y3.point then
      return
    end
    api.destroy_debug_spawn_areas()
    local spawn_keys = {
      'main_spawn',
      'boss_spawn',
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
          pcall(area.set_collision, area, false, false, false)
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

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local design_seconds = env.design_seconds
  local random_point_in_area = env.random_point_in_area
  local set_attr_pack = env.set_attr_pack
  local add_attr_pack = env.add_attr_pack

  local api = {}

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

  local function is_boss_runtime_enemy(info)
    return info and (info.kind == 'boss' or info.is_boss == true) or false
  end

  local function is_elite_runtime_enemy(info)
    return info and (info.is_elite == true or is_boss_runtime_enemy(info)) or false
  end

  local function get_current_wave()
    return CONFIG.waves[STATE.current_wave_index]
  end

  local function get_boss_name(wave)
    return string.format('第%d波Boss', wave.index)
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
        end
      end

      return true
    end

    unit:event('单位-死亡', function()
      if not info.remove_runtime(true) then
        return
      end

      if info.kind == 'boss' then
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
    end)

    return info
  end

  local function spawn_enemy(unit_id, area_id, facing, info)
    local spawn_point = random_point_in_area(area_id)
    local unit = y3.unit.create_unit(env.get_enemy_player(), unit_id, spawn_point, facing or 180.0)
    if info and info.attr_overrides then
      set_attr_pack(unit, info.attr_overrides)
    end
    if info and info.spawn_hp ~= nil then
      unit:set_hp(info.spawn_hp)
    elseif info and info.attr_overrides and info.attr_overrides.hp_max ~= nil then
      unit:set_hp(info.attr_overrides.hp_max)
    end
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
    if runner.wave.max_alive and runner.alive_count >= runner.wave.max_alive then
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
    local batch_count = math.random(wave.batch_min, wave.batch_max)
    local soft_cap_left = CONFIG.total_enemy_soft_cap - STATE.total_enemy_alive
    local wave_cap_left = wave.max_alive - runner.alive_count
    batch_count = math.min(batch_count, soft_cap_left, wave_cap_left)

    for _ = 1, batch_count, 1 do
      spawn_enemy(wave.main_unit_id, wave.spawn_area_id, 180.0, {
        kind = 'main',
        owner = runner,
        wave = wave,
        attr_overrides = wave.main_attr_overrides,
        spawn_hp = wave.main_spawn_hp,
        reward = wave.main_kill_reward,
      })
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
  end

  local function cleanup_challenge_units(instance)
    for _, info in ipairs(instance.infos) do
      if info.alive and info.unit and info.unit:is_exist() then
        info.remove_runtime(false)
        info.unit:remove()
      end
    end
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
      boss_info = nil,
      alive_count = 0,
      next_spawn_sec = 0,
    }

    message(string.format('%s 开始，Boss 将在 %.0f 秒后加入战场。', wave.name, design_seconds(wave.boss_spawn_sec)))
  end

  function api.finish_challenge(instance, is_success)
    if not instance or not instance.active then
      return
    end

    instance.active = false
    STATE.active_challenges[instance.id] = nil

    if is_success then
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
  end

  local function spawn_challenge_batch(instance, batch_index, batch)
    if instance.spawned_batches[batch_index] then
      return
    end
    instance.spawned_batches[batch_index] = true

    if instance.def.id == 'treasure_trial' then
      if batch_index == 1 then
        local boss_info = spawn_enemy(instance.def.boss_unit_id, instance.def.spawn_area_id, 180.0, {
          kind = 'challenge',
          owner = instance,
          is_boss = true,
          is_elite = true,
          reward = nil,
        })
        instance.infos[#instance.infos + 1] = boss_info
        for _ = 1, batch.count - 1, 1 do
          local info = spawn_enemy(instance.def.guard_unit_id, instance.def.spawn_area_id, 180.0, {
            kind = 'challenge',
            owner = instance,
            is_elite = true,
            reward = nil,
          })
          instance.infos[#instance.infos + 1] = info
        end
      else
        for _ = 1, batch.count, 1 do
          local info = spawn_enemy(instance.def.guard_unit_id, instance.def.spawn_area_id, 180.0, {
            kind = 'challenge',
            owner = instance,
            is_elite = true,
            reward = nil,
          })
          instance.infos[#instance.infos + 1] = info
        end
      end
    else
      for _ = 1, batch.count, 1 do
        local info = spawn_enemy(instance.def.unit_id, instance.def.spawn_area_id, 180.0, {
          kind = 'challenge',
          owner = instance,
          reward = nil,
        })
        instance.infos[#instance.infos + 1] = info
      end
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

    if STATE.challenge_charges < def.cost_charge then
      message('挑战次数不足。')
      return
    end

    local recharge_was_full = STATE.challenge_charges >= CONFIG.challenge_rules.max_charges
    STATE.challenge_charges = STATE.challenge_charges - def.cost_charge
    if recharge_was_full then
      STATE.challenge_recover_elapsed = 0
    end

    local instance = {
      id = def.id,
      def = def,
      elapsed = 0,
      active = true,
      alive_count = 0,
      dead_count = 0,
      infos = {},
      spawned_batches = {},
      all_batches_spawned = false,
    }
    STATE.active_challenges[challenge_id] = instance

    message(string.format('%s 开始，持续 %.0f 秒。', def.name, design_seconds(def.duration_sec)))
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

    if not runner.boss_spawned and runner.elapsed >= runner.wave.boss_spawn_sec then
      spawn_boss(runner)
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

        if instance.active and instance.all_batches_spawned and instance.alive_count <= 0 then
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

    if STATE.challenge_charges >= CONFIG.challenge_rules.max_charges then
      STATE.challenge_recover_elapsed = 0
      return
    end

    STATE.challenge_recover_elapsed = STATE.challenge_recover_elapsed + dt
    while STATE.challenge_charges < CONFIG.challenge_rules.max_charges
      and STATE.challenge_recover_elapsed >= CONFIG.challenge_rules.recover_sec do
      STATE.challenge_recover_elapsed = STATE.challenge_recover_elapsed - CONFIG.challenge_rules.recover_sec
      STATE.challenge_charges = STATE.challenge_charges + 1
      message(string.format('挑战次数 +1，当前 %d/%d。', STATE.challenge_charges, CONFIG.challenge_rules.max_charges))
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

  function api.create_hero(basic_attack_range)
    local hero = env.get_player():create_unit(CONFIG.unit_ids.hero, STATE.hero_spawn_point, 0)
    env.get_player():select_unit(hero)

    hero:set_name('守关英雄')
    set_attr_pack(hero, CONFIG.hero_init_stats)
    hero:set_attr('attack_range', basic_attack_range or 250)
    hero:add_state('禁止普攻')

    hero:add_state('禁止移动')
    hero:add_state('禁止转向')
    hero:set_turning_speed(0)
    hero:stop()

    if CONFIG.debug_time_scale < 1 then
      add_attr_pack(hero, CONFIG.debug_hero_bonus_stats)
    end

    hero:set_hp(hero:get_attr('hp_max'))
    STATE.hero_common_attack = hero:get_common_attack()

    hero:event('单位-死亡', function()
      finish_game(false, '英雄倒下。')
    end)

    hero:event('单位-造成伤害后', function(_, data)
      env.on_hero_damage(data)
    end)

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

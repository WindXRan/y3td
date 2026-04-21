local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG or {}
  local y3 = env.y3
  local is_battle_active = env.is_battle_active
  local update_passive_resources = env.update_passive_resources
  local battlefield_system = env.battlefield_system
  local update_bond_effects = env.update_bond_effects
  local update_auto_active_effects = env.update_auto_active_effects
  local update_effect_debug = env.update_effect_debug
  local update_enemy_statuses = env.update_enemy_statuses
  local update_attack_skills = env.update_attack_skills
  local update_temporary_treasures = env.update_temporary_treasures
  local update_mainline_task = env.update_mainline_task
  local ensure_runtime_hud = env.ensure_runtime_hud
  local set_battle_hud_visible = env.set_battle_hud_visible
  local refresh_runtime_hud = env.refresh_runtime_hud
  local refresh_choice_panel = env.refresh_choice_panel
  local refresh_swallow_panel = env.refresh_swallow_panel
  local refresh_runtime_overview = env.refresh_runtime_overview
  local refresh_inventory_panel = env.refresh_inventory_panel
  local outgame_system = env.outgame_system
  local debug_tools_system = env.debug_tools_system
  local is_active_enemy = env.is_active_enemy
  local get_enemies_in_range = env.get_enemies_in_range
  local deal_skill_damage = env.deal_skill_damage
  local hero_attr_system = env.hero_attr_system
  local runtime_tick = 0.25
  local battle_ui_refresh_interval = math.max(0.25, tonumber(CONFIG.runtime_ui_refresh_interval) or 0.5)
  local battle_ui_refresh_slice_interval = math.max(runtime_tick, battle_ui_refresh_interval / 4)
  local artillery_damage_batch_size = 12
  local slow_update_threshold_ms = 25
  local frame_gap_threshold_ms = 80
  local function resolve_slow_update_log_path()
    if type(script_path) == 'string' then
      local script_root = script_path:match('^(.-)%?')
      if type(script_root) == 'string' and script_root ~= '' then
        return script_root .. '/.log/slow_update.log'
      end
    end
    return 'slow_update.log'
  end
  local slow_update_log_path = resolve_slow_update_log_path()
  local loops_started = false

  local function get_clock_ms()
    if os and os.clock_banned then
      return os.clock_banned() * 1000
    end
    if y3 and y3.ltimer and y3.ltimer.clock then
      return y3.ltimer.clock()
    end
    return nil
  end

  local function append_slow_update_log(line)
    local handle = io.open(slow_update_log_path, 'a')
    if not handle then
      return false
    end
    handle:write(line)
    handle:write('\n')
    handle:close()
    return true
  end

  local function reset_slow_update_log()
    local handle = io.open(slow_update_log_path, 'w')
    if not handle then
      return false
    end
    handle:write(string.format(
      '[diag.slow_update] reset phase=%s path=%s\n',
      tostring(STATE.session_phase),
      tostring(slow_update_log_path)
    ))
    handle:close()
    return true
  end

  local function log_frame_gap(scope, last_key, expected_ms)
    local now_ms = get_clock_ms()
    if not now_ms then
      return
    end
    local last_ms = STATE[last_key]
    STATE[last_key] = now_ms
    if not last_ms then
      return
    end
    local gap_ms = now_ms - last_ms
    local allowed_ms = math.max(expected_ms or 0, frame_gap_threshold_ms)
    if gap_ms <= allowed_ms then
      return
    end
    local line = string.format(
      '[diag.frame_gap] scope=%s gap_ms=%.3f expected_ms=%.3f phase=%s elapsed=%s',
      tostring(scope),
      gap_ms,
      expected_ms or 0,
      tostring(STATE.session_phase),
      tostring(STATE.runtime_elapsed or 0)
    )
    print(line)
    append_slow_update_log(line)
  end

  local function profile_if_slow(scope, fn, threshold_ms)
    local started_at = get_clock_ms()
    local results = { fn() }
    local ended_at = get_clock_ms()
    if started_at and ended_at then
      local cost_ms = ended_at - started_at
      if cost_ms >= (threshold_ms or slow_update_threshold_ms) then
        local line = string.format(
          '[diag.slow_update] scope=%s cost_ms=%s phase=%s elapsed=%s',
          tostring(scope),
          tostring(cost_ms),
          tostring(STATE.session_phase),
          tostring(STATE.runtime_elapsed or 0)
        )
        print(line)
        append_slow_update_log(line)
      end
    end
    return table.unpack(results)
  end

  local function get_hero_attack_value()
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, '攻击结算值') or STATE.hero:get_attr('攻击结算值')
    value = y3.helper.tonumber(value) or 0
    if value > 0 then
      return value
    end
    return y3.helper.tonumber(hero_attr_system and hero_attr_system.get_attr(STATE.hero, '攻击') or STATE.hero:get_attr('攻击') or STATE.hero:get_attr('物理攻击')) or 0
  end

  local function try_refresh_battle_ui_slice(slice_index)
    STATE.debug_battle_ui_refresh_count = (STATE.debug_battle_ui_refresh_count or 0) + 1
    if (STATE.debug_battle_ui_refresh_count % 20) == 1 then
      print(string.format(
        '[diag.loops] battle_ui_refresh count=%s slice=%s phase=%s visible=%s',
        tostring(STATE.debug_battle_ui_refresh_count),
        tostring(slice_index),
        tostring(STATE.session_phase),
        tostring(STATE.runtime_battle_ui_visible)
      ))
    end

    local ok, err = pcall(function()
      if slice_index == 1 then
        ensure_runtime_hud()
        refresh_runtime_hud()
        return
      end

      if slice_index == 2 then
        refresh_choice_panel()
        if refresh_swallow_panel then
          refresh_swallow_panel()
        end
        return
      end

      if slice_index == 3 then
        if refresh_inventory_panel then
          refresh_inventory_panel()
        end
        return
      end

      refresh_runtime_overview()
    end)
    if ok then
      STATE.runtime_ui_fault_logged = false
      STATE.runtime_ui_fault_message = nil
      return true
    end

    local err_text = tostring(err)
    if STATE.runtime_ui_fault_logged ~= true or STATE.runtime_ui_fault_message ~= err_text then
      print(string.format('[runtime.loops] battle ui refresh failed, gameplay continues: %s', err_text))
    end
    STATE.runtime_ui_fault_logged = true
    STATE.runtime_ui_fault_message = err_text
    return false
  end

  local function refresh_non_battle_ui()
    STATE.runtime_ui_refresh_elapsed = 0
    if STATE.runtime_battle_ui_visible == true then
      set_battle_hud_visible(false)
      STATE.runtime_battle_ui_visible = false
    end
    if outgame_system then
      outgame_system.refresh_ui()
    end
  end

  local function queue_artillery_barrage(damage, targets)
    if type(targets) ~= 'table' or #targets == 0 then
      return false
    end
    STATE.pending_artillery_barrages = STATE.pending_artillery_barrages or {}
    STATE.pending_artillery_barrages[#STATE.pending_artillery_barrages + 1] = {
      damage = damage,
      targets = targets,
    }
    return true
  end

  local function process_pending_artillery_barrages()
    local barrages = STATE.pending_artillery_barrages
    if type(barrages) ~= 'table' or #barrages == 0 then
      return
    end

    local next_barrages = {}
    for _, barrage in ipairs(barrages) do
      local targets = barrage.targets or {}
      local processed = 0
      while #targets > 0 and processed < artillery_damage_batch_size do
        local unit = targets[#targets]
        targets[#targets] = nil
        processed = processed + 1
        if is_active_enemy(unit) then
          deal_skill_damage(unit, barrage.damage, '法术')
        end
      end
      if #targets > 0 then
        next_barrages[#next_barrages + 1] = barrage
      end
    end
    STATE.pending_artillery_barrages = next_barrages
  end

  local function schedule_phase_loop(initial_delay, callback)
    y3.ltimer.wait(math.max(0, initial_delay or 0), function()
      if callback then
        callback()
      end
      y3.ltimer.loop(runtime_tick, function()
        if callback then
          callback()
        end
      end)
    end)
  end

  local function start_runtime_loops()
    if loops_started then
      print('[diag.loops] start_runtime_loops skipped duplicate_start')
      return false
    end
    loops_started = true
    STATE.debug_runtime_loops_start_count = (STATE.debug_runtime_loops_start_count or 0) + 1
    print(string.format('[diag.loops] start_runtime_loops count=%s', tostring(STATE.debug_runtime_loops_start_count)))
    local reset_ok = reset_slow_update_log()
    print(string.format('[diag.loops] slow_update_log path=%s reset_ok=%s', tostring(slow_update_log_path), tostring(reset_ok)))

    y3.ltimer.loop(runtime_tick, function()
      log_frame_gap('runtime_tick', 'debug_last_runtime_tick_wall_ms', runtime_tick * 1000 + frame_gap_threshold_ms)
      if is_battle_active() then
        if STATE.runtime_battle_ui_visible ~= true then
          set_battle_hud_visible(true)
          STATE.runtime_battle_ui_visible = true
        end
        STATE.runtime_elapsed = (STATE.runtime_elapsed or 0) + runtime_tick
        profile_if_slow('update_passive_resources', function()
          update_passive_resources(runtime_tick)
        end)
        profile_if_slow('battlefield.update_wave', function()
          battlefield_system.update_wave(runtime_tick)
        end)
        profile_if_slow('battlefield.update_challenges', function()
          battlefield_system.update_challenges(runtime_tick)
        end)
        profile_if_slow('battlefield.update_challenge_charges', function()
          battlefield_system.update_challenge_charges(runtime_tick)
        end)
        if update_mainline_task then
          profile_if_slow('update_mainline_task', function()
            update_mainline_task(runtime_tick)
          end)
        end
        profile_if_slow('update_temporary_treasures', function()
          update_temporary_treasures(runtime_tick)
        end)
        profile_if_slow('process_pending_artillery_barrages', function()
          process_pending_artillery_barrages()
        end)
        return
      end

      refresh_non_battle_ui()
    end)

    schedule_phase_loop(runtime_tick * 0.33, function()
      log_frame_gap('phase_effects', 'debug_last_phase_effects_wall_ms', runtime_tick * 1000 + frame_gap_threshold_ms)
      if not is_battle_active() then
        return
      end

      profile_if_slow('update_bond_effects', function()
        update_bond_effects(runtime_tick)
      end)
      profile_if_slow('update_auto_active_effects', function()
        update_auto_active_effects(runtime_tick)
      end)
      if update_effect_debug and CONFIG.effect_debug_auto_update_enabled == true then
        profile_if_slow('update_effect_debug', function()
          update_effect_debug(runtime_tick)
        end)
      end
    end)

    schedule_phase_loop(runtime_tick * 0.66, function()
      log_frame_gap('phase_status_attack', 'debug_last_phase_status_attack_wall_ms', runtime_tick * 1000 + frame_gap_threshold_ms)
      if not is_battle_active() then
        return
      end

      profile_if_slow('update_enemy_statuses', function()
        update_enemy_statuses(runtime_tick)
      end)
      profile_if_slow('update_attack_skills', function()
        update_attack_skills(runtime_tick)
      end)
    end)

    schedule_phase_loop(runtime_tick * 0.16, function()
      log_frame_gap('phase_ui_slice', 'debug_last_phase_ui_slice_wall_ms', runtime_tick * 1000 + frame_gap_threshold_ms)
      if not is_battle_active() then
        return
      end

      STATE.runtime_ui_refresh_elapsed = (STATE.runtime_ui_refresh_elapsed or 0) + runtime_tick
      if STATE.runtime_ui_refresh_elapsed >= battle_ui_refresh_slice_interval then
        STATE.runtime_ui_refresh_elapsed = 0
        STATE.runtime_ui_refresh_slice = ((STATE.runtime_ui_refresh_slice or 0) % 4) + 1
        profile_if_slow(
          'battle_ui_slice_' .. tostring(STATE.runtime_ui_refresh_slice),
          function()
            try_refresh_battle_ui_slice(STATE.runtime_ui_refresh_slice)
          end
        )
      end
    end)

    y3.ltimer.loop(1, function()
      log_frame_gap('artillery_tick', 'debug_last_artillery_tick_wall_ms', 1000 + frame_gap_threshold_ms)
      if not is_battle_active() then
        return
      end

      local skill = STATE.skill_runtime
      if skill.artillery_interval <= 0 or skill.artillery_radius <= 0 or skill.artillery_ratio <= 0 then
        return
      end

      skill.artillery_cd = skill.artillery_cd + 1
      if skill.artillery_cd < skill.artillery_interval then
        return
      end
      skill.artillery_cd = 0

      local anchor = STATE.all_enemies:get_random()
      if not is_active_enemy(anchor) then
        return
      end

      local attack_value = get_hero_attack_value()
      local damage = skill.artillery_base + attack_value * skill.artillery_ratio
      profile_if_slow('queue_artillery_barrage.targets', function()
        queue_artillery_barrage(damage, get_enemies_in_range(anchor, skill.artillery_radius))
      end)
    end)

    if y3.game.is_debug_mode() and CONFIG.gm_panel_auto_refresh_enabled == true then
      y3.ltimer.loop(runtime_tick, function()
        debug_tools_system.ensure_gm_panel()
        debug_tools_system.refresh_gm_panel()
      end)
    end
  end

  return {
    start_runtime_loops = start_runtime_loops,
  }
end

return M

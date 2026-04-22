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
  local refresh_attr_panel = env.refresh_attr_panel
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
  local perf_diag_enabled = CONFIG.runtime_perf_diag_enabled == true
  local perf_diag_log_to_file = perf_diag_enabled and CONFIG.runtime_perf_diag_log_to_file == true
  local perf_diag_cooldown_ms = math.max(500, tonumber(CONFIG.runtime_perf_diag_cooldown_ms) or 2000)
  local runtime_tick_ms = math.floor(runtime_tick * 1000 + 0.5)
  local battle_ui_refresh_slice_interval_ms = math.floor(battle_ui_refresh_slice_interval * 1000 + 0.5)
  local artillery_interval_ms = 1000
  local dropped_backlog_threshold_ms = runtime_tick_ms * 2
  local frame_delta_cap_ms = 250
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
    if not perf_diag_log_to_file then
      return false
    end
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
    if not perf_diag_log_to_file then
      return false
    end
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

  local function emit_perf_diag(line, scope_key, now_ms)
    if not perf_diag_enabled then
      return false
    end

    if scope_key then
      local current_ms = now_ms or get_clock_ms() or 0
      local last_key = '__perf_diag_last_' .. tostring(scope_key)
      local last_ms = STATE[last_key]
      if last_ms and (current_ms - last_ms) < perf_diag_cooldown_ms then
        return false
      end
      STATE[last_key] = current_ms
    end

    print(line)
    append_slow_update_log(line)
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
    emit_perf_diag(line, 'frame_gap:' .. tostring(scope), now_ms)
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
        emit_perf_diag(line, 'slow_update:' .. tostring(scope), ended_at)
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
    if perf_diag_enabled and (STATE.debug_battle_ui_refresh_count % 20) == 1 then
      emit_perf_diag(string.format(
        '[diag.loops] battle_ui_refresh count=%s slice=%s phase=%s visible=%s',
        tostring(STATE.debug_battle_ui_refresh_count),
        tostring(slice_index),
        tostring(STATE.session_phase),
        tostring(STATE.runtime_battle_ui_visible)
      ), 'battle_ui_refresh', nil)
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
        if refresh_attr_panel then
          refresh_attr_panel()
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

  local function log_dropped_backlog(scope, backlog_ms, applied_ms)
    local line = string.format(
      '[diag.backlog_drop] scope=%s backlog_ms=%s applied_ms=%s phase=%s elapsed=%s',
      tostring(scope),
      tostring(backlog_ms),
      tostring(applied_ms),
      tostring(STATE.session_phase),
      tostring(STATE.runtime_elapsed or 0)
    )
    emit_perf_diag(line, 'backlog_drop:' .. tostring(scope), nil)
  end

  local function consume_phase_delta(accumulator_key, interval_ms, max_apply_ms)
    local elapsed_ms = STATE[accumulator_key] or 0
    if elapsed_ms < interval_ms then
      return nil
    end
    local apply_ms = math.min(elapsed_ms, max_apply_ms or interval_ms)
    STATE[accumulator_key] = 0
    if elapsed_ms > (dropped_backlog_threshold_ms + 1) and apply_ms < elapsed_ms then
      log_dropped_backlog(accumulator_key, elapsed_ms, apply_ms)
    end
    return apply_ms / 1000
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

  local function run_core_battle_phase(dt)
    STATE.runtime_elapsed = (STATE.runtime_elapsed or 0) + dt
    profile_if_slow('update_passive_resources', function()
      update_passive_resources(dt)
    end)
    profile_if_slow('battlefield.update_wave', function()
      battlefield_system.update_wave(dt)
    end)
    profile_if_slow('battlefield.update_challenges', function()
      battlefield_system.update_challenges(dt)
    end)
    profile_if_slow('battlefield.update_challenge_charges', function()
      battlefield_system.update_challenge_charges(dt)
    end)
    if update_mainline_task then
      profile_if_slow('update_mainline_task', function()
        update_mainline_task(dt)
      end)
    end
    profile_if_slow('update_temporary_treasures', function()
      update_temporary_treasures(dt)
    end)
    profile_if_slow('process_pending_artillery_barrages', function()
      process_pending_artillery_barrages()
    end)
  end

  local function run_effects_phase(dt)
    log_frame_gap('phase_effects', 'debug_last_phase_effects_wall_ms', runtime_tick_ms + frame_gap_threshold_ms)
    profile_if_slow('update_bond_effects', function()
      update_bond_effects(dt)
    end)
    profile_if_slow('update_auto_active_effects', function()
      update_auto_active_effects(dt)
    end)
    if update_effect_debug and CONFIG.effect_debug_auto_update_enabled == true then
      profile_if_slow('update_effect_debug', function()
        update_effect_debug(dt)
      end)
    end
  end

  local function run_status_attack_phase(dt)
    log_frame_gap('phase_status_attack', 'debug_last_phase_status_attack_wall_ms', runtime_tick_ms + frame_gap_threshold_ms)
    profile_if_slow('update_enemy_statuses', function()
      update_enemy_statuses(dt)
    end)
    profile_if_slow('update_attack_skills', function()
      update_attack_skills(dt)
    end)
  end

  local function run_ui_slice_phase()
    log_frame_gap('phase_ui_slice', 'debug_last_phase_ui_slice_wall_ms', battle_ui_refresh_slice_interval_ms + frame_gap_threshold_ms)
    STATE.runtime_ui_refresh_slice = ((STATE.runtime_ui_refresh_slice or 0) % 4) + 1
    profile_if_slow(
      'battle_ui_slice_' .. tostring(STATE.runtime_ui_refresh_slice),
      function()
        try_refresh_battle_ui_slice(STATE.runtime_ui_refresh_slice)
      end
    )
  end

  local function run_artillery_phase(dt)
    log_frame_gap('artillery_tick', 'debug_last_artillery_tick_wall_ms', artillery_interval_ms + frame_gap_threshold_ms)

    local skill = STATE.skill_runtime
    if not skill then
      return
    end
    if skill.artillery_interval > 0 and skill.artillery_radius > 0 and skill.artillery_ratio > 0 then
      skill.artillery_cd = skill.artillery_cd + dt
      if skill.artillery_cd >= skill.artillery_interval then
        skill.artillery_cd = skill.artillery_cd - skill.artillery_interval

        local anchor = STATE.all_enemies:get_random()
        if is_active_enemy(anchor) then
          local attack_value = get_hero_attack_value()
          local damage = skill.artillery_base + attack_value * skill.artillery_ratio
          profile_if_slow('queue_artillery_barrage.targets', function()
            queue_artillery_barrage(damage, get_enemies_in_range(anchor, skill.artillery_radius))
          end)
        end
      end
    end
  end

  local function initialize_runtime_phase_state(now_ms)
    STATE.runtime_frame_last_clock_ms = now_ms
    STATE.runtime_core_accum_ms = 0
    STATE.runtime_effects_accum_ms = math.floor(runtime_tick_ms * 0.34)
    STATE.runtime_status_accum_ms = math.floor(runtime_tick_ms * 0.67)
    STATE.runtime_ui_accum_ms = math.floor(battle_ui_refresh_slice_interval_ms * 0.5)
    STATE.runtime_artillery_accum_ms = 0
    STATE.runtime_non_battle_accum_ms = 0
  end

  local function step_runtime_frame()
    local now_ms = get_clock_ms()
    if not now_ms then
      return
    end

    if not STATE.runtime_frame_last_clock_ms then
      initialize_runtime_phase_state(now_ms)
      return
    end

    local delta_ms = now_ms - STATE.runtime_frame_last_clock_ms
    STATE.runtime_frame_last_clock_ms = now_ms
    if delta_ms <= 0 then
      return
    end

    if delta_ms > frame_delta_cap_ms then
      log_dropped_backlog('runtime_frame_delta', delta_ms, frame_delta_cap_ms)
      delta_ms = frame_delta_cap_ms
    end

    log_frame_gap('runtime_frame', 'debug_last_runtime_frame_wall_ms', math.floor(1000 / math.max(1, y3.config.logic_frame or 30)) + frame_gap_threshold_ms)

    if not is_battle_active() then
      STATE.runtime_non_battle_accum_ms = (STATE.runtime_non_battle_accum_ms or 0) + delta_ms
      if STATE.runtime_non_battle_accum_ms >= runtime_tick_ms then
        STATE.runtime_non_battle_accum_ms = 0
        refresh_non_battle_ui()
      end
      return
    end

    if STATE.runtime_battle_ui_visible ~= true then
      set_battle_hud_visible(true)
      STATE.runtime_battle_ui_visible = true
    end

    STATE.runtime_core_accum_ms = (STATE.runtime_core_accum_ms or 0) + delta_ms
    STATE.runtime_effects_accum_ms = (STATE.runtime_effects_accum_ms or 0) + delta_ms
    STATE.runtime_status_accum_ms = (STATE.runtime_status_accum_ms or 0) + delta_ms
    STATE.runtime_ui_accum_ms = (STATE.runtime_ui_accum_ms or 0) + delta_ms
    STATE.runtime_artillery_accum_ms = (STATE.runtime_artillery_accum_ms or 0) + delta_ms

    log_frame_gap('runtime_tick', 'debug_last_runtime_tick_wall_ms', runtime_tick_ms + frame_gap_threshold_ms)

    local core_dt = consume_phase_delta('runtime_core_accum_ms', runtime_tick_ms, runtime_tick_ms * 2)
    if core_dt then
      profile_if_slow('runtime_phase_core', function()
        run_core_battle_phase(core_dt)
      end)
    end

    local status_dt = consume_phase_delta('runtime_status_accum_ms', runtime_tick_ms, runtime_tick_ms * 2)
    if status_dt then
      profile_if_slow('runtime_phase_status_attack', function()
        run_status_attack_phase(status_dt)
      end)
    end

    local effects_dt = consume_phase_delta('runtime_effects_accum_ms', runtime_tick_ms, runtime_tick_ms * 2)
    if effects_dt then
      profile_if_slow('runtime_phase_effects', function()
        run_effects_phase(effects_dt)
      end)
    end

    local ui_due = consume_phase_delta('runtime_ui_accum_ms', battle_ui_refresh_slice_interval_ms, battle_ui_refresh_slice_interval_ms * 2)
    if ui_due then
      profile_if_slow('runtime_phase_ui', function()
        run_ui_slice_phase()
      end)
    end

    local artillery_dt = consume_phase_delta('runtime_artillery_accum_ms', artillery_interval_ms, artillery_interval_ms * 2)
    if artillery_dt then
      profile_if_slow('runtime_phase_artillery', function()
        run_artillery_phase(artillery_dt)
      end)
    end
  end

  local function start_runtime_loops()
    if loops_started then
      emit_perf_diag('[diag.loops] start_runtime_loops skipped duplicate_start', 'loops_duplicate_start', nil)
      return false
    end
    loops_started = true
    STATE.debug_runtime_loops_start_count = (STATE.debug_runtime_loops_start_count or 0) + 1
    emit_perf_diag(
      string.format('[diag.loops] start_runtime_loops count=%s', tostring(STATE.debug_runtime_loops_start_count)),
      'loops_start',
      nil
    )
    local reset_ok = reset_slow_update_log()
    emit_perf_diag(
      string.format('[diag.loops] slow_update_log path=%s reset_ok=%s', tostring(slow_update_log_path), tostring(reset_ok)),
      'loops_log_reset',
      nil
    )

    local initial_clock_ms = get_clock_ms()
    if initial_clock_ms then
      initialize_runtime_phase_state(initial_clock_ms)
    end

    y3.ltimer.loop_frame(1, function()
      step_runtime_frame()
    end)

    if y3.game.is_debug_mode() and CONFIG.gm_panel_auto_refresh_enabled == true then
      STATE.runtime_gm_panel_accum_ms = 0
      y3.ltimer.loop_frame(1, function()
        local now_ms = get_clock_ms()
        local last_ms = STATE.runtime_gm_panel_last_clock_ms
        STATE.runtime_gm_panel_last_clock_ms = now_ms
        if not now_ms or not last_ms then
          return
        end
        local delta_ms = now_ms - last_ms
        if delta_ms <= 0 then
          return
        end
        STATE.runtime_gm_panel_accum_ms = (STATE.runtime_gm_panel_accum_ms or 0) + delta_ms
        if STATE.runtime_gm_panel_accum_ms < runtime_tick_ms then
          return
        end
        STATE.runtime_gm_panel_accum_ms = 0
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

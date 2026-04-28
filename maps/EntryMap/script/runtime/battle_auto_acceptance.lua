local BondModifierPool = require 'data.object_tables.bond_modifier_pool'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message or print
  local is_battle_active = env.is_battle_active
  local get_enemy_player = env.get_enemy_player
  local has_unit_data = env.has_unit_data
  local activate_modifier_bond_effect = env.activate_modifier_bond_effect
  local set_force_special_effects_100 = env.set_force_special_effects_100
  local run_bond_self_test = env.run_bond_self_test
  local get_game_time = env.get_game_time

  local function ensure_runtime()
    STATE.battle_auto_acceptance = STATE.battle_auto_acceptance or {
      phase_started = false,
      initialized = false,
      spawned = false,
      dummy_unit_id = nil,
      units = {},
      target_hp = 9999999999,
      spawn_count = 10,
      spawn_radius = 520,
      activation_report = nil,
      run_id = 0,
      log_file_path = nil,
      hero_anchor = nil,
      skill_audit = {
        by_source = {},
        last_emit_time = 0,
        evaluated = false,
      },
    }
    return STATE.battle_auto_acceptance
  end

  local function get_log_file_path(runtime)
    local run_id = tonumber(runtime.run_id) or 0
    return string.format('.log/n0_auto_acceptance_%04d.log', run_id)
  end

  local function append_log(runtime, text)
    local path = runtime.log_file_path
    runtime.log_lines = runtime.log_lines or {}
    runtime.log_lines[#runtime.log_lines + 1] = tostring(text or '')
    if not path or path == '' then
      return false
    end
    local ok, err = pcall(function()
      local file = io.open(path, 'a')
      if not file then
        return
      end
      file:write(tostring(text or ''), '\n')
      file:close()
    end)
    if not ok then
      message(string.format('[auto_acceptance][log_fail] %s', tostring(err)))
      return false
    end
    return true
  end

  local function flush_report_to_message(runtime)
    local lines = runtime.log_lines or {}
    if #lines == 0 then
      return
    end
    message('[auto_acceptance][REPORT_BEGIN]')
    for _, line in ipairs(lines) do
      message('[auto_acceptance] ' .. tostring(line))
    end
    message('[auto_acceptance][REPORT_END]')
  end

  local function to_metric_key(scope, key)
    return string.format('%s|%s', tostring(scope or 'unknown'), tostring(key or 'unknown'))
  end

  local function ensure_audit_bucket(runtime, scope, key)
    runtime.skill_audit = runtime.skill_audit or {
      by_source = {},
      last_emit_time = 0,
      evaluated = false,
    }
    runtime.skill_audit.by_source = runtime.skill_audit.by_source or {}
    local bucket_key = to_metric_key(scope, key)
    local bucket = runtime.skill_audit.by_source[bucket_key]
    if not bucket then
      bucket = {
        scope = tostring(scope or 'unknown'),
        key = tostring(key or 'unknown'),
        casts = 0,
        hits = 0,
        total_damage = 0,
      }
      runtime.skill_audit.by_source[bucket_key] = bucket
    end
    return bucket
  end

  local function record_metric(runtime, scope, key, field, value)
    local bucket = ensure_audit_bucket(runtime, scope, key)
    value = tonumber(value) or 0
    if field == 'cast' then
      bucket.casts = (bucket.casts or 0) + math.max(0, value)
    elseif field == 'hit' then
      bucket.hits = (bucket.hits or 0) + math.max(0, value)
    elseif field == 'damage' then
      bucket.total_damage = (bucket.total_damage or 0) + math.max(0, value)
    end
  end

  local function gather_audit_buckets(runtime)
    local rows = {}
    local by_source = runtime and runtime.skill_audit and runtime.skill_audit.by_source or {}
    for _, bucket in pairs(by_source or {}) do
      rows[#rows + 1] = bucket
    end
    table.sort(rows, function(a, b)
      local da = tonumber(a and a.total_damage) or 0
      local db = tonumber(b and b.total_damage) or 0
      if da == db then
        return tostring(a and a.key or '') < tostring(b and b.key or '')
      end
      return da > db
    end)
    return rows
  end

  local function find_bucket(runtime, scope, key)
    local by_source = runtime and runtime.skill_audit and runtime.skill_audit.by_source or nil
    if not by_source then
      return nil
    end
    return by_source[to_metric_key(scope, key)]
  end

  local function emit_skill_audit(runtime, force)
    if not runtime or not runtime.phase_started then
      return
    end
    local now = tonumber(get_game_time and get_game_time() or 0) or 0
    local phase_start_time = tonumber(runtime.phase_start_time) or now
    local elapsed = math.max(0.1, now - phase_start_time)
    local last_emit = tonumber(runtime.skill_audit and runtime.skill_audit.last_emit_time) or 0
    if not force and (now - last_emit) < 5 then
      return
    end
    runtime.skill_audit.last_emit_time = now

    local rows = gather_audit_buckets(runtime)
    local limit = math.min(12, #rows)
    message(string.format('[auto_acceptance][SKILL_AUDIT_BEGIN] entries=%d time=%.2f', #rows, now))
    for i = 1, limit do
      local row = rows[i]
      local dps = 0
      if elapsed > 0 then
        dps = (tonumber(row.total_damage) or 0) / elapsed
      end
      message(string.format(
        '[auto_acceptance][SKILL_AUDIT] scope=%s key=%s cast=%d hit=%d dmg=%.0f dps=%.1f',
        tostring(row.scope),
        tostring(row.key),
        math.floor(tonumber(row.casts) or 0),
        math.floor(tonumber(row.hits) or 0),
        tonumber(row.total_damage) or 0,
        dps
      ))
    end
    message('[auto_acceptance][SKILL_AUDIT_END]')

    if runtime.skill_audit and runtime.skill_audit.evaluated ~= true and elapsed >= 8 and #rows > 0 then
      local required_bonds = { '龙骑士', '枪炮师', '冰霜法师', '雷电法王' }
      local fail_count = 0
      local pass_count = 0
      for _, bond_name in ipairs(required_bonds) do
        local row = find_bucket(runtime, 'bond', bond_name)
        local hits = tonumber(row and row.hits) or 0
        local damage = tonumber(row and row.total_damage) or 0
        if hits <= 0 or damage <= 0 then
          fail_count = fail_count + 1
          message(string.format('[auto_acceptance][FAIL][SKILL] %s 命中或伤害为0 hit=%d dmg=%.0f', bond_name, hits, damage))
        else
          pass_count = pass_count + 1
          message(string.format('[auto_acceptance][PASS][SKILL] %s hit=%d dmg=%.0f', bond_name, hits, damage))
        end
      end
      message(string.format('[auto_acceptance][SKILL_AUDIT_SUMMARY] pass=%d fail=%d', pass_count, fail_count))
      runtime.skill_audit.evaluated = true
    end
  end

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

  local function clear_runtime_units(runtime)
    for _, unit in ipairs(runtime.units or {}) do
      if STATE.all_enemies and STATE.all_enemies.remove_unit then
        pcall(function()
          STATE.all_enemies:remove_unit(unit)
        end)
      end
      if unit and unit.is_exist and unit:is_exist() then
        pcall(function()
          unit:remove()
        end)
      end
    end
    runtime.units = {}
    runtime.spawned = false
  end

  local function pick_dummy_unit_id()
    local candidates = {}
    if CONFIG and CONFIG.unit_ids and CONFIG.unit_ids.main_monsters then
      for _, unit_id in pairs(CONFIG.unit_ids.main_monsters) do
        candidates[#candidates + 1] = unit_id
      end
    end
    if CONFIG and CONFIG.unit_ids and CONFIG.unit_ids.bosses then
      for _, unit_id in pairs(CONFIG.unit_ids.bosses) do
        candidates[#candidates + 1] = unit_id
      end
    end
    for _, unit_id in ipairs(candidates) do
      local id = tonumber(unit_id)
      if id and id > 0 and (not has_unit_data or has_unit_data(id)) then
        return id
      end
    end
    return nil
  end

  local function activate_all_bond_effects()
    local ok_count = 0
    local fail_count = 0
    for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
      local bond_name = tostring(effect and effect.bond_name or '')
      if bond_name ~= '' then
        local ok = activate_modifier_bond_effect and activate_modifier_bond_effect(bond_name, true) or false
        if ok == true then
          ok_count = ok_count + 1
        else
          fail_count = fail_count + 1
          message(string.format('[auto_acceptance][FAIL] 羁绊激活失败：%s', bond_name))
        end
      end
    end
    return {
      ok = ok_count,
      fail = fail_count,
    }
  end

  local function spawn_dummy_targets(runtime)
    local enemy_player = get_enemy_player and get_enemy_player() or nil
    if not enemy_player or not y3 or not y3.unit or not y3.unit.create_unit then
      return false
    end
    local unit_id = runtime.dummy_unit_id or pick_dummy_unit_id()
    if not unit_id then
      message('[auto_acceptance] 未找到可用靶子单位ID，跳过靶子生成。')
      return false
    end
    runtime.dummy_unit_id = unit_id

    local center = nil
    if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and STATE.hero.get_point then
      center = STATE.hero:get_point()
    end
    if not center and STATE.defense_point then
      center = STATE.defense_point
    end
    if not center then
      return false
    end

    clear_runtime_units(runtime)
    local count = math.max(1, tonumber(runtime.spawn_count) or 10)
    local radius = math.max(180, tonumber(runtime.spawn_radius) or 520)
    for i = 1, count do
      local angle = (math.pi * 2) * (i - 1) / count
      local cx = center.get_x and center:get_x() or 0
      local cy = center.get_y and center:get_y() or 0
      local cz = center.get_z and center:get_z() or 0
      local x = cx + math.cos(angle) * radius
      local y = cy + math.sin(angle) * radius
      local point = y3.point.create(x, y, cz)
      local ok, unit = pcall(y3.unit.create_unit, enemy_player, unit_id, point, 180)
      if ok and unit and unit.is_exist and unit:is_exist() then
        pcall(function()
          unit:set_name('验收靶子')
          unit:set_attr('生命', runtime.target_hp)
          unit:set_attr('最大生命', runtime.target_hp)
          unit:set_hp(runtime.target_hp)
        end)
        if STATE.all_enemies and STATE.all_enemies.add_unit then
          pcall(function()
            STATE.all_enemies:add_unit(unit)
          end)
        end
        runtime.units[#runtime.units + 1] = unit
      end
    end
    runtime.spawned = #runtime.units > 0
    if runtime.spawned then
      message(string.format('[auto_acceptance] 靶子已生成：count=%d unit_id=%s hp=%d', #runtime.units, tostring(unit_id), runtime.target_hp))
    end
    return runtime.spawned
  end

  local function sustain_dummy_targets(runtime)
    for index = #runtime.units, 1, -1 do
      local unit = runtime.units[index]
      if not unit or not unit.is_exist or not unit:is_exist() then
        table.remove(runtime.units, index)
      else
        pcall(function()
          unit:set_attr('生命', runtime.target_hp)
          unit:set_attr('最大生命', runtime.target_hp)
          unit:set_hp(runtime.target_hp)
        end)
      end
    end
  end

  local function init_battle_once(runtime)
    if runtime.initialized then
      return
    end
    runtime.initialized = true
    runtime.phase_started = true
    runtime.phase_start_time = tonumber(get_game_time and get_game_time() or 0) or 0
    runtime.run_id = (tonumber(runtime.run_id) or 0) + 1
    runtime.target_hp = 9999999999
    runtime.log_file_path = get_log_file_path(runtime)
    runtime.log_lines = {}
    runtime.skill_audit = {
      by_source = {},
      last_emit_time = 0,
      evaluated = false,
    }
    if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and STATE.hero.get_point then
      local point = STATE.hero:get_point()
      if point then
        runtime.hero_anchor = {
          x = point.get_x and point:get_x() or 0,
          y = point.get_y and point:get_y() or 0,
          z = point.get_z and point:get_z() or 0,
        }
      end
    end

    if set_force_special_effects_100 then
      set_force_special_effects_100(true)
    end
    local self_test = run_bond_self_test and run_bond_self_test() or { total = 0, passed = 0, failed = 0 }
    local activation = activate_all_bond_effects()
    runtime.activation_report = {
      self_test = self_test,
      activation = activation,
    }
    append_log(runtime, '=== N0 AUTO ACCEPTANCE START ===')
    append_log(runtime, string.format('run_id=%d game_time=%.2f', runtime.run_id, tonumber(get_game_time and get_game_time() or 0) or 0))
    append_log(runtime, string.format(
      'self_test: total=%s pass=%s fail=%s',
      tostring(self_test.total or 0),
      tostring(self_test.passed or 0),
      tostring(self_test.failed or 0)
    ))
    append_log(runtime, string.format(
      'activation: ok=%d fail=%d',
      tonumber(activation.ok) or 0,
      tonumber(activation.fail) or 0
    ))
    message(string.format(
      '[auto_acceptance] 特效自动验收启动：自检 pass=%s/%s fail=%s，羁绊激活 ok=%d fail=%d',
      tostring(self_test.passed or 0),
      tostring(self_test.total or 0),
      tostring(self_test.failed or 0),
      tonumber(activation.ok) or 0,
      tonumber(activation.fail) or 0
    ))
    spawn_dummy_targets(runtime)
    append_log(runtime, string.format(
      'dummy_spawn: success=%s count=%d unit_id=%s hp=%d',
      tostring(runtime.spawned == true),
      #(runtime.units or {}),
      tostring(runtime.dummy_unit_id),
      tonumber(runtime.target_hp) or 0
    ))
    append_log(runtime, string.format('log_path=%s', tostring(runtime.log_file_path)))
  end

  local function update(dt)
    local runtime = ensure_runtime()
    if not is_battle_active or not is_battle_active() then
      if runtime.phase_started then
        emit_skill_audit(runtime, true)
        flush_report_to_message(runtime)
        clear_runtime_units(runtime)
      end
      runtime.phase_started = false
      runtime.initialized = false
      runtime.phase_start_time = nil
      runtime.hero_anchor = nil
      return
    end

    if not is_n0_stage_active() then
      if runtime.phase_started then
        emit_skill_audit(runtime, true)
        flush_report_to_message(runtime)
        clear_runtime_units(runtime)
      end
      runtime.phase_started = false
      runtime.initialized = false
      runtime.phase_start_time = nil
      runtime.hero_anchor = nil
      return
    end

    init_battle_once(runtime)
    if runtime.hero_anchor and STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and y3 and y3.point and y3.point.create then
      pcall(function()
        local anchor = runtime.hero_anchor
        local point = y3.point.create(anchor.x, anchor.y, anchor.z or 0)
        if STATE.hero.set_point then
          STATE.hero:set_point(point)
        end
        if STATE.hero.stop then
          STATE.hero:stop()
        end
      end)
    end
    if not runtime.spawned then
      spawn_dummy_targets(runtime)
    end
    sustain_dummy_targets(runtime)
    emit_skill_audit(runtime, false)
  end

  return {
    update = update,
    spawn_dummy_targets = function()
      local runtime = ensure_runtime()
      runtime.dummy_unit_id = runtime.dummy_unit_id or pick_dummy_unit_id()
      return spawn_dummy_targets(runtime)
    end,
    clear_dummy_targets = function()
      clear_runtime_units(ensure_runtime())
    end,
    record_damage = function(payload)
      local runtime = ensure_runtime()
      if not runtime.phase_started or not is_n0_stage_active() then
        return
      end
      payload = payload or {}
      local scope = tostring(payload.scope or 'unknown')
      local key = tostring(payload.key or 'unknown')
      local damage = tonumber(payload.damage) or 0
      local hit = tonumber(payload.hit) or 0
      if hit <= 0 and damage > 0 then
        hit = 1
      end
      if hit > 0 then
        record_metric(runtime, scope, key, 'hit', hit)
      end
      if damage > 0 then
        record_metric(runtime, scope, key, 'damage', damage)
      end
    end,
    record_event = function(payload)
      local runtime = ensure_runtime()
      if not runtime.phase_started or not is_n0_stage_active() then
        return
      end
      payload = payload or {}
      local scope = tostring(payload.scope or 'unknown')
      local key = tostring(payload.key or 'unknown')
      local cast = tonumber(payload.cast) or 0
      if cast > 0 then
        record_metric(runtime, scope, key, 'cast', cast)
      end
    end,
  }
end

return M

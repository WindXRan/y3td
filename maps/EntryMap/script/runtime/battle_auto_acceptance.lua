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
  local activate_single_modifier_bond_effect = env.activate_single_modifier_bond_effect
  local clear_active_modifier_bond_effects = env.clear_active_modifier_bond_effects
  local set_force_special_effects_100 = env.set_force_special_effects_100
  local run_bond_self_test = env.run_bond_self_test
  local get_game_time = env.get_game_time
  -- N0 默认按真实触发率运行；如需强制 100% 触发，仅在构造时显式传入 true。
  local force_special_effects_100_in_n0 = env.force_special_effects_100_in_n0 == true
  -- 默认关闭 N0 自动验收，避免开局自动生成验收靶子/锚定主角影响实机。
  local auto_start_in_n0 = env.auto_start_in_n0 == true
  local DEFAULT_N0_ACTIVATION_MODE = 'all'

  local function parse_bool(value, default_value)
    if value == nil then
      return default_value == true
    end
    if type(value) == 'boolean' then
      return value
    end
    local raw = string.lower(tostring(value))
    if raw == '1' or raw == 'true' or raw == 'yes' or raw == 'on' then
      return true
    end
    if raw == '0' or raw == 'false' or raw == 'no' or raw == 'off' then
      return false
    end
    return default_value == true
  end

  local function trim_text(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
  end

  local function normalize_activation_mode(raw)
    local mode = string.lower(trim_text(raw))
    if mode == 'single' or mode == 'one' then
      return 'single'
    end
    if mode == 'none' or mode == 'off' then
      return 'none'
    end
    return 'all'
  end

  local function ensure_runtime()
    STATE.battle_auto_acceptance = STATE.battle_auto_acceptance or {
      phase_started = false,
      initialized = false,
      spawned = false,
      dummy_unit_id = nil,
      units = {},
      unit_slots = {},
      target_hp = 9999999999,
      spawn_count = 10,
      spawn_radius = 520,
      spawn_front_distance = 760,
      spawn_row_spacing = 170,
      activation_report = nil,
      run_id = 0,
      log_file_path = nil,
      hero_anchor = nil,
      skill_audit = {
        by_source = {},
        last_emit_time = 0,
        evaluated = false,
      },
      force_special_effects_owned = false,
      activation_mode_override = nil,
      single_bond_name_override = nil,
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

  local BOND_DPS_LIMITS = {
    ['刀锋战士'] = { min = 0, max = 900 },
    ['全能骑士'] = { min = 0, max = 900 },
    ['龙骑士'] = { min = 20, max = 1200 },
    ['枪炮师'] = { min = 20, max = 1000 },
    ['冰霜法师'] = { min = 20, max = 1000 },
    ['雷电法王'] = { min = 20, max = 1200 },
    ['火法师'] = { min = 20, max = 900 },
    ['战斗法师'] = { min = 20, max = 1100 },
    ['游侠'] = { min = 20, max = 1000 },
    ['神射手'] = { min = 20, max = 900 },
    ['剑宗'] = { min = 20, max = 1200 },
    ['剑魂'] = { min = 20, max = 900 },
    ['狂战士'] = { min = 20, max = 1100 },
    ['魔剑士'] = { min = 20, max = 1100 },
    ['猎人'] = { min = 0, max = 900 },
    ['骷髅法师'] = { min = 0, max = 900 },
  }
  local PASSIVE_BONDS_ALLOW_ZERO = {
    ['刀锋战士'] = true,
    ['全能骑士'] = true,
  }

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
      local required_bonds = {}
      local activation = runtime.activation_report and runtime.activation_report.activation or nil
      if activation and type(activation.activated_bonds) == 'table' then
        for _, bond_name in ipairs(activation.activated_bonds) do
          bond_name = trim_text(bond_name)
          if bond_name ~= '' then
            required_bonds[#required_bonds + 1] = bond_name
          end
        end
      end
      if #required_bonds <= 0 then
        required_bonds = { '龙骑士', '枪炮师', '冰霜法师', '雷电法王' }
      end
      message(string.format(
        '[auto_acceptance][SKILL_AUDIT_REQUIRED_BONDS] %s',
        table.concat(required_bonds, '|')
      ))
      local fail_count = 0
      local pass_count = 0
      for _, bond_name in ipairs(required_bonds) do
        local row = find_bucket(runtime, 'bond', bond_name)
        local hits = tonumber(row and row.hits) or 0
        local damage = tonumber(row and row.total_damage) or 0
        local dps = elapsed > 0 and (damage / elapsed) or 0
        local limit = BOND_DPS_LIMITS[bond_name]
        local min_dps = limit and tonumber(limit.min) or 0
        local max_dps = limit and tonumber(limit.max) or 999999
        local passive_allow_zero = PASSIVE_BONDS_ALLOW_ZERO[bond_name] == true
        if (hits <= 0 or damage <= 0) and passive_allow_zero then
          pass_count = pass_count + 1
          message(string.format('[auto_acceptance][PASS][SKILL] %s 被动羁绊允许0伤害命中', bond_name))
        elseif hits <= 0 or damage <= 0 then
          fail_count = fail_count + 1
          message(string.format('[auto_acceptance][FAIL][SKILL] %s 命中或伤害为0 hit=%d dmg=%.0f', bond_name, hits, damage))
        elseif dps < min_dps or dps > max_dps then
          fail_count = fail_count + 1
          message(string.format(
            '[auto_acceptance][FAIL][BALANCE] %s dps=%.1f 超出区间[%.1f, %.1f]',
            bond_name,
            dps,
            min_dps,
            max_dps
          ))
        else
          pass_count = pass_count + 1
          message(string.format('[auto_acceptance][PASS][SKILL] %s hit=%d dmg=%.0f dps=%.1f', bond_name, hits, damage, dps))
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
    runtime.unit_slots = {}
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

  local function resolve_n0_activation_plan(runtime)
    local stage_def = STATE and STATE.current_stage_def or nil
    local mode = normalize_activation_mode(
      runtime.activation_mode_override
      or (stage_def and stage_def.n0_activation_mode)
      or DEFAULT_N0_ACTIVATION_MODE
    )
    local target_bond_name = trim_text(runtime.single_bond_name_override or (stage_def and stage_def.n0_single_bond))

    local ordered_bonds = {}
    local bond_exists = {}
    for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
      local bond_name = trim_text(effect and effect.bond_name)
      if bond_name ~= '' and not bond_exists[bond_name] then
        bond_exists[bond_name] = true
        ordered_bonds[#ordered_bonds + 1] = bond_name
      end
    end

    if mode == 'none' then
      return mode, {}
    end
    if mode == 'single' then
      if target_bond_name ~= '' and bond_exists[target_bond_name] then
        return mode, { target_bond_name }
      end
      if #ordered_bonds <= 0 then
        return mode, {}
      end
      -- 未指定具体羁绊时按 run_id 轮换单羁绊，便于多局覆盖不同特殊效果。
      local run_id = tonumber(runtime and runtime.run_id) or 1
      local index = ((math.max(1, run_id) - 1) % #ordered_bonds) + 1
      return mode, { ordered_bonds[index] }
    end

    return mode, ordered_bonds
  end

  local function activate_bond_effects_by_plan(runtime)
    local ok_count = 0
    local fail_count = 0
    local activated_bonds = {}
    local mode, bond_names = resolve_n0_activation_plan(runtime)
    if clear_active_modifier_bond_effects then
      local clear_ok = clear_active_modifier_bond_effects()
      if clear_ok ~= true then
        fail_count = fail_count + 1
        message('[auto_acceptance][WARN] 清空已激活羁绊失败，可能存在残留效果。')
      end
    end
    if mode == 'none' then
      ok_count = ok_count + 1
      return {
        ok = ok_count,
        fail = fail_count,
        mode = mode,
        activated_bonds = activated_bonds,
      }
    end
    if mode == 'single' and #bond_names > 0 and activate_single_modifier_bond_effect then
      local bond_name = tostring(bond_names[1] or '')
      if bond_name ~= '' then
        local ok = activate_single_modifier_bond_effect(bond_name, true)
        if ok == true then
          ok_count = 1
          activated_bonds[#activated_bonds + 1] = bond_name
        else
          fail_count = 1
          message(string.format('[auto_acceptance][FAIL] 羁绊单激活失败：%s', bond_name))
        end
      end
      return {
        ok = ok_count,
        fail = fail_count,
        mode = mode,
        activated_bonds = activated_bonds,
      }
    end
    for _, bond_name in ipairs(bond_names or {}) do
      bond_name = tostring(bond_name or '')
      if bond_name ~= '' then
        local ok = activate_modifier_bond_effect and activate_modifier_bond_effect(bond_name, true) or false
        if ok == true then
          ok_count = ok_count + 1
          activated_bonds[#activated_bonds + 1] = bond_name
        else
          fail_count = fail_count + 1
          message(string.format('[auto_acceptance][FAIL] 羁绊激活失败：%s', bond_name))
        end
      end
    end
    return {
      ok = ok_count,
      fail = fail_count,
      mode = mode,
      activated_bonds = activated_bonds,
    }
  end

  local OPENING_ELAPSED_BY_BOND = {
    ['火法师'] = 5,
    ['冰霜法师'] = 5,
    ['寒冰法师'] = 5,
    ['雷电法王'] = 1.2,
    ['猎人'] = 30,
    ['骷髅法师'] = 30,
  }

  local function apply_opening_no_cooldown(runtime)
    local stage_def = STATE and STATE.current_stage_def or nil
    local enabled = parse_bool(stage_def and stage_def.n0_opening_no_cooldown, true)
    if not enabled then
      return
    end

    for _, effect_state in pairs(runtime and runtime.modifier_pool_effect_state or {}) do
      if type(effect_state) == 'table' then
        local bond_name = tostring(effect_state.bond_name or '')
        local elapsed = OPENING_ELAPSED_BY_BOND[bond_name]
        if elapsed and elapsed > 0 then
          effect_state.elapsed = math.max(tonumber(effect_state.elapsed) or 0, elapsed)
        end
        effect_state.cooldown = 0
      end
    end

    local attack_state = STATE and STATE.attack_skill_state
    if attack_state and attack_state.by_id then
      for skill_id, skill in pairs(attack_state.by_id) do
        if skill_id ~= 'basic_attack' and type(skill) == 'table' then
          skill.cooldown_remaining = 0
        end
      end
    end

    if STATE and STATE.auto_active_effects and STATE.auto_active_effects.cooldowns then
      for effect_id in pairs(STATE.auto_active_effects.cooldowns) do
        STATE.auto_active_effects.cooldowns[effect_id] = 0
      end
    end

    if STATE and STATE.hero_form_skill_runtime and STATE.hero_form_skill_runtime.cooldowns then
      for skill_id in pairs(STATE.hero_form_skill_runtime.cooldowns) do
        STATE.hero_form_skill_runtime.cooldowns[skill_id] = 0
      end
    end
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

    -- N0 靶子位置固定：优先防线点，不使用英雄实时位置，避免随技能漂移。
    local center = STATE.defense_point
    if not center and STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and STATE.hero.get_point then
      center = STATE.hero:get_point()
    end
    if not center then
      return false
    end

    clear_runtime_units(runtime)
    local count = math.max(1, tonumber(runtime.spawn_count) or 10)
    local front_distance = math.max(320, tonumber(runtime.spawn_front_distance) or tonumber(runtime.spawn_radius) or 760)
    local row_spacing = math.max(80, tonumber(runtime.spawn_row_spacing) or 170)
    -- 固定朝向：沿 +X 轴前方摆放，确保不同技能不会改变靶子阵列方向。
    local forward = 0
    local side = forward + math.pi * 0.5
    local cx = center.get_x and center:get_x() or 0
    local cy = center.get_y and center:get_y() or 0
    local cz = center.get_z and center:get_z() or 0
    local front_x = cx + math.cos(forward) * front_distance
    local front_y = cy + math.sin(forward) * front_distance
    for i = 1, count do
      local lateral = (i - (count + 1) * 0.5) * row_spacing
      local x = front_x + math.cos(side) * lateral
      local y = front_y + math.sin(side) * lateral
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
        runtime.unit_slots[#runtime.units] = { x = x, y = y, z = cz or 0 }
      end
    end
    runtime.spawned = #runtime.units > 0
    if runtime.spawned then
      message(string.format('[auto_acceptance] 靶子已生成：count=%d unit_id=%s hp=%d', #runtime.units, tostring(unit_id), runtime.target_hp))
    end
    return runtime.spawned
  end

  local function is_dummy_unit(runtime, unit)
    for _, dummy in ipairs(runtime.units or {}) do
      if dummy == unit then
        return true
      end
    end
    return false
  end

  local function purge_non_dummy_enemies(runtime)
    if not STATE or not STATE.all_enemies or not STATE.all_enemies.pick then
      return
    end
    for _, unit in ipairs(STATE.all_enemies:pick() or {}) do
      if unit and unit.is_exist and unit:is_exist() and (not is_dummy_unit(runtime, unit)) then
        pcall(function()
          if unit.set_hp then
            unit:set_hp(0)
          elseif unit.kill then
            unit:kill()
          elseif unit.remove then
            unit:remove()
          end
        end)
      end
    end
  end

  local function sustain_dummy_targets(runtime)
    for index = #runtime.units, 1, -1 do
      local unit = runtime.units[index]
      if not unit or not unit.is_exist or not unit:is_exist() then
        table.remove(runtime.units, index)
        table.remove(runtime.unit_slots, index)
      else
        pcall(function()
          unit:set_attr('生命', runtime.target_hp)
          unit:set_attr('最大生命', runtime.target_hp)
          unit:set_hp(runtime.target_hp)
          -- 强制靶子回到固定槽位，避免受击退/寻路导致漂移。
          local slot = runtime.unit_slots and runtime.unit_slots[index] or nil
          if slot and y3 and y3.point and y3.point.create and unit.set_point then
            unit:set_point(y3.point.create(slot.x, slot.y, slot.z or 0))
          end
          if unit.stop then
            unit:stop()
          end
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
      if force_special_effects_100_in_n0 then
        set_force_special_effects_100(true)
        runtime.force_special_effects_owned = true
      else
        set_force_special_effects_100(false)
        runtime.force_special_effects_owned = false
      end
    end
    local self_test = run_bond_self_test and run_bond_self_test() or { total = 0, passed = 0, failed = 0 }
    local activation = activate_bond_effects_by_plan(runtime)
    apply_opening_no_cooldown(runtime)
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
      'activation: mode=%s ok=%d fail=%d bonds=%s',
      tostring(activation.mode or 'all'),
      tonumber(activation.ok) or 0,
      tonumber(activation.fail) or 0,
      table.concat(activation.activated_bonds or {}, '|')
    ))
    message(string.format(
      '[auto_acceptance] 特效自动验收启动：自检 pass=%s/%s fail=%s，羁绊激活 mode=%s ok=%d fail=%d',
      tostring(self_test.passed or 0),
      tostring(self_test.total or 0),
      tostring(self_test.failed or 0),
      tostring(activation.mode or 'all'),
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
    if auto_start_in_n0 ~= true then
      if runtime.phase_started then
        emit_skill_audit(runtime, true)
        flush_report_to_message(runtime)
        clear_runtime_units(runtime)
      end
      if set_force_special_effects_100 and runtime.force_special_effects_owned then
        set_force_special_effects_100(false)
        runtime.force_special_effects_owned = false
      end
      runtime.phase_started = false
      runtime.initialized = false
      runtime.phase_start_time = nil
      runtime.hero_anchor = nil
      return
    end
    if not is_battle_active or not is_battle_active() then
      if runtime.phase_started then
        emit_skill_audit(runtime, true)
        flush_report_to_message(runtime)
        clear_runtime_units(runtime)
      end
      if set_force_special_effects_100 and runtime.force_special_effects_owned then
        set_force_special_effects_100(false)
        runtime.force_special_effects_owned = false
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
      if set_force_special_effects_100 and runtime.force_special_effects_owned then
        set_force_special_effects_100(false)
        runtime.force_special_effects_owned = false
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
    -- N0 禁止刷怪：除验收靶子外，其它敌人全部清除。
    purge_non_dummy_enemies(runtime)
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
    set_activation_mode = function(mode)
      local runtime = ensure_runtime()
      runtime.activation_mode_override = normalize_activation_mode(mode)
      -- 切换羁绊模式时不重刷靶子，原地重配效果。
      if runtime.phase_started and is_n0_stage_active() then
        local activation = activate_bond_effects_by_plan(runtime)
        apply_opening_no_cooldown(runtime)
        runtime.activation_report = runtime.activation_report or {}
        runtime.activation_report.activation = activation
        append_log(runtime, string.format(
          'activation_switch: mode=%s ok=%d fail=%d bonds=%s',
          tostring(activation.mode or 'all'),
          tonumber(activation.ok) or 0,
          tonumber(activation.fail) or 0,
          table.concat(activation.activated_bonds or {}, '|')
        ))
      end
    end,
    set_single_bond_name = function(bond_name)
      local runtime = ensure_runtime()
      runtime.single_bond_name_override = trim_text(bond_name)
      -- 切换单羁绊目标时不重刷靶子，原地重配效果。
      if runtime.phase_started and is_n0_stage_active() then
        local activation = activate_bond_effects_by_plan(runtime)
        apply_opening_no_cooldown(runtime)
        runtime.activation_report = runtime.activation_report or {}
        runtime.activation_report.activation = activation
        append_log(runtime, string.format(
          'activation_switch_single: bond=%s mode=%s ok=%d fail=%d',
          tostring(runtime.single_bond_name_override or ''),
          tostring(activation.mode or 'single'),
          tonumber(activation.ok) or 0,
          tonumber(activation.fail) or 0
        ))
      end
    end,
    restart_current_run = function()
      local runtime = ensure_runtime()
      clear_runtime_units(runtime)
      if set_force_special_effects_100 and runtime.force_special_effects_owned then
        set_force_special_effects_100(false)
        runtime.force_special_effects_owned = false
      end
      runtime.phase_started = false
      runtime.initialized = false
      runtime.phase_start_time = nil
      runtime.hero_anchor = nil
      runtime.skill_audit = {
        by_source = {},
        last_emit_time = 0,
        evaluated = false,
      }
      runtime.log_lines = {}
      return true
    end,
  }
end

return M

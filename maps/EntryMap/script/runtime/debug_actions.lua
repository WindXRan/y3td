local M = {}
local CONFIG = require 'config.entry_config'

  local STATE = _G.STATE
  local ATTACK_SKILL_DEPRECATED = CONFIG and CONFIG.attack_skill_deprecated == true
  local debug_message = _G.debug_message
  local get_hero_max_level = _G.get_hero_max_level or function() return 1 end
  local sync_hero_progression = _G.sync_hero_progression or function() end
  local ATTACK_SKILL_BLUEPRINTS = _G.ATTACK_SKILL_BLUEPRINTS or { list = {} }
  local unlock_attack_skill = _G.unlock_attack_skill or function() end
  local show_attack_skill_loadout = _G.show_attack_skill_loadout or function() end
  local try_bond_draw = _G.try_bond_draw or function() end
  local force_spawn_boss = _G.force_spawn_boss or function() end
  local execute_enemy = _G.execute_enemy or function() end
  local is_battle_active = _G.is_battle_active or function() return false end
  local grant_bond_card = _G.grant_bond_card or function() end
  local effect_debug_system = _G.effect_debug_system
  local force_trigger_effect = _G.force_trigger_effect or function() end
  local open_effect_debug_panel_ui = _G.open_effect_debug_panel_ui or function() end
  local function get_resource_system()
    return _G.resource_system or require('runtime.resource_system').create()
  end
  local sample_skill_system = _G.sample_skills_system
  local DEFAULT_DEBUG_PROJECTILE_KEY = 134255250

  local api = {}

  local function guard_battle()
    if not is_battle_active or is_battle_active() then
      return true
    end

    debug_message('当前不在战斗中。')
    return false
  end

  function api.debug_add_test_resources()
    if not guard_battle() then
      return
    end
    get_resource_system().add_gold(500)
    get_resource_system().add_wood(300)
    debug_message(string.format(
      'Debug resources added: gold %d, wood %d.',
      get_resource_system().get_gold(),
      get_resource_system().get_wood()
    ))
  end

  function api.debug_grant_levels(level_count)
    if not guard_battle() then
      return
    end
    if not STATE.hero_progress then
      return
    end

    local grant_count = math.max(1, level_count or 1)
    local granted = 0
    while granted < grant_count and STATE.hero_progress.level < get_hero_max_level() do
      STATE.hero_progress.level = STATE.hero_progress.level + 1
      STATE.hero_progress.exp = 0
      sync_hero_progression()
      granted = granted + 1
    end

    debug_message(string.format(
      'Debug levels granted: Lv%d.',
      STATE.hero_progress.level
    ))
  end

  function api.debug_unlock_all_attack_skills()
    if not guard_battle() then
      return
    end
    if ATTACK_SKILL_DEPRECATED then
      debug_message('攻击技能系统已废弃，仅保留普攻。')
      show_attack_skill_loadout()
      return
    end
    local unlocked = 0
    for _, blueprint in ipairs(ATTACK_SKILL_BLUEPRINTS.list or {}) do
      local _, _, is_new = unlock_attack_skill(blueprint.id)
      if is_new then
        unlocked = unlocked + 1
      end
      if unlocked >= 3 then
        break
      end
    end

    debug_message(string.format(
      'Debug attack skills unlocked: new %d.',
      unlocked
    ))
    show_attack_skill_loadout()
  end

  function api.debug_trigger_bond_draw()
    if not guard_battle() then
      return
    end
    if get_resource_system().get_wood() < 100 then
      get_resource_system().set_wood(100)
      debug_message('Wood was below 100; auto-refilled to 100.')
    end
    try_bond_draw()
  end

  function api.debug_refill_challenge_charges()
    if not guard_battle() then
      return
    end
    STATE.challenge_charge_map = STATE.challenge_charge_map or {}
    STATE.challenge_recover_elapsed_map = STATE.challenge_recover_elapsed_map or {}

    local total = 0
    for challenge_id in pairs(CONFIG.challenges or {}) do
      STATE.challenge_charge_map[challenge_id] = CONFIG.challenge_rules.max_charges
      STATE.challenge_recover_elapsed_map[challenge_id] = 0
      total = total + (CONFIG.challenge_rules.max_charges or 0)
    end
    STATE.challenge_charges = total
    STATE.challenge_recover_elapsed = 0
    debug_message('All challenge charges refilled to max.')
  end

  function api.debug_force_spawn_boss()
    if not guard_battle() then
      return
    end
    local ok, err = force_spawn_boss()
    if not ok then
      debug_message(err)
      return
    end
    debug_message('Current wave boss was forced to spawn.')
  end

  function api.debug_execute_enemy(unit)
    if not guard_battle() then
      return false
    end
    return execute_enemy(unit)
  end

  function api.debug_kill_all_active_enemies()
    if not guard_battle() then
      return
    end
    if not STATE.all_enemies then
      return
    end

    local killed = 0
    for _, unit in ipairs(STATE.all_enemies:pick()) do
      if api.debug_execute_enemy(unit) then
        killed = killed + 1
      end
    end

    debug_message(string.format('Enemies eliminated by debug action: %d.', killed))
  end

  function api.debug_grant_bond_card(card_id)
    if not guard_battle() then
      return
    end
    local ok, result = grant_bond_card(card_id)
    debug_message(ok and result or result)
  end

  function api.debug_open_effect_debug_panel()
    if not guard_battle() then
      return
    end
    if open_effect_debug_panel_ui then
      open_effect_debug_panel_ui()
    end
    debug_message('特效调试面板已打开。')
  end

  function api.debug_select_effect(effect_id)
    if not guard_battle() then
      return
    end
    local ok, result = effect_debug_system.select_effect(effect_id)
    debug_message(ok and ('已选中特效：' .. tostring(result)) or tostring(result))
  end

  function api.debug_mount_effect(effect_id)
    if not guard_battle() then
      return
    end
    local ok, result = effect_debug_system.mount_effect(effect_id)
    debug_message(ok and result or result)
  end

  function api.debug_unmount_effect(effect_id)
    if not guard_battle() then
      return
    end
    local ok, result = effect_debug_system.unmount_effect(effect_id)
    debug_message(ok and result or result)
  end

  function api.debug_clear_mounted_effects()
    if not guard_battle() then
      return
    end
    local ok, result = effect_debug_system.clear_mounted_effects()
    debug_message(ok and result or result)
  end

  function api.debug_trigger_effect(effect_id)
    if not guard_battle() then
      return
    end

    local selected_id = effect_id or effect_debug_system.get_selected_effect_id()
    local ok, snapshot_or_err = force_trigger_effect(selected_id)
    local effect_name = selected_id or 'unknown'
    if ok then
      effect_debug_system.push_log(
        'trigger',
        selected_id,
        'success',
        string.format('cd=%.2f', snapshot_or_err.cooldown or 0)
      )
      debug_message(string.format('特效触发成功：%s', effect_name))
      return
    end

    local reason = type(snapshot_or_err) == 'table' and snapshot_or_err.last_reason or tostring(snapshot_or_err)
    effect_debug_system.push_log('trigger', selected_id, 'failed', reason or '')
    debug_message(string.format('特效触发失败：%s (%s)', effect_name, tostring(reason)))
  end

  function api.debug_start_effect_observe(effect_id)
    if not guard_battle() then
      return
    end
    local ok, result = effect_debug_system.start_observe(effect_id, 10)
    debug_message(ok and result or result)
  end

  function api.debug_print_effect_logs()
    if not guard_battle() then
      return
    end
    effect_debug_system.print_logs(8)
  end

  function api.debug_list_sample_skills()
    if not guard_battle() then
      return
    end
    debug_message('当前已装配技能（含普攻）：')
    if STATE.attack_skill_state and STATE.attack_skill_state.slots then
      local printed = 0
      for slot = 1, 5 do
        local skill = STATE.attack_skill_state.slots[slot]
        if skill then
          printed = printed + 1
          debug_message(string.format(
            '  [%d] %s (%s)',
            slot,
            tostring(skill.name or skill.id or '未知技能'),
            tostring(skill.id or 'unknown')
          ))
        end
      end
      if printed == 0 then
        debug_message('  （暂无已装配技能）')
      end
    else
      debug_message('  （技能状态未初始化）')
    end

    if not sample_skill_system or not sample_skill_system.list_samples then
      debug_message('Sample 技能系统未初始化。')
      return
    end
    debug_message('Sample 技能列表（不含普攻，仅测试样例）：')
    for _, line in ipairs(sample_skill_system.list_samples()) do
      debug_message(line)
    end
  end

  function api.debug_cast_sample_skill(sample_id)
    if not guard_battle() then
      return
    end
    if not sample_skill_system or not sample_skill_system.cast_sample then
      debug_message('Sample 技能系统未初始化。')
      return
    end
    if not sample_id or sample_id == '' then
      debug_message('用法：.esample <sample_id> 或 .esample list')
      return
    end
    local ok, result = sample_skill_system.cast_sample(sample_id)
    debug_message(ok and result or result)
  end

  function api.debug_cast_next_sample_skill()
    if not guard_battle() then
      return
    end
    if not sample_skill_system or not sample_skill_system.cast_next_sample then
      debug_message('Sample 技能系统未初始化。')
      return
    end
    local ok, result = sample_skill_system.cast_next_sample()
    debug_message(ok and result or result)
  end

  function api.debug_print_sample_framework_telemetry(sample_id)
    if not guard_battle() then
      return
    end
    if not sample_skill_system or not sample_skill_system.get_framework_telemetry then
      debug_message('技能框架 telemetry 未初始化。')
      return
    end
    local id = tostring(sample_id or '')
    if id == '' then
      debug_message('用法：.eframe <sample_id>，例如 .eframe ice_lance')
      return
    end
    local t = sample_skill_system.get_framework_telemetry(id)
    if not t then
      debug_message(string.format('未找到 telemetry：%s', id))
      return
    end
    debug_message(string.format(
      '[FRAME] %s cast=%d succ=%d fail=%d hits=%d avg_hits=%.2f empty=%d empty_rate=%.2f%% dmg=%.0f last=%s',
      id,
      tonumber(t.cast_count) or 0,
      tonumber(t.success_count) or 0,
      tonumber(t.fail_count) or 0,
      tonumber(t.total_hits) or 0,
      tonumber(t.avg_hits_per_cast) or 0,
      tonumber(t.empty_cast_count) or 0,
      (tonumber(t.empty_cast_rate) or 0) * 100,
      tonumber(t.total_damage) or 0,
      tostring(t.last_reason or '')
    ))
  end

  function api.debug_print_sample_framework_report()
    if not guard_battle() then
      return
    end
    if not sample_skill_system or not sample_skill_system.print_framework_telemetry_report then
      debug_message('技能框架 telemetry 汇总接口未初始化。')
      return
    end
    local ok, result = sample_skill_system.print_framework_telemetry_report()
    if ok then
      debug_message('已打印 telemetry 验收快照。')
      return
    end
    debug_message(tostring(result or 'telemetry report 打印失败。'))
  end

  function api.debug_run_framework_tier_suite()
    if not guard_battle() then
      return
    end
    if not sample_skill_system or not sample_skill_system.run_framework_tier_suite then
      debug_message('分档连测接口未初始化。')
      return
    end
    local ok, result = sample_skill_system.run_framework_tier_suite()
    debug_message(ok and result or result)
  end

  function api.debug_print_framework_tier_report()
    if not guard_battle() then
      return
    end
    if not sample_skill_system or not sample_skill_system.build_framework_tier_report then
      debug_message('分档报告接口未初始化。')
      return
    end
    debug_message('框架分档报告：')
    for _, line in ipairs(sample_skill_system.build_framework_tier_report() or {}) do
      debug_message(line)
    end
  end

  function api.debug_set_global_projectile_override(projectile_key)
    if not guard_battle() then
      return
    end
    local key = tonumber(projectile_key) or 0
    key = math.floor(key)
    if key <= 0 then
      debug_message('用法：设置全局投射物时，ID 必须为正整数。')
      return
    end
    STATE.debug_force_projectile_key = key
    debug_message(string.format('全局投射物覆盖已开启：%d', key))
  end

  function api.debug_clear_global_projectile_override()
    if not guard_battle() then
      return
    end
    STATE.debug_force_projectile_key = nil
    debug_message('全局投射物覆盖已关闭。')
  end

  function api.debug_toggle_global_projectile_override(projectile_key)
    if not guard_battle() then
      return
    end
    if tonumber(STATE.debug_force_projectile_key) and tonumber(STATE.debug_force_projectile_key) > 0 then
      api.debug_clear_global_projectile_override()
      return
    end
    local key = tonumber(projectile_key) or DEFAULT_DEBUG_PROJECTILE_KEY
    api.debug_set_global_projectile_override(key)
  end

  function api.debug_get_global_projectile_override()
    local key = tonumber(STATE.debug_force_projectile_key) or 0
    if key <= 0 then
      return nil
    end
    return key
  end

  _G.debug_actions_system = api
  _G.SYSTEM = _G.SYSTEM or {}
  _G.SYSTEM.debug_actions = api
  M = api

return M

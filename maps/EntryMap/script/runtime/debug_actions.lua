local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local ATTACK_SKILL_DEPRECATED = CONFIG and CONFIG.attack_skill_deprecated == true
  local debug_message = env.debug_message
  local get_hero_max_level = env.get_hero_max_level
  local sync_hero_progression = env.sync_hero_progression
  local ATTACK_SKILL_BLUEPRINTS = env.ATTACK_SKILL_BLUEPRINTS or { list = {} }
  local unlock_attack_skill = env.unlock_attack_skill
  local show_attack_skill_loadout = env.show_attack_skill_loadout
  local try_bond_draw = env.try_bond_draw
  local force_spawn_boss = env.force_spawn_boss
  local execute_enemy = env.execute_enemy
  local is_battle_active = env.is_battle_active
  local grant_bond_card = env.grant_bond_card
  local grant_treasure = env.grant_treasure
  local dump_temporary_treasures = env.dump_temporary_treasures
  local effect_debug_system = env.effect_debug_system
  local force_trigger_effect = env.force_trigger_effect
  local open_effect_debug_panel_ui = env.open_effect_debug_panel_ui
  local sample_skill_system = env.sample_skill_system
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
    if not STATE.resources then
      return
    end

    STATE.resources.gold = STATE.resources.gold + 500
    STATE.resources.wood = STATE.resources.wood + 300
    debug_message(string.format(
      'Debug resources added: gold %d, wood %d.',
      STATE.resources.gold,
      STATE.resources.wood
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
    if not STATE.resources then
      return
    end
    if STATE.resources.wood < 100 then
      STATE.resources.wood = 100
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

  function api.debug_grant_treasure(treasure_id, replace_slot)
    if not guard_battle() then
      return
    end
    local ok, result = grant_treasure(treasure_id, replace_slot)
    debug_message(ok and result or result)
  end

  function api.debug_print_temporary_treasures()
    if not guard_battle() then
      return
    end
    local lines = dump_temporary_treasures()
    if #lines == 0 then
      debug_message('当前没有临时宝物。')
      return
    end
    for _, line in ipairs(lines) do
      debug_message(line)
    end
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
    if not sample_skill_system or not sample_skill_system.list_samples then
      debug_message('Sample 技能系统未初始化。')
      return
    end
    debug_message('Sample 技能列表：')
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
      debug_message('用法：.eframe <sample_id>，例如 .eframe sf_line_pierce')
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

  return api
end

return M

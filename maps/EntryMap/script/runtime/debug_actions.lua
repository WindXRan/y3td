local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local debug_message = env.debug_message
  local get_hero_max_level = env.get_hero_max_level
  local sync_hero_progression = env.sync_hero_progression
  local unlock_attack_skill = env.unlock_attack_skill
  local show_attack_skill_loadout = env.show_attack_skill_loadout
  local show_upgrade_choices = env.show_upgrade_choices
  local try_bond_draw = env.try_bond_draw
  local force_spawn_boss = env.force_spawn_boss
  local execute_enemy = env.execute_enemy
  local is_battle_active = env.is_battle_active
  local grant_bond_card = env.grant_bond_card
  local grant_treasure = env.grant_treasure
  local dump_temporary_treasures = env.dump_temporary_treasures
  local effect_debug_system = env.effect_debug_system
  local force_trigger_effect = env.force_trigger_effect

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
    STATE.skill_points = STATE.skill_points + 5
    debug_message(string.format(
      'Debug resources added: gold %d, wood %d, skill points %d.',
      STATE.resources.gold,
      STATE.resources.wood,
      STATE.skill_points
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
      STATE.skill_points = STATE.skill_points + 1
      granted = granted + 1
    end

    debug_message(string.format(
      'Debug levels granted: Lv%d, skill points %d.',
      STATE.hero_progress.level,
      STATE.skill_points
    ))
  end

  function api.debug_unlock_all_attack_skills()
    if not guard_battle() then
      return
    end
    local unlocked = 0
    for _, skill_id in ipairs({ 'arcane_arrow', 'flame_arrow', 'frost_arrow', 'thunder' }) do
      local _, _, is_new = unlock_attack_skill(skill_id)
      if is_new then
        unlocked = unlocked + 1
      end
    end

    STATE.skill_points = STATE.skill_points + 3
    debug_message(string.format(
      'Debug attack skills unlocked: new %d, skill points %d.',
      unlocked,
      STATE.skill_points
    ))
    show_attack_skill_loadout()
  end

  function api.debug_open_upgrade_panel()
    if not guard_battle() then
      return
    end
    if STATE.skill_points <= 0 then
      STATE.skill_points = 1
      debug_message('Skill points were empty; auto-added 1 point.')
    end
    show_upgrade_choices()
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
    STATE.challenge_charges = CONFIG.challenge_rules.max_charges
    STATE.challenge_recover_elapsed = 0
    debug_message(string.format(
      'Challenge charges refilled: %d/%d.',
      STATE.challenge_charges,
      CONFIG.challenge_rules.max_charges
    ))
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

  return api
end

return M

--[[
状态显示管理模块
职责：管理游戏运行时状态的显示输出
]]

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local message = env.message
  local progression_system = env.progression_system
  
  local api = {}
  
  -- 获取当前波次信息
  local function get_current_wave()
    local battlefield_system = _G.battlefield_system
    return battlefield_system and battlefield_system.get_current_wave()
  end

  -- 获取Boss名称
  local function get_boss_name(wave)
    local battlefield_system = _G.battlefield_system
    return battlefield_system and battlefield_system.get_boss_name(wave)
  end
  
  -- 显示运行时状态信息
  function api.show_runtime_status()
    -- 非战斗阶段显示选关信息
    if STATE.session.phase ~= 'battle' then
      local stage_name = STATE.session.current_stage_def and
          (STATE.session.current_stage_def.display_label or STATE.session.current_stage_def.display_name) or '未选择'
      local mode_name = STATE.session.current_mode_def and STATE.session.current_mode_def.display_name or '标准模式'
      message(string.format('当前处于局外选关阶段：%s %s。', stage_name, mode_name))
      return
    end

    -- 战斗阶段显示详细状态
    local wave = get_current_wave()
    local wave_text = wave and wave.name or '未开始'
    local boss_text = '无'
    
    -- 处理Boss状态显示
    if STATE.battle.active_wave then
      if STATE.battle.active_wave.boss_spawned then
        boss_text = get_boss_name(STATE.battle.active_wave.wave) .. ' 已登场'
      else
        local remain = math.max(0, STATE.battle.active_wave.wave.boss_spawn_sec - STATE.battle.active_wave.elapsed)
        boss_text = string.format('Boss倒计时 %.1f', remain)
      end
    end

    -- 统计进行中的挑战数量
    local challenge_count = 0
    for _ in pairs(STATE.battle.active_challenges) do
      challenge_count = challenge_count + 1
    end

    -- 构建挑战次数文本
    local challenge_charge_text = ''
    if STATE.challenge_charge_map then
      local parts = {}
      for _, challenge_id in ipairs({ 'gold_trial', 'wood_trial', 'exp_trial' }) do
        local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
        if def then
          parts[#parts + 1] = string.format(
            '%s %d/%d',
            tostring(def.hotkey or challenge_id),
            tonumber(STATE.challenge_charge_map[challenge_id]) or 0,
            CONFIG.challenge_rules.max_charges or 0
          )
        end
      end
      challenge_charge_text = table.concat(parts, ' ')
    else
      challenge_charge_text = string.format('%d/%d', STATE.battle.challenge_charges, CONFIG.challenge_rules.max_charges)
    end

    -- 获取待领奖励数量
    local reward_system = _G.reward_system
    
    -- 输出完整状态信息
    message(string.format(
      '状态：%s，%s，英雄 %s，敌人数 %d，金币 %d，木材 %d，挑战次数 %s，进行中挑战 %d，待领奖励 %d。',
      wave_text,
      boss_text,
      progression_system.get_hero_progress_text(),
      STATE.battle.total_enemy_alive,
      STATE.battle.resources.gold,
      STATE.battle.resources.wood,
      challenge_charge_text,
      challenge_count,
      reward_system and reward_system.get_reward_queue_count() or 0
    ))
  end
  
  -- 设置战斗HUD可见性
  function api.set_battle_hud_visible(visible)
    local hud = _G.hud_system
    if hud and hud.set_battle_hud_visible then
      return hud.set_battle_hud_visible(visible)
    end
    return false
  end
  
  return api
end

return M

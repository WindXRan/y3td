--[[
Round Choice 状态机模块
职责：管理回合选择的互斥状态和各种选择类型的处理
]]

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local BondSystem = env.BondSystem
  local GearUpgrades = env.GearUpgrades
  local AttrChoices = env.AttrChoices
  local message = env.message
  
  local api = {}
  
  local CHOICE_KINDS = {
    BOND = 'bond',
    GEAR = 'gear',
    ATTR = 'attr',
    EVOLUTION = 'evolution',
  }
  
  function api.get_pending_round_choice_label(kind)
    if kind == CHOICE_KINDS.BOND then
      return 'F 战术抽卡'
    end
    if kind == CHOICE_KINDS.GEAR then
      return '成长武器词条'
    end
    if kind == CHOICE_KINDS.ATTR then
      return '属性四选一'
    end
    if kind == CHOICE_KINDS.EVOLUTION then
      return '英雄'
    end
    return '当前选择'
  end
  
  local function get_pending_round_choice_kind()
    -- 检查 Gear 选择
    if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
      return CHOICE_KINDS.GEAR
    end
    
    -- 检查属性选择
    if env.attr_choice_system and env.attr_choice_system.get_pending_choice_kind then
      local attr_kind = env.attr_choice_system.get_pending_choice_kind()
      if attr_kind then
        return attr_kind
      end
    end
    
    -- 检查羁绊选择
    if STATE.subsystems.bond and STATE.subsystems.bond.awaiting_choice and STATE.subsystems.bond.current_choices then
      return CHOICE_KINDS.BOND
    end
    
    -- 检查进化选择（英雄二选一）
    local evolution_runtime = STATE.subsystems.evolution
    if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
      return CHOICE_KINDS.EVOLUTION
    end
    
    return nil
  end
  
  function api.show_pending_round_choice(kind)
    local current_kind = kind or get_pending_round_choice_kind()
    STATE.ui.choice_panel_hidden = false
    
    if current_kind == CHOICE_KINDS.BOND then
      BondSystem.try_draw(env.create_bond_env())
      return
    end
    
    if current_kind == CHOICE_KINDS.GEAR then
      -- Gear choice handled separately
      return
    end
    
    if current_kind == CHOICE_KINDS.ATTR then
      local runtime_hud_system = _G.runtime_hud_system
      return runtime_hud_system and runtime_hud_system.refresh_hud and runtime_hud_system.refresh_hud() or nil
    end
    
    if current_kind == CHOICE_KINDS.EVOLUTION then
      if env.show_evolution_choices then
        env.show_evolution_choices()
      end
      return
    end
  end
  
  function api.ensure_round_choice_available(allowed_kind)
    local kind = get_pending_round_choice_kind()
    if not kind or kind == allowed_kind then
      return true
    end
    message('请先完成当前' .. api.get_pending_round_choice_label(kind) .. '。')
    api.show_pending_round_choice(kind)
    return false
  end
  
  function api.apply_bond_choice(index)
    local result = BondSystem.apply_choice(env.create_bond_env(), index)
    if result == 'replace' then
      STATE.ui.choice_panel_hidden = false
      local hud = _G.hud_system
      if hud and hud.show_bond_replacement_panel then
        hud.show_bond_replacement_panel()
      end
      return
    end
    STATE.ui.choice_panel_hidden = true
  end
  
  function api.apply_round_choice(index)
    local kind = get_pending_round_choice_kind()
    
    if kind == CHOICE_KINDS.GEAR then
      if GearUpgrades.apply_affix_choice({
            STATE = STATE,
            CONFIG = CONFIG,
            audio_system = env.audio_system,
            progression_system = env.progression_system,
            message = message,
          }, index) then
        STATE.ui.choice_panel_hidden = true
        return true
      end
      return false
    end
    
    if kind == CHOICE_KINDS.ATTR then
      local ok = env.attr_choice_system and env.attr_choice_system.apply_choice and env.attr_choice_system.apply_choice(index) or false
      if ok then
        STATE.ui.choice_panel_hidden = true
      end
      return ok
    end
    
    if kind == CHOICE_KINDS.BOND then
      api.apply_bond_choice(index)
      STATE.ui.choice_panel_hidden = true
      return true
    end
    
    if kind == CHOICE_KINDS.EVOLUTION then
      -- 英雄二选一：调用 reward_system 处理
      if env.reward_system then
        env.reward_system.apply_evolution_choice(index)
        STATE.ui.choice_panel_hidden = true
        return true
      end
      return false
    end
    
    return false
  end
  
  return api
end

return M

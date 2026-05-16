--[[
回合管理模块
职责：管理回合流程、回合结束检测、回合选择状态管理
]]

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local message = env.message
  local BootServices = env.BootServices
  local BondSystem = env.BondSystem
  local GearUpgrades = env.GearUpgrades
  local attr_choice_system = env.attr_choice_system
  
  local api = {}
  
  -- 创建 Bond 环境的辅助函数
  local create_bond_env = env.create_bond_env or function()
    return {
      STATE = STATE,
      CONFIG = CONFIG,
      y3 = env.y3,
      message = message,
    }
  end
  
  -- 获取待处理的回合选择类型
  function api.get_pending_round_choice_kind()
    -- 检查 Gear 选择
    if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
      return 'gear'
    end
    
    -- 检查属性选择
    if attr_choice_system and attr_choice_system.get_pending_choice_kind then
      local attr_kind = attr_choice_system.get_pending_choice_kind()
      if attr_kind then
        return attr_kind
      end
    end
    
    -- 检查羁绊选择
    if STATE.subsystems.bond and STATE.subsystems.bond.awaiting_choice and STATE.subsystems.bond.current_choices then
      return 'bond'
    end
    
    -- 检查进化选择
    local evolution_runtime = STATE.subsystems.evolution
    if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
      return 'evolution'
    end
    
    return nil
  end
  
  -- 获取回合选择标签
  function api.get_pending_round_choice_label(kind)
    if kind == 'bond' then return 'F 战术抽卡' end
    if kind == 'gear' then return '成长武器词条' end
    if kind == 'attr' then return '属性四选一' end
    if kind == 'evolution' then return '英雄' end
    return '当前选择'
  end
  
  -- 显示待处理的回合选择
  function api.show_pending_round_choice(kind)
    local current_kind = kind or api.get_pending_round_choice_kind()
    STATE.ui.choice_panel_hidden = false
    
    if current_kind == 'bond' then
      BondSystem.try_draw(create_bond_env())
      return
    end
    
    -- 其他类型的选择由各自的系统处理
  end
  
  -- 确保回合选择可用（检查是否有待处理的选择）
  function api.ensure_round_choice_available(allowed_kind)
    local kind = api.get_pending_round_choice_kind()
    if not kind or kind == allowed_kind then
      return true
    end
    message('请先完成当前' .. api.get_pending_round_choice_label(kind) .. '。')
    api.show_pending_round_choice(kind)
    return false
  end
  
  -- 应用羁绊选择
  function api.apply_bond_choice(index)
    local result = BondSystem.apply_choice(create_bond_env(), index)
    if result == 'replace' then
      STATE.ui.choice_panel_hidden = false
      local runtime_hud_system = BootServices.get_service('runtime_hud_system')
      if runtime_hud_system and runtime_hud_system.show_bond_replacement_panel then
        runtime_hud_system.show_bond_replacement_panel()
      end
      return 'replace'
    end
    STATE.ui.choice_panel_hidden = true
    return true
  end
  
  -- 应用回合选择
  function api.apply_round_choice(index)
    local kind = api.get_pending_round_choice_kind()
    
    if kind == 'gear' then
      if GearUpgrades.apply_affix_choice({
            STATE = STATE,
            CONFIG = CONFIG,
            message = message,
          }, index) then
        -- 同步装备效果
        local hero_attr_system = BootServices.get_service('hero_attr_system')
        if STATE.battle.hero and hero_attr_system then
          GearUpgrades.sync_runtime_bonuses(STATE, STATE.battle.hero, CONFIG.gear_upgrade_config, hero_attr_system)
        end
        STATE.ui.choice_panel_hidden = true
        return true
      end
      return false
    end
    
    if kind == 'attr' then
      if attr_choice_system and attr_choice_system.apply_choice then
        local ok = attr_choice_system.apply_choice(index)
        if ok then
          STATE.ui.choice_panel_hidden = true
        end
        return ok
      end
      return false
    end
    
    if kind == 'bond' then
      return api.apply_bond_choice(index)
    end
    
    if kind == 'evolution' then
      local reward_system = BootServices.get_service('reward_system')
      if reward_system and reward_system.apply_evolution_choice then
        reward_system.apply_evolution_choice(index)
        STATE.ui.choice_panel_hidden = true
        return true
      end
      return false
    end
    
    return false
  end
  
  -- 刷新当前选择状态
  function api.refresh_current_choice()
    STATE.ui.choice_panel_hidden = false
  end
  
  return api
end

return M

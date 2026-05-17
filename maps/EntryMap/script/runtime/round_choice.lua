-- 回合选择系统：每波结束后处理 gear/attr/bond/evolution 四种选择的仲裁和路由
-- 自初始化模块，require 时设置 _G 对应函数

local BondSystem = require 'runtime.bonds_chain'
local GearUpgrades = require 'runtime.gear_upgrades'
local BondDrawConfig = require 'data.tables.bond.bond_effect_runtime_rules'

-- 选择类型名称映射（纯函数，无依赖）
local get_pending_round_choice_label = function(kind)
  if kind == 'bond' then
    return 'F 战术抽卡'
  end
  if kind == 'gear' then
    return '成长武器词条'
  end
  if kind == 'attr' then
    return '属性四选一'
  end
  if kind == 'evolution' then
    return '英雄'
  end
  return '当前选择'
end

-- 检测当前待处理的回合选择类型（优先级：gear > attr > bond > evolution）
local get_pending_round_choice_kind = function()
  local STATE = _G.STATE
  if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
    return 'gear'
  end
  local attr_choice_system = _G.attr_choice_system
  if attr_choice_system and attr_choice_system.get_pending_choice_kind then
    local attr_kind = attr_choice_system.get_pending_choice_kind()
    if attr_kind then
      return attr_kind
    end
  end
  if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice and STATE.bond_runtime.current_choices then
    return 'bond'
  end
  local evolution_runtime = STATE.evolution_runtime
  if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
    return 'evolution'
  end
  return nil
end

-- 展示对应类型的选择面板
local show_pending_round_choice = function(kind)
  local STATE = _G.STATE
  local current_kind = kind or get_pending_round_choice_kind()
  STATE.choice_panel_hidden = false
  if current_kind == 'bond' then
    BondSystem.try_draw(_G.create_bond_env())
    return
  end
  if current_kind == 'gear' then
    return
  end
  if current_kind == 'attr' then
    local runtime_hud_system = _G.runtime_hud_system
    return runtime_hud_system and runtime_hud_system.refresh_hud and runtime_hud_system.refresh_hud() or nil
  end
  if current_kind == 'evolution' then
    local reward_system = _G.reward_system
    reward_system.show_evolution_choices()
    return
  end
end

-- 确保当前选择的类型可用（有未完成选择时拦截并提示）
local ensure_round_choice_available = function(allowed_kind)
  local kind = get_pending_round_choice_kind()
  if not kind or kind == allowed_kind then
    return true
  end
  _G.message('请先完成当前' .. get_pending_round_choice_label(kind) .. '。')
  show_pending_round_choice(kind)
  return false
end

-- 应用羁绊选择结果（处理替换流程）
local apply_bond_choice = function(index)
  local STATE = _G.STATE
  local result = BondSystem.apply_choice(_G.create_bond_env(), index)
  if result == 'replace' then
    STATE.choice_panel_hidden = false
    local runtime_hud_system = _G.runtime_hud_system
    if runtime_hud_system and runtime_hud_system.show_bond_replacement_panel then
      runtime_hud_system.show_bond_replacement_panel()
    end
    return
  end
  STATE.choice_panel_hidden = true
end

-- 选择路由：将玩家选择分发到对应系统
local apply_round_choice = function(index)
  local kind = get_pending_round_choice_kind()
  local STATE = _G.STATE

  if kind == 'gear' then
    if GearUpgrades.apply_affix_choice({
          STATE = STATE,
          CONFIG = _G.CONFIG,
          message = _G.message,
        }, index) then
      if STATE.hero and _G.sync_gear_runtime_effects then
        _G.sync_gear_runtime_effects(STATE, STATE.hero, _G.CONFIG.gear_upgrade_config)
      end
      STATE.choice_panel_hidden = true
      return true
    end
    return false
  end

  if kind == 'attr' then
    local attr_choice_system = _G.attr_choice_system
    local ok = attr_choice_system and attr_choice_system.apply_choice and attr_choice_system.apply_choice(index) or false
    if ok then
      STATE.choice_panel_hidden = true
    end
    return ok
  end

  if kind == 'bond' then
    apply_bond_choice(index)
    STATE.choice_panel_hidden = true
    return true
  end

  if kind == 'evolution' then
    _G.reward_system.apply_evolution_choice(index)
    STATE.choice_panel_hidden = true
    return true
  end

  return false
end

-- 尝试羁绊抽卡
local try_bond_draw = function()
  local STATE = _G.STATE
  STATE.choice_panel_hidden = false
  if not ensure_round_choice_available('bond') then
    return
  end
  if not STATE.resources or (STATE.resources.wood or 0) < (BondDrawConfig.draw_cost or 100) then
    local hud = _G.hud_system
    if hud and hud.show_center_tip then
      hud.show_center_tip('木头不足，无法抽卡！')
    end
  end
  BondSystem.try_draw(_G.create_bond_env())
end

-- 尝试开始挑战
local try_start_challenge = function(challenge_id)
  if not ensure_round_choice_available(nil) then
    return
  end
  local battlefield_system = _G.battlefield_system
  return battlefield_system and battlefield_system.try_start_challenge(challenge_id)
end

-- 使用属性钻石刷新四选一
local use_attr_diamond = function()
  if not ensure_round_choice_available('attr') then
    return false
  end
  local attr_choice_system = _G.attr_choice_system
  local ok = attr_choice_system and attr_choice_system.use_diamond and attr_choice_system.use_diamond() or false
  if ok then
    _G.STATE.choice_panel_hidden = false
    show_pending_round_choice('attr')
  end
  return ok
end

-- 导出
_G.get_pending_round_choice_kind = get_pending_round_choice_kind
_G.ensure_round_choice_available = ensure_round_choice_available
_G.apply_round_choice = apply_round_choice
_G.try_bond_draw = try_bond_draw
_G.try_start_challenge = try_start_challenge
_G.use_attr_diamond = use_attr_diamond

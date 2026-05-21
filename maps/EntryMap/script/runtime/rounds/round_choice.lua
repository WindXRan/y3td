-- 回合选择系统：每波结束后处理 attr/evolution 两种选择的仲裁和路由
-- 自初始化模块，require 时设置 _G 对应函数

-- 选择类型名称映射（纯函数，无依赖）
local get_pending_round_choice_label = function(kind)
  if kind == 'attr' then
    return '属性四选一'
  end
  if kind == 'evolution' then
    return '英雄'
  end
  return '当前选择'
end

-- 检测当前待处理的回合选择类型（优先级：attr > evolution）
local get_pending_round_choice_kind = function()
  local STATE = _G.STATE
  local attr_choice_system = _G.attr_choice_system
  if attr_choice_system and attr_choice_system.get_pending_choice_kind then
    local attr_kind = attr_choice_system.get_pending_choice_kind()
    if attr_kind then
      return attr_kind
    end
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

-- 选择路由：将玩家选择分发到对应系统
local apply_round_choice = function(index)
  local kind = get_pending_round_choice_kind()
  local STATE = _G.STATE

  if kind == 'attr' then
    local attr_choice_system = _G.attr_choice_system
    local ok = attr_choice_system and attr_choice_system.apply_choice and attr_choice_system.apply_choice(index) or false
    if ok then
      STATE.choice_panel_hidden = true
    end
    return ok
  end

  if kind == 'evolution' then
    _G.reward_system.apply_evolution_choice(index)
    STATE.choice_panel_hidden = true
    return true
  end

  return false
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
_G.use_attr_diamond = use_attr_diamond

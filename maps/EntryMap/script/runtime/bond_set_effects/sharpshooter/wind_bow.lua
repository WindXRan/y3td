local M = {
  id = 'wind_bow',
  display_name = '疾风弓',
  effect_id = 'rapid_overdrive',
}

local function get_effect_debug_system(env)
  return env and env.effect_debug_system or nil
end

local function get_auto_active_effects_system(env)
  return env and env.auto_active_effects_system or nil
end

function M.activate(env)
  local effect_debug_system = get_effect_debug_system(env)
  if not effect_debug_system then
    return false, 'effect_debug_system_not_ready'
  end
  return effect_debug_system.mount_effect(M.effect_id)
end

function M.deactivate(env)
  local effect_debug_system = get_effect_debug_system(env)
  if not effect_debug_system then
    return false, 'effect_debug_system_not_ready'
  end
  return effect_debug_system.unmount_effect(M.effect_id)
end

function M.trigger(env)
  local auto_active_effects_system = get_auto_active_effects_system(env)
  if not auto_active_effects_system then
    return false, 'auto_active_effects_system_not_ready'
  end
  return auto_active_effects_system.force_trigger_effect(M.effect_id)
end

function M.get_state(env)
  local auto_active_effects_system = get_auto_active_effects_system(env)
  if not auto_active_effects_system then
    return nil
  end
  return auto_active_effects_system.get_effect_runtime_snapshot(M.effect_id)
end

function M.register_global_apis(env)
  local function wind_bow_effect(action)
    local command = tostring(action or 'register')
    if command == 'register' or command == 'mount' or command == 'on' or command == '启用' or command == '注册' then
      return M.activate(env)
    end
    if command == 'unregister' or command == 'unmount' or command == 'off' or command == '禁用' or command == '注销' then
      return M.deactivate(env)
    end
    if command == 'trigger' or command == 'cast' or command == '触发' then
      return M.trigger(env)
    end
    if command == 'state' or command == 'status' or command == '状态' then
      return M.get_state(env)
    end
    return false, 'unknown_wind_bow_action'
  end

  rawset(_G, 'WindBowEffect', wind_bow_effect)
  rawset(_G, 'RegisterWindBowEffect', function()
    return M.activate(env)
  end)
  rawset(_G, 'UnregisterWindBowEffect', function()
    return M.deactivate(env)
  end)
  rawset(_G, 'TriggerWindBowEffect', function()
    return M.trigger(env)
  end)
  rawset(_G, 'GetWindBowEffectState', function()
    return M.get_state(env)
  end)

  rawset(_G, '疾风弓效果', wind_bow_effect)
  rawset(_G, '注册疾风弓', function()
    return M.activate(env)
  end)
  rawset(_G, '注销疾风弓', function()
    return M.deactivate(env)
  end)
  rawset(_G, '触发疾风弓', function()
    return M.trigger(env)
  end)
  rawset(_G, '获取疾风弓状态', function()
    return M.get_state(env)
  end)
end

return M

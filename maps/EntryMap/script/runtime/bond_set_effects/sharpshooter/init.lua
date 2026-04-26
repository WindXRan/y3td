local WindBow = require 'runtime.bond_set_effects.sharpshooter.wind_bow'

local M = {
  id = 'sharpshooter',
  display_name = '神射手',
}

local EFFECTS = {
  WindBow,
}

local function is_effect_match(effect, effect_id)
  return effect.id == effect_id or effect.effect_id == effect_id
end

function M.activate(env)
  local ok = true
  local last_result
  for _, effect in ipairs(EFFECTS) do
    if effect.activate then
      local current_ok, result = effect.activate(env)
      ok = ok and current_ok ~= false
      last_result = result or last_result
    end
  end
  return ok, last_result or 'sharpshooter_activated'
end

function M.deactivate(env)
  local ok = true
  local last_result
  for _, effect in ipairs(EFFECTS) do
    if effect.deactivate then
      local current_ok, result = effect.deactivate(env)
      ok = ok and current_ok ~= false
      last_result = result or last_result
    end
  end
  return ok, last_result or 'sharpshooter_deactivated'
end

function M.trigger_effect(env, effect_id)
  for _, effect in ipairs(EFFECTS) do
    if is_effect_match(effect, effect_id) and effect.trigger then
      return effect.trigger(env)
    end
  end
  return nil
end

function M.get_effect_state(env, effect_id)
  for _, effect in ipairs(EFFECTS) do
    if is_effect_match(effect, effect_id) and effect.get_state then
      return effect.get_state(env)
    end
  end
  return nil
end

function M.register_global_apis(env)
  local function sharpshooter_effect(action)
    local command = tostring(action or 'activate')
    if command == 'activate' or command == 'register' or command == 'on' or command == '激活' or command == '注册' then
      return M.activate(env)
    end
    if command == 'deactivate' or command == 'unregister' or command == 'off' or command == '关闭' or command == '注销' then
      return M.deactivate(env)
    end
    if command == 'trigger' or command == '触发' then
      return WindBow.trigger(env)
    end
    if command == 'state' or command == 'status' or command == '状态' then
      return WindBow.get_state(env)
    end
    return false, 'unknown_sharpshooter_action'
  end

  rawset(_G, 'SharpshooterEffect', sharpshooter_effect)
  rawset(_G, 'ActivateSharpshooterEffect', function()
    return M.activate(env)
  end)
  rawset(_G, 'DeactivateSharpshooterEffect', function()
    return M.deactivate(env)
  end)

  rawset(_G, '神射手效果', sharpshooter_effect)
  rawset(_G, '激活神射手', function()
    return M.activate(env)
  end)
  rawset(_G, '注销神射手', function()
    return M.deactivate(env)
  end)

  WindBow.register_global_apis(env)
end

return M

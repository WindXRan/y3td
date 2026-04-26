local Sharpshooter = require 'runtime.bond_set_effects.sharpshooter'

local M = {}

local SETS = {
  sharpshooter = Sharpshooter,
}

function M.create(env)
  local api = {}

  local function get_set(set_id)
    return SETS[set_id or 'sharpshooter']
  end

  function api.activate_set(set_id)
    local set = get_set(set_id)
    if not set or not set.activate then
      return false, 'unknown_bond_set_effect'
    end
    return set.activate(env)
  end

  function api.deactivate_set(set_id)
    local set = get_set(set_id)
    if not set or not set.deactivate then
      return false, 'unknown_bond_set_effect'
    end
    return set.deactivate(env)
  end

  function api.trigger_effect(effect_id)
    for _, set in pairs(SETS) do
      if set.trigger_effect then
        local ok, result = set.trigger_effect(env, effect_id)
        if ok ~= nil then
          return ok, result
        end
      end
    end
    return false, 'unknown_bond_set_effect'
  end

  function api.get_effect_state(effect_id)
    for _, set in pairs(SETS) do
      if set.get_effect_state then
        local result = set.get_effect_state(env, effect_id)
        if result ~= nil then
          return result
        end
      end
    end
    return nil
  end

  function api.register_global_apis()
    for _, set in pairs(SETS) do
      if set.register_global_apis then
        set.register_global_apis(env)
      end
    end
  end

  return api
end

return M

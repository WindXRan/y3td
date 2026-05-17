local M = {}

function M.create(env)
  local api = {}
  local STATE = env.STATE

  function api.on_hunter_first_hit(target)
    -- 猎人首击效果
  end

  function api.on_reserve_formula_damage(data)
    -- 保留公式伤害
  end

  function api.get_special_effect(name)
    local effects = {
      hunter_first_hit = { name = '猎人首击', multiplier = 1.5 },
      reserve_formula = { name = '公式保留', multiplier = 1.0 },
    }
    return effects[name]
  end

  return api
end

return M

local M = {}

function M.create(env)
  local api = {}
  local STATE = env.STATE

  function api.on_chain(trigger)
    -- 闪电链效果
  end

  function api.on_splash(trigger)
    -- 溅射效果
  end

  function api.on_execute(trigger)
    -- 处决效果
  end

  function api.on_medbot(trigger)
    -- 医疗机器人效果
  end

  function api.on_artillery(trigger)
    -- 火炮效果
  end

  function api.on_strike(trigger)
    -- 强力一击效果
  end

  function api.get_stats()
    return {}
  end

  function api.sync(hero, hero_attr_system)
    -- 同步相关属性
  end

  return api
end

return M

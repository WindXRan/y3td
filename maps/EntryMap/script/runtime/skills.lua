local M = {}

-- 旧版框架技能系统已下线。
-- 当前仅保留兼容接口，避免历史调用崩溃。

local function unsupported()
  return nil
end

function M.build_unique_skill(_id, _visual)
  return unsupported()
end

function M.list_unique_skill_ids()
  return {}
end

function M.build_unique_skill_variant(_id, _tier, _visual)
  return unsupported()
end

function M.build_production_skill(id, _tier, _visual, _override)
  -- 历史别名兼容：sample 仍可能调用这个入口。
  return M.build_unique_skill(id)
end

function M.list_unique_tiers()
  return { 'mid' }
end

return M

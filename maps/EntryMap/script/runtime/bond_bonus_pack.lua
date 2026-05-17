local M = {}

function M.sync_all()
  -- 这个函数由外部在合适的时机调用
end

function M.scan(state)
  if not state or not state.bond_runtime or not state.bond_runtime.equipped then
    return {}
  end
  local result = {}
  for _, entry in ipairs(state.bond_runtime.equipped) do
    if entry and entry.bonus_pack then
      result[#result + 1] = entry.bonus_pack
    end
  end
  return result
end

function M.apply(state)
  -- 应用所有奖励包
end

return M

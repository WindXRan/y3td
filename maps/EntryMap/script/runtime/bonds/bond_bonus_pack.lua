local M = {}

function M.copy(pack)
  local out = {}
  for k, v in pairs(pack or {}) do out[k] = v end
  return out
end

function M.add_value(target, key, value) target[key] = (target[key] or 0) + value end
function M.remove_value(target, key, value) target[key] = (target[key] or 0) - value end

function M.merge(base, override)
  local out = M.copy(base)
  for k, v in pairs(override or {}) do out[k] = v end
  return out
end

function M.subtract(base, override)
  local out = M.copy(base)
  for k, v in pairs(override or {}) do out[k] = (out[k] or 0) - v end
  return out
end

function M.scan(state)
  if not state or not state.bond_runtime or not state.bond_runtime.equipped then return {} end
  local result = {}
  for _, entry in ipairs(state.bond_runtime.equipped) do
    if entry and entry.bonus_pack then result[#result + 1] = entry.bonus_pack end
  end
  return result
end

return M
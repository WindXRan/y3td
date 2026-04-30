local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'
local BondVisualEditorIds = require 'data.object_tables.bond_visual_editor_ids'

local M = {}

local function has_chinese(text)
  text = tostring(text or '')
  return string.find(text, '[\228-\233][\128-\191][\128-\191]') ~= nil
end

local function push_unique(list, set, value)
  local key = tonumber(value)
  if not key or key <= 0 then
    return
  end
  key = math.floor(key)
  if set[key] then
    return
  end
  set[key] = true
  list[#list + 1] = key
end

local function collect_projectile_ids(extra_ids)
  local result = {}
  local set = {}

  for _, value in pairs((RuntimeEditorIds and RuntimeEditorIds.projectile) or {}) do
    push_unique(result, set, value)
  end

  for _, cfg in pairs((BondVisualEditorIds and BondVisualEditorIds.visual_by_bond) or {}) do
    if type(cfg) == 'table' then
      push_unique(result, set, cfg.projectile_key)
    end
  end

  for _, value in ipairs(extra_ids or {}) do
    push_unique(result, set, value)
  end

  table.sort(result)
  return result
end

function M.validate(env, extra_ids)
  local y3 = env and env.y3
  if not y3 or not y3.projectile or not y3.projectile.get_name_by_key then
    return true
  end

  local bad = {}
  for _, projectile_key in ipairs(collect_projectile_ids(extra_ids)) do
    local ok_name, name = pcall(y3.projectile.get_name_by_key, projectile_key)
    local text = ok_name and tostring(name or '') or ''
    if text == '' or not has_chinese(text) then
      bad[#bad + 1] = string.format('%d(%s)', projectile_key, text ~= '' and text or '无名称')
    end
  end

  if #bad > 0 then
    error('[projectile_name_guard] 以下投射物缺少中文名：' .. table.concat(bad, ', '))
  end
  return true
end

return M


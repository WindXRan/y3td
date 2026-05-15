local CsvLoader = require 'data.csv_loader'
local ShopItems = require 'data.tables.economy.shop_items'

local M = {}

local function trim(value)
  local s = tostring(value or '')
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function to_bool(raw, default_value)
  local text = string.lower(trim(raw))
  if text == '' then
    return default_value == true
  end
  return text == '1' or text == 'true' or text == 'yes' or text == 'y'
end

local function make_key(tab, action)
  return trim(tab) .. '|' .. trim(action)
end

local function is_archive_stackable_item(spec, item_name)
  if not spec then
    return false
  end
  if trim(spec.title or spec.name) ~= trim(item_name) then
    return false
  end
  return spec.stackable == true
    and trim(spec.partition) == '存档'
    and trim(spec.primary or spec.l1_tab) == '仓库'
end

local function find_shop_item(item_name)
  for _, spec in ipairs(ShopItems.list or {}) do
    if is_archive_stackable_item(spec, item_name) then
      return spec
    end
  end
  return nil
end

local rows = CsvLoader.read_rows_optional({path = 'data_csv/outgame/outgame_archive_action_costs.csv'})
local by_key = {}

for _, row in ipairs(rows) do
  if to_bool(row.enabled, true) then
    local tab = trim(row.tab)
    local action = trim(row.action)
    local item_name = trim(row.item_name or row.resource_key)
    if tab ~= '' and action ~= '' and item_name ~= '' then
      local item_spec = find_shop_item(item_name)
      local item_label = trim(row.item_label or row.resource_label)
      local item_icon = tonumber(row.item_icon or row.resource_icon) or tonumber(item_spec and item_spec.icon) or 0
      by_key[make_key(tab, action)] = {
        tab = tab,
        action = action,
        item_name = item_name,
        item_label = item_label ~= '' and item_label or item_name,
        item_icon = item_icon,
        require_stackable_archive_item = true,
        base_cost = math.max(0, tonumber(row.base_cost) or 0),
        per_level = math.max(0, tonumber(row.per_level) or 0),
      }
    end
  end
end

function M.get(tab, action)
  return by_key[make_key(tab, action)]
end

function M.get_cost(tab, action, level)
  local cfg = M.get(tab, action)
  if not cfg then
    return nil
  end
  local current_level = math.max(0, tonumber(level) or 0)
  return math.floor((cfg.base_cost or 0) + (cfg.per_level or 0) * current_level)
end

M.by_key = by_key

return M

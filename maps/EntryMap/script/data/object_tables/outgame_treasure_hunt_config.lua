local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local item_rows = CsvLoader.read_rows('data_csv/outgame_treasure_hunt_items.csv')
local effect_rows = CsvLoader.read_rows('data_csv/outgame_treasure_hunt_effects.csv')
local effect_groups = CsvLoader.group_by(effect_rows, 'item_id')

local function to_boolean(raw)
  return raw == 'true' or raw == '1'
end

local function to_number_if_possible(raw)
  if raw == nil or raw == '' or raw == 'null' then
    return nil
  end
  return tonumber(raw)
end

local function sort_by_order_index(list, fallback_key)
  table.sort(list, function(a, b)
    local a_order = tonumber(a.order_index) or 0
    local b_order = tonumber(b.order_index) or 0
    if a_order == b_order then
      return tostring(a[fallback_key] or a.id or '') < tostring(b[fallback_key] or b.id or '')
    end
    return a_order < b_order
  end)
end

local function build_effects(rows)
  local list = {}
  for _, row in ipairs(rows or {}) do
    list[#list + 1] = {
      order_index = tonumber(row.order_index) or 0,
      item_id = row.item_id,
      effect_type = row.effect_type,
      effect_key = row.effect_key,
      op = row.op,
      value = to_number_if_possible(row.value) or 0,
      display_text = row.display_text ~= '' and row.display_text or nil,
      notes = row.notes ~= '' and row.notes or nil,
    }
  end
  sort_by_order_index(list, 'effect_key')
  return list
end

local list = {}
local by_rarity = {}

for _, row in ipairs(item_rows) do
  local entry = {
    order_index = tonumber(row.order_index) or 0,
    id = row.id,
    name = row.name,
    rarity = row.rarity,
    cost_points = tonumber(row.cost_points) or 0,
    item_kind = row.item_kind ~= '' and row.item_kind or 'misc',
    bundle_count = math.max(1, tonumber(row.bundle_count) or 1),
    is_exchangeable = to_boolean(row.is_exchangeable),
    is_stackable = to_boolean(row.is_stackable),
    effect_cap_rule = row.effect_cap_rule ~= '' and row.effect_cap_rule or 'none',
    initial_owned_count = math.max(0, tonumber(row.initial_owned_count) or 0),
    summary = row.summary,
    notes = row.notes ~= '' and row.notes or nil,
    effects = build_effects(effect_groups[row.id]),
  }
  list[#list + 1] = entry
  by_rarity[entry.rarity] = by_rarity[entry.rarity] or {}
  by_rarity[entry.rarity][#by_rarity[entry.rarity] + 1] = entry
end

sort_by_order_index(list, 'id')
for _, rarity_list in pairs(by_rarity) do
  sort_by_order_index(rarity_list, 'id')
end

return {
  pool_id = 'treasure_hunt_time_labyrinth',
  display_name = '夺宝奇兵·时光迷城',
  currency_name = '夺宝积分',
  default_points = 0,
  list = list,
  by_id = helpers.list_to_map(list),
  by_rarity = by_rarity,
}

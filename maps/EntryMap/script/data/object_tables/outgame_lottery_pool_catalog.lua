local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local rows = CsvLoader.read_rows('data_csv/outgame_lottery_treasure_hunt_pool_1.csv')

local function sort_entries(list)
  table.sort(list, function(a, b)
    if a.order_index == b.order_index then
      return tostring(a.id) < tostring(b.id)
    end
    return a.order_index < b.order_index
  end)
end

local items = {}
local by_pool = {}
local by_rarity = {}

for _, row in ipairs(rows) do
  local item = {
    order_index = tonumber(row.order_index) or 0,
    pool_id = row.pool_id,
    id = row.item_id,
    item_id = row.item_id,
    name = row.name,
    rarity = row.rarity,
    source_exchange_points = tonumber(row.source_exchange_points) or 0,
    summary = row.summary,
    source_image = row.source_image ~= '' and row.source_image or nil,
    notes = row.notes ~= '' and row.notes or nil,
  }
  items[#items + 1] = item
  by_pool[item.pool_id] = by_pool[item.pool_id] or {
    id = item.pool_id,
    pool_id = item.pool_id,
    display_name = '夺宝奇兵',
    rarity_order = { 'N', 'R', 'SR', 'SSR' },
    list = {},
    by_id = {},
    by_rarity = {},
  }
  local pool = by_pool[item.pool_id]
  pool.list[#pool.list + 1] = item
  pool.by_id[item.id] = item
  pool.by_rarity[item.rarity] = pool.by_rarity[item.rarity] or {}
  pool.by_rarity[item.rarity][#pool.by_rarity[item.rarity] + 1] = item
  by_rarity[item.rarity] = by_rarity[item.rarity] or {}
  by_rarity[item.rarity][#by_rarity[item.rarity] + 1] = item
end

sort_entries(items)
for _, pool in pairs(by_pool) do
  sort_entries(pool.list)
  for _, rarity_items in pairs(pool.by_rarity) do
    sort_entries(rarity_items)
  end
end
for _, rarity_items in pairs(by_rarity) do
  sort_entries(rarity_items)
end

local pools = {}
for _, pool in pairs(by_pool) do
  pools[#pools + 1] = pool
end
table.sort(pools, function(a, b)
  return tostring(a.pool_id) < tostring(b.pool_id)
end)

return {
  list = pools,
  by_id = helpers.list_to_map(pools),
  items = items,
  items_by_id = helpers.list_to_map(items),
  by_rarity = by_rarity,
}

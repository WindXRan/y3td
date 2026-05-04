local helpers = require 'data.tables.helpers'
local CsvLoader = require 'data.csv_loader'

local SUIT_IDS = {
  DRAGON       = 'suit_dragon',
  PHOENIX      = 'suit_phoenix',
  TIGER        = 'suit_tiger',
  CRANE        = 'suit_crane',
  VIPER        = 'suit_viper',
}

local CONSUMABLE_KEYS = {
  STAR_STONE   = 'consumable_star_stone',
}

local function load_upgrade_costs()
  local rows = CsvLoader.read_rows_optional('data_csv/by_feature/economy/suit_upgrade_cost.csv') or {}
  local list = {}
  
  for _, row in ipairs(rows) do
    local suit_id = tostring(row.suit_id or '')
    local star_level = tonumber(row.star_level)
    if suit_id ~= '' and star_level then
      list[#list + 1] = {
        suit_id = suit_id,
        star_level = star_level,
        upgrade_success_rate = tonumber(row.success_rate) or 1.0,
        cost_items = {
          { 
            consumable_key = tostring(row.consumable_key or ''), 
            amount = tonumber(row.cost_amount) or 0 
          },
        },
      }
    end
  end
  
  return list
end

local list = load_upgrade_costs()

local function get_cost_by_suit_and_level(suit_id, target_star_level)
  for _, item in ipairs(list) do
    if item.suit_id == suit_id and item.star_level == target_star_level then
      return item
    end
  end
  return nil
end

return {
  SUIT_IDS = SUIT_IDS,
  CONSUMABLE_KEYS = CONSUMABLE_KEYS,
  list = list,
  by_suit_id = helpers.list_to_map(list, 'suit_id'),
  get_cost_by_suit_and_level = get_cost_by_suit_and_level,
}
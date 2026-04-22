local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local rows = CsvLoader.read_rows('data_csv/outgame_lottery_pool_rules.csv')

local function to_boolean(raw)
  return raw == 'true' or raw == '1'
end

local function split_pipe(text)
  local result = {}
  for value in string.gmatch(tostring(text or ''), '([^|]+)') do
    local normalized = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
    if normalized ~= '' then
      result[#result + 1] = normalized
    end
  end
  return result
end

local list = {}
for _, row in ipairs(rows) do
  local rarity_order = split_pipe(row.rarity_order)
  local entry = {
    id = row.pool_id,
    pool_id = row.pool_id,
    display_name = row.display_name,
    currency_name = row.currency_name,
    draw_cost_single = tonumber(row.draw_cost_single) or 1,
    draw_cost_ten = tonumber(row.draw_cost_ten) or 10,
    default_selected = to_boolean(row.default_selected),
    rarity_order = rarity_order,
    rates = {
      N = tonumber(row.rate_n) or 0,
      R = tonumber(row.rate_r) or 0,
      SR = tonumber(row.rate_sr) or 0,
      SSR = tonumber(row.rate_ssr) or 0,
    },
    repeat_refunds = {
      N = tonumber(row.refund_n) or 0,
      R = tonumber(row.refund_r) or 0,
      SR = tonumber(row.refund_sr) or 0,
      SSR = tonumber(row.refund_ssr) or 0,
    },
    first_single_guarantee_rarity = row.first_single_guarantee_rarity ~= '' and row.first_single_guarantee_rarity or nil,
    first_ten_guarantee_rarity = row.first_ten_guarantee_rarity ~= '' and row.first_ten_guarantee_rarity or nil,
    pity_draw_count = tonumber(row.pity_draw_count) or 0,
    pity_guarantee_rarity = row.pity_guarantee_rarity ~= '' and row.pity_guarantee_rarity or nil,
    notes = row.notes ~= '' and row.notes or nil,
  }
  list[#list + 1] = entry
end

table.sort(list, function(a, b)
  return tostring(a.pool_id) < tostring(b.pool_id)
end)

local default_pool_id = nil
for _, entry in ipairs(list) do
  if entry.default_selected then
    default_pool_id = entry.pool_id
    break
  end
end
if default_pool_id == nil and list[1] then
  default_pool_id = list[1].pool_id
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
  default_pool_id = default_pool_id,
}

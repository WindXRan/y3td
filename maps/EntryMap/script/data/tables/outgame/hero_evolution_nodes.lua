local CsvLoader = require 'data.csv_loader'
local helpers = require 'data.tables.helpers'

local CSV_PATH = 'data_csv/outgame/hero_evolution_nodes.csv'

local pool_rules_by_id = {
  evolution_pool_global = {
    pool_rule_id = 'evolution_pool_global',
    choice_count = 2,
    common_weight = 55,
    rare_weight = 30,
    epic_weight = 15,
    guarantee_high_quality = true,
    same_round_no_repeat = true,
    exclude_owned = true,
    enabled = true,
  },
}

local function build_from_csv_row(row)
  return {
    id = row.id,
    trigger_level = CsvLoader.to_number(row.trigger_level, 0),
    choice_count = CsvLoader.to_number(row.choice_count, 2),
    pool_rule_id = row.pool_rule_id ~= '' and row.pool_rule_id or 'evolution_pool_global',
    queue_priority = CsvLoader.to_number(row.queue_priority, 95),
    ui_title = row.ui_title ~= '' and row.ui_title or '英雄进阶',
  }
end

local function load_from_csv()
  local rows = CsvLoader.read_rows(CSV_PATH)
  local list = {}
  for _, row in ipairs(rows) do
    local node = build_from_csv_row(row)
    if node.id and node.id ~= '' then
      list[#list + 1] = node
    end
  end
  return list
end

local list = load_from_csv()

local by_level = {}
for _, node in ipairs(list) do
  by_level[node.trigger_level] = node
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
  by_level = by_level,
  pool_rules_by_id = pool_rules_by_id,
}
local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local node_rows = CsvLoader.read_rows('data_csv/evolution_nodes.csv')

local function to_boolean(raw)
  return raw == 'true' or raw == '1'
end

local list = {}
local pool_rules = {}
for _, row in ipairs(node_rows) do
  local pool_rule_id = row.pool_rule_id
  list[#list + 1] = {
    id = row.id,
    trigger_level = tonumber(row.trigger_level) or 0,
    choice_count = tonumber(row.choice_count) or 0,
    pool_rule_id = pool_rule_id,
    queue_priority = tonumber(row.queue_priority) or 0,
    ui_title = row.ui_title,
  }
  if pool_rule_id and pool_rule_id ~= '' and not pool_rules[pool_rule_id] then
    pool_rules[pool_rule_id] = {
      pool_rule_id = pool_rule_id,
      choice_count = tonumber(row.choice_count) or 0,
      common_weight = tonumber(row.common_weight) or 0,
      rare_weight = tonumber(row.rare_weight) or 0,
      epic_weight = tonumber(row.epic_weight) or 0,
      guarantee_high_quality = to_boolean(row.guarantee_high_quality),
      same_round_no_repeat = to_boolean(row.same_round_no_repeat),
      exclude_owned = to_boolean(row.exclude_owned),
      enabled = to_boolean(row.enabled),
    }
  end
end

table.sort(list, function(a, b)
  return (a.trigger_level or 0) < (b.trigger_level or 0)
end)

local by_level = {}
for _, node in ipairs(list) do
  by_level[node.trigger_level] = node
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
  by_level = by_level,
  pool_rules_by_id = pool_rules,
}

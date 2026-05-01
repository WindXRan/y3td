local helpers = require 'data.tables.helpers'

local list = {
  {
    id = 'evolution_node_lv10',
    trigger_level = 10,
    choice_count = 2,
    pool_rule_id = 'evolution_pool_global',
    queue_priority = 95,
    ui_title = '英雄进阶',
  },
  {
    id = 'evolution_node_lv20',
    trigger_level = 20,
    choice_count = 2,
    pool_rule_id = 'evolution_pool_global',
    queue_priority = 95,
    ui_title = '英雄进阶',
  },
  {
    id = 'evolution_node_lv30',
    trigger_level = 30,
    choice_count = 2,
    pool_rule_id = 'evolution_pool_global',
    queue_priority = 95,
    ui_title = '英雄进阶',
  },
  {
    id = 'evolution_node_lv40',
    trigger_level = 40,
    choice_count = 2,
    pool_rule_id = 'evolution_pool_global',
    queue_priority = 95,
    ui_title = '英雄进阶',
  },
}

local by_level = {}
for _, node in ipairs(list) do
  by_level[node.trigger_level] = node
end

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

return {
  list = list,
  by_id = helpers.list_to_map(list),
  by_level = by_level,
  pool_rules_by_id = pool_rules_by_id,
}



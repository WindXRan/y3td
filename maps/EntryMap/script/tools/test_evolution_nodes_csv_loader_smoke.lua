package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local nodes = require 'data.object_tables.evolution_nodes'

assert(type(nodes.list) == 'table', 'nodes.list should be a table')
assert(type(nodes.by_id) == 'table', 'nodes.by_id should be a table')
assert(type(nodes.by_level) == 'table', 'nodes.by_level should be a table')
assert(type(nodes.pool_rules_by_id) == 'table', 'pool_rules_by_id should be a table')
assert(#nodes.list == 4, 'expected 4 evolution nodes')

local node_lv10 = nodes.by_level[10]
assert(node_lv10 ~= nil, 'level 10 node should exist')
assert(node_lv10.id == 'mark_node_lv10', 'level 10 node id should stay intact')
assert(node_lv10.pool_rule_id == 'mark_pool_global', 'level 10 node should keep pool_rule_id')
assert(node_lv10.ui_title == '10级进化选择', 'level 10 node title should stay intact')

local global_rule = nodes.pool_rules_by_id.mark_pool_global
assert(global_rule ~= nil, 'mark_pool_global should exist')
assert(global_rule.guarantee_high_quality == true, 'global rule should enable high-quality guarantee')
assert(global_rule.choice_count == 3, 'global rule choice_count should be numeric')

print('evolution nodes csv loader smoke ok')

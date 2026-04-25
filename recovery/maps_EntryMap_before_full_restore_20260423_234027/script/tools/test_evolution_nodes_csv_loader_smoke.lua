package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local nodes = require 'data.object_tables.evolution_nodes'

assert(type(nodes.list) == 'table', 'nodes.list should be a table')
assert(type(nodes.by_id) == 'table', 'nodes.by_id should be a table')
assert(type(nodes.by_level) == 'table', 'nodes.by_level should be a table')
assert(type(nodes.pool_rules_by_id) == 'table', 'pool_rules_by_id should be a table')
assert(#nodes.list == 8, 'expected 8 evolution nodes')

local node_lv5 = nodes.by_level[5]
assert(node_lv5 ~= nil, 'level 5 node should exist')
assert(node_lv5.id == 'evolution_node_lv05', 'level 5 node id should match the new cadence')
assert(node_lv5.pool_rule_id == 'evolution_pool_global', 'level 5 node should use the global evolution pool')
assert(node_lv5.ui_title == '5级真身抉择', 'level 5 node title should use the new hero-evolution copy')
assert(node_lv5.choice_count == 2, 'level 5 node should be a 2-choice evolution pick')

local node_lv40 = nodes.by_level[40]
assert(node_lv40 ~= nil, 'level 40 node should exist')
assert(node_lv40.id == 'evolution_node_lv40', 'level 40 node id should match the new cadence')

local global_rule = nodes.pool_rules_by_id.evolution_pool_global
assert(global_rule ~= nil, 'evolution_pool_global should exist')
assert(global_rule.guarantee_high_quality == true, 'global rule should enable high-quality guarantee')
assert(global_rule.choice_count == 2, 'global rule choice_count should be numeric')

print('evolution nodes csv loader smoke ok')

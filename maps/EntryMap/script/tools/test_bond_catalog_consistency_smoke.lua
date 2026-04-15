package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local attreffect = require 'data.object_tables.attreffect'
local bond_nodes = require 'data.object_tables.bond_nodes'
local bond_root_sets = require 'data.object_tables.bond_root_sets'
local bond_draw_config = require 'data.object_tables.bond_draw_config'

assert(type(bond_nodes.list) == 'table', 'bond_nodes.list should be a table')
assert(type(bond_root_sets.list) == 'table', 'bond_root_sets.list should be a table')
assert(type(bond_draw_config.group_choice_defs) == 'table', 'bond_draw_config.group_choice_defs should be a table')

local vitality_effects = attreffect.by_source.bond_node and attreffect.by_source.bond_node['bond_body_core_vitality']
assert(vitality_effects ~= nil, 'expected bond vitality effect rows in attreffect')
assert(vitality_effects.attr['力量'] == 50, 'expected bond vitality strength effect')
assert(vitality_effects.attr['生命'] == 100, 'expected bond vitality hp effect')

local momentum_effects = attreffect.by_source.bond_node and attreffect.by_source.bond_node['bond_body_core_momentum']
assert(momentum_effects ~= nil, 'expected bond momentum effect rows in attreffect')
assert(momentum_effects.runtime['all_damage_bonus'] == 0.04, 'expected momentum runtime bonus')

local strength_effects = attreffect.by_source.bond_node and attreffect.by_source.bond_node['bond_growth_strength']
assert(strength_effects ~= nil, 'expected bond strength effect rows in attreffect')
assert(strength_effects.resource['wood'] == 50, 'expected bond unlock wood reward in attreffect')

local root_set_ids = {}
for _, root_set in ipairs(bond_root_sets.list or {}) do
  assert(root_set.root_id ~= nil and root_set.root_id ~= '', 'expected bond root_id')
  assert(root_set.required_count ~= nil and root_set.required_count > 0, 'expected positive required_count: ' .. tostring(root_set.root_id))
  assert(root_set_ids[root_set.root_id] == nil, 'expected unique bond root_id: ' .. tostring(root_set.root_id))
  root_set_ids[root_set.root_id] = true
end

local group_choice_ids = {}
for group_id, def in pairs(bond_draw_config.group_choice_defs or {}) do
  assert(group_id ~= nil and group_id ~= '', 'expected group choice group_id')
  assert(def.id ~= nil and def.id ~= '', 'expected group choice id: ' .. tostring(group_id))
  assert(def.display_name ~= nil and def.display_name ~= '', 'expected group choice display_name: ' .. tostring(group_id))
  assert(group_choice_ids[group_id] == nil, 'expected unique group choice group_id: ' .. tostring(group_id))
  group_choice_ids[group_id] = true
end

for _, root_id in ipairs(bond_nodes.root_ids or {}) do
  local node = bond_nodes.by_id[root_id]
  assert(node ~= nil, 'expected root node to exist: ' .. tostring(root_id))
  assert(node.parent_id == nil, 'expected root node parent_id to be nil: ' .. tostring(root_id))
  assert(root_set_ids[root_id] == true, 'expected root node to have root set meta: ' .. tostring(root_id))
  assert(group_choice_ids[node.group_id] == true, 'expected root node group to have group choice meta: ' .. tostring(node.group_id))
end

for _, node in ipairs(bond_nodes.list or {}) do
  assert(node.id ~= nil and node.id ~= '', 'expected bond node id')
  assert(node.group_id ~= nil and node.group_id ~= '', 'expected bond node group_id: ' .. tostring(node.id))
  assert(node.line_id ~= nil and node.line_id ~= '', 'expected bond node line_id: ' .. tostring(node.id))
  assert(node.tier ~= nil and node.tier > 0, 'expected positive bond node tier: ' .. tostring(node.id))
  assert(group_choice_ids[node.group_id] == true, 'expected bond node group to exist in group choices: ' .. tostring(node.id))

  if node.parent_id ~= nil then
    local parent = bond_nodes.by_id[node.parent_id]
    assert(parent ~= nil, 'expected bond node parent to exist: ' .. tostring(node.id))
    assert(parent.group_id == node.group_id, 'expected bond node parent group to match child group: ' .. tostring(node.id))
  end

  for _, next_id in ipairs(node.next_ids or {}) do
    local next_node = bond_nodes.by_id[next_id]
    assert(next_node ~= nil, 'expected next node to exist: ' .. tostring(node.id) .. ' -> ' .. tostring(next_id))
    assert(next_node.group_id == node.group_id, 'expected next node group to match current group: ' .. tostring(node.id))
  end
end

for _, group_id in ipairs(bond_draw_config.group_choice_order or {}) do
  local def = bond_draw_config.group_choice_defs[group_id]
  assert(def ~= nil, 'expected ordered group choice def: ' .. tostring(group_id))
  local seen_paths = {}
  for _, path_text in ipairs(def.path_texts or {}) do
    assert(path_text ~= nil and path_text ~= '', 'expected non-empty group path text: ' .. tostring(group_id))
    assert(seen_paths[path_text] == nil, 'expected unique path text inside group: ' .. tostring(group_id))
    seen_paths[path_text] = true
  end
end

print('[OK] bond catalog consistency smoke passed')

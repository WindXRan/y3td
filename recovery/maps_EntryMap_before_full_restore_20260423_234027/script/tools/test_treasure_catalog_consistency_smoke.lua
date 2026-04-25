package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local catalog = require 'data.object_tables.treasure_catalog'

assert(type(catalog) == 'table', 'treasure_catalog should return a table')
assert(type(catalog.list) == 'table', 'treasure_catalog.list should be a table')
assert(type(catalog.sets) == 'table', 'treasure_catalog.sets should be a table')

local treasure_ids = {}
local set_item_counts = {}

for _, item in ipairs(catalog.list) do
  assert(item.order_index ~= nil and item.order_index > 0, 'expected treasure order_index to be present')
  assert(item.id ~= nil and item.id ~= '', 'expected treasure id')
  assert(treasure_ids[item.id] == nil, 'expected unique treasure id: ' .. tostring(item.id))
  treasure_ids[item.id] = item
  assert(type(item.effects) == 'table' and #item.effects > 0, 'expected treasure effects to be configured: ' .. tostring(item.id))

  local seen_effect_orders = {}
  for _, effect in ipairs(item.effects) do
    assert(effect.order_index ~= nil and effect.order_index > 0, 'expected treasure effect order_index to be present: ' .. tostring(item.id))
    assert(effect.effect_type ~= nil and effect.effect_type ~= '', 'expected treasure effect_type: ' .. tostring(item.id))
    assert(seen_effect_orders[effect.order_index] == nil, 'expected unique treasure effect order_index: ' .. tostring(item.id))
    seen_effect_orders[effect.order_index] = true
  end

  if item.is_set_item then
    assert(item.set_id ~= nil and item.set_id ~= '', 'expected set item to declare set_id: ' .. item.id)
    set_item_counts[item.set_id] = (set_item_counts[item.set_id] or 0) + 1
  else
    assert(item.set_id == nil, 'expected non-set treasure to leave set_id empty: ' .. item.id)
  end
end

for _, set_def in ipairs(catalog.sets) do
  assert(set_def.order_index ~= nil and set_def.order_index > 0, 'expected set order_index to be present')
  assert(type(set_def.members) == 'table', 'expected set members table: ' .. tostring(set_def.set_id))
  assert(#set_def.members == set_def.piece_count, 'expected set member count to match piece_count: ' .. tostring(set_def.set_id))
  assert(type(set_def.effects) == 'table' and #set_def.effects > 0, 'expected set effects to be configured: ' .. tostring(set_def.set_id))

  local seen_member_orders = {}
  local seen_member_ids = {}
  for _, member in ipairs(set_def.members) do
    assert(member.order_index ~= nil and member.order_index > 0, 'expected member order_index to be present: ' .. tostring(set_def.set_id))
    assert(member.treasure_id ~= nil and member.treasure_id ~= '', 'expected member treasure_id: ' .. tostring(set_def.set_id))
    assert(treasure_ids[member.treasure_id] ~= nil, 'expected member treasure to exist: ' .. tostring(member.treasure_id))
    assert(seen_member_orders[member.order_index] == nil, 'expected unique member order_index in set: ' .. tostring(set_def.set_id))
    assert(seen_member_ids[member.treasure_id] == nil, 'expected unique member treasure_id in set: ' .. tostring(set_def.set_id))
    seen_member_orders[member.order_index] = true
    seen_member_ids[member.treasure_id] = true
  end

  local seen_effect_orders = {}
  for _, effect in ipairs(set_def.effects) do
    assert(effect.order_index ~= nil and effect.order_index > 0, 'expected set effect order_index to be present: ' .. tostring(set_def.set_id))
    assert(effect.effect_type ~= nil and effect.effect_type ~= '', 'expected set effect_type: ' .. tostring(set_def.set_id))
    assert(seen_effect_orders[effect.order_index] == nil, 'expected unique set effect order_index: ' .. tostring(set_def.set_id))
    seen_effect_orders[effect.order_index] = true
  end

  assert(set_item_counts[set_def.set_id] == set_def.piece_count, 'expected set item count to match piece_count: ' .. tostring(set_def.set_id))
end

print('[OK] treasure catalog consistency smoke passed')

package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local CsvLoader = require 'data.csv_loader'
local attreffect = require 'data.tables.attreffect'
local marks = require 'data.tables.marks'

assert(type(marks) == 'table', 'marks should return a table')
assert(type(marks.list) == 'table', 'marks.list should be a table')
assert(type(attreffect.list) == 'table', 'attreffect.list should be a table')

local tag_rows = CsvLoader.read_rows('data_csv/mark_tags.csv')

assert(tag_rows[1] ~= nil and tag_rows[1].order_index ~= nil and tag_rows[1].order_index ~= '', 'expected mark_tags order_index')

local storm_effects = attreffect.by_source.mark and attreffect.by_source.mark['storm_mark']
assert(storm_effects ~= nil, 'expected storm_mark effect rows in attreffect')
assert(storm_effects.attack_skill['cooldown_reduction'] == 0.10, 'expected storm_mark cooldown reduction in attreffect')

local void_effects = attreffect.by_source.mark and attreffect.by_source.mark['void_mark']
assert(void_effects ~= nil, 'expected void_mark effect rows in attreffect')
assert(void_effects.runtime['skill_damage_bonus'] == 0.28, 'expected void_mark skill damage bonus in attreffect')
assert(void_effects.attack_skill['cooldown_reduction'] == 0.12, 'expected void_mark cooldown reduction in attreffect')

local void_mark = marks.by_id['void_mark']
assert(void_mark.bonuses.runtime['skill_damage_bonus'] == 0.28, 'expected marks object table to keep runtime bonus wiring')
assert(void_mark.bonuses.attack_skill['cooldown_reduction'] == 0.12, 'expected marks object table to keep attack_skill wiring')

local seen_mark_ids = {}
for _, mark in ipairs(marks.list) do
  assert(mark.id ~= nil and mark.id ~= '', 'expected mark id')
  assert(mark.order_index ~= nil and mark.order_index > 0, 'expected mark order_index')
  assert(seen_mark_ids[mark.id] == nil, 'expected unique mark id: ' .. tostring(mark.id))
  seen_mark_ids[mark.id] = true

  if mark.bonuses.attr ~= nil then
    for attr_name, value in pairs(mark.bonuses.attr) do
      assert(attr_name ~= nil and attr_name ~= '', 'expected attr bonus key: ' .. tostring(mark.id))
      assert(value ~= nil, 'expected attr bonus value: ' .. tostring(mark.id))
    end
  end

  if mark.bonuses.runtime ~= nil then
    for runtime_key, value in pairs(mark.bonuses.runtime) do
      assert(runtime_key ~= nil and runtime_key ~= '', 'expected runtime bonus key: ' .. tostring(mark.id))
      assert(value ~= nil, 'expected runtime bonus value: ' .. tostring(mark.id))
    end
  end

  if mark.bonuses.attack_skill ~= nil then
    for runtime_key, value in pairs(mark.bonuses.attack_skill) do
      assert(runtime_key ~= nil and runtime_key ~= '', 'expected attack_skill bonus key: ' .. tostring(mark.id))
      assert(value ~= nil, 'expected attack_skill bonus value: ' .. tostring(mark.id))
    end
  end

  local seen_tags = {}
  for _, tag in ipairs(mark.tags or {}) do
    assert(tag ~= nil and tag ~= '', 'expected mark tag: ' .. tostring(mark.id))
    assert(seen_tags[tag] == nil, 'expected unique mark tag: ' .. tostring(mark.id))
    seen_tags[tag] = true
  end
end

print('[OK] marks catalog consistency smoke passed')


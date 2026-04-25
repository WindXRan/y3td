package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local roster = require 'data.object_tables.hero_roster'
local skills = require 'data.object_tables.hero_form_skills'

assert(type(skills) == 'table', 'hero_form_skills module should return a table')
assert(type(skills.list) == 'table', 'hero_form_skills.list should be a table')
assert(type(skills.by_id) == 'table', 'hero_form_skills.by_id should be a table')
assert(type(skills.by_hero_id) == 'table', 'hero_form_skills.by_hero_id should be a table')
assert(#skills.list == 30, 'expected 30 hero form skills')

for _, entry in ipairs(roster.list) do
  local skill = skills.by_hero_id[entry.id]
  assert(skill ~= nil, string.format('hero %s should have matching hero form skill', tostring(entry.id)))
  assert(skill.hero_id == entry.id, string.format('hero skill %s should map back to hero %s', tostring(skill.id), tostring(entry.id)))
  assert(skill.rarity == entry.rarity, string.format('hero %s and skill %s should share rarity', tostring(entry.id), tostring(skill.id)))
  assert(skill.summary and skill.summary ~= '', string.format('hero skill %s should keep summary', tostring(skill.id)))
  assert(skill.item_desc and skill.item_desc ~= '', string.format('hero skill %s should keep item_desc', tostring(skill.id)))
  assert(skill.pattern and skill.pattern ~= '', string.format('hero skill %s should expose pattern', tostring(skill.id)))
  assert(skill.trigger_type and skill.trigger_type ~= '', string.format('hero skill %s should expose trigger_type', tostring(skill.id)))
end

local ur_skill = skills.by_id.tianmu_ji
assert(ur_skill ~= nil, 'tianmu_ji should exist')
assert(ur_skill.pattern == 'repeat_strikes', 'tianmu_ji should use repeat_strikes pattern')
assert(ur_skill.trigger_type == 'basic_attack', 'tianmu_ji should trigger from basic_attack')

local heal_skill = skills.by_id.qinglian_hu
assert(heal_skill ~= nil, 'qinglian_hu should exist')
assert(heal_skill.trigger_type == 'low_hp_interval', 'qinglian_hu should use low_hp_interval trigger')
assert(heal_skill.heal_ratio == 0.12, 'qinglian_hu should keep heal ratio')

print('hero form skills csv loader smoke ok')

package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local roster = require 'data.object_tables.hero_roster'

assert(type(roster) == 'table', 'hero_roster module should return a table')
assert(type(roster.list) == 'table', 'hero_roster.list should be a table')
assert(type(roster.by_id) == 'table', 'hero_roster.by_id should be a table')
assert(type(roster.by_unit_id) == 'table', 'hero_roster.by_unit_id should be a table')
assert(#roster.list == 30, 'expected 30 hero roster entries')

local rarity_counts = {
  R = 0,
  SR = 0,
  SSR = 0,
  UR = 0,
}
local seen_unit_ids = {}

for _, entry in ipairs(roster.list) do
  assert(type(entry.unit_id) == 'number', string.format('hero %s should expose numeric unit_id', tostring(entry.id)))
  assert(not seen_unit_ids[entry.unit_id], string.format('unit_id %s should not repeat in roster', tostring(entry.unit_id)))
  seen_unit_ids[entry.unit_id] = true
  assert(entry.skill_id and entry.skill_id ~= '', string.format('hero %s should expose skill_id', tostring(entry.id)))
  assert(rarity_counts[entry.rarity] ~= nil, string.format('hero %s should use supported rarity', tostring(entry.id)))
  rarity_counts[entry.rarity] = rarity_counts[entry.rarity] + 1
end

assert(rarity_counts.R == 12, 'expected 12 R heroes')
assert(rarity_counts.SR == 9, 'expected 9 SR heroes')
assert(rarity_counts.SSR == 6, 'expected 6 SSR heroes')
assert(rarity_counts.UR == 3, 'expected 3 UR heroes')

assert(roster.by_unit_id[100008] ~= nil, 'current war god evolution form should exist in hero roster')
assert(roster.by_unit_id[100009] ~= nil, 'current void evolution form should exist in hero roster')

print('hero roster csv loader smoke ok')

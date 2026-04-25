package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local CsvLoader = require 'data.csv_loader'

local rarity_rows = CsvLoader.read_rows('data_csv/treasure_compat_rarity_map.csv')
local duration_rows = CsvLoader.read_rows('data_csv/treasure_compat_duration_rules.csv')
local tag_rows = CsvLoader.read_rows('data_csv/treasure_compat_tag_rules.csv')
local runtime_key_rows = CsvLoader.read_rows('data_csv/treasure_compat_runtime_key_map.csv')

assert(#rarity_rows >= 3, 'expected treasure compat rarity map to be configured')
assert(#duration_rows >= 2, 'expected treasure compat duration rules to be configured')
assert(#tag_rows >= 2, 'expected treasure compat tag rules to be configured')
assert(#runtime_key_rows >= 3, 'expected treasure compat runtime key map to be configured')

assert(rarity_rows[1].source_rarity ~= nil and rarity_rows[1].source_rarity ~= '', 'expected rarity map source_rarity')
assert(rarity_rows[1].output_quality ~= nil and rarity_rows[1].output_quality ~= '', 'expected rarity map output_quality')
assert(rarity_rows[1].output_pool_weight ~= nil and rarity_rows[1].output_pool_weight ~= '', 'expected rarity map output_pool_weight')
assert(duration_rows[1].match_field ~= nil and duration_rows[1].match_field ~= '', 'expected duration rule match_field')
assert(duration_rows[1].match_value ~= nil and duration_rows[1].match_value ~= '', 'expected duration rule match_value')
assert(duration_rows[1].output_duration_type ~= nil and duration_rows[1].output_duration_type ~= '', 'expected duration rule output_duration_type')
assert(duration_rows[1].output_treasure_type ~= nil and duration_rows[1].output_treasure_type ~= '', 'expected duration rule output_treasure_type')
assert(tag_rows[1].match_field ~= nil and tag_rows[1].match_field ~= '', 'expected tag rule match_field')
assert(tag_rows[1].match_value ~= nil and tag_rows[1].match_value ~= '', 'expected tag rule match_value')
assert(tag_rows[1].output_tag ~= nil and tag_rows[1].output_tag ~= '', 'expected tag rule output_tag')
assert(runtime_key_rows[1].source_key ~= nil and runtime_key_rows[1].source_key ~= '', 'expected runtime key map source_key')
assert(runtime_key_rows[1].output_runtime_key ~= nil and runtime_key_rows[1].output_runtime_key ~= '', 'expected runtime key map output_runtime_key')

print('[OK] treasure compat rule tables smoke passed')

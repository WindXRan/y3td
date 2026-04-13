package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local CsvLoader = require 'data.csv_loader'

local bucket_rows = CsvLoader.read_rows('data_csv/treasure_compat_effect_bucket_rules.csv')

assert(#bucket_rows >= 5, 'expected treasure compat effect bucket rules to be configured')
assert(bucket_rows[1].match_effect_type ~= nil and bucket_rows[1].match_effect_type ~= '', 'expected effect bucket rule match_effect_type')
assert(bucket_rows[1].match_effect_key ~= nil and bucket_rows[1].match_effect_key ~= '', 'expected effect bucket rule match_effect_key')
assert(bucket_rows[1].output_bucket ~= nil and bucket_rows[1].output_bucket ~= '', 'expected effect bucket rule output_bucket')

print('[OK] treasure compat bucket rules smoke passed')

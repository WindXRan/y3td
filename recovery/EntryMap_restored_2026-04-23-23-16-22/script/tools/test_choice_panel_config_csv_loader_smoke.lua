package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.choice_panel_config'

assert(type(cfg) == 'table', 'choice_panel_config should return a table')
assert(type(cfg.refresh_costs) == 'table', 'refresh_costs should be a table')
assert(type(cfg.badge_text_by_quality) == 'table', 'badge_text_by_quality should be a table')

assert(cfg.refresh_costs[0] == 40, 'refresh cost for 0 paid refreshes should stay intact')
assert(cfg.refresh_costs[1] == 80, 'refresh cost for 1 paid refresh should stay intact')
assert(cfg.refresh_cost_default == 100, 'default refresh cost should stay intact')

assert(cfg.badge_text_by_quality.common == 'N', 'common badge text should stay intact')
assert(cfg.badge_text_by_quality.rare == 'R', 'rare badge text should stay intact')
assert(cfg.badge_text_by_quality.epic == 'E', 'epic badge text should stay intact')
assert(cfg.badge_text_by_quality.legendary == 'L', 'legendary badge text should stay intact')

print('choice_panel_config csv loader smoke ok')

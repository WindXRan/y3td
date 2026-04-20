package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local cfg = require 'data.object_tables.hero_attr_config'

assert(type(cfg.panel_default_attrs) == 'table', 'panel_default_attrs should be a table')
assert(type(cfg.hero_init_stats) == 'table', 'hero_init_stats should be a table')
assert(type(cfg.debug_hero_bonus_stats) == 'table', 'debug_hero_bonus_stats should be a table')
assert(type(cfg.panel_default_attrs['攻击白字']) == 'number', 'panel default attr should remain numeric')
assert(type(cfg.hero_init_stats['生命白字']) == 'number', 'hero init stat should remain numeric')
assert(type(cfg.hero_init_stats['攻击范围']) == 'number', 'hero init attack range should remain numeric')
assert(type(cfg.hero_init_stats['多重数量']) == 'number', 'hero init multishot count should remain numeric')
assert(type(cfg.hero_init_stats['弹射次数']) == 'number', 'hero init chain bounce count should remain numeric')
assert(type(cfg.debug_hero_bonus_stats['攻击范围']) == 'number', 'debug hero bonus stat should remain numeric')
assert(cfg.hero_init_stats['攻击白字'] == 46, 'hero init attack should stay intact')
assert(cfg.hero_init_stats['攻击范围'] == 2000, 'hero init attack range should stay intact')
assert(cfg.hero_init_stats['多重数量'] == 2, 'hero init multishot count should start at 2')
assert(cfg.hero_init_stats['弹射次数'] == 0, 'hero init chain bounce count should start at 0')
assert(cfg.debug_hero_bonus_stats['生命'] == 1400, 'debug hero bonus life should stay intact')

print('hero_attr_config csv loader smoke ok')

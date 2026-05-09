package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'

assert(ArchiveTabDefinitions.get_render_mode == nil, 'expected get_render_mode to be removed')

local cfg = ArchiveTabDefinitions.get_tab_render_config('英雄图鉴')
assert(type(cfg) == 'table', 'expected tab render config table')
assert(cfg.render_mode == nil, 'expected tab render config to stop exposing render_mode')

print('archive_tab_definitions render_mode removal smoke passed')

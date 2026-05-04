package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local ArchiveShop = require 'ui.outgame_archive_shop'

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', label or 'assert_eq', tostring(expected), tostring(actual)), 2)
  end
end

assert(type(ArchiveShop._build_owned_badge) == 'function', 'expected owned badge formatter')
assert(type(ArchiveShop._is_selected_spec) == 'function', 'expected selected spec helper')
assert(type(ArchiveShop._get_quality_style) == 'function', 'expected quality style helper')

local owned_badge = ArchiveShop._build_owned_badge({ owned_text = '已拥有' })
assert_eq(owned_badge.text, '已拥有', 'owned badge text')
assert_eq(owned_badge.owned, true, 'owned badge state')
assert_eq(owned_badge.color[1], 86, 'owned badge color')

local unowned_badge = ArchiveShop._build_owned_badge({ owned_text = '未拥有' })
assert_eq(unowned_badge.text, '未拥有', 'unowned badge text')
assert_eq(unowned_badge.owned, false, 'unowned badge state')
assert_eq(unowned_badge.color[1], 255, 'unowned badge color')

assert_eq(ArchiveShop._is_selected_spec({ archive_panel_shop_item = 'a' }, { key = 'a' }), true, 'selected spec')
assert_eq(ArchiveShop._is_selected_spec({ archive_panel_shop_item = 'a' }, { key = 'b' }), false, 'unselected spec')

local sr = ArchiveShop._get_quality_style('SR')
local ur = ArchiveShop._get_quality_style('UR')
assert_eq(sr.label, 'SR', 'sr quality label')
assert_eq(ur.label, 'UR', 'ur quality label')
assert(sr.text_color[1] ~= ur.text_color[1] or sr.text_color[2] ~= ur.text_color[2], 'expected distinct quality colors')

print('[shop_ui_state_test] ok')

package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local ShopItems = require 'data.tables.economy.shop_items'

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', label or 'assert_eq', tostring(expected), tostring(actual)), 2)
  end
end

local parse = ShopItems._parse_detail_blocks
assert(type(parse) == 'function', 'expected shop item detail block parser')

local blocks = parse('title=属性加成;body=全属性 +50\\n攻速 +10%;style=attr|title=来源;body=传说宝箱;style=normal')
assert_eq(#blocks, 2, 'block count')
assert_eq(blocks[1].title, '属性加成', 'block 1 title')
assert_eq(blocks[1].body, '全属性 +50\n攻速 +10%', 'block 1 body')
assert_eq(blocks[1].style, 'attr', 'block 1 style')
assert_eq(blocks[2].title, '来源', 'block 2 title')
assert_eq(blocks[2].body, '传说宝箱', 'block 2 body')
assert_eq(blocks[2].style, 'normal', 'block 2 style')

local escaped = parse('title=提示;body=A\\|B\\;C\\=D;style=warning')
assert_eq(#escaped, 1, 'escaped block count')
assert_eq(escaped[1].body, 'A|B;C=D', 'escaped body')
assert_eq(escaped[1].style, 'warning', 'escaped style')

local first = ShopItems.list[1]
assert(type(first.detail_blocks) == 'table' and #first.detail_blocks > 0, 'expected loaded shop items to expose detail_blocks')

print('[shop_detail_blocks_test] ok')

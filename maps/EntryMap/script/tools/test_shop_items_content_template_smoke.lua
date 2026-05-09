package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local ShopItems = require 'data.tables.economy.shop_items'

local target = nil
for _, spec in ipairs(ShopItems.list or {}) do
  if tostring(spec.title) == '御剑寒芒' then
    target = spec
    break
  end
end

assert(target ~= nil, 'expected shop item 御剑寒芒 to exist')
assert(target.content_template == '商品', 'expected 御剑寒芒 to expose content_template=商品 from CSV')
assert(target.render_mode == nil, 'expected 御剑寒芒 to stop exposing render_mode')

print('shop_items content_template smoke passed')

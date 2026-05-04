
local shop_items = require 'data.tables.economy.shop_items'

print('========== 商城数据诊断 ==========')
print('总条目数:', #shop_items.list)
print('一级页签数:', #shop_items.primary_tabs)
print('默认一级页签:', shop_items.primary_tab)

print('\n--- 所有一级页签 ---')
for i, tab in ipairs(shop_items.primary_tabs) do
  print(i .. '.', tab)
end

print('\n--- 每个一级页签对应的二级页签 ---')
for tab, cats in pairs(shop_items.categories_by_primary) do
  print(tab .. ':', table.concat(cats, ', '))
end

print('\n--- 前 20 个条目的详情 ---')
for i = 1, math.min(20, #shop_items.list) do
  local spec = shop_items.list[i]
  print(string.format('%d. %s [primary=%s, category=%s, partition=%s, source=%s]',
    i, spec.title, spec.primary, spec.category, spec.partition, spec.source))
end

print('\n--- 按来源统计 ---')
local source_stats = {}
for i, spec in ipairs(shop_items.list) do
  local source = spec.source or 'unknown'
  source_stats[source] = (source_stats[source] or 0) + 1
end
for source, count in pairs(source_stats) do
  print(source .. ': ' .. count .. '条')
end

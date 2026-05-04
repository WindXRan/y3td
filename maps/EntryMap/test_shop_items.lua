local ok, result = pcall(require, 'data.tables.economy.shop_items')
if ok then
  print('✓ shop_items.lua loaded successfully!')
  print('  Number of items:', #result.list)
  print('  Number of categories:', #result.categories)
else
  print('✗ shop_items.lua failed to load:')
  print('  ' .. tostring(result))
end
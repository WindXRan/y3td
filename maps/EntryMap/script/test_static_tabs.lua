
-- 静态页签测试脚本（CSV 配置版）
local print = print
local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'

print('=========================================')
print('CSV 页签配置测试')
print('=========================================')

-- 测试 0: 显示配置源
print('\n✅ 测试 0: 配置来源')
if ArchiveTabDefinitions._config then
  print('  配置已从 CSV 加载（或使用默认配置）')
end

-- 测试 1: 获取合法分区
print('\n✅ 测试 1: 合法分区')
local partitions = ArchiveTabDefinitions.get_valid_partitions()
for i, p in ipairs(partitions) do
  print(string.format('  %d. %s', i, p))
end

-- 测试 2: 获取合法一级页签
print('\n✅ 测试 2: 合法一级页签')
local primaries = ArchiveTabDefinitions.get_valid_primary_tabs()
for i, p in ipairs(primaries) do
  local default_partition = ArchiveTabDefinitions.get_default_partition_for_primary(p)
  print(string.format('  %d. %s (默认分区: %s)', i, p, default_partition))
end

-- 测试 3: 获取生涯页签
print('\n✅ 测试 3: 生涯页签')
local career_tabs = ArchiveTabDefinitions.get_career_tabs()
for i, p in ipairs(career_tabs) do
  print(string.format('  %d. %s', i, p))
end

-- 测试 4: 验证功能
print('\n✅ 测试 4: 验证功能')
local test_cases = {
  { type = 'partition', value = '商城', should_ok = true, desc = '有效分区' },
  { type = 'partition', value = '无效分区', should_ok = false, desc = '无效分区' },
  { type = 'primary', value = '商品', should_ok = true, desc = '有效一级页签' },
  { type = 'primary', value = '无效页签', should_ok = false, desc = '无效一级页签' },
}

for i, test in ipairs(test_cases) do
  local ok, err
  local context = string.format('测试 %d', i)
  if test.type == 'partition' then
    ok, err = ArchiveTabDefinitions.validate_partition(test.value, context)
  elseif test.type == 'primary' then
    ok, err = ArchiveTabDefinitions.validate_primary_tab(test.value, context)
  end

  local result = ok and '✅ 通过' or '❌ 失败'
  local expected_ok = test.should_ok and '应该通过' or '应该失败'
  print(string.format('  %s: %s "%s" - %s (%s)', result, test.desc, test.value, expected_ok, ok == test.should_ok and '匹配' or '不匹配'))
  if not ok and err then
    print(string.format('    错误信息: %s', err))
  end
end

-- 测试 5: 测试 shop_items 的加载
print('\n✅ 测试 5: 加载 shop_items 数据')
local ok, ShopItems = pcall(require, 'data.tables.economy.shop_items')
if ok then
  print(string.format('  加载成功! 共 %d 个商品', #ShopItems.list))
  print(string.format('  一级页签数量: %d', #ShopItems.primary_tabs))
  
  -- 打印一级页签
  print('  一级页签列表:')
  for i, tab in ipairs(ShopItems.primary_tabs) do
    print(string.format('    %d. %s', i, tab))
  end
  
  -- 检查验证错误
  if ShopItems.has_validation_errors then
    print(string.format('  ⚠️  发现 %d 个验证错误:', #ShopItems.validation_errors))
    for i, err in ipairs(ShopItems.validation_errors) do
      print(string.format('    %d. %s', i, err))
    end
  else
    print('  ✅ 无验证错误')
  end
else
  print(string.format('  ❌ 加载失败: %s', tostring(ShopItems)))
end

print('\n=========================================')
print('测试完成')
print('=========================================')

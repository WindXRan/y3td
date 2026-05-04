
local CsvLoader = require 'data.csv_loader'

print('========== 测试 CSV 加载器 ==========')
local rows = CsvLoader.read_rows_optional('data_csv/by_feature/economy/shangchengdaojv.csv')

print('CSV 总读取行数:', #rows)

if #rows > 0 then
  print('\n--- 第一行数据（索引 1）---')
  local first = rows[1]
  for k, v in pairs(first) do
    print(string.format('  %s: %q', k, v))
  end

  print('\n--- 前 10 行的 name 和 tab1 ---')
  for i = 1, math.min(10, #rows) do
    local row = rows[i]
    local name = row.name or ''
    local tab1 = row.tab1 or ''
    print(string.format('%d. name=%q, tab1=%q, partition=%q', i, name, tab1, row.partition))
  end

  print('\n--- 所有行的 tab1 统计 ---')
  local tab1_counts = {}
  for i, row in ipairs(rows) do
    local tab1 = row.tab1 or '(empty)'
    tab1_counts[tab1] = (tab1_counts[tab1] or 0) + 1
  end
  for tab1, count in pairs(tab1_counts) do
    print(string.format('  %q: %d条', tab1, count))
  end
end

print('\n--- 测试套装 CSV ---')
local suit_rows = CsvLoader.read_rows_optional('data_csv/by_feature/economy/suit_catalog.csv')
print('套装 CSV 行数:', #suit_rows)
if #suit_rows > 0 then
  print('第一行套装:')
  for k, v in pairs(suit_rows[1]) do
    print(string.format('  %s: %q', k, v))
  end
end

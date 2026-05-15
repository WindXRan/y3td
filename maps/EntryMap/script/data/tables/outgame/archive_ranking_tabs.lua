local CsvLoader = require 'data.csv_loader'

local M = {}

local function trim(value)
  local s = tostring(value or '')
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function to_bool(raw, default_value)
  local text = string.lower(trim(raw))
  if text == '' then
    return default_value == true
  end
  return text == '1' or text == 'true' or text == 'yes' or text == 'y'
end

local default_list = {
  { tab = 1, title = '战力排行榜', list_node = '排行榜列表_1', enabled = true },
  { tab = 2, title = '杀敌排行榜[N]', list_node = '排行榜列表_1_1', enabled = true },
  { tab = 3, title = '杀敌排行榜[R]', list_node = '排行榜列表_1_2', enabled = true },
}

local rows = CsvLoader.read_rows_optional({path = 'data_csv/outgame/outgame_archive_ranking_tabs.csv'})
local list = {}

for row_index, row in ipairs(rows) do
  if to_bool(row.enabled, true) then
    local tab = tonumber(row.tab) or tonumber(row.index) or row_index
    if tab and tab > 0 then
      list[#list + 1] = {
        tab = tab,
        title = trim(row.title),
        list_node = trim(row.list_node),
        enabled = true,
      }
    end
  end
end

if #list == 0 then
  list = default_list
end

table.sort(list, function(a, b)
  return (a.tab or 0) < (b.tab or 0)
end)

M.list = list
M.by_tab = {}
for _, entry in ipairs(list) do
  M.by_tab[entry.tab] = entry
end

return M

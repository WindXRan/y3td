package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'
local ShopItems = require 'data.tables.economy.shop_items'

local function count_primary(partition, primary)
  local count = 0
  for _, spec in ipairs(ShopItems.list or {}) do
    if tostring(spec.partition or '') == partition and tostring(spec.primary or '') == primary then
      count = count + 1
    end
  end
  return count
end

local function has_category(partition, primary, category)
  for _, spec in ipairs(ShopItems.list or {}) do
    if tostring(spec.partition or '') == partition and tostring(spec.primary or '') == primary then
      for _, one in ipairs(spec.categories or {}) do
        if one == category then
          return true
        end
      end
    end
  end
  return false
end

for _, primary in ipairs(ArchiveTabDefinitions.get_valid_primary_tabs()) do
  local partition = ArchiveTabDefinitions.get_default_partition_for_primary(primary)
  local primary_count = count_primary(partition, primary)
  assert(primary_count > 0, string.format('expected tab %s/%s to have content rows', partition, primary))

  for _, category in ipairs(ArchiveTabDefinitions.get_secondary_tabs_for_primary(primary)) do
    if category == '全部' then
      assert(primary_count > 0, string.format('expected tab %s/%s 全部 to have content rows', partition, primary))
    else
      assert(has_category(partition, primary, category), string.format('expected tab %s/%s/%s to have content rows', partition, primary, category))
    end
  end
end

print('archive tab content coverage smoke passed')

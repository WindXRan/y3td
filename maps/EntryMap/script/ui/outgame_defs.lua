local M = {}
local ShopItems = require 'data.tables.economy.shop_items'
local QualityImageTable = require 'data.tables.economy.quality_image_table'

local function build_outgame_detail_config(config)
  local table_config = config.outgame_detail_config or {}
  return {
    mode_details = table_config.mode_details or {},
    stage_details = table_config.stage_details or {},
  }
end

local function build_archive_shop_specs(shop_items)
  local list = {}
  local by_key = {}
  local primary_tabs = {}
  local primary_seen = {}
  local categories = {}
  local category_seen = {}
  local categories_by_primary = {}

  local function resolve_bg_by_quality(quality, fallback_bg)
    return QualityImageTable.get_frame_image(quality) or fallback_bg or shop_items.default_bg or 131166
  end

  local primary_order = { '商品', '仓库', '皮肤', '翅膀', '荣誉等级', '地图等级', '典藏积分' }

  local function classify_primary(spec)
    local configured_primary = tostring(spec.primary or '')
    if configured_primary ~= '' then
      return configured_primary
    end
    local title = tostring(spec.title or '')
    local category = tostring(spec.category or '')
    if title:find('皮肤', 1, true) or category:find('皮肤', 1, true) then
      return '皮肤'
    end
    if title:find('翅膀', 1, true) or category:find('翅膀', 1, true) then
      return '翅膀'
    end
    if title:find('荣誉', 1, true) or category:find('荣誉', 1, true) then
      return '荣誉等级'
    end
    if title:find('积分', 1, true) or category:find('积分', 1, true) then
      return '荣誉等级'
    end
    if title:find('地图等级', 1, true) or category:find('地图等级', 1, true) then
      return '地图等级'
    end
    return '商品'
  end

  local function normalize_category(spec)
    if type(spec.categories) == 'table' and #spec.categories > 0 then
      return tostring(spec.categories[1] or '全部')
    end
    local category = tostring(spec.category or '')
    return category ~= '' and category or '全部'
  end

  local function push_spec(spec)
    if not spec or not spec.key or by_key[spec.key] then
      return
    end
    local primary = classify_primary(spec)
    local category = normalize_category(spec)
    local category_list = (type(spec.categories) == 'table' and spec.categories) or { category }
    spec.primary = primary
    spec.category = category
    spec.categories = category_list
    spec.bg = spec.bg or resolve_bg_by_quality(spec.quality, shop_items.default_bg)
    spec.default_bg = spec.default_bg or shop_items.default_bg or 131166

    list[#list + 1] = spec
    by_key[spec.key] = spec

    if primary_seen[primary] ~= true then
      primary_seen[primary] = true
      primary_tabs[#primary_tabs + 1] = primary
    end

    categories_by_primary[primary] = categories_by_primary[primary] or {}
    local by_primary_seen = categories_by_primary[primary .. '__seen'] or {}
    for _, one in ipairs(category_list) do
      local c = tostring(one or '')
      if c ~= '' and by_primary_seen[c] ~= true then
        by_primary_seen[c] = true
        categories_by_primary[primary][#categories_by_primary[primary] + 1] = c
      end
      if c ~= '' and category_seen[c] ~= true then
        category_seen[c] = true
        categories[#categories + 1] = c
      end
    end
    categories_by_primary[primary .. '__seen'] = by_primary_seen
  end

  for _, spec in ipairs(shop_items.list or {}) do
    push_spec(spec)
  end

  local ordered_primary_tabs = {}
  local ordered_seen = {}
  for _, primary in ipairs(primary_order) do
    if primary_seen[primary] == true then
      ordered_primary_tabs[#ordered_primary_tabs + 1] = primary
      ordered_seen[primary] = true
    end
  end
  for _, primary in ipairs(primary_tabs) do
    if ordered_seen[primary] ~= true then
      ordered_primary_tabs[#ordered_primary_tabs + 1] = primary
    end
  end
  for key in pairs(categories_by_primary) do
    if tostring(key):sub(-6) == '__seen' then
      categories_by_primary[key] = nil
    end
  end

  return {
    list = list,
    by_key = by_key,
    primary_tabs = ordered_primary_tabs,
    categories = categories,
    categories_by_primary = categories_by_primary,
    primary_tab = ordered_primary_tabs[1] or '商品',
    default_icon = shop_items.default_icon or 906565,
  }
end

function M.create(config)
  local merged_shop = build_archive_shop_specs(ShopItems)
  return {
    archive_shop_item_specs = merged_shop.list,
    archive_shop_primary_tab = merged_shop.primary_tab,
    archive_shop_primary_tabs = merged_shop.primary_tabs or {},
    archive_shop_categories = merged_shop.categories,
    archive_shop_categories_by_primary = merged_shop.categories_by_primary or {},
    archive_shop_default_icon = merged_shop.default_icon,
    outgame_detail_config = build_outgame_detail_config(config),
  }
end

return M

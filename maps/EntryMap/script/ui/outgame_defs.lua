local M = {}
local ShopItems = require 'data.tables.economy.shop_items'
local QualityImageTable = require 'data.tables.economy.quality_image_table'
local GameTables = require 'data.game_tables'
local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'
local IconResolver = require 'data.tables.icon_resolver'

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function resolve_display_icon(...)
  return IconResolver.pick(...)
end

local function normalize_quality(value, fallback)
  local raw = trim(value)
  if raw == '' then
    return fallback or 'N'
  end
  local upper = string.upper(raw)
  if upper == 'N' or upper == 'R' or upper == 'SR' or upper == 'SSR' or upper == 'UR' then
    return upper
  end
  local lower = string.lower(raw)
  return ({
    common = 'N',
    rare = 'R',
    excellent = 'R',
    epic = 'SR',
    legendary = 'SSR',
  })[lower] or fallback or upper
end

local function compact_lines(...)
  local result = {}
  for index = 1, select('#', ...) do
    local line = select(index, ...)
    local text = trim(line)
    if text ~= '' then
      result[#result + 1] = text
    end
  end
  return result
end

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
  local categories = {}
  local categories_by_primary = {}

  local function resolve_bg_by_quality(quality, fallback_bg)
    return QualityImageTable.get_frame_image(quality) or fallback_bg or shop_items.default_bg or 131166
  end

  local primary_order = ArchiveTabDefinitions.get_valid_primary_tabs()

  local function classify_primary(spec)
    local configured_primary = tostring(spec.primary or '')
    if configured_primary ~= '' then
      return configured_primary
    end
    return primary_order[1] or '商品'
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
  end

  for _, spec in ipairs(shop_items.list or {}) do
    local primary = classify_primary(spec)
    if primary ~= '英雄图鉴' then
      push_spec(spec)
    end
  end

  for _, hero in ipairs((GameTables.hero_roster and GameTables.hero_roster.list) or {}) do
    local id = trim(hero.id)
    local name = trim(hero.name)
    if id ~= '' and name ~= '' then
      local quality = normalize_quality(hero.rarity, 'R')
      local hero_class = trim(hero.title)
      if hero_class == '' then
        hero_class = '全部'
      end
      local categories = { hero_class, '全部' }
      local hero_icon = tonumber(hero.icon) or tonumber(hero['图标']) or tonumber(hero['icon_id'])
      local hero_bg = tonumber(hero.bg) or tonumber(hero['底图']) or tonumber(hero['背景']) or tonumber(hero['背景图']) or tonumber(hero['BG'])
      push_spec({
        key = 'hero_catalog_' .. id,
        node = 'hero_catalog_' .. id,
        index = tonumber(hero.order_index) or 0,
        title = name,
        icon = resolve_display_icon(hero_icon, hero_bg, shop_items.default_icon, 906565),
        bg = hero_bg or resolve_bg_by_quality(quality, shop_items.default_bg),
        default_icon = resolve_display_icon(shop_items.default_icon, hero_bg, 906565),
        default_bg = shop_items.default_bg or 131166,
        attr_text = trim(hero.title),
        value_text = trim(hero.rarity),
        special_effect = trim(hero.summary),
        obtain = hero.is_initial_hero and '初始英雄' or '局内解锁或后续投放',
        owned_text = hero.is_initial_hero and '已解锁' or '未解锁',
        quality = quality,
        l1_tab = '英雄图鉴',
        l2_tab = quality,
        l2_tabs = categories,
        partition = '生涯',
        primary = '英雄图鉴',
        category = quality,
        categories = categories,
        attr_lines = compact_lines(
          trim(hero.title) ~= '' and ('定位：' .. trim(hero.title)) or nil,
          trim(hero.skill_id) ~= '' and ('技能：' .. trim(hero.skill_id)) or nil,
          hero.unit_id ~= nil and ('单位ID：' .. tostring(hero.unit_id)) or nil
        ),
        line_1 = trim(hero.title),
        line_2 = trim(hero.summary),
        line_3 = hero.is_initial_hero and '初始英雄' or '局内解锁或后续投放',
        source = 'hero_roster',
      })
    end
  end

  -- 所有一级页签和二级页签完全从 CSV 配表生成，不做任何自动补全
  for _, primary in ipairs(primary_order) do
    primary_tabs[#primary_tabs + 1] = primary
    local secondaries = ArchiveTabDefinitions.get_secondary_tabs_for_primary(primary)
    categories_by_primary[primary] = {}
    for _, sec in ipairs(secondaries) do
      categories_by_primary[primary][#categories_by_primary[primary] + 1] = sec
      categories[#categories + 1] = sec
    end
  end

  return {
    list = list,
    by_key = by_key,
    primary_tabs = primary_tabs,
    categories = categories,
    categories_by_primary = categories_by_primary,
    primary_tab = primary_order[1] or '商品',
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

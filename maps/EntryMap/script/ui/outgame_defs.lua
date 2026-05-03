local M = {}
local ShopItems = require 'data.tables.economy.shop_items'
local QualityImageTable = require 'data.tables.economy.quality_image_table'
local GameTables = require 'data.game_tables'
local BondNodes = require 'data.tables.bond.bond_nodes'
local BondModifierPool = require 'data.tables.bond.bond_modifier_pool'

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
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
    local primary = classify_primary(spec)
    if primary ~= '英雄图鉴' and primary ~= '羁绊图鉴' then
      push_spec(spec)
    end
  end

  for _, hero in ipairs((GameTables.hero_roster and GameTables.hero_roster.list) or {}) do
    local id = trim(hero.id)
    local name = trim(hero.name)
    if id ~= '' and name ~= '' then
      local quality = normalize_quality(hero.rarity, 'R')
      local categories = { quality, '全部' }
      local hero_icon = tonumber(hero.icon) or tonumber(hero['图标']) or tonumber(hero['icon_id'])
      local hero_bg = tonumber(hero.bg) or tonumber(hero['底图']) or tonumber(hero['背景']) or tonumber(hero['背景图']) or tonumber(hero['BG'])
      push_spec({
        key = 'hero_catalog_' .. id,
        node = 'hero_catalog_' .. id,
        index = tonumber(hero.order_index) or 0,
        title = name,
        icon = hero_icon or shop_items.default_icon or 906565,
        bg = hero_bg or resolve_bg_by_quality(quality, shop_items.default_bg),
        default_icon = shop_items.default_icon or 906565,
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
        render_mode = 'icon',
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

  local pushed_bond = {}
  local function push_bond_spec(spec)
    local id = trim(spec.id or spec.bond_name or spec.name)
    local title = trim(spec.display_name or spec.name or spec.bond_name)
    if id == '' or title == '' or pushed_bond[id] == true then
      return
    end
    pushed_bond[id] = true
    local quality = normalize_quality(spec.quality, 'SR')
    local category = trim(spec.archetype or spec.group_id or spec.trigger_kind or quality)
    if category == '' then
      category = quality
    end
    local categories = { category, quality, '全部' }
    local desc = trim((type(spec.desc) == 'table' and (spec.desc.single or spec.desc.advanced)) or spec.desc)
    local required_count = tonumber(spec.required_count) or tonumber(spec.tier) or nil
    local condition = required_count and ('集齐 ' .. tostring(required_count) .. ' 张同羁绊卡牌') or '局内收集同羁绊卡牌激活'
    local bond_icon = tonumber(spec.icon) or tonumber(spec['图标']) or tonumber(spec['icon_id'])
    local bond_bg = tonumber(spec.bg) or tonumber(spec['底图']) or tonumber(spec['背景']) or tonumber(spec['背景图']) or tonumber(spec['BG'])
    push_spec({
      key = 'bond_catalog_' .. id,
      node = 'bond_catalog_' .. id,
      index = tonumber(spec.index) or tonumber(spec.tier) or 0,
      title = title,
      icon = bond_icon or shop_items.default_icon or 906565,
      bg = bond_bg or resolve_bg_by_quality(quality, shop_items.default_bg),
      default_icon = shop_items.default_icon or 906565,
      default_bg = shop_items.default_bg or 131166,
      attr_text = condition,
      value_text = required_count and tostring(required_count) or '',
      special_effect = desc,
      obtain = condition,
      owned_text = '未激活',
      quality = quality,
      l1_tab = '羁绊图鉴',
      l2_tab = category,
      l2_tabs = categories,
      partition = '生涯',
      render_mode = 'icon',
      primary = '羁绊图鉴',
      category = category,
      categories = categories,
      attr_lines = compact_lines(
        '激活条件：' .. condition,
        spec.line_id and ('路线：' .. tostring(spec.line_id)) or nil,
        spec.group_id and ('分组：' .. tostring(spec.group_id)) or nil
      ),
      line_1 = condition,
      line_2 = desc,
      line_3 = condition,
      source = spec.source or 'bond_table',
    })
  end

  for _, node_id in ipairs((BondNodes and BondNodes.root_ids) or {}) do
    local node_def = BondNodes.by_id[node_id]
    if node_def then
      push_bond_spec(node_def)
    end
  end
  if next(pushed_bond) == nil then
    for _, effect in ipairs((BondModifierPool and BondModifierPool.activation_effects) or {}) do
      push_bond_spec({
        id = effect.id,
        bond_name = effect.bond_name,
        name = effect.name,
        desc = effect.desc,
        icon = effect.icon,
        bg = effect.bg,
        quality = effect.quality,
        required_count = effect.required_count,
        source = 'bond_modifier_pool',
      })
    end
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

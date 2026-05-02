local M = {}
local EquipmentCatalog = require 'data.tables.economy.equipment_catalog'
local ShopItems = require 'data.tables.economy.shop_items'
local Consumables = require 'data.tables.economy.consumables'
local QualityImageTable = require 'data.tables.economy.quality_image_table'

local function build_universal_specs()
  local specs = {
    pass = {
      { node = 'pass_badge_1', title = 'N难度通关奖励', line_1 = '累计通关可领取夺宝券。', line_2 = '当前用于查看通关奖励进度。', line_3 = '点击其它条目可切换详情。' },
      { node = 'pass_badge_2', title = 'R难度通关奖励', line_1 = '奖励随难度逐步提高。', line_2 = '通关后写入存档进度。', line_3 = '可作为赛季成长目标。' },
      { node = 'pass_badge_3', title = 'N难度累计通关', line_1 = '展示 N 难度通关次数。', line_2 = '用于核对夺宝券来源。', line_3 = '当前为存档预览条目。' },
      { node = 'pass_badge_4', title = 'R难度累计通关', line_1 = '展示 R 难度通关次数。', line_2 = '列表点击会刷新右侧详情。', line_3 = '未达成时显示为预览。' },
      { node = 'pass_badge_5', title = 'N/R阶段目标', line_1 = '高难度通关累计目标。', line_2 = '奖励内容可由配置表驱动。', line_3 = '适合展示阶段性奖励。' },
    },
    map = {
      { node = 'map_badge_1', title = '地图等级 1', line_1 = '地图等级提供基础成长奖励。', line_2 = '已接入列表点击详情。', line_3 = '后续可显示当前等级进度。' },
      { node = 'map_badge_2', title = '地图等级 2', line_1 = '提升地图等级解锁更多收益。', line_2 = '条目以列表形式展示。', line_3 = '点击可查看奖励说明。' },
      { node = 'map_badge_3', title = '地图等级 3', line_1 = '可放置等级礼包或属性。', line_2 = '未领取状态可继续扩展。', line_3 = '当前作为可点示例。' },
    },
    community = {
      { node = 'community_badge_1', title = '收藏奖励', line_1 = '社区行为奖励入口。', line_2 = '可展示收藏/关注状态。', line_3 = '点击条目查看详情。' },
      { node = 'community_badge_2', title = '分享奖励', line_1 = '分享活动奖励预览。', line_2 = '后续可接入活动存档。', line_3 = '当前为交互示例。' },
      { node = 'community_badge_3', title = '社群礼包', line_1 = '社群兑换类奖励。', line_2 = '适合显示礼包码状态。', line_3 = '点击会刷新右侧说明。' },
    },
    achievement = {
      { node = 'achievement_badge_1', title = '生涯首胜', line_1 = '首次通关任意难度。', line_2 = '达成后可领取成就奖励。', line_3 = '点击查看成就条件。' },
      { node = 'achievement_badge_2', title = '连胜挑战', line_1 = '连续胜利累计目标。', line_2 = '可用于长期目标展示。', line_3 = '当前显示预览数据。' },
      { node = 'achievement_badge_3', title = '资源大师', line_1 = '累计获得资源类成就。', line_2 = '后续可接入统计字段。', line_3 = '点击后切换详情。' },
    },
    lottery = {
      { node = 'lottery_badge_1', title = '幸运戒', line_1 = '群抽奖奖励池物品。', line_2 = '可通过口令或抽奖获得。', line_3 = '点击查看奖励说明。' },
      { node = 'lottery_badge_2', title = '强化石', line_1 = '常规抽奖材料。', line_2 = '用于装备成长。', line_3 = '当前展示为列表条目。' },
      { node = 'lottery_badge_3', title = '夺宝券', line_1 = '用于进入夺宝奖池。', line_2 = '通关和活动均可产出。', line_3 = '点击后刷新右侧详情。' },
    },
    test = {
      { node = 'test_badge_1', title = '测试礼包 A', line_1 = '测试大厅调试条目。', line_2 = '用于验证点击与详情刷新。', line_3 = '正式版可替换为活动奖励。' },
      { node = 'test_badge_2', title = '测试礼包 B', line_1 = '保留给调试流程。', line_2 = '不影响正式存档字段。', line_3 = '点击可确认交互可用。' },
    },
    fish = {
      { node = 'fish_feature_1', title = '小丑鱼图鉴', line_1 = '捕鱼模式图鉴条目。', line_2 = '可展示捕获次数与奖励。', line_3 = '点击切换右侧详情。' },
      { node = 'fish_feature_2', title = '海龟图鉴', line_1 = '稀有鱼类图鉴预览。', line_2 = '适合展示捕获条件。', line_3 = '后续可接入存档计数。' },
      { node = 'fish_feature_3', title = '宝箱鱼图鉴', line_1 = '特殊收益鱼类。', line_2 = '可展示掉落奖励。', line_3 = '当前为可点击示例。' },
    },
  }

  return specs
end

local function build_pool_specs()
  local specs = {}
  for index, item in ipairs(EquipmentCatalog.list or {}) do
    local item_key = item.id
    local tags = type(item.tags) == 'table' and table.concat(item.tags, ' / ') or ''
    specs[#specs + 1] = {
      node = string.format('equipment_%s', tostring(item_key or index)),
      item_key = item_key,
      title = item.name or tostring(item_key or index),
      glyph = tostring(index),
      cost = 100 + (index % 5) * 20,
      line_1 = item.summary or item.archetype or '装备图鉴物品。',
      line_2 = tags ~= '' and ('标签：' .. tags) or '已接入真实装备目录。',
    }
  end
  return specs
end

local function build_outgame_detail_config(config)
  local table_config = config.outgame_detail_config or {}
  local stage_details = table_config.stage_details or {}
  local mode_details = table_config.mode_details or {}

  return {
    mode_details = mode_details,
    stage_details = stage_details,
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

  local PRIMARY_ORDER = { '商品', '仓库', '皮肤', '翅膀', '荣誉等级', '地图等级', '典藏积分' }
  local function classify_primary(spec)
    local configured_primary = tostring(spec.primary or '')
    if configured_primary ~= '' then
      return configured_primary
    end
    local title = tostring(spec.title or '')
    local category = tostring(spec.category or '')
    local source = tostring(spec.source or '')
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
    local categories = spec.categories
    if type(categories) == 'table' and #categories > 0 then
      return tostring(categories[1] or '全部')
    end
    local category = tostring(spec.category or '')
    if category == '' then
      return '全部'
    end
    return category
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
    end
    categories_by_primary[primary .. '__seen'] = by_primary_seen
    for _, one in ipairs(category_list) do
      local c = tostring(one or '')
      if c ~= '' and category_seen[c] ~= true then
        category_seen[c] = true
        categories[#categories + 1] = c
      end
    end
  end

  for _, spec in ipairs(shop_items.list or {}) do
    spec.bg = spec.bg or resolve_bg_by_quality(spec.quality, shop_items.default_bg)
    spec.default_bg = spec.default_bg or shop_items.default_bg or 131166
    push_spec(spec)
  end
  for _, spec in ipairs(Consumables.list or {}) do
    push_spec({
      key = spec.key,
      node = spec.node or spec.key,
      index = spec.id or 0,
      title = spec.title,
      icon = spec.icon or shop_items.default_icon or 906565,
      bg = spec.bg or resolve_bg_by_quality(spec.quality, shop_items.default_bg),
      default_icon = shop_items.default_icon or 906565,
      default_bg = shop_items.default_bg or 131166,
      attr_text = '',
      value_text = '',
      special_effect = spec.special_effect or '',
      obtain = spec.obtain or '商城购买',
      owned_text = spec.owned_text or '未拥有',
      stackable = true,
      quality = spec.quality or 'N',
      primary = '仓库',
      category = '全部',
      attr_lines = spec.attr_lines or {},
      line_1 = spec.line_1 or '',
      line_2 = spec.line_2 or '',
      line_3 = spec.line_3 or '',
      source = 'consumables',
    })
  end

  local ordered_primary_tabs = {}
  local ordered_seen = {}
  for _, primary in ipairs(PRIMARY_ORDER) do
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

local function build_honor_level_specs_from_shop(shop_specs)
  local list = {}
  for _, spec in ipairs(shop_specs or {}) do
    if spec.primary == '典藏积分' or spec.primary == '荣誉等级' then
      list[#list + 1] = {
        key = spec.key,
        node = spec.node,
        level = tonumber(spec.index) or (#list + 1),
        title = spec.title,
        icon = spec.icon,
        quality = spec.quality,
        obtain = spec.obtain,
        extra_effect = spec.special_effect,
        initial_unlocked = tostring(spec.owned_text or '') == '已拥有',
        attr_lines = spec.attr_lines or {},
        line_1 = spec.line_1 or '',
        line_2 = spec.line_2 or '',
        line_3 = spec.line_3 or '',
        source = 'shop_item',
      }
    end
  end
  table.sort(list, function(a, b)
    return (a.level or 0) < (b.level or 0)
  end)
  return list
end

function M.create(config)
  local merged_shop = build_archive_shop_specs(ShopItems)
  local honor_level_specs = build_honor_level_specs_from_shop(merged_shop.list)
  return {
    stage_list = config.stages and config.stages.list or {},
    stages_by_id = config.stages and config.stages.by_id or {},
    modes_by_id = config.stage_modes and config.stage_modes.by_id or {},
    save_slot = config.save_slots and config.save_slots.outgame_profile or 1,
    attr_bonus_by_stage_mode = config.outgame_attr_bonus_config and config.outgame_attr_bonus_config.by_stage_mode or {},
    stage_page_size = 7,
    single_mode_id = 'standard',
    single_mode_label = '主线模式',
    view_mode_mainline = 'mainline',
    view_mode_cultivation = 'cultivation',
    daily_task_defs = {
      { key = 'clear_any_1', title = '首次通关任意难度', reward = '奖励：金币+500', target = 1 },
      { key = 'clear_any_3', title = '通关3次任意难度', reward = '奖励：强化石+3', target = 3 },
      { key = 'online_60', title = '累计在线60分钟', reward = '奖励：木材+30', target = 60 },
      { key = 'online_120', title = '累计在线120分钟', reward = '奖励：泡点+300', target = 120 },
      { key = 'online_300', title = '累计在线300分钟', reward = '奖励：重铸石+3', target = 300 },
    },
    color = {
      selected_bg = { 84, 138, 226, 255 },
      selected_text = { 245, 248, 255, 255 },
      available_bg = { 40, 58, 92, 236 },
      available_text = { 220, 232, 246, 255 },
      locked_bg = { 34, 38, 48, 214 },
      locked_text = { 164, 172, 186, 255 },
      cleared_bg = { 58, 100, 82, 232 },
      cleared_text = { 232, 246, 238, 255 },
      start_ready_bg = { 82, 132, 96, 236 },
      start_locked_bg = { 58, 62, 72, 214 },
    },
    archive_page_keys = { 'profile', 'equipment', 'universal', 'chest', 'pool' },
    archive_page_panel_names = {
      profile = 'ArchivePageProfile',
      equipment = 'ArchivePageEquipment',
      universal = 'ArchivePageUniversal',
      chest = 'ArchivePageChest',
      pool = 'ArchivePagePool',
    },
    archive_menu_specs = {
      { key = 'profile', page_key = 'profile', visible = true },
      { key = 'universal', page_key = 'universal', visible = true },
      { key = 'chest', page_key = 'chest', visible = true },
      { key = 'club', page_key = nil, visible = true },
      { key = 'equipment', page_key = 'equipment', visible = true },
      { key = 'hero', page_key = nil, visible = true },
      { key = 'beast', page_key = nil, visible = true },
      { key = 'skin', page_key = nil, visible = true },
      { key = 'shop', page_key = 'shop', visible = true },
      { key = 'heirloom', page_key = nil, visible = true },
    },
    archive_universal_keys = { 'pass', 'map', 'community', 'achievement', 'lottery', 'test', 'fish' },
    archive_universal_item_specs = build_universal_specs(),
    archive_universal_tab_labels = {
      pass = '通关',
      map = '地图',
      community = '社区',
      achievement = '成就',
      lottery = '抽奖',
      test = '测试',
      fish = '捕鱼',
    },
    honor_level_specs = honor_level_specs,
    archive_pool_item_specs = build_pool_specs(),
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

local CsvLoader = require 'data.csv_loader'

local M = {}

local function trim(value)
  local s = tostring(value or '')
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function is_placeholder(raw)
  local text = string.lower(trim(raw))
  return text == 'string' or text == 'number' or text == 'bool' or text == '__字段说明__'
end

local QUALITY_KEYS = {
  N = true,
  R = true,
  SR = true,
  SSR = true,
  UR = true,
  UB = true,
}

local function resolve_shop_tab_label(row)
  local second = trim(row['二级页签'])
  if second ~= '' and not is_placeholder(second) and QUALITY_KEYS[second] ~= true then
    return second
  end
  -- 历史兼容：旧表把实际“二级分类”写在三级页签，这里只做降级读取兼容。
  local third = trim(row['三级页签'])
  if third ~= '' and not is_placeholder(third) then
    return third
  end
  return ''
end

local function to_bool(raw, default_value)
  local text = string.lower(trim(raw))
  if text == '' then
    return default_value == true
  end
  return text == '1' or text == 'true' or text == 'yes' or text == 'y'
end

local default_entries = {
  { key = 'honor_level', node = '生涯.称号', l1_tab = '生涯', l2_tab = '荣誉等级', label_node = 'label', label = '荣誉等级', value_node = nil, value_source = nil, action = 'open_archive_honor_level', order_index = 10 },
  { key = 'map_level', node = '商城.地图等级', l1_tab = '商城', l2_tab = '地图等级', label_node = 'label', label = '地图等级', value_node = 'bg.lv', value_source = 'map_level', action = 'open_archive_map_level', order_index = 40 },
  { key = 'shop', node = '商城.商城1', l1_tab = '商城', l2_tab = '商品', label_node = 'label', label = '商城', value_node = nil, value_source = nil, action = 'open_archive_shop', order_index = 50 },
  { key = 'warehouse', node = '存档.仓库', l1_tab = '存档', l2_tab = '仓库', label_node = 'label', label = '仓库', value_node = nil, value_source = nil, action = 'open_archive_warehouse', order_index = 60 },
}

local function read_shop_rows()
  local rows = CsvLoader.read_rows_optional('data_csv/outgame/economy/shangchengdaojv.csv')
  if #rows > 0 then
    return rows
  end
  return CsvLoader.read_rows_optional('data_csv/by_feature/economy/shangchengdaojv.csv')
end

local function read_career_title_rows()
  return CsvLoader.read_rows_optional('data_csv/outgame/shengya_chenghao.csv')
end

local function read_career_achievement_rows()
  return CsvLoader.read_rows_optional('data_csv/outgame/shengya_chengjiu.csv')
end

local function read_career_hero_rows()
  return CsvLoader.read_rows_optional('data_csv/outgame/shengya_yingxiongtujian.csv')
end

local function read_career_bond_rows()
  return CsvLoader.read_rows_optional('data_csv/outgame/shengya_jibantujian.csv')
end

local function build_from_shop_csv()
  local rows = read_shop_rows()
  local entries = {}
  local has_honor = false
  local has_map = false

  for _, row in ipairs(rows) do
    local l2 = resolve_shop_tab_label(row)
    if l2 == '荣誉等级' or l2 == '典藏积分' then
      has_honor = true
    elseif l2 == '地图等级' then
      has_map = true
    end
  end

  if has_honor then
    entries[#entries + 1] = {
      key = 'honor_level',
      node = '生涯.称号',
      tab1 = '生涯',
      tab2 = '荣誉等级',
      l1_tab = '生涯',
      l2_tab = '荣誉等级',
      label_node = 'label',
      label = '荣誉等级',
      value_node = nil,
      value_source = nil,
      action = 'open_archive_honor_level',
      order_index = 10,
    }
  end
  if #read_career_title_rows() > 0 then
    entries[#entries + 1] = {
      key = 'career_title',
      node = '生涯.称号',
      tab1 = '生涯',
      tab2 = '称号',
      l1_tab = '生涯',
      l2_tab = '称号',
      label_node = 'label',
      label = '称号',
      value_node = nil,
      value_source = nil,
      action = 'open_archive_honor_level',
      order_index = 12,
    }
  end
  if #read_career_achievement_rows() > 0 then
    entries[#entries + 1] = {
      key = 'career_achievement',
      node = '生涯.成就',
      tab1 = '生涯',
      tab2 = '成就',
      l1_tab = '生涯',
      l2_tab = '成就',
      label_node = 'label',
      label = '成就',
      value_node = nil,
      value_source = nil,
      action = 'open_archive_career',
      order_index = 14,
    }
  end
  if #read_career_hero_rows() > 0 then
    entries[#entries + 1] = {
      key = 'career_hero_album',
      node = '生涯.英雄图鉴',
      tab1 = '生涯',
      tab2 = '英雄图鉴',
      l1_tab = '生涯',
      l2_tab = '英雄图鉴',
      label_node = 'label',
      label = '英雄图鉴',
      value_node = nil,
      value_source = nil,
      action = 'open_archive_hero_album',
      order_index = 16,
    }
  end
  if #read_career_bond_rows() > 0 then
    entries[#entries + 1] = {
      key = 'career_bond_album',
      node = '生涯.羁绊图鉴',
      tab1 = '生涯',
      tab2 = '羁绊图鉴',
      l1_tab = '生涯',
      l2_tab = '羁绊图鉴',
      label_node = 'label',
      label = '羁绊图鉴',
      value_node = nil,
      value_source = nil,
      action = 'open_archive_album',
      order_index = 18,
    }
  end
  if has_map then
    entries[#entries + 1] = {
      key = 'map_level',
      node = '商城.地图等级',
      tab1 = '商城',
      tab2 = '地图等级',
      l1_tab = '商城',
      l2_tab = '地图等级',
      label_node = 'label',
      label = '地图等级',
      value_node = 'bg.lv',
      value_source = 'map_level',
      action = 'open_archive_map_level',
      order_index = 40,
    }
  end

  -- 无论 csv 命中如何，保证存档/生涯/商城最小分区都存在，避免页签缺失。
  if #entries <= 0 then
    entries[#entries + 1] = {
      key = 'honor_level',
      node = '生涯.称号',
      l1_tab = '生涯',
      l2_tab = '荣誉等级',
      label_node = 'label',
      label = '荣誉等级',
      value_node = nil,
      value_source = nil,
      action = 'open_archive_honor_level',
      order_index = 10,
    }
  end

  local shop_l2_seen = {}
  local shop_rows = read_shop_rows()
  local order = 50
  for _, row in ipairs(shop_rows) do
    local l2 = resolve_shop_tab_label(row)
    if l2 ~= '' and shop_l2_seen[l2] ~= true then
      shop_l2_seen[l2] = true
      local action = 'open_archive_shop'
      local node = '商城.商城1'
      local value_node = nil
      local value_source = nil
      if l2 == '典藏积分' then
        action = 'open_archive_collection_score'
        node = '商城.典藏积分'
        value_node = 'bg.num'
        value_source = 'archive_pool_score'
      elseif l2 == '地图等级' then
        action = 'open_archive_map_level'
        node = '商城.地图等级'
        value_node = 'bg.lv'
        value_source = 'map_level'
      end
      entries[#entries + 1] = {
        key = 'shop_' .. tostring(order),
        node = node,
        tab1 = '商城',
        tab2 = l2,
        l1_tab = '商城',
        l2_tab = l2,
        label_node = 'label',
        label = l2,
        value_node = value_node,
        value_source = value_source,
        action = action,
        order_index = order,
      }
      order = order + 1
    end
  end

  -- 保底：如果商城配表空，仍给一个商品入口。
  if next(shop_l2_seen) == nil then
    entries[#entries + 1] = {
      key = 'shop',
      node = '商城.商城1',
      tab1 = '商城',
      tab2 = '商品',
      l1_tab = '商城',
      l2_tab = '商品',
      label_node = 'label',
      label = '商城',
      value_node = nil,
      value_source = nil,
      action = 'open_archive_shop',
      order_index = 50,
    }
  end

  entries[#entries + 1] = {
    key = 'warehouse',
    node = '存档.仓库',
    tab1 = '存档',
    tab2 = '仓库',
    l1_tab = '存档',
    l2_tab = '仓库',
    label_node = 'label',
    label = '仓库',
    value_node = nil,
    value_source = nil,
    action = 'open_archive_warehouse',
    order_index = 60,
  }

  return entries
end

local function build_from_archive_content_csv()
  local rows = CsvLoader.read_rows_optional('data_csv/outgame/archive_content_items.csv')
  local entries = {}
  for row_index, row in ipairs(rows) do
    if to_bool(row.enabled, true) then
      local key = trim(row.key or row['键'])
      local node = trim(row.node or row['节点'])
      local l1_tab = trim(row['一级页签'] or row.l1_tab or row.section)
      local l2_tab = trim(row['二级页签'] or row.l2_tab or row.category)
      if key ~= '' and node ~= '' then
        entries[#entries + 1] = {
          key = key,
          node = node,
          tab1 = l1_tab,
          tab2 = l2_tab,
          l1_tab = l1_tab,
          l2_tab = l2_tab,
          label_node = trim(row.label_node),
          label = trim(row.label),
          value_node = trim(row.value_node) ~= '' and trim(row.value_node) or nil,
          value_source = trim(row.value_source) ~= '' and trim(row.value_source) or nil,
          action = trim(row.action) ~= '' and trim(row.action) or nil,
          order_index = tonumber(row.order_index) or row_index,
        }
      end
    end
  end
  return entries
end

local entries = build_from_shop_csv()
if #entries == 0 then
  entries = build_from_archive_content_csv()
end
if #entries == 0 then
  entries = default_entries
end

table.sort(entries, function(a, b)
  local ao = tonumber(a.order_index) or 0
  local bo = tonumber(b.order_index) or 0
  if ao == bo then
    return tostring(a.key or '') < tostring(b.key or '')
  end
  return ao < bo
end)

M.entries = entries
M.by_key = {}
for _, entry in ipairs(M.entries) do
  M.by_key[entry.key] = entry
end

return M

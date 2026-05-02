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

local function read_shop_rows()
  local rows = CsvLoader.read_rows_optional('data_csv/outgame/economy/shangchengdaojv.csv')
  if #rows > 0 then
    return rows
  end
  return CsvLoader.read_rows_optional('data_csv/by_feature/economy/shangchengdaojv.csv')
end

local function build_from_shop_csv()
  local rows = read_shop_rows()
  local list = {}
  local seen = {}

  local function push(entry)
    local dedup_key = table.concat({
      tostring(entry.l1_key or ''),
      tostring(entry.l2_key or ''),
      tostring(entry.action or ''),
    }, '#')
    if seen[dedup_key] == true then
      return
    end
    seen[dedup_key] = true
    list[#list + 1] = entry
  end

  for _, row in ipairs(rows) do
    local l2 = resolve_shop_tab_label(row)
    if l2 ~= '' then
      if l2 == '荣誉等级' or l2 == '典藏积分' then
        push({
          l0_key = 'archive_root',
          l0_title = '存档生涯商城',
          l1_key = 'career',
          l1_title = '生涯',
          l2_key = 'honor_level',
          l2_title = '荣誉等级',
          action = 'open_archive_honor_level',
          section = 'career',
          shop_primary = '',
          shop_category = '',
          order_index = 20,
        })
      elseif l2 == '地图等级' then
        push({
          l0_key = 'archive_root',
          l0_title = '存档生涯商城',
          l1_key = 'shop',
          l1_title = '商城',
          l2_key = 'map_level',
          l2_title = '地图等级',
          action = 'open_archive_map_level',
          section = 'shop',
          shop_primary = '地图等级',
          shop_category = '',
          order_index = 50,
        })
      end
    end
  end

  -- 保底页签：始终存在存档/商城，避免分区缺失。
  push({
    l0_key = 'archive_root',
    l0_title = '存档生涯商城',
    l1_key = 'archive',
    l1_title = '存档',
    l2_key = 'warehouse',
    l2_title = '仓库',
    action = 'open_archive',
    section = 'archive',
    shop_primary = '',
    shop_category = '',
    order_index = 10,
  })
  push({
    l0_key = 'archive_root',
    l0_title = '存档生涯商城',
    l1_key = 'shop',
    l1_title = '商城',
    l2_key = 'goods',
    l2_title = '商品',
    action = 'open_archive_shop',
    section = 'shop',
    shop_primary = '商品',
    shop_category = '',
    order_index = 30,
  })
  -- 保底补一个生涯入口，避免“生涯”无二级页签。
  push({
    l0_key = 'archive_root',
    l0_title = '存档生涯商城',
    l1_key = 'career',
    l1_title = '生涯',
    l2_key = 'honor_level',
    l2_title = '荣誉等级',
    action = 'open_archive_honor_level',
    section = 'career',
    shop_primary = '',
    shop_category = '',
    order_index = 20,
  })

  table.sort(list, function(a, b)
    local ao = tonumber(a.order_index) or 0
    local bo = tonumber(b.order_index) or 0
    if ao == bo then
      return tostring(a.action or '') < tostring(b.action or '')
    end
    return ao < bo
  end)
  return list
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

local function build_from_archive_tabs_csv()
  local rows = CsvLoader.read_rows_optional('data_csv/outgame/archive_tabs.csv')
  local list = {}
  for row_index, row in ipairs(rows) do
    if to_bool(row.enabled, true) then
      list[#list + 1] = {
        l0_key = trim(row.l0_key),
        l0_title = trim(row.l0_title),
        l1_key = trim(row.l1_key),
        l1_title = trim(row.l1_title),
        l2_key = trim(row.l2_key),
        l2_title = trim(row.l2_title),
        action = trim(row.action),
        section = trim(row.section),
        shop_primary = trim(row.shop_primary),
        shop_category = trim(row.shop_category),
        order_index = tonumber(row.order_index) or row_index,
      }
    end
  end
  table.sort(list, function(a, b)
    local ao = tonumber(a.order_index) or 0
    local bo = tonumber(b.order_index) or 0
    if ao == bo then
      return tostring(a.action or '') < tostring(b.action or '')
    end
    return ao < bo
  end)
  return list
end

local list = build_from_shop_csv()
if #list > 0 then
  local seen = {}
  for _, entry in ipairs(list) do
    seen[(entry.action or '') .. '#' .. (entry.shop_primary or '')] = true
  end
  local function add_career_tab(l2_title, action, order_index)
    local key = action .. '#career#' .. l2_title
    if seen[key] == true then
      return
    end
    seen[key] = true
    list[#list + 1] = {
      l0_key = 'archive_root',
      l0_title = '存档生涯商城',
      l1_key = 'career',
      l1_title = '生涯',
      l2_key = 'career_' .. tostring(#list + 1),
      l2_title = l2_title,
      action = action,
      section = 'career',
      shop_primary = '',
      shop_category = '',
      order_index = order_index,
    }
  end
  if #read_career_title_rows() > 0 then
    add_career_tab('称号', 'open_archive_honor_level', 22)
  end
  if #read_career_achievement_rows() > 0 then
    add_career_tab('成就', 'open_archive_career', 24)
  end
  if #read_career_hero_rows() > 0 then
    add_career_tab('英雄图鉴', 'open_archive_hero_album', 26)
  end
  if #read_career_bond_rows() > 0 then
    add_career_tab('羁绊图鉴', 'open_archive_album', 28)
  end

  local shop_rows = read_shop_rows()
  local order = 100
  for _, row in ipairs(shop_rows) do
    local l2 = resolve_shop_tab_label(row)
    if l2 ~= '' then
      local action = 'open_archive_shop'
      if l2 == '典藏积分' then
        action = 'open_archive_collection_score'
      elseif l2 == '地图等级' then
        action = 'open_archive_map_level'
      end
      local key = action .. '#' .. l2
      if seen[key] ~= true then
        seen[key] = true
        list[#list + 1] = {
          l0_key = 'archive_root',
          l0_title = '存档生涯商城',
          l1_key = 'shop',
          l1_title = '商城',
          l2_key = 'shop_' .. tostring(#list + 1),
          l2_title = l2,
          action = action,
          section = 'shop',
          shop_primary = l2,
          shop_category = '',
          order_index = order,
        }
        order = order + 1
      end
    end
  end
  table.sort(list, function(a, b)
    local ao = tonumber(a.order_index) or 0
    local bo = tonumber(b.order_index) or 0
    if ao == bo then
      return tostring(a.action or '') < tostring(b.action or '')
    end
    return ao < bo
  end)
end
if #list == 0 then
  list = build_from_archive_tabs_csv()
end

M.list = list
M.by_action = {}
for _, entry in ipairs(list) do
  if entry.action ~= '' then
    M.by_action[entry.action] = entry
  end
end

return M

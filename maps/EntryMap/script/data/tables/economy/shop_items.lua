local EditorJsonTable = require 'data.tables.editor_json_table'
local CsvLoader = require 'data.csv_loader'
local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'
local TipBlockStyle = require 'data.tables.tip_block_style'

local M = {}

local DEFAULT_ICON = 906565
local DEFAULT_BG = 131166

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function is_placeholder_text(value)
  local text = string.lower(trim(value))
  if text == '' then
    return false
  end
  return text == 'string'
    or text == 'number'
    or text == 'int'
    or text == 'float'
    or text == 'bool'
    or text == 'boolean'
    or text == 'table'
    or text == 'any'
end

local function split_pipe(value)
  local result = {}
  for part in tostring(value or ''):gmatch('[^|]+') do
    result[#result + 1] = trim(part)
  end
  return result
end

local PERCENT_ATTR_KEYWORDS = {
  '加成',
  '增幅',
  '伤害',
  '减免',
  '暴率',
  '暴伤',
  '暴击',
  '攻速',
  '速度',
  '概率',
  '几率',
  '收益',
  '效果',
}
local function is_percent_attr(attr_name)
  local name = tostring(attr_name or '')
  for _, keyword in ipairs(PERCENT_ATTR_KEYWORDS) do
    if name:find(keyword, 1, true) then
      return true
    end
  end
  return false
end

local function format_attr_value(attr_name, value_text)
  local text = trim(value_text)
  if text == '' then
    return text
  end
  if text:find('%%', 1, true) then
    return text
  end
  if is_percent_attr(attr_name) then
    return text .. '%'
  end
  return text
end

local function build_attr_lines(attr_text, value_text)
  local attrs = split_pipe(attr_text)
  local values = split_pipe(value_text)
  local lines = {}
  for index, attr_name in ipairs(attrs) do
    local value = format_attr_value(attr_name, values[index] or '')
    if attr_name ~= '' then
      lines[#lines + 1] = value ~= '' and string.format('%s +%s', attr_name, value) or attr_name
    end
  end
  return lines
end

local list = {}
local by_key = {}
local categories = {}
local category_seen = {}
local primary_tabs = {}
local primary_seen = {}
local categories_by_primary = {}
local category_seen_by_primary = {}

local function resolve_primary_tab(row)
  return trim(row.tab1 or row['一级页签'] or row['一级页签 '] or row['一级标签'] or row['一级分类'])
end

local function to_number_or_nil(value)
  local num = tonumber(value)
  if num and num > 0 then
    return num
  end
  return nil
end

local function read_first_number(row, keys)
  for _, key in ipairs(keys or {}) do
    local value = row[key]
    local num = to_number_or_nil(value)
    if num then
      return num
    end
  end
  return nil
end

local function parse_icon_bg_from_image_field(value)
  local text = trim(value)
  if text == '' then
    return nil, nil
  end
  local left, right = text:match('^(%d+)%s*[|,/%s]%s*(%d+)$')
  if left and right then
    return tonumber(left), tonumber(right)
  end
  local single = tonumber(text)
  if single and single > 0 then
    return single, nil
  end
  return nil, nil
end

local function resolve_secondary_tab(row)
  local raw = trim(row.tab2 or row['二级页签'] or row['页签'] or row['二级标签'] or row['二级分类'])
  if is_placeholder_text(raw) then
    return ''
  end
  return raw
end

local function collect_secondary_tabs(row)
  local list = {}
  local seen = {}
  local function push(raw)
    local v = trim(raw)
    if v == '' or is_placeholder_text(v) or seen[v] == true then
      return
    end
    seen[v] = true
    list[#list + 1] = v
  end
  -- 兼容旧字段：tab2 可用 | 分隔
  local raw_tab2 = resolve_secondary_tab(row)
  for part in tostring(raw_tab2 or ''):gmatch('[^|]+') do
    push(part)
  end
  -- 新字段：两个独立的二级页签
  push(row.tab2_a or row['tab2_a'] or row['二级页签A'] or row['二级页签a'] or row['二级页签_1'])
  push(row.tab2_b or row['tab2_b'] or row['二级页签B'] or row['二级页签b'] or row['二级页签_2'])
  return list
end

local function resolve_legacy_third_tab(row)
  local raw = trim(row.tab3 or row['三级页签'] or row['三级标签'] or row['三级分类'])
  if is_placeholder_text(raw) then
    return ''
  end
  return raw
end

local function normalize_tab1(raw)
  local value = trim(raw)
  if value == '' then
    return ArchiveTabDefinitions.get_valid_primary_tabs()[1] or '商品'
  end
  return value
end

local function normalize_tab2(raw)
  local value = trim(raw)
  if value == '' or is_placeholder_text(value) then
    return ''
  end
  return value
end

local function normalize_partition(raw_partition, tab1)
  local value = trim(raw_partition)
  local valid_partitions = ArchiveTabDefinitions.get_valid_partitions()
  for _, p in ipairs(valid_partitions) do
    if value == p then
      return value
    end
  end
  return ArchiveTabDefinitions.get_default_partition_for_primary(tab1)
end

local function normalize_content_template(raw)
  local value = trim(raw)
  if value == '' or is_placeholder_text(value) then
    return ''
  end
  return value
end

local function resolve_shop_tab1(row)
  local raw = resolve_primary_tab(row)
  if raw == '' or is_placeholder_text(raw) then
    return ArchiveTabDefinitions.get_valid_primary_tabs()[1] or '商品'
  end
  return normalize_tab1(raw)
end

local function split_tab2_list_from_row(row)
  local result = {}
  local seen = {}
  local source_tabs = collect_secondary_tabs(row)
  for _, raw in ipairs(source_tabs) do
    local one = normalize_tab2(raw)
    if one ~= '' and seen[one] ~= true then
      seen[one] = true
      result[#result + 1] = one
    end
  end
  -- 历史兼容：旧表把“实际二级分类”写在三级页签
  if #result == 0 then
    local legacy = normalize_tab2(resolve_legacy_third_tab(row))
    if legacy ~= '' then
      result[1] = legacy
    end
  end
  return result
end

local function append_source_rows(target, table_name, fallback_primary)
  local rows = EditorJsonTable.read_rows(table_name)
  for index, row in ipairs(rows or {}) do
    target[#target + 1] = {
      row = row,
      table_name = table_name,
      row_index = index,
      fallback_primary = fallback_primary,
    }
  end
end

local function append_csv_rows(target, csv_path, source_name, fallback_primary)
  local rows = CsvLoader.read_rows_optional({path = csv_path})
  for index, row in ipairs(rows or {}) do
    target[#target + 1] = {
      row = row,
      table_name = source_name,
      row_index = index,
      fallback_primary = fallback_primary,
    }
  end
end

local source_rows = {}
append_csv_rows(source_rows, 'data_csv/by_feature/economy/shangchengdaojv.csv', 'csv_shangchengdaojv_feature', ArchiveTabDefinitions.get_valid_primary_tabs()[1] or '商品')
-- 统一单源：商城数据只从 CSV 读取，避免旧编辑器表结构污染页签与标题字段。

local primary_tab = ''
local row_fingerprint_seen = {}

for index, source in ipairs(source_rows) do
  local row = source.row or {}
  local name = trim(row.name or row['名称'])
  -- CSV 中带换行长文本可能被错误切分为“伪行”，直接过滤。
  local is_broken_row = name:find('","', 1, true) ~= nil
    or name:find(',,', 1, true) ~= nil
    or (name:find(',', 1, true) ~= nil and name:find('地图寻宝', 1, true) ~= nil)
    or (name:find(',', 1, true) ~= nil and name:find('商城', 1, true) ~= nil)
  if is_broken_row then
    goto continue
  end
  if name ~= '' and not is_placeholder_text(name) and name ~= '名称' then
    local primary = resolve_primary_tab(row)
    if primary == '' then
      primary = source.fallback_primary or (ArchiveTabDefinitions.get_valid_primary_tabs()[1] or '商品')
    end
    if primary_tab == '' and primary ~= '' then
      primary_tab = primary
    end
    local quality = trim(row.quality or row['品质'])
    if is_placeholder_text(quality) then
      quality = ''
    end
    local tab1 = resolve_shop_tab1(row)
    local tab2_list = split_tab2_list_from_row(row)
    local tab2 = tab2_list[1]
    local special_effect = trim(row.special_effect or row['特殊效果'] or row['额外效果字符串'])
    special_effect = special_effect:gsub('[\r\n]+', ' ')
    if is_placeholder_text(special_effect) then
      special_effect = ''
    end
    local obtain = trim(row.obtain or row['获取方式'])
    if is_placeholder_text(obtain) then
      obtain = ''
    end
    local owned_text = trim(row.owned_text or row['拥有数量'] or row['是否初始解锁'])
    if is_placeholder_text(owned_text) then
      owned_text = ''
    end
    local fingerprint = table.concat({
      name,
      tab1,
      tostring(tab2 or ''),
      trim(row.attr or row['属性']),
      trim(row.value or row['数值']),
      special_effect,
      obtain,
    }, '|')
    if row_fingerprint_seen[fingerprint] == true then
      goto continue
    end
    row_fingerprint_seen[fingerprint] = true

    local key = string.format('shop_item_%s_%03d_%03d', source.table_name or 'unknown', source.row_index or 0, index)
    local attr_lines = build_attr_lines(row.attr or row['属性'], row.value or row['数值'])
    local detail_blocks = TipBlockStyle.build_shop_item_blocks(attr_lines, special_effect, obtain)
    local image_icon, image_bg = parse_icon_bg_from_image_field(row.image or row['图片'])
    local icon = read_first_number(row, { '图标', 'icon', 'Icon', 'ICON', 'icon_id', '图标ID', 'icon_id_res', '图片icon' })
      or image_icon
      or DEFAULT_ICON
    local bg = read_first_number(row, { '底图', '背景', '背景图', 'BG', 'bg', 'frame', '框图', '背景ID' })
      or image_bg
      or DEFAULT_BG
    local partition = normalize_partition(row.partition or row['分区'] or row['区域'] or '', tab1)
    local content_template = normalize_content_template(row.content_template or row['content_template'] or row['内容模板'])

    local spec = {
      key = key,
      node = key,
      index = index,
      title = name,
      icon = icon,
      bg = bg,
      default_icon = DEFAULT_ICON,
      default_bg = DEFAULT_BG,
      attr_text = trim(row.attr or row['属性']),
      value_text = trim(row.value or row['数值']),
      special_effect = special_effect,
      obtain = obtain,
      owned_text = owned_text,
      stackable = row.stackable == true or row.stackable == 1 or row.stackable == '1' or row.stackable == 'true'
        or row['能否堆叠'] == true or row['能否堆叠'] == 1 or row['能否堆叠'] == '1' or row['能否堆叠'] == 'true',
      quality = quality,
      -- 统一语义：仅保留两级页签（tab1/tab2），分区不算页签。
      l1_tab = tab1,
      l2_tab = tab2,
      l2_tabs = tab2_list,
      partition = partition,
      content_template = content_template,
      primary = tab1,
      category = tab2,
      categories = tab2_list,
      attr_lines = attr_lines,
      detail_blocks = detail_blocks,
      line_1 = attr_lines[1] or '暂无属性',
      line_2 = attr_lines[2] or special_effect,
      line_3 = obtain,
      source = source.table_name or 'shop_item',
    }
    list[#list + 1] = spec
    by_key[key] = spec

    if primary_seen[tab1] ~= true then
      primary_seen[tab1] = true
      primary_tabs[#primary_tabs + 1] = tab1
    end

    if categories_by_primary[tab1] == nil then
      categories_by_primary[tab1] = {}
      category_seen_by_primary[tab1] = {}
    end
    if tab2 and tab2 ~= '' then
      if category_seen_by_primary[tab1][tab2] ~= true then
        category_seen_by_primary[tab1][tab2] = true
        categories_by_primary[tab1][#categories_by_primary[tab1] + 1] = tab2
      end
      if category_seen[tab2] ~= true then
        category_seen[tab2] = true
        categories[#categories + 1] = tab2
      end
    end
  end
  ::continue::
end

M.list = list
M.by_key = by_key
M.categories = categories
M.default_icon = DEFAULT_ICON
M.default_bg = DEFAULT_BG
M.primary_tab = primary_tab ~= '' and primary_tab or (ArchiveTabDefinitions.get_valid_primary_tabs()[1] or '商品')
M.primary_tabs = primary_tabs
M.categories_by_primary = categories_by_primary

return M

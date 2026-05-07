
local CsvLoader = require 'data.csv_loader'

local M = {}

-- 辅助函数
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

-- 默认配置（作为 CSV 加载失败时的后备）
local DEFAULT_CONFIG = {
  partitions = { '商城', '存档', '生涯' },
  primary_tabs = {
    { name = '仓库', default_partition = '存档' },
    { name = '商品', default_partition = '商城' },
    { name = '皮肤', default_partition = '商城' },
    { name = '翅膀', default_partition = '商城' },
    { name = '套装', default_partition = '商城' },
    { name = '地图等级', default_partition = '存档' },
    { name = '荣誉等级', default_partition = '存档' },
    { name = '成就', default_partition = '生涯' },
    { name = '英雄图鉴', default_partition = '生涯' },
    { name = '羁绊图鉴', default_partition = '生涯' },
    { name = '称号', default_partition = '生涯' },
  },
  career_tabs = { '成就', '英雄图鉴', '羁绊图鉴', '称号' },
}

-- 从 CSV 加载配置
local function split_pipe(raw)
  local result = {}
  for part in tostring(raw or ''):gmatch('[^|]+') do
    local value = trim(part)
    if value ~= '' then
      result[#result + 1] = value
    end
  end
  return result
end

local function load_from_csv()
  local rows = CsvLoader.read_rows_optional('data_csv/outgame/outgame_archive_tabs.csv')

  local partitions = {}
  local primary_tabs = {}
  local valid_partitions_map = {}
  local valid_primary_tabs_map = {}
  local secondary_tabs_map = {}
  local render_configs = {}

  for _, row in ipairs(rows) do
    local type_name = trim(row.type)
    local name = trim(row.name)
    local enabled = to_bool(row.enabled, true)

    if enabled and name ~= '' then
      if type_name == '分区' then
        partitions[#partitions + 1] = name
        valid_partitions_map[name] = true
      elseif type_name == '一级页签' then
        primary_tabs[#primary_tabs + 1] = {
          name = name,
          default_partition = trim(row.default_partition),
        }
        valid_primary_tabs_map[name] = true
        local secondaries = split_pipe(row.secondary_tabs)
        if #secondaries > 0 then
          secondary_tabs_map[name] = secondaries
        end
        -- 解析渲染配置
        local render_mode = trim(row.render_mode)
        if render_mode == '' then
          render_mode = 'group'
        end
        local label_mode = trim(row.label_mode)
        if label_mode == '' then
          label_mode = 'title'
        end
        render_configs[name] = {
          render_mode = render_mode,
          label_mode = label_mode,
          content_node = trim(row.content_node),
          tip_content = split_pipe(row.tip_content),
          content_template = trim(row.content_template),
          content_list = trim(row.content_list),
        }
      end
    end
  end

  -- 如果 CSV 为空或无效，使用默认配置
  if #partitions == 0 and #primary_tabs == 0 then
    return {
      partitions = DEFAULT_CONFIG.partitions,
      primary_tabs = DEFAULT_CONFIG.primary_tabs,
      career_tabs = DEFAULT_CONFIG.career_tabs,
      valid_partitions_map = { ['商城'] = true, ['存档'] = true, ['生涯'] = true },
      valid_primary_tabs_map = {
        ['仓库'] = true, ['商品'] = true, ['皮肤'] = true, ['翅膀'] = true,
        ['套装'] = true, ['地图等级'] = true, ['荣誉等级'] = true,
        ['成就'] = true, ['英雄图鉴'] = true, ['羁绊图鉴'] = true, ['称号'] = true,
      },
      secondary_tabs_map = {},
    }
  end

  -- 构建职业页签列表（从一级页签中筛选属于生涯分区的）
  local career_tabs = {}
  for _, tab in ipairs(primary_tabs) do
    if tab.default_partition == '生涯' then
      career_tabs[#career_tabs + 1] = tab.name
    end
  end

  return {
    partitions = partitions,
    primary_tabs = primary_tabs,
    career_tabs = career_tabs,
    valid_partitions_map = valid_partitions_map,
    valid_primary_tabs_map = valid_primary_tabs_map,
    secondary_tabs_map = secondary_tabs_map,
    render_configs = render_configs,
  }
end

-- 加载配置
local config = load_from_csv()
local RENDER_CONFIGS = config.render_configs or {}

-- 构建访问用的数据结构
local PARTITION_LIST = config.partitions
local PRIMARY_TAB_LIST = {}
local VALID_PRIMARY_TABS = {}  -- key: 页签名, value: { default_partition: ... }
local VALID_PARTITIONS = config.valid_partitions_map

for _, tab in ipairs(config.primary_tabs) do
  PRIMARY_TAB_LIST[#PRIMARY_TAB_LIST + 1] = tab.name
  VALID_PRIMARY_TABS[tab.name] = {
    default_partition = tab.default_partition,
  }
end

-- 从 CSV 加载二级页签配置
local VALID_SECONDARY_TABS = {}
for _, name in ipairs(PRIMARY_TAB_LIST) do
  VALID_SECONDARY_TABS[name] = {}
end
-- 将 CSV 中配置的二级页签列表填入校验表
for primary_name, secondary_list in pairs(config.secondary_tabs_map) do
  local target = VALID_SECONDARY_TABS[primary_name]
  if not target then
    target = {}
    VALID_SECONDARY_TABS[primary_name] = target
  end
  for _, secondary_name in ipairs(secondary_list) do
    target[secondary_name] = true
  end
end

local CAREER_TABS = config.career_tabs

-- 验证分区是否合法
function M.validate_partition(partition, context)
  if not VALID_PARTITIONS[partition] then
    local valid_list = table.concat(PARTITION_LIST, ', ')
    return false, string.format('%s: 无效的分区 "%s"，有效值为: %s', context, partition, valid_list)
  end
  return true, nil
end

-- 验证一级页签是否合法
function M.validate_primary_tab(primary, context)
  if not VALID_PRIMARY_TABS[primary] then
    local valid_list = table.concat(PRIMARY_TAB_LIST, ', ')
    return false, string.format('%s: 无效的一级页签 "%s"，有效值为: %s', context, primary, valid_list)
  end
  return true, nil
end

-- 验证二级页签是否合法
function M.validate_secondary_tab(primary, secondary, context)
  local valid_secondaries = VALID_SECONDARY_TABS[primary]
  if not valid_secondaries then
    return false, string.format('%s: 无效的一级页签 "%s"，无法验证二级页签', context, primary)
  end
  -- 如果二级页签列表为空，表示接受任何二级页签
  if next(valid_secondaries) == nil then
    return true, nil
  end
  if not valid_secondaries[secondary] then
    local valid_secondary_list = {}
    for k, _ in pairs(valid_secondaries) do
      valid_secondary_list[#valid_secondary_list + 1] = k
    end
    local valid_list = table.concat(valid_secondary_list, ', ')
    return false, string.format('%s: 无效的二级页签 "%s" (在一级页签 "%s" 下)，有效值为: %s', context, secondary, primary, valid_list)
  end
  return true, nil
end

-- 获取一级页签的默认分区
function M.get_default_partition_for_primary(primary)
  local tab_def = VALID_PRIMARY_TABS[primary]
  if not tab_def then
    return PARTITION_LIST[1] or '商城'
  end
  return tab_def.default_partition
end

-- 获取所有合法的分区
function M.get_valid_partitions()
  return PARTITION_LIST
end

-- 获取所有合法的一级页签
function M.get_valid_primary_tabs()
  return PRIMARY_TAB_LIST
end

-- 获取生涯页签列表
function M.get_career_tabs()
  return CAREER_TABS
end

-- 获取某个一级页签下的二级页签列表（从 CSV 配置）
function M.get_secondary_tabs_for_primary(primary)
  return config.secondary_tabs_map[primary] or {}
end

-- 为指定的一级页签添加合法的二级页签（运行时动态追加）
function M.add_valid_secondary_tab(primary, secondary)
  if not VALID_SECONDARY_TABS[primary] then
    VALID_SECONDARY_TABS[primary] = {}
  end
  VALID_SECONDARY_TABS[primary][secondary] = true
end

-- 获取一级页签的完整渲染配置
function M.get_tab_render_config(primary)
  return RENDER_CONFIGS[primary] or {
    render_mode = 'group',
    label_mode = 'title',
    content_node = '通用内容',
    tip_content = {},
    content_template = '',
    content_list = '',
  }
end

-- 获取一级页签的渲染模式
function M.get_render_mode(primary)
  local cfg = RENDER_CONFIGS[primary]
  return (cfg and cfg.render_mode) or 'group'
end

-- 获取一级页签的内容节点名
function M.get_content_node(primary)
  local cfg = RENDER_CONFIGS[primary]
  local node = (cfg and cfg.content_node)
  if node and node ~= '' then
    return node
  end
  return '通用内容'
end

-- 获取一级页签的内容模板子节点名
function M.get_content_template(primary)
  local cfg = RENDER_CONFIGS[primary]
  return (cfg and cfg.content_template) or ''
end

-- 获取一级页签的内容列表容器名
function M.get_content_list(primary)
  local cfg = RENDER_CONFIGS[primary]
  return (cfg and cfg.content_list) or ''
end

-- 获取一级页签的提示文本内容（多行）
function M.get_tip_content(primary)
  local cfg = RENDER_CONFIGS[primary]
  return (cfg and cfg.tip_content) or {}
end

-- 导出数据结构供外部访问
M.PARTITION_LIST = PARTITION_LIST
M.PRIMARY_TAB_LIST = PRIMARY_TAB_LIST
M.VALID_PARTITIONS = VALID_PARTITIONS
M.VALID_PRIMARY_TABS = VALID_PRIMARY_TABS
M.VALID_SECONDARY_TABS = VALID_SECONDARY_TABS
M.CAREER_TABS = CAREER_TABS
M.RENDER_CONFIGS = RENDER_CONFIGS
M._config = config

return M

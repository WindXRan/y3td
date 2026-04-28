local M = {}
local HonorLevels = require 'data.object_tables.honor_levels'
local EquipmentCatalog = require 'data.object_tables.equipment_catalog'
local ShopItems = require 'data.object_tables.shop_items'

local function append_specs(target, prefix, start_index, end_index, title_prefix, line_1, line_2, line_3)
  for index = start_index, end_index do
    target[#target + 1] = {
      node = string.format('%s_%d', prefix, index),
      title = string.format('%s %d', title_prefix, index),
      line_1 = line_1,
      line_2 = line_2,
      line_3 = line_3,
    }
  end
end

local function build_talent_specs()
  local columns = {
    output = { node = 'output_column', title = '输出系' },
    survival = { node = 'survival_column', title = '生存系' },
    resource = { node = 'resource_column', title = '资源系' },
  }
  local nodes = {
    { key = 'output_1', column = 'output', node = 'node_1', title = '战斗天才', max_level = 3, cost = 1, require_points = 0, effect = '攻击成长 +10/级', attr_bonus_per_level = { ['攻击白字'] = 10 } },
    { key = 'output_2', column = 'output', node = 'node_2', title = '传奇老兵', max_level = 3, cost = 1, require_points = 0, effect = '杀敌加成 +5%/级', attr_bonus_per_level = { ['杀敌加成'] = 5 } },
    { key = 'output_3', column = 'output', node = 'node_3', title = '敏锐', max_level = 6, cost = 1, require_points = 1, effect = '攻击速度 +1%/级', attr_bonus_per_level = { ['攻击速度'] = 1 } },
    { key = 'output_4', column = 'output', node = 'node_4', title = '聪慧', max_level = 6, cost = 1, require_points = 1, effect = '技能伤害 +1%/级', attr_bonus_per_level = { ['技能伤害'] = 1 } },
    { key = 'output_5', column = 'output', node = 'node_5', title = '破甲', max_level = 6, cost = 1, require_points = 1, effect = '破甲 +2/级', attr_bonus_per_level = { ['护甲穿透'] = 2 } },
    { key = 'output_6', column = 'output', node = 'node_6', title = '专注', max_level = 6, cost = 1, require_points = 3, effect = '技能伤害 +1%/级', attr_bonus_per_level = { ['技能伤害'] = 1 } },
    { key = 'output_7', column = 'output', node = 'node_7', title = '狂暴', max_level = 6, cost = 1, require_points = 3, effect = '暴击率 +1%/级', attr_bonus_per_level = { ['物理暴击'] = 1 } },
    { key = 'output_8', column = 'output', node = 'node_8', title = '强击', max_level = 6, cost = 1, require_points = 5, effect = '每级获得 +10 攻击力', attr_bonus_per_level = { ['攻击白字'] = 10 } },
    { key = 'output_9', column = 'output', node = 'node_9', title = '迅猛', max_level = 6, cost = 1, require_points = 5, effect = '攻击速度 +1%/级', attr_bonus_per_level = { ['攻击速度'] = 1 } },
    { key = 'output_10', column = 'output', node = 'node_10', title = '精锐', max_level = 6, cost = 1, require_points = 5, effect = '最终伤害 +1%/级', attr_bonus_per_level = { ['最终伤害'] = 1 } },
    { key = 'output_11', column = 'output', node = 'node_11', title = '勇猛战士', max_level = 6, cost = 1, require_points = 8, effect = '攻击与最终伤害 +1%/级', attr_bonus_per_level = { ['攻击白字'] = 10, ['最终伤害'] = 1 } },
    { key = 'survival_1', column = 'survival', node = 'node_1', title = '不灭之力', max_level = 3, cost = 1, require_points = 0, effect = '最大生命 +80/级', attr_bonus_per_level = { ['生命白字'] = 80 } },
    { key = 'survival_2', column = 'survival', node = 'node_2', title = '战争领主', max_level = 3, cost = 1, require_points = 0, effect = '护甲 +2/级', attr_bonus_per_level = { ['护甲白字'] = 2 } },
    { key = 'survival_3', column = 'survival', node = 'node_3', title = '野蛮', max_level = 6, cost = 1, require_points = 1, effect = '生命恢复 +1/级', attr_bonus_per_level = { ['生命恢复'] = 1 } },
    { key = 'survival_4', column = 'survival', node = 'node_4', title = '盛宴', max_level = 6, cost = 1, require_points = 1, effect = '杀敌恢复 +0.5/级', attr_bonus_per_level = { ['杀敌恢复'] = 0.5 } },
    { key = 'survival_5', column = 'survival', node = 'node_5', title = '骨甲', max_level = 6, cost = 1, require_points = 1, effect = '受到伤害 -1%/级', attr_bonus_per_level = { ['伤害减免'] = 1 } },
    { key = 'survival_6', column = 'survival', node = 'node_6', title = '热诚', max_level = 6, cost = 1, require_points = 3, effect = '恢复效果 +2%/级', attr_bonus_per_level = { ['恢复效果'] = 2 } },
    { key = 'survival_7', column = 'survival', node = 'node_7', title = '全面', max_level = 6, cost = 1, require_points = 3, effect = '全属性 +10/级', attr_bonus_per_level = { ['力量白字'] = 10, ['敏捷白字'] = 10, ['智力白字'] = 10 } },
    { key = 'survival_8', column = 'survival', node = 'node_8', title = '护甲', max_level = 6, cost = 1, require_points = 5, effect = '额外护甲 +3/级', attr_bonus_per_level = { ['护甲白字'] = 3 } },
    { key = 'survival_9', column = 'survival', node = 'node_9', title = '坚韧', max_level = 6, cost = 1, require_points = 5, effect = '受到伤害 -1%/级', attr_bonus_per_level = { ['伤害减免'] = 1 } },
    { key = 'survival_10', column = 'survival', node = 'node_10', title = '战争', max_level = 6, cost = 1, require_points = 5, effect = '最大生命 +80/级', attr_bonus_per_level = { ['生命白字'] = 80 } },
    { key = 'survival_11', column = 'survival', node = 'node_11', title = '无畏达人', max_level = 6, cost = 1, require_points = 8, effect = '生命与护甲成长提升', attr_bonus_per_level = { ['生命白字'] = 80, ['护甲白字'] = 2 } },
    { key = 'resource_1', column = 'resource', node = 'node_1', title = '神匠契约', max_level = 3, cost = 1, require_points = 0, effect = '强化收益 +1%/级', attr_bonus_per_level = { ['强化收益'] = 1 } },
    { key = 'resource_2', column = 'resource', node = 'node_2', title = '神木祝福', max_level = 3, cost = 1, require_points = 0, effect = '资源获取 +1%/级', attr_bonus_per_level = { ['资源获取'] = 1 } },
    { key = 'resource_3', column = 'resource', node = 'node_3', title = '祝福', max_level = 6, cost = 1, require_points = 1, effect = '幸运 +1/级', attr_bonus_per_level = { ['幸运'] = 1 } },
    { key = 'resource_4', column = 'resource', node = 'node_4', title = '掘金', max_level = 6, cost = 1, require_points = 1, effect = '金币收益 +1%/级', attr_bonus_per_level = { ['金币收益'] = 1 } },
    { key = 'resource_5', column = 'resource', node = 'node_5', title = '暗杀', max_level = 6, cost = 1, require_points = 1, effect = '首领伤害 +1%/级', attr_bonus_per_level = { ['首领伤害'] = 1 } },
    { key = 'resource_6', column = 'resource', node = 'node_6', title = '商人', max_level = 6, cost = 1, require_points = 3, effect = '商店折扣 +1%/级', attr_bonus_per_level = { ['商店折扣'] = 1 } },
    { key = 'resource_7', column = 'resource', node = 'node_7', title = '杀手', max_level = 6, cost = 1, require_points = 3, effect = '杀敌资源 +1%/级', attr_bonus_per_level = { ['杀敌资源'] = 1 } },
    { key = 'resource_8', column = 'resource', node = 'node_8', title = '闪金', max_level = 6, cost = 1, require_points = 5, effect = '额外金币 +1%/级', attr_bonus_per_level = { ['金币收益'] = 1 } },
    { key = 'resource_9', column = 'resource', node = 'node_9', title = '屠刀', max_level = 6, cost = 1, require_points = 5, effect = '精英伤害 +1%/级', attr_bonus_per_level = { ['精英伤害'] = 1 } },
    { key = 'resource_10', column = 'resource', node = 'node_10', title = '树枝', max_level = 6, cost = 1, require_points = 5, effect = '木材收益 +1%/级', attr_bonus_per_level = { ['木材收益'] = 1 } },
    { key = 'resource_11', column = 'resource', node = 'node_11', title = '天赋异禀', max_level = 6, cost = 1, require_points = 8, effect = '通用资源收益提升', attr_bonus_per_level = { ['资源获取'] = 1, ['金币收益'] = 1 } },
  }
  local by_key = {}
  for _, spec in ipairs(nodes) do
    spec.column_node = columns[spec.column].node
    by_key[spec.key] = spec
  end
  return columns, nodes, by_key
end

local function build_universal_specs()
  local specs = {
    pass = {
      { node = 'pass_badge_1', title = '难度 1 通关奖励', line_1 = '累计通关可领取夺宝券。', line_2 = '当前用于查看通关奖励进度。', line_3 = '点击其它难度可切换详情。' },
      { node = 'pass_badge_2', title = '难度 2 通关奖励', line_1 = '奖励随难度逐步提高。', line_2 = '通关后写入存档进度。', line_3 = '可作为赛季成长目标。' },
      { node = 'pass_badge_3', title = '难度 3 通关奖励', line_1 = '展示更高难度通关次数。', line_2 = '用于核对夺宝券来源。', line_3 = '当前为存档预览条目。' },
      { node = 'pass_badge_4', title = '难度 4 通关奖励', line_1 = '后续可接入实际领取状态。', line_2 = '列表点击会刷新右侧详情。', line_3 = '未达成时显示为预览。' },
      { node = 'pass_badge_5', title = '难度 5 通关奖励', line_1 = '高难度通关累计目标。', line_2 = '奖励内容可由配置表驱动。', line_3 = '适合展示阶段性奖励。' },
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
      { node = 'lottery_badge_2', title = '强化石', line_1 = '常规抽奖材料。', line_2 = '用于装备或天赋成长。', line_3 = '当前展示为列表条目。' },
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

  if #HonorLevels.list > 0 then
    specs.map = HonorLevels.list
  end

  append_specs(specs.pass, 'pass_badge', 6, 10, '难度', '更高难度通关奖励。', '滚动列表中的可点击条目。', '后续可接入实际领取状态。')
  if #HonorLevels.list <= 0 then
    append_specs(specs.map, 'map_badge', 4, 21, '地图等级', '地图等级阶段奖励。', '可展示等级达成与领取状态。', '当前作为图鉴列表预览。')
  end
  append_specs(specs.community, 'community_badge', 4, 14, '社区福利', '社区活动奖励条目。', '可接入收藏、关注、分享等状态。', '点击后刷新右侧详情。')
  append_specs(specs.achievement, 'achievement_badge', 4, 14, '成就', '长期目标成就条目。', '可显示达成进度与奖励。', '点击后查看成就条件。')
  append_specs(specs.lottery, 'lottery_badge', 4, 14, '群抽奖', '群抽奖奖励条目。', '可展示口令与抽奖产出。', '点击后刷新奖励说明。')
  append_specs(specs.test, 'test_badge', 3, 8, '测试礼包', '测试大厅调试条目。', '用于验证滚动网格点击。', '正式版可替换为活动奖励。')
  append_specs(specs.fish, 'fish_feature', 4, 5, '捕鱼图鉴', '捕鱼模式功能条目。', '可展示捕获次数与收益。', '点击后查看图鉴详情。')
  append_specs(specs.fish, 'fish_rarity', 1, 3, '鱼类品质', '鱼类品质分类。', '用于划分捕鱼图鉴奖励。', '点击后查看该品质说明。')
  for row_index, count in ipairs({ 6, 7, 4 }) do
    for index = 1, count do
      specs.fish[#specs.fish + 1] = {
        node = string.format('fish_badge_%d_%d', row_index, index),
        title = string.format('鱼类图鉴 %d-%d', row_index, index),
        line_1 = '捕鱼模式图鉴条目。',
        line_2 = '可接入捕获次数和奖励状态。',
        line_3 = '滚动列表中的可点击鱼类。',
      }
    end
  end
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

function M.create(config)
  local talent_columns, talent_nodes, talent_by_key = build_talent_specs()
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
      { key = 'clear_any_1', title = '首次通关任意难度', reward = '奖励：天赋点+500', target = 1 },
      { key = 'clear_any_3', title = '通关3次任意难度', reward = '奖励：强化石+3', target = 3 },
      { key = 'online_60', title = '累计在线60分钟', reward = '奖励：宝物精华+30', target = 60 },
      { key = 'online_120', title = '累计在线120分钟', reward = '奖励：泡点+300', target = 120 },
      { key = 'online_300', title = '累计在线300分钟', reward = '奖励：重铸石+3', target = 300 },
    },
    talent_columns = talent_columns,
    talent_nodes = talent_nodes,
    talent_by_key = talent_by_key,
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
    archive_page_keys = { 'profile', 'equipment', 'talent', 'universal', 'chest', 'pool' },
    archive_page_panel_names = {
      profile = 'ArchivePageProfile',
      equipment = 'ArchivePageEquipment',
      talent = 'ArchivePageTalent',
      universal = 'ArchivePageUniversal',
      chest = 'ArchivePageChest',
      pool = 'ArchivePagePool',
    },
    archive_menu_specs = {
      { key = 'profile', page_key = 'profile', visible = true },
      { key = 'universal', page_key = 'universal', visible = true },
      { key = 'chest', page_key = 'chest', visible = true },
      { key = 'club', page_key = nil, visible = true },
      { key = 'talent', page_key = 'talent', visible = true },
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
      map = #HonorLevels.list > 0 and '荣誉' or '地图',
      community = '社区',
      achievement = '成就',
      lottery = '抽奖',
      test = '测试',
      fish = '捕鱼',
    },
    honor_level_specs = HonorLevels.list,
    archive_pool_item_specs = build_pool_specs(),
    archive_shop_item_specs = ShopItems.list,
    archive_shop_primary_tab = ShopItems.primary_tab,
    archive_shop_primary_tabs = ShopItems.primary_tabs or {},
    archive_shop_categories = ShopItems.categories,
    archive_shop_categories_by_primary = ShopItems.categories_by_primary or {},
    archive_shop_default_icon = ShopItems.default_icon,
  }
end

return M

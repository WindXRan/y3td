local M = {}

local function define(name, category, order, format, extra)
  extra = extra or {}
  extra.name = name
  extra.category = category
  extra.order = order
  extra.format = format
  if extra.persist == nil then
    extra.persist = true
  end
  return extra
end

M.categories = {
  DAMAGE = '伤害属性',
  DEFENSE = '防守属性',
  RESOURCE = '资源属性',
  AMPLIFY = '增幅属性',
  OTHER = '其他属性',
}

M.aliases = {
  ['物理攻击'] = '攻击',
  ['最大生命'] = '生命',
  ['暴击率'] = '物理暴击',
  ['暴击伤害'] = '物理暴伤',
  ['命中率'] = '命中',
  ['护甲穿透'] = '护甲穿透',
  ['物理吸血'] = '物理吸血',
  ['BOSS伤害'] = '挑战伤害',
  ['精英伤害'] = '精控伤害',
  ['冻伤伤害'] = '冻结伤害',
  ['最终攻击增幅'] = '最终攻击',
  ['最终生命增幅'] = '最终生命',
  ['最终护甲增幅'] = '最终护甲',
  ['物系伤害'] = '金行伤害',
  ['火系伤害'] = '火行伤害',
  ['电系伤害'] = '木行伤害',
  ['能量伤害'] = '金行伤害',
  ['冰系伤害'] = '水行伤害',
  ['风系伤害'] = '木行伤害',
}

M.list = {
  define('攻击', M.categories.DAMAGE, 10, 'integer', { derived_output = true, persist = false }),
  define('攻击白字', M.categories.DAMAGE, 11, 'integer'),
  define('攻击绿字', M.categories.DAMAGE, 12, 'integer'),
  define('攻击范围', M.categories.DAMAGE, 20, 'integer'),
  define('攻击速度', M.categories.DAMAGE, 25, 'integer'),
  define('攻击间隔', M.categories.DAMAGE, 30, 'fixed2'),
  define('命中', M.categories.DAMAGE, 40, 'percent', { is_ratio = true }),
  define('物理暴击', M.categories.DAMAGE, 50, 'percent', { is_ratio = true }),
  define('物理暴伤', M.categories.DAMAGE, 60, 'percent', { is_ratio = true }),
  define('魔法暴击', M.categories.DAMAGE, 70, 'percent', { is_ratio = true }),
  define('魔法暴伤', M.categories.DAMAGE, 80, 'percent', { is_ratio = true }),
  define('物理伤害', M.categories.DAMAGE, 90, 'percent', { is_ratio = true }),
  define('魔法伤害', M.categories.DAMAGE, 100, 'percent', { is_ratio = true }),
  define('物理吸血', M.categories.DAMAGE, 110, 'percent', { is_ratio = true }),
  define('普攻伤害', M.categories.DAMAGE, 120, 'percent', { is_ratio = true }),
  define('技能伤害', M.categories.DAMAGE, 130, 'percent_or_zero', { is_ratio = true }),
  define('所有伤害', M.categories.DAMAGE, 140, 'percent', { is_ratio = true }),
  define('最终伤害', M.categories.DAMAGE, 150, 'percent', { is_ratio = true }),
  define('无视护甲', M.categories.DAMAGE, 160, 'percent', { is_ratio = true }),
  define('护甲穿透', M.categories.DAMAGE, 170, 'integer'),
  define('多重数量', M.categories.DAMAGE, 180, 'integer'),
  define('多重伤害', M.categories.DAMAGE, 190, 'percent', { is_ratio = true }),
  define('弹射次数', M.categories.DAMAGE, 200, 'integer'),
  define('弹射伤害', M.categories.DAMAGE, 210, 'percent', { is_ratio = true }),

  define('生命', M.categories.DEFENSE, 10, 'integer', { derived_output = true, persist = false }),
  define('生命白字', M.categories.DEFENSE, 11, 'integer'),
  define('生命绿字', M.categories.DEFENSE, 12, 'integer'),
  define('护甲', M.categories.DEFENSE, 20, 'integer', { derived_output = true, persist = false }),
  define('护甲白字', M.categories.DEFENSE, 21, 'integer'),
  define('护甲绿字', M.categories.DEFENSE, 22, 'integer'),
  define('格挡', M.categories.DEFENSE, 30, 'integer'),
  define('闪避', M.categories.DEFENSE, 40, 'percent', { is_ratio = true }),
  define('生命恢复', M.categories.DEFENSE, 50, 'fixed1'),
  define('伤害减免', M.categories.DEFENSE, 60, 'percent', { is_ratio = true }),
  define('闪避恢复', M.categories.DEFENSE, 70, 'fixed1'),
  define('杀敌恢复', M.categories.DEFENSE, 80, 'fixed1'),
  define('控制时长', M.categories.DEFENSE, 90, 'percent', { is_ratio = true }),

  define('杀敌经验', M.categories.RESOURCE, 10, 'percent', { is_ratio = true }),
  define('杀敌加成', M.categories.RESOURCE, 20, 'percent', { is_ratio = true }),
  define('杀敌木材', M.categories.RESOURCE, 30, 'percent', { is_ratio = true }),
  define('杀敌金币', M.categories.RESOURCE, 40, 'percent', { is_ratio = true }),
  define('每秒经验', M.categories.RESOURCE, 50, 'fixed1', { growth_kind = 'per_second' }),
  define('每秒木材', M.categories.RESOURCE, 60, 'fixed1', { growth_kind = 'per_second' }),
  define('每秒金币', M.categories.RESOURCE, 70, 'fixed1', { growth_kind = 'per_second' }),
  define('每秒杀敌', M.categories.RESOURCE, 80, 'fixed1', { growth_kind = 'per_second' }),

  define('力量', M.categories.AMPLIFY, 10, 'integer', { derived_output = true, persist = false }),
  define('力量白字', M.categories.AMPLIFY, 11, 'integer'),
  define('力量绿字', M.categories.AMPLIFY, 12, 'integer'),
  define('敏捷', M.categories.AMPLIFY, 20, 'integer', { derived_output = true, persist = false }),
  define('敏捷白字', M.categories.AMPLIFY, 21, 'integer'),
  define('敏捷绿字', M.categories.AMPLIFY, 22, 'integer'),
  define('智力', M.categories.AMPLIFY, 30, 'integer', { derived_output = true, persist = false }),
  define('智力白字', M.categories.AMPLIFY, 31, 'integer'),
  define('智力绿字', M.categories.AMPLIFY, 32, 'integer'),
  define('力量增幅', M.categories.AMPLIFY, 40, 'percent', { is_ratio = true }),
  define('敏捷增幅', M.categories.AMPLIFY, 50, 'percent', { is_ratio = true }),
  define('智力增幅', M.categories.AMPLIFY, 60, 'percent', { is_ratio = true }),
  define('攻击增幅', M.categories.AMPLIFY, 70, 'percent', { is_ratio = true }),
  define('生命增幅', M.categories.AMPLIFY, 80, 'percent', { is_ratio = true }),
  define('护甲增幅', M.categories.AMPLIFY, 90, 'percent', { is_ratio = true }),
  define('每秒攻击', M.categories.AMPLIFY, 100, 'fixed1', { growth_kind = 'per_second' }),
  define('每秒力量', M.categories.AMPLIFY, 110, 'fixed1', { growth_kind = 'per_second' }),
  define('每秒敏捷', M.categories.AMPLIFY, 120, 'fixed1', { growth_kind = 'per_second' }),
  define('每秒智力', M.categories.AMPLIFY, 130, 'fixed1', { growth_kind = 'per_second' }),
  define('每秒生命', M.categories.AMPLIFY, 140, 'fixed1', { growth_kind = 'per_second' }),
  define('杀敌攻击', M.categories.AMPLIFY, 150, 'fixed2', { growth_kind = 'on_kill' }),
  define('杀敌力量', M.categories.AMPLIFY, 160, 'fixed2', { growth_kind = 'on_kill' }),
  define('杀敌敏捷', M.categories.AMPLIFY, 170, 'fixed2', { growth_kind = 'on_kill' }),
  define('杀敌智力', M.categories.AMPLIFY, 180, 'fixed2', { growth_kind = 'on_kill' }),
  define('杀敌生命', M.categories.AMPLIFY, 190, 'fixed2', { growth_kind = 'on_kill' }),
  define('杀敌护甲', M.categories.AMPLIFY, 200, 'fixed2', { growth_kind = 'on_kill' }),
  define('最终力量', M.categories.AMPLIFY, 210, 'fixed1', { derived_output = true }),
  define('最终敏捷', M.categories.AMPLIFY, 220, 'fixed1', { derived_output = true }),
  define('最终智力', M.categories.AMPLIFY, 230, 'fixed1', { derived_output = true }),
  define('最终攻击', M.categories.AMPLIFY, 240, 'percent', { is_ratio = true }),
  define('最终生命', M.categories.AMPLIFY, 250, 'percent', { is_ratio = true }),
  define('最终护甲', M.categories.AMPLIFY, 260, 'percent', { is_ratio = true }),
  define('攻击结算值', M.categories.AMPLIFY, 265, 'fixed1', { derived_output = true, persist = false }),
  define('生命结算值', M.categories.AMPLIFY, 266, 'fixed1', { derived_output = true, persist = false }),
  define('护甲结算值', M.categories.AMPLIFY, 267, 'fixed1', { derived_output = true, persist = false }),
  define('最终力量增幅', M.categories.AMPLIFY, 270, 'percent', { is_ratio = true }),
  define('最终敏捷增幅', M.categories.AMPLIFY, 280, 'percent', { is_ratio = true }),
  define('最终智力增幅', M.categories.AMPLIFY, 290, 'percent', { is_ratio = true }),

  define('金行伤害', M.categories.OTHER, 10, 'percent', { is_ratio = true }),
  define('木行伤害', M.categories.OTHER, 20, 'percent', { is_ratio = true }),
  define('水行伤害', M.categories.OTHER, 30, 'percent', { is_ratio = true }),
  define('精控伤害', M.categories.OTHER, 40, 'percent', { is_ratio = true }),
  define('燃烧伤害', M.categories.OTHER, 50, 'percent', { is_ratio = true }),
  define('百分比恢复', M.categories.OTHER, 60, 'percent', { is_ratio = true }),
  define('穿透次数', M.categories.OTHER, 70, 'integer'),
  define('火行伤害', M.categories.OTHER, 80, 'percent', { is_ratio = true }),
  define('土行伤害', M.categories.OTHER, 90, 'percent', { is_ratio = true }),
  define('挑战伤害', M.categories.OTHER, 110, 'percent', { is_ratio = true }),
  define('冻结伤害', M.categories.OTHER, 120, 'percent', { is_ratio = true }),
  define('恢复效果', M.categories.OTHER, 130, 'percent', { is_ratio = true }),
  define('卡牌增幅', M.categories.OTHER, 140, 'percent', { is_ratio = true }),
}

M.by_name = {}
M.default_values = {}
M.sorted_by_category = {
  [M.categories.DAMAGE] = {},
  [M.categories.DEFENSE] = {},
  [M.categories.RESOURCE] = {},
  [M.categories.AMPLIFY] = {},
  [M.categories.OTHER] = {},
}

for _, def in ipairs(M.list) do
  M.by_name[def.name] = def
  M.default_values[def.name] = def.default or 0
  table.insert(M.sorted_by_category[def.category], def)
end

for _, defs in pairs(M.sorted_by_category) do
  table.sort(defs, function(a, b)
    if a.order == b.order then
      return a.name < b.name
    end
    return a.order < b.order
  end)
end

return M

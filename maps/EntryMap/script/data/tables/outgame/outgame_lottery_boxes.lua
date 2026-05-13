local M = {}

M.LOTTERY_BOXES = {
  {
    box_id = 'normal_box',
    name = '普通宝箱',
    description = '每日免费抽取一次，包含基础养成材料',
    icon = 134242447,
    bg = 907123,
    cost_type = 'ticket',
    cost_amount = 1,
    free_daily_count = 1,
    guaranteed_rare = false,
    reward_pool = {
      {
        item_id = 'gold_small',
        name = '金币袋',
        icon = 906565,
        quality = 'common',
        weight = 30,
        attrs = {
          { name = '金币', value = 500, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'gold_medium',
        name = '金币箱',
        icon = 906565,
        quality = 'common',
        weight = 15,
        attrs = {
          { name = '金币', value = 1000, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'wood',
        name = '木材',
        icon = 906566,
        quality = 'common',
        weight = 20,
        attrs = {
          { name = '木材', value = 50, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'stone',
        name = '石材',
        icon = 906567,
        quality = 'common',
        weight = 20,
        attrs = {
          { name = '石材', value = 50, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'upgrade_stone',
        name = '升级石',
        icon = 906568,
        quality = 'rare',
        weight = 8,
        attrs = {
          { name = '攻击加成', value = 3, unit = '%' },
          { name = '生命加成', value = 3, unit = '%' },
        },
        special_effect = '',
      },
      {
        item_id = 'essence',
        name = '精华',
        icon = 906569,
        quality = 'rare',
        weight = 5,
        attrs = {
          { name = '能量', value = 20, unit = '' },
          { name = '神识', value = 10, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'skill_book',
        name = '技能书',
        icon = 906570,
        quality = 'rare',
        weight = 2,
        attrs = {
          { name = '最终伤害', value = 1, unit = '%' },
        },
        special_effect = '解锁随机技能',
      },
    },
  },
  {
    box_id = 'premium_box',
    name = '高级宝箱',
    description = '十连必出稀有物品，概率获得英雄碎片',
    icon = 134242448,
    bg = 907124,
    cost_type = 'ticket',
    cost_amount = 10,
    free_daily_count = 0,
    guaranteed_rare = true,
    reward_pool = {
      {
        item_id = 'gold_large',
        name = '金币宝箱',
        icon = 906565,
        quality = 'common',
        weight = 15,
        attrs = {
          { name = '金币', value = 2000, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'wood_large',
        name = '木材堆',
        icon = 906566,
        quality = 'common',
        weight = 10,
        attrs = {
          { name = '木材', value = 100, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'stone_large',
        name = '石材堆',
        icon = 906567,
        quality = 'common',
        weight = 10,
        attrs = {
          { name = '石材', value = 100, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'upgrade_stone_plus',
        name = '精炼石',
        icon = 906568,
        quality = 'rare',
        weight = 15,
        attrs = {
          { name = '攻击加成', value = 8, unit = '%' },
          { name = '生命加成', value = 8, unit = '%' },
          { name = '能量', value = 5, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'heavy_forging_stone',
        name = '重铸石',
        icon = 906571,
        quality = 'rare',
        weight = 10,
        attrs = {
          { name = '攻击加成', value = 5, unit = '%' },
          { name = '最终伤害', value = 2, unit = '%' },
        },
        special_effect = '可重铸装备属性',
      },
      {
        item_id = 'essence_large',
        name = '精华瓶',
        icon = 906569,
        quality = 'rare',
        weight = 12,
        attrs = {
          { name = '能量', value = 50, unit = '' },
          { name = '神识', value = 30, unit = '' },
          { name = '魂力', value = 30, unit = '' },
        },
        special_effect = '',
      },
      {
        item_id = 'skill_book_plus',
        name = '高级技能书',
        icon = 906570,
        quality = 'rare',
        weight = 8,
        attrs = {
          { name = '最终伤害', value = 3, unit = '%' },
          { name = '攻击加成', value = 5, unit = '%' },
        },
        special_effect = '解锁稀有技能',
      },
      {
        item_id = 'hero_fragment',
        name = '英雄碎片',
        icon = 906572,
        quality = 'epic',
        weight = 5,
        attrs = {
          { name = '英雄碎片', value = 10, unit = '' },
          { name = '排名积分', value = 100, unit = '' },
        },
        special_effect = '可合成英雄',
      },
      {
        item_id = 'rare_hero_fragment',
        name = '稀有英雄碎片',
        icon = 906573,
        quality = 'epic',
        weight = 3,
        attrs = {
          { name = '稀有英雄碎片', value = 5, unit = '' },
          { name = '攻击加成', value = 2, unit = '%' },
          { name = '排名积分', value = 300, unit = '' },
        },
        special_effect = '可合成稀有英雄',
      },
      {
        item_id = 'epic_hero_fragment',
        name = '史诗英雄碎片',
        icon = 906574,
        quality = 'legendary',
        weight = 2,
        attrs = {
          { name = '史诗英雄碎片', value = 3, unit = '' },
          { name = '攻击加成', value = 5, unit = '%' },
          { name = '最终伤害', value = 5, unit = '%' },
          { name = '排名积分', value = 500, unit = '' },
        },
        special_effect = '可合成史诗英雄',
      },
    },
  },
}

M.by_box_id = {}
for _, box in ipairs(M.LOTTERY_BOXES) do
  M.by_box_id[box.box_id] = box
end

local function calculate_total_weight(pool)
  local total = 0
  for _, item in ipairs(pool) do
    total = total + (item.weight or 0)
  end
  return total
end

for _, box in ipairs(M.LOTTERY_BOXES) do
  box.total_weight = calculate_total_weight(box.reward_pool)
end

return M
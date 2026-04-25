local helpers = require 'entry_objects.helpers'

local list = {
  {
    order_index = 1,
    id = 201390081,
    name = '流云双刃',
    rarity = 'rare',
    archetype = '迅击暴击',
    tags = { '攻速', '暴击', '物攻' },
    summary = '偏向普攻连斩的轻型双刃，适合吃攻速、暴击和多段命中收益。',
  },
  {
    order_index = 2,
    id = 201390082,
    name = '洪荒之刃',
    rarity = 'rare',
    archetype = '重击爆发',
    tags = { '物攻', '暴击', '被动' },
    summary = '高物攻高暴击的爆发武器，适合打单体斩杀和真实伤害补刀。',
  },
  {
    order_index = 3,
    id = 201390083,
    name = '狩魂杖',
    rarity = 'rare',
    archetype = '法吸混伤',
    tags = { '法吸', '法术', '物法双修', '主动' },
    summary = '兼顾法强、物攻与吸血的混伤法杖，适合持续作战和主动偷取类玩法。',
  },
  {
    order_index = 4,
    id = 201390084,
    name = '奇甲天书',
    rarity = 'rare',
    archetype = '法强增幅',
    tags = { '法术', '法伤', '成长' },
    summary = '纯法强向的天书型装备，适合放大技能倍率和法术爆发。',
  },
  {
    order_index = 5,
    id = 201390085,
    name = '弥勒杖',
    rarity = 'rare',
    archetype = '攻速冷却',
    tags = { '攻速', '冷却', '主动' },
    summary = '攻速与冷却缩减并重的法器，适合高频施法和技能穿插普攻的套路。',
  },
  {
    order_index = 6,
    id = 201390086,
    name = '鸣鸿刀',
    rarity = 'rare',
    archetype = '追击斩首',
    tags = { '物攻', '暴击', '收割' },
    summary = '稳定提升物攻与暴击的单刀，适合打追击收割和斩杀窗口。',
  },
  {
    order_index = 7,
    id = 201390087,
    name = '风速弓',
    rarity = 'rare',
    archetype = '机动连射',
    tags = { '攻速', '移速', '主动' },
    summary = '兼顾攻速与机动性的弓系装备，适合风筝、走A和连射弹道流。',
  },
  {
    order_index = 8,
    id = 201390088,
    name = '羽裂斧',
    rarity = 'rare',
    archetype = '狂斧暴击',
    tags = { '攻速', '暴击', '物攻' },
    summary = '偏向近战压制的狂暴斧型装备，适合普攻暴击和贴脸输出。',
  },
  {
    order_index = 9,
    id = 201390089,
    name = '奔雷锤',
    rarity = 'rare',
    archetype = '雷击连打',
    tags = { '攻速', '物攻', '被动' },
    summary = '高攻速锤系装备，适合触发连锁命中、额外落雷和多段普攻特效。',
  },
  {
    order_index = 10,
    id = 201390090,
    name = '天玄蚀灵',
    rarity = 'epic',
    archetype = '蚀灵附伤',
    tags = { '攻速', '物攻', '法伤', '主动' },
    summary = '兼具攻速与附伤爆发的高阶武器，适合普攻附加法伤和爆发窗口强化。',
  },
}

table.sort(list, function(a, b)
  local a_order = a.order_index or 0
  local b_order = b.order_index or 0
  if a_order == b_order then
    return tostring(a.id or '') < tostring(b.id or '')
  end
  return a_order < b_order
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
  bar_slot_count = 6,
  test_loadout_ids = {
    201390081,
    201390082,
  },
}

local config = {
  group_labels = {},
  per_second_attr_keys = {},
  manual_color_keywords = {
    green = {
      '自适应伤害',
      '技能伤害',
      '魔法伤害',
      '所有伤害',
      '物理暴伤',
      '魔法暴伤',
      '物理暴击',
      '魔法暴击',
      '攻击力',
      '生命值',
      '生命恢复',
      '护甲',
      '格挡',
      '力量',
      '敏捷',
      '智力',
      '木材',
      '金币',
      '经验',
      '杀敌金币',
      '杀敌经验',
      '杀敌加成',
      '每秒',
    },
    cyan = {
      '%d+%.?%d*%%',
      '%d+%.?%d*',
    },
  },
}

config.manual_color_keywords.green = config.manual_color_keywords.green or {}
config.manual_color_keywords.cyan = config.manual_color_keywords.cyan or {}

return config

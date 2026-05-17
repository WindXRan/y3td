-- attr_display_config.lua — 属性面板展示配置，单一数据源
-- 每个条目定义属性在面板中的显示名、格式和默认值
--
-- 字段说明:
--   display  — 面板上显示的文本
--   attr     — 内部属性名（传入 read_attr / hero_attr_system.get_attr）
--   format   — "number" | "percent"
--   decimals — 小数位数（默认 number=0, percent=1）
--   default  — 可选，值为 0 时替换为此默认值（如攻速默认 100%）
--   is_gold  — true 表示特殊处理：从 STATE.resources.gold 读取

return {
  { display = '攻击成长', attr = '每秒攻击', format = 'number', decimals = 0 },
  { display = '生命成长', attr = '每秒生命', format = 'number', decimals = 0 },
  { display = '攻击范围', attr = '攻击范围', format = 'number', decimals = 0 },
  { display = '多重数量', attr = '多重数量', format = 'number', decimals = 0 },
  { display = '生命回复', attr = '生命恢复', format = 'number', decimals = 0 },
  { display = '移动速度', attr = '移动速度', format = 'number', decimals = 0 },
  { display = '攻击速度', attr = '攻击速度', format = 'percent', decimals = 0, default = 100 },
  { display = '闪避概率', attr = '闪避', format = 'percent', decimals = 0 },
  { display = '被动概率', attr = '命中', format = 'percent', decimals = 0 },
  { display = '护甲穿透', attr = '护甲穿透', format = 'percent', decimals = 0 },
  { display = '物理暴率', attr = '物理暴击', format = 'percent', decimals = 1 },
  { display = '物理暴伤', attr = '物理暴伤', format = 'percent', decimals = 1, default = 200 },
  { display = '法术暴率', attr = '魔法暴击', format = 'percent', decimals = 1 },
  { display = '法术暴伤', attr = '魔法暴伤', format = 'percent', decimals = 1, default = 200 },
  { display = '射箭伤害', attr = '普攻伤害', format = 'percent', decimals = 1 },
  { display = '物理增伤', attr = '物理伤害', format = 'percent', decimals = 1 },
  { display = '法术增伤', attr = '魔法伤害', format = 'percent', decimals = 1 },
  { display = '最终伤害', attr = '最终伤害', format = 'percent', decimals = 1 },
  { display = '最终减免', attr = '伤害减免', format = 'percent', decimals = 1 },
  { display = '召唤加成', attr = '召唤加成', format = 'percent', decimals = 1 },
  { display = '经验加成', attr = '杀敌经验', format = 'percent', decimals = 1 },
  { display = '金币', is_gold = true, format = 'number', decimals = 0 },
  { display = '绝学伤害', attr = '技能伤害', format = 'percent', decimals = 1 },
  { display = '小怪增伤', attr = '所有伤害', format = 'percent', decimals = 1 },
  { display = '精英增伤', attr = '精英伤害', format = 'percent', decimals = 1 },
  { display = 'BOSS增伤', attr = '挑战伤害', format = 'percent', decimals = 1 },
}

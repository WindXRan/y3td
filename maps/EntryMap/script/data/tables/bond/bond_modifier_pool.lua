-- 技能卡牌池（羁绊系统核心数据）
-- 每个羁绊(bond)包含若干卡牌(card)
-- bond_effect_runtime_rules.lua 定义效果规则，本文件定义卡牌收集结构

local M = {}

M.enabled = true

-- 默认图标（若未指定 icon 则使用）
local DEFAULT_ICON = 131414

-- 全部卡牌（扁平列表）— .cards 是主名，.list 兼容旧代码
M.cards = {}
M.list = M.cards

-- 按 card_id 索引
M.card_by_id = {}

-- 按羁绊名分组：cards_by_bond[bond_name] = { card, ... }
M.cards_by_bond = {}

-- 辅助：添加一张卡牌
local function card(id, name, bond, quality, icon, desc, activation_desc, extra_skill_desc, attr_pack)
  icon = icon or DEFAULT_ICON
  local c = {
    id = id,
    name = name,
    bond_name = bond,
    quality = quality or 'rare',
    icon = icon,
    bg = icon,
    desc = desc or '',
    activation_desc = activation_desc or '',
    extra_skill_desc = extra_skill_desc or '',
    attr_pack = attr_pack or {},
  }
  M.cards[#M.cards + 1] = c
  M.card_by_id[id] = c
  M.cards_by_bond[bond] = M.cards_by_bond[bond] or {}
  M.cards_by_bond[bond][#M.cards_by_bond[bond] + 1] = c
end

-- ========================
-- 核心羁绊卡牌定义
-- ========================

-- 枪炮师（普攻触发：直线穿透波）
card('bbq', 'BBQ', '枪炮师', 'epic', nil,
  '攻击时有12%概率发射穿透弹幕，对直线敌人造成280%攻击的物理伤害。',
  '', '', { attack_speed = 5 })
card('tactical_reposition', '战术走位', '枪炮师', 'rare', nil,
  '枪炮师子弹波数量+1。',
  '', '', { attack_speed = 3 })

-- 神射手（普攻触发：精准射击）
card('piercing_arrow', '穿云箭', '神射手', 'epic', nil,
  '攻击时有16%概率射出穿云箭，造成185%攻击+攻速系数伤害，附带220范围溅射。',
  '', '', { attack_range = 30 })
card('armor_piercing', '穿甲射击', '神射手', 'rare', nil,
  '穿云箭伤害提升，溅射范围扩大。',
  '', '', { attack_range = 15 })

-- 游侠（普攻触发：箭雨）
card('viper_sting', '毒蛇钉刺', '游侠', 'epic', nil,
  '攻击时有14%概率对目标区域降下毒箭雨，420半径内5次伤害。',
  '', '', { attack_speed = 4 })
card('poison_arrow_rain', '毒箭雨', '游侠', 'rare', nil,
  '箭雨伤害和范围提升。',
  '', '', { attack_speed = 3 })
card('keen_sense', '敏锐', '游侠', 'rare', nil,
  '游侠触发概率提升。',
  '', '', { attack_speed = 2 })

-- 狂战士（普攻触发：残血爆发）
card('frenzy_slash', '狂刀斩', '狂战士', 'epic', nil,
  '攻击时有34%概率触发残血爆发，造成10%攻击+6%已损生命值伤害。',
  '', '', { hp_max = 40 })
card('heavy_armor_mastery', '重甲精通', '狂战士', 'rare', nil,
  '狂战士触发伤害提升。',
  '', '', { hp_max = 25 })
card('strength_awakening', '力量唤醒', '狂战士', 'rare', nil,
  '生命值越低，狂战士触发伤害越高。',
  '', '', { hp_max = 20 })

-- 剑魂（普攻触发：连击爆发）
card('slash_strike', '斩击', '剑魂', 'epic', nil,
  '每8次普攻触发一次剑魂斩击，造成180%攻击伤害。',
  '', '', { attack = 8 })
card('sword_soul', '剑魂', '剑魂', 'rare', nil,
  '剑魂斩击伤害提升，附带溅射效果。',
  '', '', { attack = 5 })

-- 剑宗（普攻触发：剑气风暴）
card('china_pride', '中华傲决', '剑宗', 'epic', nil,
  '每击杀100个敌人获得1层剑气。攻击时有12%概率触发剑气风暴，420半径15跳。',
  '', '', { attack = 10 })
card('phantom_blade_dance', '幻影剑舞', '剑宗', 'rare', nil,
  '剑气风暴持续时间和伤害提升。',
  '', '', { attack = 6 })

-- 龙骑士（普攻触发：火龙吐息）
card('dragon_fire', '龙息', '龙骑士', 'epic', nil,
  '攻击时有概率触发火龙吐息，沿攻击方向穿透敌人造成持续伤害。',
  '', '', { attack = 12 })
card('tail_sweep', '神龙摆尾', '龙骑士', 'rare', nil,
  '火龙吐息附带更宽范围和更高伤害。',
  '', '', { attack = 6 })

-- 战斗法师
card('battle_mage_focus', '魔法专注', '战斗法师', 'epic', nil,
  '攻击时有14%概率触发法术爆发，对420范围造成335%攻击的法术伤害。',
  '', '', { attack = 8 })
card('arcane_affinity', '奥术亲和', '战斗法师', 'rare', nil,
  '战斗法师触发伤害提升，冷却缩短。',
  '', '', { attack = 5 })

-- 魔剑士（击杀触发：入魔）
card('demon_possession', '入魔', '魔剑士', 'epic', nil,
  '每击杀4个敌人有40%概率进入入魔状态6秒，提升最终伤害。',
  '', '', { attack = 10 })
card('demonic_empowerment', '魔化强化', '魔剑士', 'rare', nil,
  '入魔状态下伤害加成提升，持续时间延长。',
  '', '', { attack = 5 })

-- 火法师（周期触发）
card('flame_furnace_shield', '火焰炉盾', '火法师', 'epic', nil,
  '每10秒恢复20%最大生命值，并对周围敌人造成火焰伤害。',
  '', '', { hp_max = 50 })
card('fire_mastery', '火焰精通', '火法师', 'rare', nil,
  '火法师伤害和回复量提升。',
  '', '', { hp_max = 25 })

-- 冰霜法师（周期触发：冰风暴）
card('frost_storm', '冰霜风暴', '冰霜法师', 'epic', nil,
  '每4秒在周围召唤冰霜风暴，460半径8跳，造成攻击+最大生命值双系数伤害。',
  '', '', { hp_max = 40 })
card('ice_barrier', '寒冰屏障', '冰霜法师', 'rare', nil,
  '冰霜风暴附带减速效果，持续时间延长。',
  '', '', { hp_max = 20 })

-- 雷电法王（周期触发：连锁闪电）
card('lightning_invocation', '引雷咒', '雷电法王', 'epic', nil,
  '每0.75秒对4个敌人释放连锁闪电，造成65%攻击伤害。',
  '', '', { attack_speed = 6 })
card('thunder_lord_wrath', '雷神之怒', '雷电法王', 'rare', nil,
  '闪电目标数和伤害提升。',
  '', '', { attack_speed = 3 })

-- 猎人（周期触发：召唤猎兽）
card('natures_body', '自然之体', '猎人', 'epic', nil,
  '每30秒召唤灵鹿辅助战斗，继承28%攻击+26%生命值，持续23秒。',
  '', '', { attack_speed = 5 })
card('summon_hawk', '召唤猎鹰', '猎人', 'rare', nil,
  '额外召唤猎鹰，继承48%攻击+16%生命值。',
  '', '', { attack_speed = 3 })

-- 骷髅法师（周期触发：召唤骷髅）
card('skeleton_revive', '骷髅复苏', '骷髅法师', 'epic', nil,
  '每30秒召唤骷髅战士辅助战斗，继承34%攻击+22%生命值，持续25秒。',
  '', '', { hp_max = 35 })
card('skeleton_dominance', '骷髅支配', '骷髅法师', 'rare', nil,
  '骷髅召唤数量+1，属性继承提升。',
  '', '', { hp_max = 20 })

-- ========================
-- 独立单卡（不属于任何羁绊套装，纯单卡效果）
-- ========================
card('gale_bow', '疾风弓', '_none_', 'rare', nil,
  '每层效果提升5攻击速度，最多叠加10层，持续5秒。',
  '', '', { attack_speed = 3 })
card('bloodthirst', '嗜血', '_none_', 'rare', nil,
  '每次普攻恢复1%最大生命值。',
  '', '', { hp_max = 15 })
card('rapid_fire', '连射', '_none_', 'rare', nil,
  '普攻额外射出1支箭矢（多重+1）。',
  '', '', { attack_speed = 4 })

return M
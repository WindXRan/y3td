local M = {}

M.version = '2026-04-29.bond_runtime_rules.v4_production_finish_pass'
M.presentation_defaults = {
  persistent_area_warmup = 0.05,
  instant_warmup = 0.02,
  default_fx_pulse_every = 3,
}

-- 羁绊技能：普攻触发类规则
M.bond_basic_attack = {
  ['枪炮师'] = {
    chance = 0.12,
    wave_count_default = 1,
    wave_count_with_tactical_reposition = 2,
    wave_damage_attack_ratio = 2.8,
    wave_damage_three_attr_ratio = 1.20,
    line = {
      distance = 1600,
      width = 240,
      max_targets = 'max',
      target_fx_scale = 1.08,
      target_fx_time = 0.28,
      hit_fx_scale = 0.96,
      hit_fx_time = 0.22,
      instant_hit = true,
    },
  },
  ['神射手'] = {
    chance = 0.16,
    damage_attack_ratio = 1.85,
    damage_attack_speed_ratio = 0.80,
    line_aoe_radius = 220,
    line_aoe_ratio = 0.72,
  },
  ['游侠'] = {
    chance = 0.12,
    arrow_rain = {
      radius = 420,
      tick_count = 5,
      tick_interval = 0.55,
      tick_damage_attack_ratio = 0.92,
      fx_pulse_every = 2,
    },
  },
  ['狂战士'] = {
    chance = 0.34,
    damage_attack_ratio = 0.11,
    damage_missing_hp_ratio = 0.06,
  },
  ['剑魂'] = {
    hit_count_trigger = 8,
    damage_attack_ratio = 1.8,
  },
  ['剑宗'] = {
    chance = 0.12,
    storm_radius = 420,
    tick_count = 18,
    tick_interval = 0.14,
    tick_damage_attack_ratio = 0.10,
    tick_damage_sword_intent_ratio = 2.4,
    spoke_count = 6,
    spoke_rotation_delta = 0.24,
    spoke_radius_ratio = 0.76,
    edge_scale_ratio = 0.72,
    edge_scale_floor = 0.65,
    fx_pulse_every = 3,
  },
  ['龙骑士'] = {
    trigger_floor_default = 0.08,
    trigger_floor_with_crit_card = 0.15,
  },
  ['战斗法师'] = {
    chance = 0.14,
    aoe_radius = 420,
    damage_attack_ratio = 3.35,
    damage_type = '法术',
  },
  ['魔剑士'] = {
    demon_damage_attack_ratio = 2.0,
  },
}

-- 羁绊技能：周期触发类规则
M.bond_periodic = {
  ['火法师'] = {
    interval = 2.4,
    damage_attack_ratio = 3.0,
    splash_radius = 460,
    splash_damage_attack_ratio = 1.6,
    damage_type = '法术',
  },
  ['冰霜法师'] = {
    interval = 4.0,
    storm_radius = 460,
    tick_count = 8,
    tick_interval = 0.32,
    tick_damage_attack_ratio = 0.20,
    tick_damage_max_hp_ratio = 0.01,
    fx_pulse_every = 2,
    damage_type = '法术',
  },
  ['猎人'] = {
    interval = 30.0,
    summon_duration = 23.0,
    summon_kind = 'magic_deer',
  },
  ['雷电法王'] = {
    interval = 0.75,
    bolts_per_tick = 4,
    base_target_count = 4,
    min_target_count = 1,
    max_target_count = 8,
    damage_ratio_default = 0.68,
    damage_ratio_with_talent = 0.98,
    range = 1200,
    runtime_bonus_key = 'lightning_target_count',
    card_bonus_target_count = 6,
  },
  ['骷髅法师'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
  },
}

-- 单羁绊卡：普攻触发规则
M.card_basic_attack = {
  ['BBQ'] = {
    chance = 0.12,
    aoe_radius = 380,
    damage_attack_ratio = 3.4,
    damage_type = '物理',
    visual_bond = '枪炮师',
  },
  ['穿云箭'] = {
    chance = 0.16,
    damage_attack_ratio = 1.85,
    damage_attack_speed_ratio = 0.80,
    line_aoe_radius = 220,
    line_aoe_ratio = 0.70,
    damage_type = '物理',
    visual_bond = '神射手',
  },
  ['穿甲射击'] = {
    chance = 0.16,
    damage_attack_ratio = 1.85,
    damage_attack_speed_ratio = 0.80,
    line_aoe_radius = 220,
    line_aoe_ratio = 0.70,
    damage_type = '物理',
    visual_bond = '神射手',
  },
  ['嗜血'] = {
    heal_max_hp_ratio = 0.01,
  },
  ['毒蛇钉刺'] = {
    chance = 0.14,
    aoe_radius = 420,
    damage_attack_ratio = 2.2,
    damage_type = '物理',
    visual_bond = '游侠',
  },
  ['毒箭雨'] = {
    chance = 0.12,
    visual_bond = '游侠',
  },
  ['敏锐'] = {
    chance = 0.12,
    visual_bond = '游侠',
  },
  ['坚韧'] = {
    chance = 0.12,
    visual_bond = '游侠',
  },
  ['毒前雨'] = {
    chance = 0.13,
    visual_bond = '游侠',
  },
  ['疾风弓'] = {
    stack_duration = 5.0,
    max_stacks = 10,
    attack_per_stack = 0,
    attack_speed_per_stack = 5,
  },
  ['幻影剑舞'] = {
    chance = 0.30,
    stack_duration = 5.0,
    max_stacks = 10,
    attack_per_stack = 20,
    attack_speed_per_stack = 2,
  },
  ['斩击'] = {
    hit_count_trigger = 8,
    damage_attack_ratio = 1.8,
    damage_type = '物理',
    visual_bond = '剑魂',
  },
  ['剑魂'] = {
    hit_count_trigger = 8,
    damage_attack_ratio = 1.8,
    damage_type = '物理',
    visual_bond = '剑魂',
  },
  ['狂刀斩'] = {
    chance = 0.30,
    damage_attack_ratio = 0.10,
    damage_missing_hp_ratio = 0.05,
    damage_type = '物理',
    visual_bond = '狂战士',
  },
  ['重甲精通'] = {
    chance = 0.30,
    damage_attack_ratio = 0.10,
    damage_missing_hp_ratio = 0.05,
    damage_type = '物理',
    visual_bond = '狂战士',
  },
  ['力量唤醒'] = {
    chance = 0.30,
    damage_attack_ratio = 0.10,
    damage_missing_hp_ratio = 0.05,
    damage_type = '物理',
    visual_bond = '狂战士',
  },
}

M.card_arrow_rain = {
  radius = 420,
  tick_count = 5,
  tick_interval = 0.55,
  tick_damage_attack_ratio = 0.92,
  fx_pulse_every = 2,
}

-- 单羁绊卡：周期触发规则
M.card_periodic = {
  ['连射'] = {
    multishot = 1,
  },
  ['火焰炉盾'] = {
    interval = 10.0,
    heal_max_hp_ratio = 0.20,
    visual_bond = '火法师',
  },
  ['引雷咒'] = {
    interval = 0.75,
    base_target_count = 3,
    bonus_target_count = 6,
    damage_ratio_default = 0.72,
    damage_ratio_with_talent = 0.98,
    range = 1200,
    visual_bond = '雷电法王',
  },
  ['自然之体'] = {
    interval = 30.0,
    summon_duration = 23.0,
    summon_kind = 'magic_deer',
    visual_bond = '猎人',
  },
  ['猎人'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'magic_bear',
    visual_bond = '猎人',
  },
  ['奔袭'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'magic_bear',
    visual_bond = '猎人',
  },
  ['召唤猎鹰'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'hawk',
    visual_bond = '猎人',
  },
  ['骷髅复苏'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['骷髅支配'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['骷髅恐惧'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['骷髅压制'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['骷髅审判'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['狂化'] = {
    cycle_interval = 2.0,
    frenzy_duration = 5.0,
    all_damage_bonus = 1.0,
    visual_bond = '狂战士',
  },
}

-- 单羁绊卡：击杀事件触发规则
M.card_kill = {
  ['入魔'] = {
    kill_threshold = 4,
    trigger_chance = 0.40,
    demon_duration = 6.0,
    visual_bond = '魔剑士',
  },
  ['中华傲决'] = {
    kill_threshold = 100,
    sword_intent_gain = 1,
    visual_bond = '剑宗',
  },
}

-- 龙骑士火龙穿透规则（由主羁绊与卡牌共同读取）
M.dragon_fireball = {
  line_distance_default = 1560,
  line_distance_with_tail_sweep = 1840,
  line_width_default = 250,
  line_width_with_tail_sweep = 360,
  width_scale_with_tail_sweep = 1.20,
  min_width = 160,
  pierce_width_ratio = 0.76,
  min_pierce_width = 140,
  tick_interval = 0.10,
}

-- 召唤物继承档案
M.summon_inherit_profiles = {
  default = {
    attack_ratio = 0.35,
    hp_ratio = 0.20,
    attack_bonus_ratio = 1.00,
    hp_bonus_ratio = 0.60,
  },
  magic_deer = {
    attack_ratio = 0.28,
    hp_ratio = 0.26,
    attack_bonus_ratio = 0.80,
    hp_bonus_ratio = 0.70,
  },
  magic_bear = {
    attack_ratio = 0.40,
    hp_ratio = 0.24,
    attack_bonus_ratio = 1.00,
    hp_bonus_ratio = 0.65,
  },
  hawk = {
    attack_ratio = 0.48,
    hp_ratio = 0.16,
    attack_bonus_ratio = 1.20,
    hp_bonus_ratio = 0.45,
  },
  skeleton = {
    attack_ratio = 0.34,
    hp_ratio = 0.22,
    attack_bonus_ratio = 0.95,
    hp_bonus_ratio = 0.60,
  },
}

-- 运行时状态效果预设
M.status_runtime_presets = {
  magic_swordsman_demon = {
    name = '入魔',
    description = '入魔：提升最终伤害并强化魔剑士输出。',
    particle_bond = '魔剑士',
    particle_scale = 1.05,
    particle_time = 9999,
    buff_refresh = 1.4,
  },
  berserker_frenzy = {
    name = '狂化',
    description = '狂化：短时间内进入爆发状态。',
    particle_bond = '狂战士',
    particle_scale = 1.00,
    particle_time = 9999,
    buff_refresh = 1.3,
  },
}

return M

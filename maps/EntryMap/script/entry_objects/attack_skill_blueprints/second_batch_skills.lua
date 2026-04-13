local M = {
  version = '2026-04-12',
  status = 'design_in_repo',
  note = '第二批通用攻击技能正式设计蓝图。当前为文档与配表约束源，尚未直接接入 runtime 抽卡与施法逻辑。',
  system = {
    slot_rule = {
      fixed_base_slot = '普攻',
      free_attack_skill_slots = 4,
      total_attack_skills = 5,
      notation = '1 个固定基础位 + 4 个自由攻击技能位',
    },
    run_rule = {
      target_duration_minutes = 30,
      level_cap = 'none',
      xp_curve = 'front_fast_back_slow',
      first_legend_window = '15-20 分钟',
    },
    card_rule = {
      notation = '9 张强化牌 + 1 张终局牌',
      rarity_plan = {
        common = 3,
        excellent = 3,
        rare = 3,
        legendary = 1,
      },
      atomicity = '除传奇牌外，单张卡默认只承载一类核心成长方向。',
      growth_lanes = {
        'damage',
        'frequency',
        'function',
        'range',
        'count',
        'form',
        'state',
        'elite',
        'trigger',
      },
    },
  },
  list = {
    {
      id = 'sword_wave',
      name = '剑气',
      damage_type = '物系物理',
      damage_form = 'weapon',
      element = 'metal',
      damage_label = '金行剑罡',
      archetype = '直线贯穿清怪',
      base = {
        damage_ratio = 1.60,
        cooldown = 4.5,
        pierce = 2,
      },
      evolution = {
        id = 'mountain_breaker_wave',
        name = '崩山剑气',
        summary = '剑气进阶为宽幅重压斩，成为中后期直线清场主核。',
      },
      cards = {
        common = {
          { id = 'sword_wave_damage', name = '剑压增幅', lane = 'damage', rarity = '普通', summary = '剑气伤害 +60%。' },
          { id = 'sword_wave_frequency', name = '迅斩回息', lane = 'frequency', rarity = '普通', summary = '冷却 -20%。' },
          { id = 'sword_wave_function', name = '裂锋', lane = 'function', rarity = '普通', summary = '穿透 +2。' },
        },
        excellent = {
          { id = 'sword_wave_range', name = '长风破', lane = 'range', rarity = '优秀', summary = '飞行距离 +70%。' },
          { id = 'sword_wave_count', name = '双锋并出', lane = 'count', rarity = '优秀', summary = '数量 +1，单道伤害 -20%。' },
          { id = 'sword_wave_form', name = '回旋剑压', lane = 'form', rarity = '优秀', summary = '释放后延迟回斩 1 次，回斩造成 70% 原伤害。' },
        },
        rare = {
          { id = 'sword_wave_state', name = '断筋剑痕', lane = 'state', rarity = '稀有', summary = '命中后附加破甲，使目标受到物系物理伤害 +15%，持续 4 秒。' },
          { id = 'sword_wave_elite', name = '斩钢', lane = 'elite', rarity = '稀有', summary = '对精英与 Boss 额外造成 +80% 伤害。' },
          { id = 'sword_wave_trigger', name = '真空裂隙', lane = 'trigger', rarity = '稀有', summary = '命中 3 名以上敌人时，在路径末端追加 1 道小型裂斩。' },
        },
        legendary = {
          { id = 'sword_wave_legend', name = '崩山剑气', lane = 'legendary', rarity = '传奇', summary = '剑气宽度大幅提升，基础伤害 +120%，并在终点落下 1 次重压震击。' },
        },
      },
    },
    {
      id = 'arcane_laser',
      name = '奥术激光',
      damage_type = '能量魔法',
      damage_form = 'spell',
      element = 'metal',
      damage_label = '金行灵光',
      archetype = '持续照射压制',
      base = {
        damage_ratio = 0.90,
        cooldown = 8.0,
        duration = 1.5,
      },
      evolution = {
        id = 'disintegration_stream',
        name = '崩解射流',
        summary = '激光进阶为持续崩解流，擅长撕开高密敌群与高血量目标。',
      },
      cards = {
        common = {
          { id = 'arcane_laser_damage', name = '激光增幅', lane = 'damage', rarity = '普通', summary = '奥术激光总伤害 +60%。' },
          { id = 'arcane_laser_frequency', name = '虚空聚焦', lane = 'frequency', rarity = '普通', summary = '冷却 -18%。' },
          { id = 'arcane_laser_function', name = '稳相束流', lane = 'function', rarity = '普通', summary = '持续时间 +0.8 秒。' },
        },
        excellent = {
          { id = 'arcane_laser_range', name = '长距照射', lane = 'range', rarity = '优秀', summary = '照射长度 +65%。' },
          { id = 'arcane_laser_count', name = '棱镜副束', lane = 'count', rarity = '优秀', summary = '结束时额外分裂 1 束副激光，副激光造成 65% 伤害。' },
          { id = 'arcane_laser_form', name = '扫射激光', lane = 'form', rarity = '优秀', summary = '释放期间自动横扫，覆盖更大的扇形区域。' },
        },
        rare = {
          { id = 'arcane_laser_state', name = '奥术灼烧', lane = 'state', rarity = '稀有', summary = '命中附加 4 秒奥术灼烧。' },
          { id = 'arcane_laser_elite', name = '裂核照射', lane = 'elite', rarity = '稀有', summary = '对同一目标持续照射 0.8 秒后，后续段伤害 +90%。' },
          { id = 'arcane_laser_trigger', name = '崩解余辉', lane = 'trigger', rarity = '稀有', summary = '照射结束时，对路径上每个命中过的敌人各追加 1 次小型爆裂。' },
        },
        legendary = {
          { id = 'arcane_laser_legend', name = '崩解射流', lane = 'legendary', rarity = '传奇', summary = '激光可穿透全路径，持续时间 +100%，并对同一目标逐段增伤。' },
        },
      },
    },
    {
      id = 'arcane_ray',
      name = '奥术射线',
      damage_type = '能量魔法',
      damage_form = 'spell',
      element = 'metal',
      damage_label = '金行灵束',
      archetype = '长线穿透爆发',
      base = {
        damage_ratio = 2.00,
        cooldown = 6.0,
        pierce = 3,
      },
      evolution = {
        id = 'void_ray',
        name = '虚空射线',
        summary = '射线进阶为高爆发湮灭束，专长贯通高威胁目标。',
      },
      cards = {
        common = {
          { id = 'arcane_ray_damage', name = '射线增幅', lane = 'damage', rarity = '普通', summary = '奥术射线伤害 +60%。' },
          { id = 'arcane_ray_frequency', name = '速构棱镜', lane = 'frequency', rarity = '普通', summary = '冷却 -20%。' },
          { id = 'arcane_ray_function', name = '贯通延伸', lane = 'function', rarity = '普通', summary = '穿透 +2。' },
        },
        excellent = {
          { id = 'arcane_ray_range', name = '虚空拉伸', lane = 'range', rarity = '优秀', summary = '射线长度 +70%。' },
          { id = 'arcane_ray_count', name = '射线齐发', lane = 'count', rarity = '优秀', summary = '额外发射 1 束射线，单束伤害 -20%。' },
          { id = 'arcane_ray_form', name = '次元棱镜', lane = 'form', rarity = '优秀', summary = '主射线命中后向两侧各分叉 1 条短射线。' },
        },
        rare = {
          { id = 'arcane_ray_state', name = '奥术崩裂', lane = 'state', rarity = '稀有', summary = '命中会施加脆化，使目标受到能量魔法伤害 +18%，持续 4 秒。' },
          { id = 'arcane_ray_elite', name = '湮灭射线', lane = 'elite', rarity = '稀有', summary = '首个命中目标额外承受 100% 攻击的能量魔法伤害。' },
          { id = 'arcane_ray_trigger', name = '裂界追光', lane = 'trigger', rarity = '稀有', summary = '击杀敌人时，对其身后延伸再释放 1 次短射线。' },
        },
        legendary = {
          { id = 'arcane_ray_legend', name = '虚空射线', lane = 'legendary', rarity = '传奇', summary = '奥术射线伤害 +120%，并无视部分护甲与魔抗。' },
        },
      },
    },
    {
      id = 'frost_nova',
      name = '冰霜新星',
      damage_type = '冰系魔法',
      damage_form = 'spell',
      element = 'water',
      damage_label = '水行寒潮',
      archetype = '近身爆发控场',
      base = {
        damage_ratio = 1.50,
        cooldown = 8.5,
        radius = 260,
      },
      evolution = {
        id = 'glacial_domain',
        name = '极寒领域',
        summary = '新星进阶为持续冰域，兼顾近身保命与控场输出。',
      },
      cards = {
        common = {
          { id = 'frost_nova_damage', name = '新星增幅', lane = 'damage', rarity = '普通', summary = '冰霜新星伤害 +60%。' },
          { id = 'frost_nova_frequency', name = '寒息轮转', lane = 'frequency', rarity = '普通', summary = '冷却 -18%。' },
          { id = 'frost_nova_function', name = '冻结延长', lane = 'function', rarity = '普通', summary = '冻结时间 +0.8 秒。' },
        },
        excellent = {
          { id = 'frost_nova_range', name = '寒潮扩张', lane = 'range', rarity = '优秀', summary = '范围 +60%。' },
          { id = 'frost_nova_count', name = '低温回响', lane = 'count', rarity = '优秀', summary = '额外释放 1 次回响新星，回响造成 65% 伤害。' },
          { id = 'frost_nova_form', name = '冰爆碎片', lane = 'form', rarity = '优秀', summary = '释放后向外飞出 8 枚冰片。' },
        },
        rare = {
          { id = 'frost_nova_state', name = '冻伤蔓延', lane = 'state', rarity = '稀有', summary = '被冻结敌人向周围扩散 1 层冻伤。' },
          { id = 'frost_nova_elite', name = '寒狱压制', lane = 'elite', rarity = '稀有', summary = '对精英与 Boss 额外造成 +80% 伤害，且减速效果强化。' },
          { id = 'frost_nova_trigger', name = '碎冰连爆', lane = 'trigger', rarity = '稀有', summary = '冻结目标死亡时，在原地触发 1 次小型冰爆。' },
        },
        legendary = {
          { id = 'frost_nova_legend', name = '极寒领域', lane = 'legendary', rarity = '传奇', summary = '释放后原地形成 4 秒极寒领域，持续冻结并追加冰爆。' },
        },
      },
    },
    {
      id = 'chain_lightning',
      name = '闪电链',
      damage_type = '电系魔法',
      damage_form = 'spell',
      element = 'wood',
      damage_label = '木行雷链',
      archetype = '连锁清怪扩散',
      base = {
        damage_ratio = 1.20,
        cooldown = 5.5,
        bounce = 5,
      },
      evolution = {
        id = 'eternal_thunder_chain',
        name = '永续雷链',
        summary = '雷链进阶为终盘扩散核，后续弹射稳定清场。',
      },
      cards = {
        common = {
          { id = 'chain_lightning_damage', name = '链击增幅', lane = 'damage', rarity = '普通', summary = '闪电链伤害 +60%。' },
          { id = 'chain_lightning_frequency', name = '高频放电', lane = 'frequency', rarity = '普通', summary = '冷却 -20%。' },
          { id = 'chain_lightning_function', name = '连锁扩展', lane = 'function', rarity = '普通', summary = '弹射次数 +3。' },
        },
        excellent = {
          { id = 'chain_lightning_range', name = '导链延伸', lane = 'range', rarity = '优秀', summary = '弹射距离 +60%。' },
          { id = 'chain_lightning_count', name = '双重导链', lane = 'count', rarity = '优秀', summary = '额外释放 1 次雷链，单条伤害 -20%。' },
          { id = 'chain_lightning_form', name = '超载电流', lane = 'form', rarity = '优秀', summary = '弹射完成后在末端额外引爆 1 次电爆。' },
        },
        rare = {
          { id = 'chain_lightning_state', name = '感电扩散', lane = 'state', rarity = '稀有', summary = '命中附加感电，使目标受到电系伤害 +18%。' },
          { id = 'chain_lightning_elite', name = '高压导体', lane = 'elite', rarity = '稀有', summary = '对精英与 Boss 命中时额外追加 1 段高压雷击。' },
          { id = 'chain_lightning_trigger', name = '回流电弧', lane = 'trigger', rarity = '稀有', summary = '命中 5 次以上时，从终点向起点回弹 1 次。' },
        },
        legendary = {
          { id = 'chain_lightning_legend', name = '永续雷链', lane = 'legendary', rarity = '传奇', summary = '后续弹射不再衰减伤害，并在感电目标间优先传播。' },
        },
      },
    },
    {
      id = 'earthquake',
      name = '地震',
      damage_type = '物系物理',
      damage_form = 'weapon',
      element = 'earth',
      damage_label = '土行震罡',
      archetype = '范围爆发减速',
      base = {
        damage_ratio = 2.20,
        cooldown = 9.0,
        radius = 280,
      },
      evolution = {
        id = 'landslide',
        name = '山崩',
        summary = '地震进阶为多段裂地核心，兼顾压制与补刀。',
      },
      cards = {
        common = {
          { id = 'earthquake_damage', name = '震波增幅', lane = 'damage', rarity = '普通', summary = '地震伤害 +60%。' },
          { id = 'earthquake_frequency', name = '地脉回震', lane = 'frequency', rarity = '普通', summary = '冷却 -18%。' },
          { id = 'earthquake_function', name = '震荡减速', lane = 'function', rarity = '普通', summary = '减速效果 +25%。' },
        },
        excellent = {
          { id = 'earthquake_range', name = '震域扩张', lane = 'range', rarity = '优秀', summary = '作用范围 +60%。' },
          { id = 'earthquake_count', name = '裂地余波', lane = 'count', rarity = '优秀', summary = '结束后追加 1 次余波，余波造成 70% 伤害。' },
          { id = 'earthquake_form', name = '岩刺突起', lane = 'form', rarity = '优秀', summary = '中心生成岩刺带，持续造成物系物理伤害。' },
        },
        rare = {
          { id = 'earthquake_state', name = '断层压制', lane = 'state', rarity = '稀有', summary = '命中后施加破势，目标造成的移动速度降低。' },
          { id = 'earthquake_elite', name = '重压地鸣', lane = 'elite', rarity = '稀有', summary = '首次命中精英与 Boss 时附带 0.6 秒击飞并额外 +80% 伤害。' },
          { id = 'earthquake_trigger', name = '崩裂追击', lane = 'trigger', rarity = '稀有', summary = '每命中 6 名敌人，在最外环追加 1 圈裂地冲击。' },
        },
        legendary = {
          { id = 'earthquake_legend', name = '山崩', lane = 'legendary', rarity = '传奇', summary = '地震进阶为连续裂地，基础伤害 +120%，并在持续期间反复掀起岩浪。' },
        },
      },
    },
    {
      id = 'tornado',
      name = '龙卷风',
      damage_type = '风系魔法',
      damage_form = 'spell',
      element = 'wood',
      damage_label = '木行罡风',
      archetype = '移动压制拖拽',
      base = {
        damage_ratio = 0.80,
        cooldown = 8.0,
        duration = 4.0,
      },
      evolution = {
        id = 'eye_of_storm_king',
        name = '风王之眼',
        summary = '龙卷进阶为追踪型压制核，承担中后期持续切割。',
      },
      cards = {
        common = {
          { id = 'tornado_damage', name = '风刃增幅', lane = 'damage', rarity = '普通', summary = '龙卷风总伤害 +60%。' },
          { id = 'tornado_frequency', name = '风脉轮转', lane = 'frequency', rarity = '普通', summary = '冷却 -18%。' },
          { id = 'tornado_function', name = '风压牵引', lane = 'function', rarity = '普通', summary = '拉扯力度 +50%。' },
        },
        excellent = {
          { id = 'tornado_range', name = '龙卷扩张', lane = 'range', rarity = '优秀', summary = '范围 +50%。' },
          { id = 'tornado_count', name = '双生龙卷', lane = 'count', rarity = '优秀', summary = '额外召唤 1 个龙卷风，单个伤害 -20%。' },
          { id = 'tornado_form', name = '切割风眼', lane = 'form', rarity = '优秀', summary = '中心区域额外造成高频切割伤害。' },
        },
        rare = {
          { id = 'tornado_state', name = '风蚀', lane = 'state', rarity = '稀有', summary = '被卷入敌人受到风系伤害 +18%。' },
          { id = 'tornado_elite', name = '飓压猎杀', lane = 'elite', rarity = '稀有', summary = '对精英与 Boss 的拉扯减半，但伤害额外 +90%。' },
          { id = 'tornado_trigger', name = '风尾回扫', lane = 'trigger', rarity = '稀有', summary = '龙卷结束时在终点留下 1 次回扫风刃。' },
        },
        legendary = {
          { id = 'tornado_legend', name = '风王之眼', lane = 'legendary', rarity = '传奇', summary = '龙卷风持续期间自动追踪高威胁目标，并获得额外切割层。' },
        },
      },
    },
    {
      id = 'electro_net',
      name = '电磁网',
      damage_type = '电系魔法',
      damage_form = 'spell',
      element = 'wood',
      damage_label = '木行雷网',
      archetype = '范围束缚控制',
      base = {
        damage_ratio = 1.40,
        cooldown = 8.0,
        radius = 240,
      },
      evolution = {
        id = 'forbidden_field',
        name = '禁锢领域',
        summary = '电磁网进阶为禁锢场，负责稳定定怪与电场压制。',
      },
      cards = {
        common = {
          { id = 'electro_net_damage', name = '电网增幅', lane = 'damage', rarity = '普通', summary = '电磁网伤害 +60%。' },
          { id = 'electro_net_frequency', name = '充能回路', lane = 'frequency', rarity = '普通', summary = '冷却 -18%。' },
          { id = 'electro_net_function', name = '束缚延长', lane = 'function', rarity = '普通', summary = '束缚时间 +0.8 秒。' },
        },
        excellent = {
          { id = 'electro_net_range', name = '电网扩张', lane = 'range', rarity = '优秀', summary = '范围 +60%。' },
          { id = 'electro_net_count', name = '网格增殖', lane = 'count', rarity = '优秀', summary = '额外生成 1 张小型电磁网，小网造成 65% 伤害。' },
          { id = 'electro_net_form', name = '连锁电弧', lane = 'form', rarity = '优秀', summary = '网中的敌人会向邻近目标释放电弧。' },
        },
        rare = {
          { id = 'electro_net_state', name = '电荷囚笼', lane = 'state', rarity = '稀有', summary = '被束缚目标附加感电，受到电系伤害 +20%。' },
          { id = 'electro_net_elite', name = '高压电网', lane = 'elite', rarity = '稀有', summary = '对精英与 Boss 造成 +80% 伤害，并提高束缚期间的段伤。' },
          { id = 'electro_net_trigger', name = '过载短路', lane = 'trigger', rarity = '稀有', summary = '束缚结束时引爆电场，对区域内敌人造成 1 次爆炸。' },
        },
        legendary = {
          { id = 'electro_net_legend', name = '禁锢领域', lane = 'legendary', rarity = '传奇', summary = '电磁网进阶为持续领域，区域内敌人反复受到束缚与电击。' },
        },
      },
    },
    {
      id = 'meteor',
      name = '陨石',
      damage_type = '火系物理',
      damage_form = 'spell',
      element = 'fire',
      damage_label = '火行陨炎',
      archetype = '高爆发范围终结',
      base = {
        damage_ratio = 3.00,
        cooldown = 10.0,
        radius = 300,
      },
      evolution = {
        id = 'worldfall_meteor',
        name = '灭世陨星',
        summary = '陨石进阶为终盘高爆发主核，承担清场与斩首双职责。',
      },
      cards = {
        common = {
          { id = 'meteor_damage', name = '陨石增幅', lane = 'damage', rarity = '普通', summary = '陨石伤害 +60%。' },
          { id = 'meteor_frequency', name = '坠星预热', lane = 'frequency', rarity = '普通', summary = '冷却 -16%。' },
          { id = 'meteor_function', name = '震荡冲击', lane = 'function', rarity = '普通', summary = '命中附带 0.8 秒击飞。' },
        },
        excellent = {
          { id = 'meteor_range', name = '陨火扩张', lane = 'range', rarity = '优秀', summary = '爆炸范围 +60%。' },
          { id = 'meteor_count', name = '双星坠落', lane = 'count', rarity = '优秀', summary = '额外召唤 1 颗陨石，单颗伤害 -20%。' },
          { id = 'meteor_form', name = '熔岩碎片', lane = 'form', rarity = '优秀', summary = '落地后飞散 6 枚熔岩碎片。' },
        },
        rare = {
          { id = 'meteor_state', name = '燃烧地带', lane = 'state', rarity = '稀有', summary = '落点形成 4 秒熔岩地带。' },
          { id = 'meteor_elite', name = '天坠处决', lane = 'elite', rarity = '稀有', summary = '对高生命目标额外造成 +90% 伤害。' },
          { id = 'meteor_trigger', name = '余震流火', lane = 'trigger', rarity = '稀有', summary = '命中 5 名以上敌人时，额外降下 1 颗小陨火。' },
        },
        legendary = {
          { id = 'meteor_legend', name = '灭世陨星', lane = 'legendary', rarity = '传奇', summary = '陨石伤害 +120%，落地后持续喷发火浪，成为终盘爆发主核。' },
        },
      },
    },
    {
      id = 'hurricane',
      name = '飓风',
      damage_type = '风系魔法',
      damage_form = 'spell',
      element = 'wood',
      damage_label = '木行飓流',
      archetype = '聚怪切割持续场',
      base = {
        damage_ratio = 1.00,
        cooldown = 8.5,
        duration = 3.5,
      },
      evolution = {
        id = 'rift_hurricane',
        name = '裂界飓风',
        summary = '飓风进阶为高覆盖聚怪核，承担持续场的终盘上限。',
      },
      cards = {
        common = {
          { id = 'hurricane_damage', name = '风暴增幅', lane = 'damage', rarity = '普通', summary = '飓风总伤害 +60%。' },
          { id = 'hurricane_frequency', name = '风场轮转', lane = 'frequency', rarity = '普通', summary = '冷却 -18%。' },
          { id = 'hurricane_function', name = '狂岚牵引', lane = 'function', rarity = '普通', summary = '聚怪力度 +50%。' },
        },
        excellent = {
          { id = 'hurricane_range', name = '飓风扩张', lane = 'range', rarity = '优秀', summary = '范围 +55%。' },
          { id = 'hurricane_count', name = '双生飓风', lane = 'count', rarity = '优秀', summary = '额外生成 1 道飓风，单道伤害 -20%。' },
          { id = 'hurricane_form', name = '风刃切割', lane = 'form', rarity = '优秀', summary = '边缘区域追加高频风刃切割。' },
        },
        rare = {
          { id = 'hurricane_state', name = '裂风标记', lane = 'state', rarity = '稀有', summary = '被卷入敌人受到风系伤害 +18%。' },
          { id = 'hurricane_elite', name = '风暴围猎', lane = 'elite', rarity = '稀有', summary = '对精英与 Boss 造成 +85% 伤害。' },
          { id = 'hurricane_trigger', name = '乱流回环', lane = 'trigger', rarity = '稀有', summary = '持续结束时在原地再留下一圈短时乱流。' },
        },
        legendary = {
          { id = 'hurricane_legend', name = '裂界飓风', lane = 'legendary', rarity = '传奇', summary = '飓风持续时间 +100%，切割层数大幅提高，并强化聚怪能力。' },
        },
      },
    },
    {
      id = 'fireball',
      name = '火球',
      damage_type = '火系魔法',
      damage_form = 'spell',
      element = 'fire',
      damage_label = '火行炎术',
      archetype = '点面兼顾爆炸',
      base = {
        damage_ratio = 1.80,
        cooldown = 4.8,
        radius = 200,
      },
      evolution = {
        id = 'doomsday_firestar',
        name = '末日炎星',
        summary = '火球进阶为高频爆裂核，兼顾直伤与灼烧收尾。',
      },
      cards = {
        common = {
          { id = 'fireball_damage', name = '火球增幅', lane = 'damage', rarity = '普通', summary = '火球伤害 +60%。' },
          { id = 'fireball_frequency', name = '炎核回转', lane = 'frequency', rarity = '普通', summary = '冷却 -20%。' },
          { id = 'fireball_function', name = '灼烧附着', lane = 'function', rarity = '普通', summary = '命中附加 4 秒持续燃烧。' },
        },
        excellent = {
          { id = 'fireball_range', name = '爆裂扩张', lane = 'range', rarity = '优秀', summary = '爆炸范围 +60%。' },
          { id = 'fireball_count', name = '双生火球', lane = 'count', rarity = '优秀', summary = '额外发射 1 枚火球，单枚伤害 -20%。' },
          { id = 'fireball_form', name = '余焰飞弹', lane = 'form', rarity = '优秀', summary = '爆炸后飞散 6 枚余焰飞弹。' },
        },
        rare = {
          { id = 'fireball_state', name = '爆燃火种', lane = 'state', rarity = '稀有', summary = '燃烧中的敌人死亡时扩散燃烧。' },
          { id = 'fireball_elite', name = '炎核处决', lane = 'elite', rarity = '稀有', summary = '对低生命精英与 Boss 造成 +100% 额外伤害。' },
          { id = 'fireball_trigger', name = '烈焰回响', lane = 'trigger', rarity = '稀有', summary = '每第 3 次命中时，在目标点追加 1 次小型回响爆炸。' },
        },
        legendary = {
          { id = 'fireball_legend', name = '末日炎星', lane = 'legendary', rarity = '传奇', summary = '火球伤害 +120%，爆炸半径大幅提高，并强化灼烧收尾能力。' },
        },
      },
    },
  },
}

return M

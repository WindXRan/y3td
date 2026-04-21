package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local model = require 'runtime.choice_panel_model'

local STATE = {
  choice_panel_hidden = false,
  current_upgrade_choices = {
    {
      key = 'upgrade_a',
      skill_id = 'basic_attack',
      name = '测试强化',
      desc = '测试描述',
    },
  },
  current_upgrade_round = {
    free_refresh_left = 0,
    refresh_paid_count = 2,
  },
  resources = {
    wood = 999,
  },
}

local api = model.create({
  STATE = STATE,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {
    basic_attack = {
      name = '普攻',
    },
  },
  TREASURE_DEFS = {},
  get_pending_round_choice_kind = function()
    return 'upgrade'
  end,
  get_treasure_runtime = function()
    return {}
  end,
  get_treasure_quality_label = function(quality)
    return quality
  end,
  get_treasure_active_count = function()
    return 0
  end,
  pick_treasure_choices = function()
    return {}
  end,
  create_bond_env = function()
    return {}
  end,
  refresh_upgrade_choices = function()
    return true
  end,
})

local panel = api.get_current_choice_panel_model()
assert(panel ~= nil, 'choice panel model should exist')
assert(panel.refresh.wood_cost == 100, 'choice panel should use config-backed refresh cost')
assert(panel.cards[1].badge_text == 'N', 'upgrade card should use config-backed badge text')
assert(panel.cards[1].use_item_desc_card == true, 'upgrade card should opt into item desc card rendering')
assert(type(panel.cards[1].item_desc_payload) == 'table', 'upgrade card should expose item desc payload')
assert(panel.cards[1].item_desc_payload.title_text == '测试强化', 'upgrade template should use the upgrade entry name as title')
assert(panel.cards[1].item_desc_payload.subtitle_text == '普攻', 'upgrade template should use the target skill name as subtitle')
assert(panel.cards[1].item_desc_payload.cost_text == '强化', 'upgrade template should expose the strengthen label')
assert(panel.cards[1].item_desc_payload.attr_lines[1] == '卡牌类型：技能强化', 'upgrade template should describe the reward type in attrs')
assert(panel.cards[1].item_desc_payload.attr_lines[2] == '作用技能：普攻', 'upgrade template should expose the target skill in attrs')
assert(panel.cards[1].item_desc_payload.affix_lines[1].title == '技能说明', 'upgrade item desc should expose skill summary section')
assert(panel.cards[1].item_desc_payload.affix_lines[2].title == '强化效果', 'upgrade item desc should expose upgrade effect section')

local gear_state = {
  choice_panel_hidden = false,
  gear_state = {
    awaiting_choice = true,
    current_choices = {
      {
        id = 'gear_common',
        level = 10,
        quality = 'common',
        display_name = '砺锋',
        summary = '攻击 +30，适合稳定抬高成长武器白值',
        bonus_pack = {
          ['攻击'] = 30,
        },
      },
      {
        id = 'gear_rare',
        level = 10,
        quality = 'rare',
        display_name = '重弓',
        summary = '力量 +60，同时提高力量成长收益',
        bonus_pack = {
          ['力量'] = 60,
        },
      },
      {
        id = 'gear_epic',
        level = 10,
        quality = 'epic',
        display_name = '猎心',
        summary = '普攻伤害 +10%，并额外获得 20 攻击',
        bonus_pack = {
          ['攻击'] = 20,
          ['普攻伤害'] = 0.10,
        },
      },
    },
  },
  resources = {
    wood = 999,
  },
}

local gear_api = model.create({
  STATE = gear_state,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {},
  TREASURE_DEFS = {},
  get_pending_round_choice_kind = function()
    return 'gear'
  end,
  get_treasure_runtime = function()
    return {}
  end,
  get_treasure_quality_label = function(quality)
    return quality
  end,
  get_treasure_active_count = function()
    return 0
  end,
  pick_treasure_choices = function()
    return {}
  end,
  create_bond_env = function()
    return {}
  end,
  refresh_upgrade_choices = function()
    return true
  end,
})

local gear_panel = gear_api.get_current_choice_panel_model()
assert(gear_panel ~= nil, 'gear choice panel model should exist')
assert(gear_panel.kind == 'gear', 'gear panel should expose gear kind')
assert(gear_panel.panel_title == '成长武器词条', 'gear panel should expose dedicated panel title')
assert(gear_panel.refresh.visible == false, 'gear panel should hide refresh action')
assert(gear_panel.cards[1].badge_text == 'N', 'gear common card should use common badge text')
assert(gear_panel.cards[2].badge_text == 'R', 'gear rare card should use rare badge text')
assert(gear_panel.cards[3].badge_text == 'E', 'gear epic card should use epic badge text')
assert(gear_panel.cards[1].subtitle_text == '普通词条', 'gear card should expose readable quality subtitle')
assert(gear_panel.cards[2].subtitle_text == '稀有词条', 'gear card should expose readable rare subtitle')
assert(gear_panel.cards[3].subtitle_text == '史诗词条', 'gear card should expose readable epic subtitle')
assert(gear_panel.cards[1].use_item_desc_card == true, 'gear card should opt into item desc card rendering')
assert(gear_panel.cards[3].body_blocks[1].text == '攻击 +20\n普攻伤害 +10%', 'gear epic card should summarize structured bonus lines')
assert(gear_panel.cards[3].item_desc_payload.title_text == '猎心', 'gear item desc should use the affix name as title')
assert(gear_panel.cards[3].item_desc_payload.subtitle_text == '成长武器 史诗词条', 'gear item desc should compose slot and quality subtitle')
assert(gear_panel.cards[3].item_desc_payload.cost_text == '史诗词条', 'gear item desc should expose readable quality text')
assert(gear_panel.cards[3].item_desc_payload.attr_lines[1] == '适用槽位：成长武器', 'gear item desc should describe the target slot')
assert(gear_panel.cards[3].item_desc_payload.attr_lines[3] == '攻击 +20', 'gear item desc should list flat bonus lines')
assert(gear_panel.cards[3].item_desc_payload.attr_lines[4] == '普攻伤害 +10%', 'gear item desc should list percent bonus lines')
assert(gear_panel.cards[3].item_desc_payload.affix_lines[1].title == '词条效果', 'gear item desc should expose the summary section')

local bond_state = {
  choice_panel_hidden = false,
  bond_runtime = {
    current_choices = {
      {
        quality = 'rare',
        display_name = '战术',
        title_text = '战术 (1/3)',
        subtitle_text = '破甲',
        advanced_text = '破甲路线成型后，额外获得穿透强化。',
        value_text = '力量+30\n敏捷+10\n\n智力+10',
      },
    },
    current_round = {
      free_refresh_left = 0,
      refresh_paid_count = 1,
    },
  },
  resources = {
    wood = 999,
  },
}

local bond_api = model.create({
  STATE = bond_state,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {},
  TREASURE_DEFS = {},
  get_pending_round_choice_kind = function()
    return 'bond'
  end,
  get_treasure_runtime = function()
    return {}
  end,
  get_treasure_quality_label = function(quality)
    return quality
  end,
  get_treasure_active_count = function()
    return 0
  end,
  pick_treasure_choices = function()
    return {}
  end,
  create_bond_env = function()
    return {}
  end,
  refresh_upgrade_choices = function()
    return true
  end,
})

local bond_panel = bond_api.get_current_choice_panel_model()
assert(bond_panel ~= nil, 'bond choice panel model should exist')
assert(type(bond_panel.cards[1].bonus_lines) == 'table', 'bond card should expose bonus_lines')
assert(bond_panel.cards[1].bonus_lines[1] == '力量+30', 'bond card bonus line 1 should match')
assert(bond_panel.cards[1].bonus_lines[2] == '敏捷+10', 'bond card bonus line 2 should match')
assert(bond_panel.cards[1].bonus_lines[3] == '智力+10', 'bond card bonus line 3 should skip empty strings and keep later rows')
assert(bond_panel.cards[1].effect_area_bonus_count == 3, 'bond card should expose visible bonus line count')
assert(bond_panel.cards[1].kind == 'bond', 'bond card should keep kind marker')
assert(bond_panel.card_renderer == 'default', 'bond panel should request default choice panel rendering')
assert(bond_panel.cards[1].render_prefab == nil, 'bond card should not request a dedicated prefab renderer')
assert(type(bond_panel.cards[1].tip_model) == 'table', 'bond card should expose tip model')
assert(bond_panel.cards[1].tip_model.set_name_text == '战术', 'tip model should parse set name')
assert(bond_panel.cards[1].tip_model.progress_text == '(1/3)', 'tip model progress should parse set completion progress from title_text')
assert(bond_panel.cards[1].tip_model.item_name_text == '破甲', 'tip model should reuse node display name')
assert(bond_panel.cards[1].tip_model.bonus_lines[1] == '力量+30', 'tip model bonus line 1 should match')
assert(bond_panel.cards[1].tip_model.effect_index_text == '', 'tip model should not synthesize effect index when effect1 is not configured')
assert(bond_panel.cards[1].tip_model.effect_body_text == '', 'tip model should keep effect1 body empty by default')
assert(bond_panel.cards[1].tip_model.set_title_text == '道统真意：', 'tip model should map advanced text into the set-effect section')
assert(bond_panel.cards[1].tip_model.set_body_lines[1] == '破甲路线成型后，额外获得穿透强化。', 'tip model should keep advanced text as set-effect copy')
assert(bond_panel.cards[1].use_item_desc_card == true, 'bond card should opt into item desc card rendering')
assert(bond_panel.cards[1].item_desc_payload.subtitle_text == '战术 (1/3)', 'bond item desc subtitle should compose set name and progress')
assert(bond_panel.cards[1].item_desc_payload.cost_text == '稀有', 'bond item desc should expose quality text instead of shorthand badge text')
assert(bond_panel.cards[1].item_desc_payload.attr_lines[1] == '力量+30', 'bond item desc should keep normal attr lines unchanged')
assert(bond_panel.cards[1].item_desc_payload.affix_lines[1].title == '3重真意', 'bond item desc should label the explanation area as the set completion effect')
assert(bond_panel.cards[1].item_desc_payload.affix_lines[1].body == '破甲路线成型后，额外获得穿透强化。', 'bond item desc should keep the set effect body text')
assert(bond_panel.cards[1].item_desc_payload.affix_lines[2] == nil, 'bond item desc should not keep a separate current-effect section')

local repeated_title_bond_state = {
  choice_panel_hidden = false,
  bond_runtime = {
    current_choices = {
      {
        quality = 'rare',
        display_name = '法术',
        title_text = '法术 (1/3)',
        subtitle_text = '法术增幅',
        advanced_text = '魔爆术：每隔18秒，触发1次魔爆术。',
        value_text = '法术增幅：法术伤害+5%',
      },
    },
    current_round = {
      free_refresh_left = 0,
      refresh_paid_count = 1,
    },
  },
  resources = {
    wood = 999,
  },
}

local repeated_title_bond_api = model.create({
  STATE = repeated_title_bond_state,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {},
  TREASURE_DEFS = {},
  get_pending_round_choice_kind = function()
    return 'bond'
  end,
  get_treasure_runtime = function()
    return {}
  end,
  get_treasure_quality_label = function(quality)
    return quality
  end,
  get_treasure_active_count = function()
    return 0
  end,
  pick_treasure_choices = function()
    return {}
  end,
  create_bond_env = function()
    return {}
  end,
  refresh_upgrade_choices = function()
    return true
  end,
})

local repeated_title_bond_panel = repeated_title_bond_api.get_current_choice_panel_model()
assert(repeated_title_bond_panel ~= nil, 'repeated title bond panel model should exist')
assert(repeated_title_bond_panel.cards[1].item_desc_payload.title_text == '法术增幅', 'bond item desc title should keep the single-card name')
assert(repeated_title_bond_panel.cards[1].item_desc_payload.attr_lines[1] == '法术伤害+5%', 'bond item desc attrs should strip duplicated card-name prefixes')

local compound_bonus_bond_state = {
  choice_panel_hidden = false,
  bond_runtime = {
    current_choices = {
      {
        quality = 'rare',
        display_name = '成长',
        title_text = '成长 (0/4)',
        subtitle_text = '敏捷',
        advanced_text = '每秒木材+0.3，杀敌力量+0.1，杀敌敏捷+0.1，杀敌智力+0.1。',
        value_text = '敏捷：力量+100，生命值+100',
      },
    },
    current_round = {
      free_refresh_left = 0,
      refresh_paid_count = 1,
    },
  },
  resources = {
    wood = 999,
  },
}

local compound_bonus_bond_api = model.create({
  STATE = compound_bonus_bond_state,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {},
  TREASURE_DEFS = {},
  get_pending_round_choice_kind = function()
    return 'bond'
  end,
  get_treasure_runtime = function()
    return {}
  end,
  get_treasure_quality_label = function(quality)
    return quality
  end,
  get_treasure_active_count = function()
    return 0
  end,
  pick_treasure_choices = function()
    return {}
  end,
  create_bond_env = function()
    return {}
  end,
  refresh_upgrade_choices = function()
    return true
  end,
})

local compound_bonus_bond_panel = compound_bonus_bond_api.get_current_choice_panel_model()
assert(compound_bonus_bond_panel ~= nil, 'compound bonus bond panel model should exist')
assert(compound_bonus_bond_panel.cards[1].bonus_lines[1] == '力量+100', 'compound bonus bond card should split the first stat onto its own line')
assert(compound_bonus_bond_panel.cards[1].bonus_lines[2] == '生命值+100', 'compound bonus bond card should split the second stat onto its own line')
assert(compound_bonus_bond_panel.cards[1].item_desc_payload.attr_lines[1] == '力量+100', 'compound bonus item desc should keep the first split stat line')
assert(compound_bonus_bond_panel.cards[1].item_desc_payload.attr_lines[2] == '生命值+100', 'compound bonus item desc should keep the second split stat line')

local evolution_state = {
  choice_panel_hidden = false,
  evolution_runtime = {
    awaiting_choice = true,
    current_choices = {
      {
        quality = 'epic',
        name = '战神进化',
        summary = '伤害加成 +12%，普攻伤害 +20%，攻击技能伤害 +20%；每 8 次普攻触发 1 次血怒践踏。',
        hero_unit_id = 100008,
      },
    },
    current_round = {
      ui_title = '10级真身抉择',
    },
  },
  resources = {
    wood = 999,
  },
}

local evolution_api = model.create({
  STATE = evolution_state,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {},
  TREASURE_DEFS = {},
  get_pending_round_choice_kind = function()
    return 'evolution'
  end,
  get_evolution_runtime = function()
    return evolution_state.evolution_runtime
  end,
  get_evolution_quality_label = function(quality)
    local labels = {
      common = '普通',
      rare = '稀有',
      epic = '史诗',
    }
    return labels[quality] or tostring(quality)
  end,
  get_treasure_runtime = function()
    return {}
  end,
  get_treasure_quality_label = function(quality)
    return quality
  end,
  get_treasure_active_count = function()
    return 0
  end,
  pick_treasure_choices = function()
    return {}
  end,
  create_bond_env = function()
    return {}
  end,
  refresh_upgrade_choices = function()
    return true
  end,
})

local evolution_panel = evolution_api.get_current_choice_panel_model()
assert(evolution_panel ~= nil, 'evolution choice panel model should exist')
assert(evolution_panel.kind == 'evolution', 'evolution panel should expose evolution kind')
assert(evolution_panel.panel_title == '10级真身抉择', 'evolution panel should expose dynamic round title')
assert(evolution_panel.refresh.visible == false, 'evolution panel should hide refresh action')
assert(evolution_panel.cards[1].badge_text == 'UR', 'evolution card should use the hero rarity as badge text')
assert(evolution_panel.cards[1].title_text == '显圣真君', 'evolution card should use the hero name as title')
assert(evolution_panel.cards[1].subtitle_text == '三界战锋', 'evolution card should use the hero title as subtitle')
assert(evolution_panel.cards[1].body_blocks[1].text == '战戟连断三轮并对首领形成极强压制。', 'evolution card should preview the active hero skill summary')
assert(evolution_panel.cards[1].use_item_desc_card == true, 'evolution card should opt into item desc card rendering')
assert(evolution_panel.cards[1].item_desc_payload.title_text == '显圣真君', 'evolution item desc should use the hero name as title')
assert(evolution_panel.cards[1].item_desc_payload.subtitle_text == '三界战锋 神通·天目戟', 'evolution item desc should compose hero title and skill name')
assert(evolution_panel.cards[1].item_desc_payload.cost_text == '史诗', 'evolution item desc should expose readable quality text')
assert(evolution_panel.cards[1].item_desc_payload.note_text == '选中后立即替换英雄模型，并启用对应专属神通。', 'evolution item desc should expose the transformation note')
assert(evolution_panel.cards[1].item_desc_payload.attr_lines[1] == '真身品阶：UR', 'evolution item desc should describe hero rarity')
assert(evolution_panel.cards[1].item_desc_payload.attr_lines[2] == '真身定位：三界战锋', 'evolution item desc should describe hero role')
assert(evolution_panel.cards[1].item_desc_payload.attr_lines[3] == '神通类型：战锋连镇', 'evolution item desc should describe hero skill subtitle')
assert(evolution_panel.cards[1].item_desc_payload.affix_lines[1].title == '真身简介', 'evolution item desc should expose the hero intro section')
assert(evolution_panel.cards[1].item_desc_payload.affix_lines[2].title == '专属神通·天目戟', 'evolution item desc should expose the exclusive skill section')
assert(evolution_panel.cards[1].item_desc_payload.affix_lines[3].title == '进化加持', 'evolution item desc should expose the evolution bonus section')

local treasure_defs = {
  echo_tome = {
    id = 'echo_tome',
    name = '回声法典',
    quality = 'rare',
    summary = '法术伤害 +20%。',
    notes = '攻击速度 +10%；暴击率 +5%',
    treasure_type = 'passive',
    ui_icon = 246810,
  },
}

local treasure_state = {
  choice_panel_hidden = false,
  treasure_runtime = {
    awaiting_choice = true,
    current_choices = {
      treasure_defs.echo_tome,
    },
    current_round = {
      free_refresh_left = 1,
      refresh_paid_count = 0,
    },
  },
  resources = {
    wood = 999,
  },
}

local treasure_api = model.create({
  STATE = treasure_state,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {},
  TREASURE_DEFS = treasure_defs,
  get_pending_round_choice_kind = function()
    return 'treasure'
  end,
  get_treasure_runtime = function()
    return treasure_state.treasure_runtime
  end,
  get_treasure_quality_label = function(quality)
    local labels = {
      common = '普通',
      rare = '稀有',
      epic = '史诗',
    }
    return labels[quality] or tostring(quality)
  end,
  get_treasure_active_count = function()
    return 2
  end,
  pick_treasure_choices = function()
    return {}
  end,
  create_bond_env = function()
    return {}
  end,
  refresh_upgrade_choices = function()
    return true
  end,
})

local treasure_panel = treasure_api.get_current_choice_panel_model()
assert(treasure_panel ~= nil, 'treasure choice panel model should exist')
assert(treasure_panel.cards[1].item_desc_payload.title_text == '回声法典', 'treasure template should use treasure name as title')
assert(treasure_panel.cards[1].item_desc_payload.subtitle_text == '常驻宝物', 'treasure template should distinguish permanent treasures in subtitle')
assert(treasure_panel.cards[1].item_desc_payload.cost_text == '稀有', 'treasure template should expose readable quality text')
assert(treasure_panel.cards[1].item_desc_payload.attr_lines[1] == '攻击速度 +10%', 'treasure template should keep note lines in attrs')
assert(treasure_panel.cards[1].item_desc_payload.attr_lines[3] == '常驻宝物：占用常驻宝物位', 'treasure template should describe slot occupancy in attrs')
assert(treasure_panel.cards[1].item_desc_payload.affix_lines[1].title == '核心效果', 'treasure template should label the description area as the core effect')

local treasure_replace_state = {
  choice_panel_hidden = false,
  treasure_runtime = {
    awaiting_choice = false,
    awaiting_replace = true,
    pending_replace_choice = treasure_defs.echo_tome,
    active_slots = {
      'echo_tome',
      nil,
      nil,
    },
  },
  resources = {
    wood = 999,
  },
}

local treasure_replace_api = model.create({
  STATE = treasure_replace_state,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {},
  TREASURE_DEFS = treasure_defs,
  get_pending_round_choice_kind = function()
    return 'treasure'
  end,
  get_treasure_runtime = function()
    return treasure_replace_state.treasure_runtime
  end,
  get_treasure_quality_label = function(quality)
    local labels = {
      common = '普通',
      rare = '稀有',
      epic = '史诗',
    }
    return labels[quality] or tostring(quality)
  end,
  get_treasure_active_count = function()
    return 3
  end,
  pick_treasure_choices = function()
    return {}
  end,
  create_bond_env = function()
    return {}
  end,
  refresh_upgrade_choices = function()
    return true
  end,
})

local treasure_replace_panel = treasure_replace_api.get_current_choice_panel_model()
assert(treasure_replace_panel ~= nil, 'treasure replace choice panel model should exist')
assert(treasure_replace_panel.cards[1].item_desc_payload.title_text == '宝物位 1', 'treasure replace template should use slot title as title')
assert(treasure_replace_panel.cards[1].item_desc_payload.subtitle_text == '回声法典', 'treasure replace template should show the equipped treasure in subtitle')
assert(treasure_replace_panel.cards[1].item_desc_payload.affix_lines[2].title == '替换说明', 'treasure replace template should keep the replacement guidance section')

print('choice_panel model config wiring ok')

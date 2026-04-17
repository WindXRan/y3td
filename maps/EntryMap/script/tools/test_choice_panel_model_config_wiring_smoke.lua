package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local model = require 'runtime.choice_panel_model'

local STATE = {
  choice_panel_hidden = false,
  current_upgrade_choices = {
    {
      key = 'upgrade_a',
      skill_id = 'arcane_arrow',
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
    arcane_arrow = {
      name = '青木灵矢',
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
assert(panel.cards[1].badge_text == 'R', 'upgrade card should use config-backed badge text')
assert(panel.cards[1].use_item_desc_card == true, 'upgrade card should opt into item desc card rendering')
assert(type(panel.cards[1].item_desc_payload) == 'table', 'upgrade card should expose item desc payload')
assert(panel.cards[1].item_desc_payload.title_text == '测试强化', 'upgrade template should use the upgrade entry name as title')
assert(panel.cards[1].item_desc_payload.subtitle_text == '青木灵矢', 'upgrade template should use the target skill name as subtitle')
assert(panel.cards[1].item_desc_payload.cost_text == '强化', 'upgrade template should expose the strengthen label')
assert(panel.cards[1].item_desc_payload.attr_lines[1] == '强化类型：常规强化', 'upgrade template should describe the reward type in attrs')
assert(panel.cards[1].item_desc_payload.affix_lines[1].title == '技能说明', 'upgrade item desc should expose skill summary section')
assert(panel.cards[1].item_desc_payload.affix_lines[2].title == '强化效果', 'upgrade item desc should expose upgrade effect section')

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

local mark_state = {
  choice_panel_hidden = false,
  mark_runtime = {
    awaiting_choice = true,
    current_choices = {
      {
        quality = 'epic',
        name = '风暴刻印',
        summary = '攻击技能冷却缩短 20%。',
      },
    },
    current_round = {
      ui_title = '10级进化选择',
    },
  },
  resources = {
    wood = 999,
  },
}

local mark_api = model.create({
  STATE = mark_state,
  message = function() end,
  BondSystem = {
    refresh_choice = function()
      return true
    end,
  },
  ATTACK_SKILL_DEFS = {},
  TREASURE_DEFS = {},
  get_pending_round_choice_kind = function()
    return 'mark'
  end,
  get_mark_runtime = function()
    return mark_state.mark_runtime
  end,
  get_mark_quality_label = function(quality)
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

local mark_panel = mark_api.get_current_choice_panel_model()
assert(mark_panel ~= nil, 'mark choice panel model should exist')
assert(mark_panel.kind == 'mark', 'mark panel should keep mark kind')
assert(mark_panel.panel_title == '10级进化选择', 'mark panel should expose dynamic round title')
assert(mark_panel.refresh.visible == false, 'mark panel should hide refresh action')
assert(mark_panel.cards[1].title_text == '风暴刻印', 'mark card should reuse mark name')
assert(mark_panel.cards[1].subtitle_text == '史诗', 'mark card should reuse mark quality label')
assert(mark_panel.cards[1].body_blocks[1].text == '攻击技能冷却缩短 20%。', 'mark card should expose summary body text')
assert(mark_panel.cards[1].use_item_desc_card == true, 'mark card should opt into item desc card rendering')
assert(mark_panel.cards[1].item_desc_payload.subtitle_text == '永久进化', 'mark template should use the permanent-evolution subtitle')
assert(mark_panel.cards[1].item_desc_payload.cost_text == '史诗', 'mark template should expose readable quality text')
assert(mark_panel.cards[1].item_desc_payload.attr_lines[1] == '生效范围：所有已装配攻击技能', 'mark template should describe the effective scope')
assert(mark_panel.cards[1].item_desc_payload.affix_lines[1].title == '进化效果', 'mark item desc should expose mark effect section')

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

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

print('choice_panel model config wiring ok')

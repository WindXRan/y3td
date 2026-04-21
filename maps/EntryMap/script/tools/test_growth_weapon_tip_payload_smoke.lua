package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local gear = require 'runtime.gear_upgrades'

local state = {
  resources = { gold = 9999 },
}

local config = {
  slots = {
    weapon = {
      slot = 'weapon',
      display_name = '成长武器',
      max_level = 100,
      affix_choice_count = 3,
      item_key = 201390082,
    },
  },
  levels_by_level = {
    [1] = {
      level = 1,
      gold_cost = 50,
      is_affix_node = false,
      bonus_pack = {
        ['攻击'] = 10,
        ['力量'] = 2,
        ['敏捷'] = 2,
        ['智力'] = 2,
      },
    },
  },
}

local fake_item_api = {
  get_name_by_key = function(item_key)
    assert(item_key == 201390082, 'expected growth weapon item key')
    return '洪荒之刃'
  end,
  get_icon_id_by_key = function(item_key)
    assert(item_key == 201390082, 'expected growth weapon item key')
    return 123456
  end,
}

gear.ensure_runtime(state, config)
local payload = gear.build_tip_payload(state, 'weapon', config, fake_item_api)

assert(payload ~= nil, 'expected payload')
assert(payload.title_text == '洪荒之刃', 'expected item name as title')
assert(payload.subtitle_text == '成长武器 Lv.1', 'expected level subtitle')
assert(payload.cost_text == '升级所需：50 金币', 'expected upgrade cost text')
assert(payload.icon_res == 123456, 'expected item icon')
assert(type(payload.attr_lines) == 'table' and #payload.attr_lines == 4, 'expected four growth attr lines')
assert(payload.attr_lines[1] == '+10攻击力', 'expected attack growth line')
assert(payload.attr_lines[2] == '+2力量', 'expected strength growth line')
assert(payload.attr_lines[3] == '+2敏捷', 'expected agility growth line')
assert(payload.attr_lines[4] == '+2智力', 'expected intelligence growth line')
assert(type(payload.affix_lines) == 'table' and type(payload.affix_lines[1]) == 'table', 'expected structured affix rows')
assert(payload.affix_lines[1].title == '当前词缀', 'expected equipment template to label the affix section')
assert(payload.affix_lines[1].body == '暂无词缀', 'expected empty affix fallback body')

print('[OK] growth weapon tip payload smoke passed')

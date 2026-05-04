package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;' .. package.path

local saved_tables = setmetatable({}, { __mode = 'k' })

package.preload['y3.util.save_data'] = function()
  return {
    load_table = function(player, slot)
      saved_tables[player] = saved_tables[player] or {}
      saved_tables[player][slot] = saved_tables[player][slot] or {}
      return saved_tables[player][slot]
    end,
  }
end

package.preload['data.tables.economy.suit_catalog'] = function()
  local slots = {
    WEAPON = 'weapon',
    ARMOR = 'armor',
    HELMET = 'helmet',
    BOOTS = 'boots',
    ACCESSORY1 = 'accessory1',
    ACCESSORY2 = 'accessory2',
  }
  local suit = {
    suit_id = 'suit_test',
    name = 'Test Suit',
    quality = 'SSR',
    icon = 1,
    equipment = {
      { slot = 'weapon', name = 'Weapon' },
      { slot = 'armor', name = 'Armor' },
      { slot = 'helmet', name = 'Helmet' },
      { slot = 'boots', name = 'Boots' },
      { slot = 'accessory1', name = 'Accessory 1' },
      { slot = 'accessory2', name = 'Accessory 2' },
    },
    level_effects = {
      [1] = {
        star_level = 1,
        description = 'Level 1',
        effects = {
          { attr_name = 'attack', value = 10, is_ratio = false },
          { attr_name = 'crit_rate', value = 0.05, is_ratio = true },
        },
      },
      [2] = {
        star_level = 2,
        description = 'Level 2',
        effects = {
          { attr_name = 'attack', value = 20, is_ratio = false },
        },
      },
    },
  }
  return {
    SUIT_IDS = { TEST = 'suit_test' },
    EQUIPMENT_SLOTS = slots,
    list = { suit },
    by_suit_id = { suit_test = suit },
    MAX_STAR_LEVEL = 10,
  }
end

package.preload['data.tables.economy.suit_upgrade_cost'] = function()
  return {
    get_cost_by_suit_and_level = function(suit_id, level)
      if suit_id ~= 'suit_test' or level > 2 then
        return nil
      end
      return {
        suit_id = suit_id,
        star_level = level,
        upgrade_success_rate = 1,
        cost_items = {
          { consumable_key = 'stone', amount = level * 10 },
        },
      }
    end,
  }
end

package.preload['data.tables.economy.suit_effects'] = function()
  local catalog = require 'data.tables.economy.suit_catalog'
  return {
    get_effects_by_suit_and_level = function(suit_id, level)
      local suit = catalog.by_suit_id[suit_id]
      return suit and suit.level_effects[level] or nil
    end,
  }
end

local SuitSystem = require 'y3.game.suit_system'

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', label or 'assert_eq', tostring(expected), tostring(actual)), 2)
  end
end

local function new_player()
  return {
    attr = {},
    ratio = {},
    add_attr_base = function(self, name, value)
      self.attr[name] = (self.attr[name] or 0) + value
    end,
    add_attr_ratio = function(self, name, value)
      self.ratio[name] = (self.ratio[name] or 0) + value
    end,
  }
end

local function test_suit_level_requires_all_slots()
  local player = new_player()
  SuitSystem.initialize_player_suit_data(player)
  SuitSystem.set_equipment_star_level(player, 'suit_test', 'weapon', 3)
  assert_eq(SuitSystem.calculate_suit_star_level(player, 'suit_test'), 0, 'partial suit level')

  for _, slot in ipairs({ 'armor', 'helmet', 'boots', 'accessory1', 'accessory2' }) do
    SuitSystem.set_equipment_star_level(player, 'suit_test', slot, 2)
  end
  assert_eq(SuitSystem.calculate_suit_star_level(player, 'suit_test'), 2, 'full suit min level')
end

local function test_upgrade_equipment_spends_cost_and_returns_new_level()
  local player = new_player()
  SuitSystem.initialize_player_suit_data(player)
  SuitSystem.set_player_consumable_amount(player, 'stone', 50)

  local ok, message, level = SuitSystem.upgrade_equipment(player, 'suit_test', 'weapon')

  assert_eq(ok, true, 'upgrade ok')
  assert_eq(message, '升阶成功', 'upgrade message')
  assert_eq(level, 1, 'new level')
  assert_eq(SuitSystem.get_equipment_star_level(player, 'suit_test', 'weapon'), 1, 'stored level')
  assert_eq(SuitSystem.get_player_consumable_amount(player, 'stone'), 40, 'remaining stones')
end

local function test_apply_suit_effects_is_idempotent()
  local player = new_player()

  SuitSystem.apply_suit_effects(player, 'suit_test', 1)
  SuitSystem.apply_suit_effects(player, 'suit_test', 1)

  assert_eq(player.attr.attack, 10, 'base attr applied once')
  assert_eq(player.ratio.crit_rate, 0.05, 'ratio attr applied once')

  SuitSystem.apply_suit_effects(player, 'suit_test', 2)
  assert_eq(player.attr.attack, 20, 'old effect replaced by new effect')
  assert_eq(player.ratio.crit_rate or 0, 0, 'removed ratio effect')
end

local function test_display_compatibility_helpers()
  local player = new_player()
  SuitSystem.initialize_player_suit_data(player)
  SuitSystem.set_player_consumable_amount(player, 'stone', 10)

  local info = SuitSystem.get_suit_display_info(player, 'suit_test')

  assert_eq(info.current_star_level, 0, 'display current level')
  assert_eq(info.max_level, 10, 'display max level')
  assert_eq(info.can_upgrade, true, 'display can upgrade')
  assert_eq(#info.equipment, 6, 'display equipment')
end

local function test_display_cost_uses_first_upgradable_slot()
  local player = new_player()
  SuitSystem.initialize_player_suit_data(player)
  SuitSystem.set_equipment_star_level(player, 'suit_test', 'weapon', 10)
  SuitSystem.set_player_consumable_amount(player, 'stone', 10)

  local info = SuitSystem.get_suit_display_info(player, 'suit_test')

  assert_eq(info.can_upgrade, true, 'display can upgrade non-weapon slot')
  assert_eq(info.upgrade_cost.star_level, 1, 'display non-weapon upgrade cost')
end

local function test_compat_upgrade_suit_accepts_specific_slot()
  local player = new_player()
  SuitSystem.initialize_player_suit_data(player)
  SuitSystem.set_player_consumable_amount(player, 'stone', 50)

  ---@diagnostic disable-next-line: redundant-parameter
  local ok, message, level, slot = SuitSystem.upgrade_suit(player, 'suit_test', 'armor')

  assert_eq(ok, true, 'specific slot upgrade ok')
  assert_eq(message, '升阶成功', 'specific slot upgrade message')
  assert_eq(level, 1, 'specific slot new level')
  assert_eq(slot, 'armor', 'specific slot returned')
  assert_eq(SuitSystem.get_equipment_star_level(player, 'suit_test', 'armor'), 1, 'specific slot stored')
  assert_eq(SuitSystem.get_equipment_star_level(player, 'suit_test', 'weapon'), 0, 'other slot unchanged')
end

local function test_display_info_exposes_each_equipment_state()
  local player = new_player()
  SuitSystem.initialize_player_suit_data(player)
  SuitSystem.set_equipment_star_level(player, 'suit_test', 'helmet', 2)
  SuitSystem.set_player_consumable_amount(player, 'stone', 50)

  local info = SuitSystem.get_suit_display_info(player, 'suit_test')
  local helmet
  for _, equip in ipairs(info.equipment) do
    if equip.slot == 'helmet' then
      helmet = equip
      break
    end
  end

  assert_eq(helmet.star_level, 2, 'equipment display star level')
  assert_eq(helmet.can_upgrade, false, 'equipment display max configured cost')
  assert_eq(info.equipment[1].can_upgrade, true, 'equipment display can upgrade another slot')
end

local tests = {
  test_suit_level_requires_all_slots,
  test_upgrade_equipment_spends_cost_and_returns_new_level,
  test_apply_suit_effects_is_idempotent,
  test_display_compatibility_helpers,
  test_display_cost_uses_first_upgradable_slot,
  test_compat_upgrade_suit_accepts_specific_slot,
  test_display_info_exposes_each_equipment_state,
}

for _, test in ipairs(tests) do
  test()
end

print(string.format('ok - %d suit system tests passed', #tests))

local helpers = require 'entry_objects.helpers'

local bond_module_paths = {
  'entry_objects.bonds.blessing',
  'entry_objects.bonds.berserk',
  'entry_objects.bonds.hunter',
  'entry_objects.bonds.greed',
  'entry_objects.bonds.barrage',
  'entry_objects.bonds.chain',
  'entry_objects.bonds.arcane',
  'entry_objects.bonds.execute',
  'entry_objects.bonds.growth',
  'entry_objects.bonds.fortress',
}

local card_module_paths = {
  'entry_objects.bond_cards.blessing_holy_water',
  'entry_objects.bond_cards.blessing_prayer',
  'entry_objects.bond_cards.berserk_fury',
  'entry_objects.bond_cards.berserk_hot_blood',
  'entry_objects.bond_cards.hunter_pursuit',
  'entry_objects.bond_cards.hunter_purge',
  'entry_objects.bond_cards.greed_coin',
  'entry_objects.bond_cards.greed_hoard',
  'entry_objects.bond_cards.barrage_swiftstring',
  'entry_objects.bond_cards.barrage_draw',
  'entry_objects.bond_cards.barrage_spread',
  'entry_objects.bond_cards.chain_echo',
  'entry_objects.bond_cards.chain_return',
  'entry_objects.bond_cards.chain_pursue',
  'entry_objects.bond_cards.arcane_chant',
  'entry_objects.bond_cards.arcane_conduit',
  'entry_objects.bond_cards.arcane_focus',
  'entry_objects.bond_cards.execute_weakness',
  'entry_objects.bond_cards.execute_suppress',
  'entry_objects.bond_cards.execute_thrust',
  'entry_objects.bond_cards.growth_hone',
  'entry_objects.bond_cards.growth_accumulate',
  'entry_objects.bond_cards.growth_merit',
  'entry_objects.bond_cards.growth_charge',
  'entry_objects.bond_cards.fortress_iron',
  'entry_objects.bond_cards.fortress_wall',
  'entry_objects.bond_cards.fortress_heal',
  'entry_objects.bond_cards.fortress_stable',
}

local defs = helpers.load_list(bond_module_paths)
local cards = helpers.load_list(card_module_paths)

local defs_by_id = helpers.list_to_map(defs)
local cards_by_id = helpers.list_to_map(cards)

return {
  defs = defs,
  defs_by_id = defs_by_id,
  cards = cards,
  cards_by_id = cards_by_id,
}

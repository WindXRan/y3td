local helpers = require 'entry_objects.helpers'

local module_paths = {
  'entry_objects.bond_recipes.hunt_decree',
  'entry_objects.bond_recipes.royal_hunt',
  'entry_objects.bond_recipes.flame_thunder_overload',
  'entry_objects.bond_recipes.frost_arcane_prism',
  'entry_objects.bond_recipes.elemental_throne',
  'entry_objects.bond_recipes.stormweb_echo',
  'entry_objects.bond_recipes.unyielding_warpath',
  'entry_objects.bond_recipes.holy_bastion',
}

local list = helpers.load_list(module_paths)
local by_output_bond_id = {}

for _, def in ipairs(list) do
  by_output_bond_id[def.output_bond_id] = def
end

return {
  list = list,
  by_output_bond_id = by_output_bond_id,
}

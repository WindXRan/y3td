local helpers = require 'entry_objects.helpers'

local module_paths = {
  'entry_objects.attack_skills.basic_attack',
  'entry_objects.attack_skills.arcane_arrow',
  'entry_objects.attack_skills.flame_arrow',
  'entry_objects.attack_skills.frost_arrow',
  'entry_objects.attack_skills.thunder',
}

local list = helpers.load_list(module_paths)

local defs_by_id = helpers.list_to_map(list)
local vfx_by_id = helpers.build_field_map(list, 'vfx', {})

return {
  list = list,
  defs_by_id = defs_by_id,
  vfx_by_id = vfx_by_id,
}

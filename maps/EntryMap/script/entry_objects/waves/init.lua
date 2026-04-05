local helpers = require 'entry_objects.helpers'

local module_paths = {
  'entry_objects.waves.wave_1',
  'entry_objects.waves.wave_2',
  'entry_objects.waves.wave_3',
  'entry_objects.waves.wave_4',
  'entry_objects.waves.wave_5',
}

local list = helpers.load_list(module_paths)

local by_id = helpers.list_to_map(list)

return {
  list = list,
  by_id = by_id,
}

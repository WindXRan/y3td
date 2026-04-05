local helpers = require 'entry_objects.helpers'

local module_paths = {
  'entry_objects.stage_modes.standard',
  'entry_objects.stage_modes.challenge',
}

local list = helpers.load_list(module_paths)
local by_id = helpers.list_to_map(list)

return {
  list = list,
  by_id = by_id,
}

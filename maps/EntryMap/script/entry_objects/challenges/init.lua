local helpers = require 'entry_objects.helpers'

local module_paths = {
  'entry_objects.challenges.gold_trial',
  'entry_objects.challenges.wood_trial',
  'entry_objects.challenges.exp_trial',
  'entry_objects.challenges.treasure_trial',
}

local list = helpers.load_list(module_paths)

local by_id = helpers.list_to_map(list)

return {
  list = list,
  by_id = by_id,
}

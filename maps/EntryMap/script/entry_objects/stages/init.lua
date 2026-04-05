local helpers = require 'entry_objects.helpers'

local module_paths = {
  'entry_objects.stages.stage_1_1',
  'entry_objects.stages.stage_1_2',
  'entry_objects.stages.stage_1_3',
}

local list = helpers.load_list(module_paths)
table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

local by_id = helpers.list_to_map(list)

return {
  list = list,
  by_id = by_id,
}

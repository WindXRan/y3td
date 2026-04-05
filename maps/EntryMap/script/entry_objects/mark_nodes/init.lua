local helpers = require 'entry_objects.helpers'

local list = helpers.load_list({
  'entry_objects.mark_nodes.mark_node_lv10',
  'entry_objects.mark_nodes.mark_node_lv20',
  'entry_objects.mark_nodes.mark_node_lv30',
  'entry_objects.mark_nodes.mark_node_lv40',
})

local by_level = {}
for _, node in ipairs(list) do
  if node and node.trigger_level then
    by_level[node.trigger_level] = node
  end
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
  by_level = by_level,
}

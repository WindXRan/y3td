package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local bonds = require 'runtime.bonds.bonds_chain'

local state = {
  resources = {
    wood = 9999,
  },
}

local entries = bonds.get_root_overview_entries(state)
assert(type(entries) == 'table', 'root overview entries should be a table')
assert(#entries == 6, 'expected 6 root overview entries')

local first = entries[1]
assert(first.root_id == 'bond_body_core', 'expected body root overview first')
assert(first.status == 'locked', 'expected body root to be locked initially')
assert(first.group_name == '体术', 'expected body group display name')
assert(first.progress_text == '0/18', 'expected body root progress text')

state.bond_runtime = bonds.create_runtime()
state.bond_runtime.state_ref = state
state.bond_runtime.unlocked_group_ids.body = true
state.bond_runtime.unlocked_node_ids.bond_body_core = true

entries = bonds.get_root_overview_entries(state)
local body_entry = nil
for _, entry in ipairs(entries) do
  if entry.root_id == 'bond_body_core' then
    body_entry = entry
  end
end

assert(body_entry ~= nil, 'expected body root overview entry')
assert(body_entry.status == 'in_progress', 'expected body root to become in_progress')
assert(body_entry.started == true, 'expected body root started')
assert(body_entry.available_next_count > 0, 'expected body root to have available next nodes')

print('[OK] bond root overview entries smoke passed')

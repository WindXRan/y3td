package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local bonds = require 'runtime.bonds_chain'
local bond_nodes = require 'data.object_tables.bond_nodes'

local function get_build_choice_entry()
  local collect_candidate_choice_entries = nil
  for index = 1, 20 do
    local name, value = debug.getupvalue(bonds.try_draw, index)
    if name == 'collect_candidate_choice_entries' then
      collect_candidate_choice_entries = value
      break
    end
  end
  assert(type(collect_candidate_choice_entries) == 'function', 'expected collect_candidate_choice_entries upvalue')

  local pick_random_candidates = nil
  for index = 1, 20 do
    local name, value = debug.getupvalue(collect_candidate_choice_entries, index)
    if name == 'pick_random_candidates' then
      pick_random_candidates = value
      break
    end
  end
  assert(type(pick_random_candidates) == 'function', 'expected pick_random_candidates upvalue')

  for index = 1, 20 do
    local name, value = debug.getupvalue(pick_random_candidates, index)
    if name == 'build_choice_entry' then
      return value
    end
  end

  error('expected build_choice_entry upvalue')
end

local build_choice_entry = get_build_choice_entry()
local state = {
  bond_runtime = bonds.create_runtime(),
  resources = {
    wood = 0,
  },
}

local function assert_choice_title(node_id, expected_title)
  local node_def = assert(bond_nodes.by_id[node_id], 'expected node def for ' .. tostring(node_id))
  local choice = build_choice_entry(state, node_def, 1)
  assert(choice.title_text == expected_title, string.format(
    'expected %s title_text to be %s, got %s',
    tostring(node_id),
    tostring(expected_title),
    tostring(choice.title_text)
  ))
end

local function assert_choice_card_name(node_id, expected_name)
  local node_def = assert(bond_nodes.by_id[node_id], 'expected node def for ' .. tostring(node_id))
  local choice = build_choice_entry(state, node_def, 1)
  assert(choice.subtitle_text == expected_name, string.format(
    'expected %s subtitle_text to be %s, got %s',
    tostring(node_id),
    tostring(expected_name),
    tostring(choice.subtitle_text)
  ))
end

assert_choice_title('bond_growth_agility', '敏捷 (0/4)')
assert_choice_title('bond_growth_barbarian_warcry', '野蛮人 (0/4)')
assert_choice_title('bond_growth_war_god_power', '战神 (0/3)')
assert_choice_card_name('bond_critical_core', '暴击强化')
assert_choice_card_name('bond_magic_core', '法术威力')
assert_choice_card_name('bond_archery_core', '箭矢弹射')
assert_choice_card_name('bond_growth_core', '智力提升')

print('bonds chain choice progress smoke ok')

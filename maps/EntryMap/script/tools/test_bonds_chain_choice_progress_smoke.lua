package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local bonds = require 'runtime.bonds_chain'
local bond_modifier_pool = require 'data.tables.bond.bond_modifier_pool'

local function normalize_text(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function has_non_empty_body_block(blocks)
  for _, block in ipairs(blocks or {}) do
    if normalize_text(block and block.text or '') ~= '' then
      return true
    end
  end
  return false
end

local function choice_has_desc_source(choice)
  if normalize_text(choice.desc_text) ~= '' then
    return true
  end
  if normalize_text(choice.current_text) ~= '' then
    return true
  end
  if normalize_text(choice.value_text) ~= '' then
    return true
  end
  if normalize_text(choice.effect_text) ~= '' then
    return true
  end
  if has_non_empty_body_block(choice.body_blocks) then
    return true
  end
  local tip_model = choice.tip_model or {}
  if normalize_text(tip_model.effect_body_text) ~= '' then
    return true
  end
  return #(tip_model.bonus_lines or {}) > 0 or #(tip_model.set_body_lines or {}) > 0
end

local function get_collect_modifier_pool_choice_entries()
  local collect_candidate_choice_entries = nil
  for index = 1, 30 do
    local name, value = debug.getupvalue(bonds.try_draw, index)
    if name == 'collect_candidate_choice_entries' then
      collect_candidate_choice_entries = value
      break
    end
  end
  assert(type(collect_candidate_choice_entries) == 'function', 'expected collect_candidate_choice_entries upvalue')

  for index = 1, 30 do
    local name, value = debug.getupvalue(collect_candidate_choice_entries, index)
    if name == 'collect_modifier_pool_choice_entries' then
      return value
    end
  end
  error('expected collect_modifier_pool_choice_entries upvalue')
end

if not bond_modifier_pool.enabled or #bond_modifier_pool.cards == 0 then
  print('modifier pool disabled, bonds chain choice progress smoke skipped')
  os.exit(0)
end

local collect_modifier_pool_choice_entries = get_collect_modifier_pool_choice_entries()
local state = {
  bond_runtime = bonds.create_runtime(),
  resources = {
    wood = 0,
  },
}

local choices = assert(collect_modifier_pool_choice_entries(state), 'expected modifier pool choices')
assert(#choices > 0, 'expected at least one modifier pool choice')

for index, choice in ipairs(choices) do
  assert(normalize_text(choice.title_text) ~= '', 'expected title_text for choice ' .. tostring(index))
  assert(normalize_text(choice.bond_root_name) ~= '', 'expected bond_root_name for choice ' .. tostring(index))
  assert(normalize_text(choice.bond_root_progress_text):match('^%d+/%d+$'), 'expected progress text for choice ' .. tostring(index))
  assert(choice_has_desc_source(choice), 'expected desc source for choice ' .. tostring(index))
end

print('bonds chain choice progress smoke ok')

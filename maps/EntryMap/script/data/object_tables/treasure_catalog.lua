local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local treasure_rows = CsvLoader.read_rows('data_csv/treasures.csv')
local effect_rows = CsvLoader.read_rows('data_csv/treasure_effects.csv')
local set_rows = CsvLoader.read_rows('data_csv/treasure_sets.csv')
local set_member_rows = CsvLoader.read_rows('data_csv/treasure_set_members.csv')
local set_effect_rows = CsvLoader.read_rows('data_csv/treasure_set_effects.csv')

local effect_groups = CsvLoader.group_by(effect_rows, 'treasure_id')
local set_member_groups = CsvLoader.group_by(set_member_rows, 'set_id')
local set_effect_groups = CsvLoader.group_by(set_effect_rows, 'set_id')

local function to_boolean(raw)
  return raw == 'true' or raw == '1'
end

local function to_number_if_possible(raw)
  if raw == nil or raw == '' then
    return raw
  end
  local value = tonumber(raw)
  if value ~= nil then
    return value
  end
  return raw
end

local function build_effects(rows)
  local effects = {}
  for _, row in ipairs(rows or {}) do
    effects[#effects + 1] = {
      effect_type = row.effect_type,
      effect_key = row.effect_key,
      op = row.op,
      value = to_number_if_possible(row.value),
      scope = row.scope,
      condition = row.condition ~= '' and row.condition or nil,
      notes = row.notes ~= '' and row.notes or nil,
    }
  end
  return effects
end

local list = {}
for _, row in ipairs(treasure_rows) do
  list[#list + 1] = {
    id = row.id,
    name = row.name,
    category = row.category,
    rarity = row.rarity,
    is_set_item = to_boolean(row.is_set_item),
    set_id = row.set_id ~= '' and row.set_id or nil,
    summary = row.summary,
    notes = row.notes ~= '' and row.notes or nil,
    effects = build_effects(effect_groups[row.id]),
  }
end

local sets = {}
for _, row in ipairs(set_rows) do
  local members = {}
  for _, member in ipairs(set_member_groups[row.set_id] or {}) do
    members[#members + 1] = {
      treasure_id = member.treasure_id,
      member_order = tonumber(member.member_order) or 0,
    }
  end
  table.sort(members, function(a, b)
    return a.member_order < b.member_order
  end)

  sets[#sets + 1] = {
    id = row.set_id,
    set_id = row.set_id,
    name = row.set_name,
    piece_count = tonumber(row.piece_count) or 0,
    bonus_desc = row.bonus_desc,
    notes = row.notes ~= '' and row.notes or nil,
    members = members,
    effects = build_effects(set_effect_groups[row.set_id]),
  }
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
  sets = sets,
  sets_by_id = helpers.list_to_map(sets),
}

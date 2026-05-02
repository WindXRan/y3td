local CsvLoader = require 'data.csv_loader'
local AttrEffect = require 'data.tables.skill.attreffect'

local node_rows = CsvLoader.read_rows_optional('data_csv/bond_nodes.csv')
local bond_effects = AttrEffect.by_source.bond_node or {}

local function split_pipe_list(raw)
  if raw == nil or raw == '' then
    return {}
  end

  local result = {}
  for part in string.gmatch(raw, '([^|]+)') do
    result[#result + 1] = part
  end
  return result
end

local function clone_number_map(source)
  local result = {}
  for key, value in pairs(source or {}) do
    result[key] = tonumber(value) or 0
  end
  return result
end

local function build_unlock_rewards(effect_bucket)
  local resource = effect_bucket and effect_bucket.resource or nil
  local rewards = {}
  if resource and resource.gold ~= nil then
    rewards.gold = tonumber(resource.gold) or 0
  end
  if resource and resource.wood ~= nil then
    rewards.wood = tonumber(resource.wood) or 0
  end
  if resource and resource.exp ~= nil then
    rewards.exp = tonumber(resource.exp) or 0
  end
  return rewards
end

local function node(def)
  def.quality = def.quality or 'rare'
  def.editor_skill_id = def.editor_skill_id or nil
  def.editor_modifier_id = def.editor_modifier_id or nil
  def.icon = def.icon or nil
  def.attr = def.attr or {}
  def.runtime = def.runtime or {}
  def.desc = def.desc or {}
  def.route_tags = def.route_tags or {}
  def.next_ids = def.next_ids or {}
  def.unlock_rewards = def.unlock_rewards or {}
  return def
end

local list = {}

for _, row in ipairs(node_rows) do
  local effect_bucket = bond_effects[row.id] or {}

  list[#list + 1] = node({
    id = row.id,
    display_name = row.display_name,
    group_id = row.group_id,
    line_id = row.line_id,
    tier = tonumber(row.tier) or 0,
    parent_id = row.parent_id ~= '' and row.parent_id or nil,
    next_ids = split_pipe_list(row.next_ids),
    route_tags = split_pipe_list(row.route_tags),
    template = row.template,
    quality = row.quality ~= '' and row.quality or 'rare',
    icon = row.icon ~= '' and (tonumber(row.icon) or row.icon) or nil,
    editor_skill_id = row.editor_skill_id ~= '' and (tonumber(row.editor_skill_id) or row.editor_skill_id) or nil,
    editor_modifier_id = row.editor_modifier_id ~= '' and (tonumber(row.editor_modifier_id) or row.editor_modifier_id) or nil,
    unlock_rewards = build_unlock_rewards(effect_bucket),
    attr = clone_number_map(effect_bucket.attr),
    runtime = clone_number_map(effect_bucket.runtime),
    desc = {
      single = row.desc_single ~= '' and row.desc_single or nil,
      advanced = row.desc_advanced ~= '' and row.desc_advanced or nil,
    },
  })
end

local by_id = {}
local root_ids = {}
local by_line = {}
local by_group = {}

for _, def in ipairs(list) do
  assert(not by_id[def.id], string.format('duplicate bond node id: %s', def.id))
  by_id[def.id] = def
  by_line[def.line_id] = by_line[def.line_id] or {}
  by_line[def.line_id][#by_line[def.line_id] + 1] = def
  by_group[def.group_id] = by_group[def.group_id] or {}
  by_group[def.group_id][#by_group[def.group_id] + 1] = def
  if not def.parent_id then
    root_ids[#root_ids + 1] = def.id
  end
end

for _, def in ipairs(list) do
  if def.parent_id then
    assert(by_id[def.parent_id], string.format('missing parent_id for bond node: %s -> %s', def.id, def.parent_id))
  end
  for _, next_id in ipairs(def.next_ids) do
    assert(by_id[next_id], string.format('missing next_id for bond node: %s -> %s', def.id, next_id))
  end
end

return {
  list = list,
  by_id = by_id,
  root_ids = root_ids,
  by_line = by_line,
  by_group = by_group,
}



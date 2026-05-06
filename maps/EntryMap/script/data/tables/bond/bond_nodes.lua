local CsvLoader = require 'data.csv_loader'

local node_rows = CsvLoader.read_rows_optional('data_csv/by_feature/bond/bond_skills.csv')

local list = {}
local by_id = {}
local by_group = {}
local by_line = {}
local root_ids = {}

local BOND_GROUPS = {
  ['枪炮师'] = true,
  ['神射手'] = true,
  ['游侠'] = true,
  ['狂战士'] = true,
  ['剑魂'] = true,
  ['剑宗'] = true,
  ['龙骑士'] = true,
  ['战斗法师'] = true,
  ['魔剑士'] = true,
  ['火法师'] = true,
  ['冰霜法师'] = true,
  ['猎人'] = true,
  ['雷电法王'] = true,
  ['骷髅法师'] = true,
  ['基础'] = true,
}

local function parse_attr_json(attr_json_str)
  if not attr_json_str or attr_json_str == '' then
    return {}
  end
  local ok, result = pcall(function()
    return assert(loadstring('return ' .. attr_json_str))()
  end)
  if ok and result then
    return result
  end
  return {}
end

for _, row in ipairs(node_rows) do
  if row.enabled == '1' or row.enabled == 1 then
    local node_id = row.skill_id
    local bond_name = row.bond_name or row.skill_name or ''
    local scope = row.scope or ''
    local attr_pack = parse_attr_json(row.attr_json)

    local node_def = {
      id = node_id,
      display_name = row.skill_name or '',
      group_id = bond_name,
      line_id = scope,
      tier = 1,
      parent_id = nil,
      next_ids = {},
      template = scope,
      quality = 'rare',
      icon = tonumber(row.icon) or 131414,
      bg = row.bg ~= '' and tonumber(row.bg) or nil,
      editor_skill_id = node_id,
      editor_modifier_id = nil,
      attr = attr_pack,
      runtime = {},
      route_tags = { bond_name },
      desc = {
        single = row.notes or '',
        advanced = row.notes or '',
      },
      scope = scope,
      trigger_kind = row.trigger_kind or '',
      damage_type = row.damage_type or '',
      visual_bond = row.visual_bond or '',
    }

    list[#list + 1] = node_def
    by_id[node_id] = node_def

    if not by_group[bond_name] then
      by_group[bond_name] = {}
    end
    by_group[bond_name][#by_group[bond_name] + 1] = node_def

    if not by_line[scope] then
      by_line[scope] = {}
    end
    by_line[scope][#by_line[scope] + 1] = node_def

    if scope == 'bond_basic' or scope == 'bond_periodic' then
      root_ids[#root_ids + 1] = node_id
    end
  end
end



local M = {
  list = list,
  by_id = by_id,
  by_group = by_group,
  by_line = by_line,
  root_ids = root_ids,
  NODE_LIST = list,
  NODE_BY_ID = by_id,
  LINE_BY_ID = by_line,
  ROOT_NODE_IDS = root_ids,
  get_node_def = function(node_id)
    return by_id[node_id]
  end,
  get_line_nodes = function(line_id)
    return by_line[line_id] or {}
  end,
}

return M

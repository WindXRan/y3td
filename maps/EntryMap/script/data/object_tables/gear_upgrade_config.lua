local CsvLoader = require 'data.csv_loader'

local slot_rows = CsvLoader.read_rows('data_csv/gear_upgrade_slots.csv')
local level_rows = CsvLoader.read_rows('data_csv/gear_upgrade_levels.csv')
local affix_rows = CsvLoader.read_rows('data_csv/gear_upgrade_affixes.csv')

local function to_boolean(raw)
  return raw == 'true' or raw == '1'
end

local function to_number(raw)
  if raw == nil or raw == '' or raw == 'null' then
    return nil
  end
  return tonumber(raw)
end

local function make_bonus_pack(row)
  local pack = {}
  local attack = to_number(row.bonus_attack) or 0
  local life = to_number(row.bonus_hp) or 0
  local armor = to_number(row.bonus_armor) or 0
  local all_attr = to_number(row.bonus_all_attr) or 0
  local attr_name = row.attr_name
  local attr_value = to_number(row.attr_value) or 0

  if attack ~= 0 then
    pack['攻击'] = attack
  end
  if life ~= 0 then
    pack['生命'] = life
  end
  if armor ~= 0 then
    pack['护甲'] = armor
  end
  if all_attr ~= 0 then
    pack['力量'] = (pack['力量'] or 0) + all_attr
    pack['敏捷'] = (pack['敏捷'] or 0) + all_attr
    pack['智力'] = (pack['智力'] or 0) + all_attr
  end
  if attr_name and attr_name ~= '' and attr_value ~= 0 then
    pack[attr_name] = (pack[attr_name] or 0) + attr_value
  end

  return pack
end

local slots = {}
local weapons_by_id = {}
local default_weapon_id = nil
for _, row in ipairs(slot_rows) do
  local weapon_id = row.weapon_id ~= '' and row.weapon_id or row.slot
  slots[row.slot] = {
    slot = row.slot,
    order_index = tonumber(row.order_index) or 0,
    display_name = row.display_name,
    max_level = tonumber(row.max_level) or 0,
    affix_choice_count = tonumber(row.affix_choice_count) or 0,
    item_key = tonumber(row.item_key) or row.item_key,
    weapon_id = weapon_id,
    weapon_name = row.weapon_name ~= '' and row.weapon_name or row.display_name,
    init_level = tonumber(row.init_level) or 1,
    base_desc = row.base_desc,
  }
  weapons_by_id[weapon_id] = {
    weapon_id = weapon_id,
    weapon_name = row.weapon_name ~= '' and row.weapon_name or row.display_name,
    init_level = tonumber(row.init_level) or 1,
    max_level = tonumber(row.max_level) or 0,
    item_key = tonumber(row.item_key) or row.item_key,
    base_desc = row.base_desc,
    slot = row.slot,
  }
  if not default_weapon_id then
    default_weapon_id = weapon_id
  end
end

local levels = {}
local levels_by_level = {}
local levels_by_weapon = {}
for _, row in ipairs(level_rows) do
  local weapon_id = row.weapon_id ~= '' and row.weapon_id or default_weapon_id
  local entry = {
    weapon_id = weapon_id,
    level = tonumber(row.level) or 0,
    order_index = tonumber(row.order_index) or 0,
    gold_cost = tonumber(row.gold_cost) or 0,
    is_affix_node = to_boolean(row.is_affix_node),
    affix_pool_id = row.affix_pool_id ~= '' and row.affix_pool_id or nil,
    bonus_pack = make_bonus_pack(row),
  }
  levels[#levels + 1] = entry
  levels_by_weapon[weapon_id] = levels_by_weapon[weapon_id] or {}
  levels_by_weapon[weapon_id][entry.level] = entry
  if weapon_id == default_weapon_id then
    levels_by_level[entry.level] = entry
  end
end

table.sort(levels, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

local affixes = {}
local affixes_by_id = {}
local affixes_by_pool = {}
for _, row in ipairs(affix_rows) do
  local entry = {
    affix_id = row.affix_id,
    pool_id = row.pool_id,
    order_index = tonumber(row.order_index) or 0,
    display_name = row.display_name,
    summary = row.summary ~= '' and row.summary or row.display_name,
    attr_name = row.attr_name,
    attr_value = to_number(row.attr_value) or 0,
    is_unique = to_boolean(row.is_unique),
    unique_group = row.unique_group ~= '' and row.unique_group or nil,
    bonus_pack = make_bonus_pack(row),
  }
  affixes[#affixes + 1] = entry
  affixes_by_id[entry.affix_id] = entry
  affixes_by_pool[entry.pool_id] = affixes_by_pool[entry.pool_id] or {}
  affixes_by_pool[entry.pool_id][#affixes_by_pool[entry.pool_id] + 1] = entry
end

table.sort(affixes, function(a, b)
  if a.pool_id == b.pool_id then
    return (a.order_index or 0) < (b.order_index or 0)
  end
  return tostring(a.pool_id) < tostring(b.pool_id)
end)

for _, pool in pairs(affixes_by_pool) do
  table.sort(pool, function(a, b)
    return (a.order_index or 0) < (b.order_index or 0)
  end)
end

return {
  slots = slots,
  weapons_by_id = weapons_by_id,
  default_weapon_id = default_weapon_id,
  levels = levels,
  levels_by_level = levels_by_level,
  levels_by_weapon = levels_by_weapon,
  affixes = affixes,
  affixes_by_id = affixes_by_id,
  affixes_by_pool = affixes_by_pool,
}

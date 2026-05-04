local helpers = require 'data.tables.helpers'
local CsvLoader = require 'data.csv_loader'

local SUIT_IDS = {
  DRAGON       = 'suit_dragon',
  PHOENIX      = 'suit_phoenix',
  TIGER        = 'suit_tiger',
  CRANE        = 'suit_crane',
  VIPER        = 'suit_viper',
}

local EQUIPMENT_SLOTS = {
  WEAPON   = 'weapon',
  ARMOR    = 'armor',
  HELMET   = 'helmet',
  BOOTS    = 'boots',
  ACCESSORY1 = 'accessory1',
  ACCESSORY2 = 'accessory2',
}

local function split_pipe(value)
  local result = {}
  for part in tostring(value or ''):gmatch('[^|]+') do
    local trimmed = part:gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed ~= '' then
      table.insert(result, trimmed)
    end
  end
  return result
end

local function parse_level_effects(row, level)
  local prefix = 'lv' .. level
  local desc = tostring(row[prefix .. '_desc'] or '')
  local attr_names = split_pipe(row[prefix .. '_attr'])
  local attr_values = split_pipe(row[prefix .. '_value'])
  local attr_types = split_pipe(row[prefix .. '_type'])
  
  local effects = {}
  for i, name in ipairs(attr_names) do
    local value = tonumber(attr_values[i]) or 0
    local is_ratio = attr_types[i] == 'ratio'
    table.insert(effects, {
      attr_name = name,
      value = value,
      is_ratio = is_ratio,
    })
  end
  
  return {
    star_level = level,
    effects = effects,
    description = desc,
  }
end

local function load_suit_catalog()
  local rows = CsvLoader.read_rows_optional('data_csv/by_feature/economy/suit_catalog.csv') or {}
  local list = {}
  
  for _, row in ipairs(rows) do
    local suit_id = tostring(row.suit_id or '')
    if suit_id ~= '' then
      local equipment = {
        { slot = EQUIPMENT_SLOTS.WEAPON, name = tostring(row.weapon_name or ''), icon = tonumber(row.icon) or 906565 },
        { slot = EQUIPMENT_SLOTS.ARMOR, name = tostring(row.armor_name or ''), icon = tonumber(row.icon) or 906565 },
        { slot = EQUIPMENT_SLOTS.HELMET, name = tostring(row.helmet_name or ''), icon = tonumber(row.icon) or 906565 },
        { slot = EQUIPMENT_SLOTS.BOOTS, name = tostring(row.boots_name or ''), icon = tonumber(row.icon) or 906565 },
        { slot = EQUIPMENT_SLOTS.ACCESSORY1, name = tostring(row.accessory1_name or ''), icon = tonumber(row.icon) or 906565 },
        { slot = EQUIPMENT_SLOTS.ACCESSORY2, name = tostring(row.accessory2_name or ''), icon = tonumber(row.icon) or 906565 },
      }
      
      local level_effects = {}
      for level = 1, 10 do
        level_effects[level] = parse_level_effects(row, level)
      end
      
      list[#list + 1] = {
        suit_id = suit_id,
        name = tostring(row.name or ''),
        icon = tonumber(row.icon) or 906565,
        quality = tostring(row.quality or ''),
        description = tostring(row.description or ''),
        effects_summary = tostring(row.effects_summary or ''),
        equipment = equipment,
        obtain_text = tostring(row.obtain_text or ''),
        owned_text = tostring(row.owned_text or ''),
        special_effect = tostring(row.special_effect or ''),
        attr_text = tostring(row.attr_text or ''),
        value_text = tostring(row.value_text or ''),
        level_effects = level_effects,
      }
    end
  end
  
  return list
end

local list = load_suit_catalog()

return {
  SUIT_IDS = SUIT_IDS,
  EQUIPMENT_SLOTS = EQUIPMENT_SLOTS,
  list = list,
  by_suit_id = helpers.list_to_map(list, 'suit_id'),
  MAX_STAR_LEVEL = 10,
}
local EditorJsonTable = require 'data.object_tables.editor_json_table'
local BondSkillTextTemplates = require 'data.object_tables.bond_skill_text_templates'

local M = {}

local ATTR_ALIASES = {
  ['攻击力'] = '攻击',
  ['移速'] = '移动速度',
  ['暴击'] = '物理暴击',
  ['法术暴率'] = '魔法暴击',
  ['法术暴伤'] = '魔法暴伤',
  ['法术伤害'] = '魔法伤害',
  ['最终减免'] = '伤害减免',
  ['射箭伤害'] = '普攻伤害',
}

local RATIO_ATTRS = {
  ['物理暴击'] = true,
  ['物理暴伤'] = true,
  ['魔法暴击'] = true,
  ['魔法暴伤'] = true,
  ['物理伤害'] = true,
  ['魔法伤害'] = true,
  ['普攻伤害'] = true,
  ['技能伤害'] = true,
  ['所有伤害'] = true,
  ['最终伤害'] = true,
  ['伤害减免'] = true,
  ['闪避'] = true,
  ['冷却缩减'] = true,
  ['召唤加成'] = true,
}

local function trim(text)
  return tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function split_pipe(text)
  local result = {}
  for part in string.gmatch(tostring(text or ''), '[^|]+') do
    result[#result + 1] = trim(part)
  end
  return result
end

local function normalize_attr_name(name)
  name = trim(name)
  if name == '' or name == '无' then
    return nil
  end
  return ATTR_ALIASES[name] or name
end

local function normalize_attr_value(attr_name, raw_value)
  local value = tonumber(raw_value) or 0
  if RATIO_ATTRS[attr_name] and math.abs(value) > 1 then
    return value / 100
  end
  return value
end

local function build_attr_pack(attr_text, value_text)
  local attrs = split_pipe(attr_text)
  local values = split_pipe(value_text)
  local pack = {}
  local lines = {}

  for index, raw_attr in ipairs(attrs) do
    local attr_name = normalize_attr_name(raw_attr)
    local raw_value = values[index]
    if attr_name and raw_value ~= nil then
      local value = normalize_attr_value(attr_name, raw_value)
      if value ~= 0 then
        pack[attr_name] = (pack[attr_name] or 0) + value
        lines[#lines + 1] = string.format('%s +%s', attr_name, tostring(raw_value))
      end
    end
  end

  return pack, lines
end

local function parse_required_count(condition)
  local count = tonumber(tostring(condition or ''):match('集齐%s*(%d+)%s*个'))
  return count or 5
end

local function read_first(row, keys, fallback)
  for _, key in ipairs(keys) do
    local value = row[key]
    if value ~= nil and tostring(value) ~= '' then
      return value
    end
  end
  return fallback
end

local function normalize_quality(value)
  local raw = trim(value)
  if raw == '' then
    return 'N'
  end
  local upper = string.upper(raw)
  if upper == 'N' or upper == 'R' or upper == 'SR' or upper == 'SSR' or upper == 'UR' then
    return upper
  end
  local lower = string.lower(raw)
  return ({
    common = 'N',
    excellent = 'R',
    rare = 'SR',
    epic = 'SSR',
    legendary = 'UR',
    ['普通'] = 'N',
    ['优秀'] = 'R',
    ['稀有'] = 'SR',
    ['史诗'] = 'SSR',
    ['传说'] = 'UR',
  })[lower] or ({
    ['普通'] = 'N',
    ['优秀'] = 'R',
    ['稀有'] = 'SR',
    ['史诗'] = 'SSR',
    ['传说'] = 'UR',
  })[raw] or upper
end

local function to_bool(value)
  if value == true then
    return true
  end
  local raw = trim(value)
  return raw == '1' or raw == '1.0' or string.lower(raw) == 'true'
end

local function build_card(row, index)
  local name = trim(read_first(row, { 'key', 'id', 'name', 'card_name', '卡牌名' }, ''))
  local bond_name = trim(read_first(row, { 'bond', 'bond_name', 'group_id', '羁绊所属' }, ''))
  if name == '' or bond_name == '' then
    return nil
  end

  local attr_pack, attr_lines = build_attr_pack(
    read_first(row, { 'attr', 'attrs', '属性' }, ''),
    read_first(row, { 'value', 'values', '数值' }, '')
  )
  local effect_desc_raw = trim(read_first(row, { 'activation_desc', 'bond_effect', '羁绊激活效果' }, ''))
  local extra_desc_raw = trim(read_first(row, { 'extra_skill_desc', 'extra_desc', '额外技能效果' }, ''))
  local effect_desc = BondSkillTextTemplates.get_activation_desc(bond_name, effect_desc_raw)
  local extra_desc = BondSkillTextTemplates.get_card_desc(name, bond_name, extra_desc_raw)
  local icon = tonumber(read_first(row, { 'icon', '图片icon', '图片', '图标' }, nil))
  local quality = normalize_quality(read_first(row, { 'quality', '品质' }, nil))

  return {
    index = index,
    id = trim(read_first(row, { 'card_id' }, '')) ~= ''
      and trim(read_first(row, { 'card_id' }, ''))
      or 'initial_bond_card_' .. tostring(index),
    name = name,
    bond_name = bond_name,
    desc = table.concat(attr_lines, '\n'),
    raw_attr_text = trim(read_first(row, { 'attr', 'attrs', '属性' }, '')),
    raw_value_text = trim(read_first(row, { 'value', 'values', '数值' }, '')),
    attr_pack = attr_pack,
    attr_lines = attr_lines,
    condition_text = trim(read_first(row, { 'condition', '条件' }, '')),
    required_count = parse_required_count(read_first(row, { 'condition', '条件' }, '')),
    activation_desc = effect_desc,
    extra_skill_desc = extra_desc,
    icon = icon,
    quality = quality,
    initially_unlocked = to_bool(read_first(row, { 'initially_unlocked', '是否初始解锁' }, '')),
  }
end

local cards = {}
local card_by_id = {}
local cards_by_bond = {}

local function read_pool_rows()
  for _, table_name in ipairs({ 'bonds_init', '初始羁绊卡池' }) do
    local rows = EditorJsonTable.read_rows(table_name)
    if type(rows) == 'table' and #rows > 0 then
      return rows
    end
  end
  return {}
end

for index, row in ipairs(read_pool_rows()) do
  local card = build_card(row, index)
  if card and card.initially_unlocked then
    cards[#cards + 1] = card
    card_by_id[card.id] = card
    cards_by_bond[card.bond_name] = cards_by_bond[card.bond_name] or {}
    cards_by_bond[card.bond_name][#cards_by_bond[card.bond_name] + 1] = card
  end
end

local activation_effects = {}
for bond_name, bond_cards in pairs(cards_by_bond) do
  local first_card = bond_cards[1]
  activation_effects[#activation_effects + 1] = {
    id = 'initial_bond_set_' .. bond_name,
    bond_name = bond_name,
    required_count = first_card and first_card.required_count or #bond_cards,
    name = bond_name,
    desc = first_card and first_card.activation_desc or '',
    icon = first_card and first_card.icon or nil,
    quality = first_card and first_card.quality or 'SR',
  }
end
table.sort(activation_effects, function(a, b)
  return tostring(a.bond_name) < tostring(b.bond_name)
end)

M.cards = cards
M.card_by_id = card_by_id
M.cards_by_bond = cards_by_bond
M.activation_effects = activation_effects
M.enabled = #cards > 0

return M

local EditorJsonTable = require 'data.tables.editor_json_table'
local BondSkillTextTemplates = require 'data.tables.bond.bond_skill_text_templates'
local CsvLoader = require 'data.csv_loader'
local SkillVisuals = require 'data.tables.skill.skill_visuals'

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

local function read_param_rows_by_skill_id()
  local result = {}
  for _, row in ipairs(CsvLoader.read_rows_optional('data_csv/bond_skill_params.csv')) do
    local skill_id = trim(row.skill_id)
    if skill_id ~= '' and skill_id ~= '__字段说明__' then
      result[skill_id] = row
    end
  end
  return result
end

local PARAM_BY_SKILL_ID = read_param_rows_by_skill_id()

local function read_param_text(skill_id, key)
  local row = PARAM_BY_SKILL_ID[trim(skill_id)]
  return row and trim(row[key]) or ''
end

local function read_param_number(skill_id, keys)
  local row = PARAM_BY_SKILL_ID[trim(skill_id)]
  if not row then
    return nil
  end
  for _, key in ipairs(keys or {}) do
    local num = tonumber(row[key])
    if num and num > 0 then
      return num
    end
  end
  return nil
end

local function resolve_visual_icon(skill_id, bond_name, fallback)
  local param_icon = read_param_number(skill_id, { 'ui_icon', 'icon' })
  if param_icon and param_icon > 0 then
    return param_icon
  end
  if fallback and tonumber(fallback) and tonumber(fallback) > 0 then
    return tonumber(fallback)
  end
  local visual = SkillVisuals.get_by_skill_id(skill_id) or SkillVisuals.get_by_bond_name(bond_name)
  local visual_icon = visual and visual.icon_key
  if visual_icon and tonumber(visual_icon) and tonumber(visual_icon) > 0 then
    return tonumber(visual_icon)
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
local bond_skill_by_bond = {}

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


local function is_enabled(raw)
  local value = string.lower(trim(raw))
  return value == '' or value == '1' or value == 'true'
end

local function build_fallback_cards_from_bond_skills()
  local rows = CsvLoader.read_rows_optional('data_csv/bond_skills.csv')
  local next_index = #cards + 1
  local bond_card_count = {}
  for _, row in ipairs(rows) do
    if is_enabled(row.enabled) then
      local scope = trim(row.scope)
      local skill_id = trim(row.skill_id)
      local skill_name = trim(row.skill_name)
      local bond_name = trim(row.bond_name)
      if (scope == 'bond_basic' or scope == 'bond_periodic') and skill_id ~= '' and bond_name ~= '' then
        local csv_icon = tonumber(row.icon) or tonumber(row['图标'])
        bond_skill_by_bond[bond_name] = {
          skill_id = skill_id,
          skill_name = skill_name,
          trigger_kind = trim(row.trigger_kind),
          damage_type = trim(row.damage_type),
          archetype = read_param_text(skill_id, 'archetype'),
          summary = read_param_text(skill_id, 'summary'),
          icon = resolve_visual_icon(skill_id, bond_name, csv_icon),
        }
      end
      if scope:match('^card_') and skill_id ~= '' and bond_name ~= '' then
        local param_name = read_param_text(skill_id, 'name')
        local summary = read_param_text(skill_id, 'summary')
        local csv_icon = tonumber(row.icon) or tonumber(row['图标'])
        local csv_bg = tonumber(row.bg) or tonumber(row['底图'])
        local card = {
          index = next_index,
          id = skill_id,
          name = param_name ~= '' and param_name or skill_name ~= '' and skill_name or skill_id,
          bond_name = bond_name,
          desc = '',
          raw_attr_text = '',
          raw_value_text = '',
          attr_pack = {},
          attr_lines = {},
          condition_text = '',
          required_count = 1,
          activation_desc = BondSkillTextTemplates.get_activation_desc(bond_name, ''),
          extra_skill_desc = summary ~= '' and summary or BondSkillTextTemplates.get_card_desc(skill_name, bond_name, ''),
          icon = resolve_visual_icon(skill_id, bond_name, csv_icon),
          bg = csv_bg,
          quality = 'SR',
          initially_unlocked = true,
        }
        cards[#cards + 1] = card
        card_by_id[card.id] = card
        cards_by_bond[bond_name] = cards_by_bond[bond_name] or {}
        cards_by_bond[bond_name][#cards_by_bond[bond_name] + 1] = card
        bond_card_count[bond_name] = (bond_card_count[bond_name] or 0) + 1
        next_index = next_index + 1
      end
    end
  end
  for bond_name, bond_cards in pairs(cards_by_bond) do
    local count = math.max(1, tonumber(bond_card_count[bond_name]) or #bond_cards or 1)
    for _, card in ipairs(bond_cards) do
      card.required_count = count
      card.condition_text = string.format('集齐 %d 个同技能卡牌', count)
    end
  end
end

if #cards == 0 then
  build_fallback_cards_from_bond_skills()
end

local activation_effects = {}
for bond_name, bond_cards in pairs(cards_by_bond) do
  local first_card = bond_cards[1]
  local bond_skill = bond_skill_by_bond[bond_name] or {}
  local desc = trim(bond_skill.summary) ~= '' and trim(bond_skill.summary) or (first_card and first_card.activation_desc or '')
  activation_effects[#activation_effects + 1] = {
    id = 'initial_bond_set_' .. bond_name,
    bond_name = bond_name,
    required_count = first_card and first_card.required_count or #bond_cards,
    name = bond_name,
    desc = desc,
    icon = resolve_visual_icon(bond_skill.skill_id, bond_name, first_card and first_card.icon or nil),
    bg = first_card and first_card.bg,
    quality = first_card and first_card.quality or 'SR',
    archetype = trim(bond_skill.archetype) ~= '' and trim(bond_skill.archetype) or trim(bond_skill.trigger_kind),
    damage_type = trim(bond_skill.damage_type),
    source_skill_id = bond_skill.skill_id,
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



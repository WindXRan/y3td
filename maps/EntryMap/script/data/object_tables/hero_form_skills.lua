local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local skill_rows = CsvLoader.read_rows('data_csv/hero_form_skills.csv')

local OPTIONAL_NUMBER_FIELDS = {
  order_index = true,
  trigger_value = true,
  cooldown = true,
  damage_ratio = true,
  splash_ratio = true,
  radius = true,
  target_count = true,
  bounce_count = true,
  repeat_count = true,
  repeat_interval = true,
  heal_ratio = true,
  hp_threshold = true,
  boss_bonus_ratio = true,
  gold_gain = true,
  delay = true,
}

local function to_optional_number(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local list = {}
for _, row in ipairs(skill_rows) do
  local entry = {
    id = row.id,
    hero_id = row.hero_id,
    rarity = row.rarity,
    name = row.name,
    subtitle = row.subtitle,
    trigger_type = row.trigger_type:gsub('%s+', ''),
    pattern = row.pattern,
    damage_type = row.damage_type,
    damage_form = row.damage_form,
    element = row.element,
    damage_label = row.damage_label,
    summary = row.summary,
    item_desc = row.item_desc,
  }

  for field_name, _ in pairs(OPTIONAL_NUMBER_FIELDS) do
    entry[field_name] = to_optional_number(row[field_name])
  end

  list[#list + 1] = entry
end

table.sort(list, function(a, b)
  local a_order = a.order_index or 0
  local b_order = b.order_index or 0
  if a_order == b_order then
    return tostring(a.id or '') < tostring(b.id or '')
  end
  return a_order < b_order
end)

local by_id = helpers.list_to_map(list)
local by_hero_id = {}
for _, skill in ipairs(list) do
  if skill.hero_id and skill.hero_id ~= '' then
    by_hero_id[skill.hero_id] = skill
  end
end

return {
  list = list,
  by_id = by_id,
  by_hero_id = by_hero_id,
}

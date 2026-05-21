local CsvLoader = require 'data.csv_loader'
local helpers = require 'data.tables.helpers'
local HeroRoster = require 'data.simple_data'.load_hero_roster()

local bonus_groups = {}
local hero_list = HeroRoster.list or {}
local hero_list_by_name = {}
for _, hero in ipairs(hero_list) do
  if hero.name then
    hero_list_by_name[hero.name] = hero
  end
end

local quality_rules = CsvLoader.read_rows({path = 'data_csv/outgame/hero_evolution_rules.csv'})

local quality_by_threshold = {}
for _, rule in ipairs(quality_rules) do
  local threshold = tonumber(rule.quality_threshold) or 0
  quality_by_threshold[threshold] = {
    quality = rule.quality,
    pool_weight = tonumber(rule.base_pool_weight) or 0,
  }
end

local sorted_thresholds = {}
for threshold in pairs(quality_by_threshold) do
  sorted_thresholds[#sorted_thresholds + 1] = threshold
end
table.sort(sorted_thresholds, function(a, b) return a > b end)

local function get_quality_by_index(index)
  for _, threshold in ipairs(sorted_thresholds) do
    if index >= threshold then
      return quality_by_threshold[threshold]
    end
  end
  return quality_by_threshold[sorted_thresholds[#sorted_thresholds]] or { quality = 'common', pool_weight = 45 }
end

local function build_bonus_bucket(evolution_id, bucket_name)
  local source = bonus_groups[evolution_id]
  local bucket = source and source[bucket_name] or nil
  if not bucket then
    return nil
  end
  local out = {}
  for key, value in pairs(bucket) do
    out[key] = tonumber(value) or 0
  end
  return out
end

local function push_evolution(index, hero_entry)
  local quality_info = get_quality_by_index(index)

  local evolution_id = string.format('mark_%s', tostring(hero_entry.id or index))

  local hero_name = hero_entry.name
  local hero_info = hero_list_by_name[hero_name] or {}
  local skill_icon = hero_info.skill_icon
  local hero_icon = hero_entry.icon
  local hero_bg = hero_entry.bg

  return {
    id = evolution_id,
    name = hero_entry.name or ('英雄专精' .. tostring(index)),
    quality = quality_info.quality,
    pool_weight = quality_info.pool_weight,
    order_index = index,
    hero_unit_id = hero_entry.unit_id,
    summary = hero_entry.summary or '激活该英雄真身与专精效果。',
    tags = { 'hero_form', quality_info.quality },
    icon = skill_icon or hero_icon,
    ui_icon = skill_icon or hero_icon,
    icon_res = skill_icon,
    bg = hero_bg,
    bonuses = {
      attr = build_bonus_bucket(evolution_id, 'attr'),
      runtime = build_bonus_bucket(evolution_id, 'runtime'),
      attack_skill = build_bonus_bucket(evolution_id, 'attack_skill'),
    },
  }
end

local list = {}

for index, hero_entry in ipairs(hero_list) do
  if index > 8 then
    break
  end
  if hero_entry and hero_entry.id then
    list[#list + 1] = push_evolution(index, hero_entry)
  end
end

table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
  quality_rules = quality_rules,
}
local CsvLoader = require 'data.csv_loader'
local catalog = require 'data.object_tables.treasure_catalog'
local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'
local helpers = require 'entry_objects.helpers'
local HeroAttrDefs = require 'runtime.hero_attr_defs'

local rarity_rows = CsvLoader.read_rows('data_csv/treasure_compat_rarity_map.csv')
local runtime_key_rows = CsvLoader.read_rows('data_csv/treasure_compat_runtime_key_map.csv')
local tag_rule_rows = CsvLoader.read_rows('data_csv/treasure_compat_tag_rules.csv')
local duration_rule_rows = CsvLoader.read_rows('data_csv/treasure_compat_duration_rules.csv')
local effect_bucket_rule_rows = CsvLoader.read_rows('data_csv/treasure_compat_effect_bucket_rules.csv')

local function build_scalar_map(rows, key_field, value_field)
  local map = {}
  for _, row in ipairs(rows or {}) do
    local key = row[key_field]
    if key ~= nil and key ~= '' then
      map[key] = row[value_field]
    end
  end
  return map
end

local RARITY_TO_QUALITY = build_scalar_map(rarity_rows, 'source_rarity', 'output_quality')
local NORMALIZED_RUNTIME_KEYS = build_scalar_map(runtime_key_rows, 'source_key', 'output_runtime_key')

local DEFAULT_POOL_WEIGHT = {}
for _, row in ipairs(rarity_rows or {}) do
  DEFAULT_POOL_WEIGHT[row.source_rarity] = tonumber(row.output_pool_weight) or 1
end

table.sort(tag_rule_rows, function(a, b)
  return (tonumber(a.order_index) or 0) < (tonumber(b.order_index) or 0)
end)

table.sort(duration_rule_rows, function(a, b)
  return (tonumber(a.order_index) or 0) < (tonumber(b.order_index) or 0)
end)

table.sort(effect_bucket_rule_rows, function(a, b)
  return (tonumber(a.order_index) or 0) < (tonumber(b.order_index) or 0)
end)

local function add_pack_value(pack, key, value)
  if key == nil or key == '' or value == nil then
    return
  end
  pack[key] = value
end

local function canonical_attr_name(key)
  local canonical = HeroAttrDefs.aliases[key] or key
  if HeroAttrDefs.by_name[canonical] then
    return canonical
  end
  return nil
end

local function canonical_runtime_key(key)
  return NORMALIZED_RUNTIME_KEYS[key] or key
end

local function infer_duration_type_and_treasure_type(item, effects)
  for _, rule in ipairs(duration_rule_rows or {}) do
    for _, effect in ipairs(effects or {}) do
      local raw_value = tostring(effect[rule.match_field] or '')
      local matched = false

      if rule.match_type == 'equals' then
        matched = raw_value == tostring(rule.match_value or '')
      elseif rule.match_type == 'contains' then
        matched = string.find(raw_value, tostring(rule.match_value or ''), 1, true) ~= nil
      elseif rule.match_type == 'default' then
        matched = true
      end

      if matched then
        local duration = nil
        if rule.output_duration_type == 'timed' then
          duration = {
            trigger = rule.output_trigger ~= '' and rule.output_trigger or 'immediate',
            duration_sec = tonumber(rule.output_duration_sec) or tonumber(raw_value:match('^(%d+)s$')) or nil,
          }
        end
        return rule.output_duration_type, duration, rule.output_treasure_type ~= '' and rule.output_treasure_type or nil
      end
    end
  end

  return 'permanent', nil, 'general'
end

local function infer_tags(item)
  local tags = {}
  local seen = {}

  for _, rule in ipairs(tag_rule_rows or {}) do
    local raw_value = tostring(item[rule.match_field] or '')
    local matched = false

    if rule.match_type == 'contains' then
      matched = string.find(raw_value, tostring(rule.match_value or ''), 1, true) ~= nil
    elseif rule.match_type == 'equals' then
      matched = raw_value == tostring(rule.match_value or '')
    end

    if matched and rule.output_tag ~= '' and not seen[rule.output_tag] then
      tags[#tags + 1] = rule.output_tag
      seen[rule.output_tag] = true
    end
  end

  return tags
end

local function build_bonus_packs(item)
  local bonuses = {
    attr = {},
    runtime = {},
    reward_ratio = {},
    passive_income = {},
    misc_effects = {},
  }

  for _, effect in ipairs(item.effects or {}) do
    local canonical_attr = canonical_attr_name(effect.effect_key)
    local handled = false

    if canonical_attr then
      add_pack_value(bonuses.attr, canonical_attr, effect.value)
    end

    for _, rule in ipairs(effect_bucket_rule_rows or {}) do
      local effect_type_match = rule.match_effect_type == effect.effect_type
      local effect_key_match = rule.match_effect_key == '*' or rule.match_effect_key == effect.effect_key
      local require_attr = rule.requires_canonical_attr == 'true' or rule.requires_canonical_attr == '1'

      if effect_type_match and effect_key_match and (not require_attr or canonical_attr ~= nil) then
        if rule.output_bucket == 'passive_income' and canonical_attr then
          add_pack_value(bonuses.passive_income, canonical_attr, effect.value)
        elseif rule.output_bucket == 'reward_ratio' then
          add_pack_value(bonuses.reward_ratio, effect.effect_key, effect.value)
        elseif rule.output_bucket == 'runtime' then
          add_pack_value(bonuses.runtime, canonical_runtime_key(effect.effect_key), effect.value)
        end
        handled = true
      end
    end

    if not handled and canonical_attr == nil then
      bonuses.misc_effects[#bonuses.misc_effects + 1] = effect
    end
  end

  return bonuses
end

local list = {}
for _, item in ipairs(catalog.list or {}) do
  local duration_type, duration, treasure_type = infer_duration_type_and_treasure_type(item, item.effects)
  list[#list + 1] = {
    order_index = item.order_index,
    id = item.id,
    editor_item_key = RuntimeEditorIds.treasure and RuntimeEditorIds.treasure[item.id] or nil,
    name = item.name,
    quality = RARITY_TO_QUALITY[item.rarity] or 'common',
    summary = item.summary,
    pool_weight = DEFAULT_POOL_WEIGHT[item.rarity] or 1,
    treasure_type = treasure_type or 'general',
    duration_type = duration_type,
    duration = duration,
    source_category = item.category,
    set_id = item.set_id,
    notes = item.notes,
    tags = infer_tags(item),
    theme_tags = {},
    best_with_tags = {},
    timing_tags = duration_type == 'timed' and { 'timed' } or { duration_type },
    bonuses = build_bonus_packs(item),
    source_effects = item.effects,
  }
end

return {
  list = list,
  by_id = helpers.list_to_map(list),
  source_catalog = catalog,
}

local catalog = require 'data.object_tables.treasure_catalog'
local helpers = require 'entry_objects.helpers'
local HeroAttrDefs = require 'runtime.hero_attr_defs'

local RARITY_TO_QUALITY = {
  normal = 'common',
  rare = 'rare',
  epic = 'epic',
}

local DEFAULT_POOL_WEIGHT = {
  normal = 8,
  rare = 6,
  epic = 4,
}

local NORMALIZED_RUNTIME_KEYS = {
  gold = '立即金币',
  wood = '立即木材',
  exp = '立即经验',
  skill_refresh_free = '技能免费刷新次数',
  hero_refresh_free = '英雄免费刷新次数',
  treasure_refresh_free = '宝物免费刷新次数',
  rune_store_mode = '神符存储模式',
  random_attr_point = '随机属性点',
  randomize_base_stats = '重置基础三维',
  wood_ratio = '木材翻倍',
  wood_clear = '木材清零',
  kill_count = '杀敌数',
  damage_ratio = '条件伤害加成',
  todo_effect = '待补充效果',
}

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

local function infer_duration_type(item, effects)
  for _, effect in ipairs(effects or {}) do
    if effect.scope == '30s' then
      return 'timed', { trigger = 'immediate', duration_sec = tonumber(effect.scope:match('^(%d+)s$')) or 30 }
    end
  end

  for _, effect in ipairs(effects or {}) do
    if effect.scope == 'instant' then
      return 'instant', nil
    end
  end

  return 'permanent', nil
end

local function infer_treasure_type(item, duration_type)
  if duration_type == 'timed' or duration_type == 'instant' then
    return 'tactical_temp'
  end
  return 'general'
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
    if effect.effect_type == 'passive_income' and canonical_attr then
      add_pack_value(bonuses.attr, canonical_attr, effect.value)
      add_pack_value(bonuses.passive_income, canonical_attr, effect.value)
    elseif canonical_attr then
      add_pack_value(bonuses.attr, canonical_attr, effect.value)
    elseif effect.effect_type == 'ratio_bonus' and (effect.effect_key == 'gold' or effect.effect_key == 'wood' or effect.effect_key == 'exp') then
      add_pack_value(bonuses.reward_ratio, effect.effect_key, effect.value)
    elseif effect.effect_type == 'resource_gain' then
      add_pack_value(bonuses.runtime, canonical_runtime_key(effect.effect_key), effect.value)
    elseif effect.effect_type == 'refresh_count' then
      add_pack_value(bonuses.runtime, canonical_runtime_key(effect.effect_key), effect.value)
    elseif effect.effect_type == 'mechanic_toggle' then
      add_pack_value(bonuses.runtime, canonical_runtime_key(effect.effect_key), effect.value)
    elseif effect.effect_type == 'trigger_growth' then
      add_pack_value(bonuses.runtime, canonical_runtime_key(effect.effect_key), effect.value)
    elseif effect.effect_type == 'temporary_buff' or effect.effect_type == 'conditional_damage' or effect.effect_type == 'probability' or effect.effect_type == 'ratio_bonus' then
      add_pack_value(bonuses.runtime, canonical_runtime_key(effect.effect_key), effect.value)
    else
      bonuses.misc_effects[#bonuses.misc_effects + 1] = effect
    end
  end

  return bonuses
end

local list = {}
for _, item in ipairs(catalog.list or {}) do
  local duration_type, duration = infer_duration_type(item, item.effects)
  list[#list + 1] = {
    id = item.id,
    name = item.name,
    quality = RARITY_TO_QUALITY[item.rarity] or 'common',
    summary = item.summary,
    pool_weight = DEFAULT_POOL_WEIGHT[item.rarity] or 1,
    treasure_type = infer_treasure_type(item, duration_type),
    duration_type = duration_type,
    duration = duration,
    source_category = item.category,
    set_id = item.set_id,
    notes = item.notes,
    tags = {},
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

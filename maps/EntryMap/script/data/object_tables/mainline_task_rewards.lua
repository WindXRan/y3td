local CsvLoader = require 'data.csv_loader'
local AttrEffect = require 'data.object_tables.attreffect'
local helpers = require 'entry_objects.helpers'

local rows = CsvLoader.read_rows('data_csv/mainline_task_rewards.csv')
local effect_rows = AttrEffect.by_source.mainline_task or {}

local LEGACY_ATTR_KEY_BY_CANONICAL_ATTR = {
  ['生命'] = 'hp',
  ['生命恢复'] = 'hp_regen',
  ['护甲'] = 'armor',
  ['格挡'] = 'block',
  ['攻击'] = 'attack',
  ['攻击范围'] = 'attack_range',
  ['攻击速度'] = 'attack_speed_pct',
  ['力量'] = 'strength',
  ['敏捷'] = 'agility',
  ['智力'] = 'intelligence',
  ['全属性'] = 'all_attributes',
  ['力量增幅'] = 'strength_growth_pct',
  ['敏捷增幅'] = 'agility_growth_pct',
  ['智力增幅'] = 'intelligence_growth_pct',
  ['攻击增幅'] = 'attack_growth_pct',
  ['物理伤害'] = 'physical_damage_pct',
  ['魔法伤害'] = 'magic_damage_pct',
  ['普攻伤害'] = 'basic_attack_damage_pct',
  ['技能伤害'] = 'skill_damage_pct',
  ['所有伤害'] = 'all_damage_pct',
  ['物理暴击'] = 'physical_crit_pct',
  ['物理暴伤'] = 'physical_crit_damage_pct',
  ['魔法暴击'] = 'magic_crit_pct',
  ['魔法暴伤'] = 'magic_crit_damage_pct',
  ['金行伤害'] = 'metal_damage_pct',
  ['木行伤害'] = 'wood_damage_pct',
  ['水行伤害'] = 'water_damage_pct',
  ['火行伤害'] = 'fire_damage_pct',
  ['土行伤害'] = 'earth_damage_pct',
}

local LEGACY_RUNTIME_KEY_BY_CANONICAL_ATTR = {
  ['每秒金币'] = 'gold_per_sec',
  ['每秒木材'] = 'wood_per_sec',
  ['每秒经验'] = 'exp_per_sec',
  ['杀敌数'] = 'kill_count',
  ['每秒杀敌'] = 'kill_per_sec',
  ['每秒力量'] = 'strength_per_sec',
  ['每秒敏捷'] = 'agility_per_sec',
  ['每秒智力'] = 'intelligence_per_sec',
  ['杀敌金币'] = 'kill_gold_pct',
  ['杀敌经验'] = 'kill_exp_pct',
  ['杀敌木材'] = 'kill_wood_pct',
  ['精控伤害'] = 'elite_damage_pct',
  ['挑战伤害'] = 'challenge_damage_pct',
}

local LEGACY_SPECIAL_KEY_BY_STATE = {
  skill_point = 'skill_point',
  hero_card_count = 'hero_card',
}

local function to_optional_number(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local function build_reward_lines(row)
  local lines = {}
  for index = 1, 3 do
    local prefix = 'reward_' .. index .. '_'
    local reward_type = row[prefix .. 'type']
    local reward_key = row[prefix .. 'key']
    local reward_value = tonumber(row[prefix .. 'value'])
    if reward_type ~= '' and reward_key ~= '' and reward_value ~= nil then
      lines[#lines + 1] = {
        slot = index,
        type = reward_type,
        key = reward_key,
        value = reward_value,
      }
    end
  end
  local bucket = effect_rows[row.id]
  for _, effect in ipairs(bucket and bucket.ordered or {}) do
    if effect.effect_kind == 'attr' then
      local legacy_attr_key = LEGACY_ATTR_KEY_BY_CANONICAL_ATTR[effect.effect_key]
      if legacy_attr_key ~= nil then
        lines[#lines + 1] = {
          slot = effect.order_index,
          type = 'attr',
          key = legacy_attr_key,
          value = effect.value,
        }
      else
        local legacy_runtime_key = LEGACY_RUNTIME_KEY_BY_CANONICAL_ATTR[effect.effect_key]
        assert(legacy_runtime_key ~= nil, 'unsupported canonical mainline attr key: ' .. tostring(effect.effect_key))
        lines[#lines + 1] = {
          slot = effect.order_index,
          type = 'runtime',
          key = legacy_runtime_key,
          value = effect.value,
        }
      end
    elseif effect.effect_kind == 'resource' then
      lines[#lines + 1] = {
        slot = effect.order_index,
        type = 'resource',
        key = effect.effect_key,
        value = effect.value,
      }
    elseif effect.effect_kind == 'state' then
      local special_key = LEGACY_SPECIAL_KEY_BY_STATE[effect.effect_key]
      assert(special_key ~= nil, 'unsupported canonical mainline state key: ' .. tostring(effect.effect_key))
      lines[#lines + 1] = {
        slot = effect.order_index,
        type = 'special',
        key = special_key,
        value = effect.value,
      }
    else
      error('unsupported mainline effect_kind in phase 1: ' .. tostring(effect.effect_kind))
    end
  end
  table.sort(lines, function(a, b)
    if (a.slot or 0) == (b.slot or 0) then
      return tostring(a.type or '') < tostring(b.type or '')
    end
    return (a.slot or 0) < (b.slot or 0)
  end)
  return lines
end

local list = {}
for _, row in ipairs(rows) do
  list[#list + 1] = {
    id = row.id,
    chapter_id = tonumber(row.chapter_id) or 0,
    order_index = tonumber(row.order_index) or 0,
    title_text = row.title_text,
    objective_text = row.objective_text,
    target_count = tonumber(row.target_count) or 0,
    time_limit = tonumber(row.time_limit) or 60,
    spawn_unit_id = to_optional_number(row.spawn_unit_id),
    spawn_area_id = row.spawn_area_id ~= '' and row.spawn_area_id or nil,
    is_boss_task = row.is_boss_task == 'true',
    reward_lines = build_reward_lines(row),
  }
end

table.sort(list, function(a, b)
  if (a.chapter_id or 0) == (b.chapter_id or 0) then
    return (a.order_index or 0) < (b.order_index or 0)
  end
  return (a.chapter_id or 0) < (b.chapter_id or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}

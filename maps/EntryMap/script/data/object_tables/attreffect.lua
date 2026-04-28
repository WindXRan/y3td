local CsvLoader = require 'data.csv_loader'
local HeroAttrDefs = require 'runtime.hero_attr_defs'

local rows = CsvLoader.read_rows_optional('data_csv/attreffect.csv')

local VALID_EFFECT_KINDS = {
  attr = true,
  resource = true,
  state = true,
  runtime = true,
  attack_skill = true,
}

local VALID_RESOURCE_KEYS = {
  gold = true,
  wood = true,
  exp = true,
}

local VALID_STATE_KEYS = {
  skill_point = true,
  hero_card_count = true,
}

local VALID_RUNTIME_KEYS = {
  agility_on_kill = true,
  agility_per_second = true,
  all_damage_bonus = true,
  attack_on_kill = true,
  attack_per_second = true,
  boss_damage_bonus = true,
  chain_bounces = true,
  bounce_count_bonus = true,
  critical_damage_bonus = true,
  elemental_damage_bonus = true,
  elite_damage_bonus = true,
  gold_per_sec_bonus = true,
  intelligence_on_kill = true,
  intelligence_per_second = true,
  kill_gold_ratio = true,
  kill_reward_ratio = true,
  low_hp_damage_bonus = true,
  multishot_count = true,
  multishot_bonus = true,
  normal_attack_damage_bonus = true,
  skill_damage_bonus = true,
  skill_echo_chance = true,
  spell_damage_bonus = true,
  strength_on_kill = true,
  strength_per_second = true,
  wood_per_sec_bonus = true,
}

local VALID_ATTACK_SKILL_KEYS = {
  cooldown_reduction = true,
  range_bonus = true,
}

local COMPAT_ATTR_KEYS = {
  ['伤害加成'] = true,
  ['杀敌数'] = true,
  ['技能急速'] = true,
  ['全属性'] = true,
}

local REMOVED_ATTR_KEYS = {
  ['金行伤害'] = true,
  ['木行伤害'] = true,
  ['水行伤害'] = true,
  ['火行伤害'] = true,
  ['土行伤害'] = true,
}

local function validate_attr_key(key)
  return HeroAttrDefs.by_name[key] ~= nil or COMPAT_ATTR_KEYS[key] == true
end

local function make_source_bucket(source_type, source_id)
  return {
    source_type = source_type,
    source_id = source_id,
    ordered = {},
    attr = {},
    resource = {},
    state = {},
    runtime = {},
    attack_skill = {},
  }
end

local by_source = {}
local list = {}
local seen_scoped_order = {}

for _, row in ipairs(rows) do
  if row.effect_kind == 'attr' and REMOVED_ATTR_KEYS[row.effect_key] == true then
    goto continue
  end

  assert(row.source_type ~= '', 'attreffect source_type is required')
  assert(row.source_id ~= '', 'attreffect source_id is required')
  assert(VALID_EFFECT_KINDS[row.effect_kind] == true, 'invalid effect_kind: ' .. tostring(row.effect_kind))

  local order_index = tonumber(row.order_index)
  assert(order_index ~= nil, 'attreffect order_index must be numeric')

  local number = tonumber(row.value)
  assert(number ~= nil, 'attreffect value must be numeric')

  if row.effect_kind == 'attr' then
    assert(validate_attr_key(row.effect_key), 'invalid attr effect_key: ' .. tostring(row.effect_key))
  elseif row.effect_kind == 'resource' then
    assert(VALID_RESOURCE_KEYS[row.effect_key] == true, 'invalid resource effect_key: ' .. tostring(row.effect_key))
  elseif row.effect_kind == 'state' then
    assert(VALID_STATE_KEYS[row.effect_key] == true, 'invalid state effect_key: ' .. tostring(row.effect_key))
  elseif row.effect_kind == 'runtime' then
    assert(VALID_RUNTIME_KEYS[row.effect_key] == true, 'invalid runtime effect_key: ' .. tostring(row.effect_key))
  elseif row.effect_kind == 'attack_skill' then
    assert(VALID_ATTACK_SKILL_KEYS[row.effect_key] == true, 'invalid attack_skill effect_key: ' .. tostring(row.effect_key))
  end

  local scoped_order = string.format('%s::%s::%d', row.source_type, row.source_id, order_index)
  assert(seen_scoped_order[scoped_order] == nil, 'duplicate scoped order: ' .. scoped_order)
  seen_scoped_order[scoped_order] = true

  by_source[row.source_type] = by_source[row.source_type] or {}
  by_source[row.source_type][row.source_id] = by_source[row.source_type][row.source_id] or make_source_bucket(row.source_type, row.source_id)
  local bucket = by_source[row.source_type][row.source_id]

  local entry = {
    source_type = row.source_type,
    source_id = row.source_id,
    order_index = order_index,
    effect_kind = row.effect_kind,
    effect_key = row.effect_key,
    value = number,
  }

  bucket.ordered[#bucket.ordered + 1] = entry
  bucket[row.effect_kind][row.effect_key] = (bucket[row.effect_kind][row.effect_key] or 0) + number
  list[#list + 1] = entry

  ::continue::
end

for _, source_group in pairs(by_source) do
  for _, bucket in pairs(source_group) do
    table.sort(bucket.ordered, function(a, b)
      if a.order_index == b.order_index then
        if a.effect_kind == b.effect_kind then
          return a.effect_key < b.effect_key
        end
        return a.effect_kind < b.effect_kind
      end
      return a.order_index < b.order_index
    end)
  end
end

table.sort(list, function(a, b)
  if a.source_type == b.source_type then
    if a.source_id == b.source_id then
      return a.order_index < b.order_index
    end
    return a.source_id < b.source_id
  end
  return a.source_type < b.source_type
end)

return {
  list = list,
  by_source = by_source,
}

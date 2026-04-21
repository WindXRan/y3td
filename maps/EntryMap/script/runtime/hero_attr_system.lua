local Defs = require 'runtime.hero_attr_defs'
local HeroAttrLog = require 'runtime.hero_attr_log'

local M = {}
local KV_PREFIX = '__hero_attr__:'
local MAIN_STAT_ATTACK_FACTOR = 5
local STRENGTH_FINAL_LIFE_RATIO_PER_POINT = 0.001
local AGILITY_PHYSICAL_DAMAGE_RATIO_PER_POINT = 0.001
local INTELLIGENCE_MAGIC_DAMAGE_RATIO_PER_POINT = 0.001

local function normalize_ratio(value)
  local number = tonumber(value) or 0
  if math.abs(number) > 1 then
    return number / 100
  end
  return number
end

local function make_default_pack(seed)
  local result = {}
  for name, value in pairs(Defs.default_values) do
    result[name] = value
  end
  for name, value in pairs(seed or {}) do
    local canonical = Defs.aliases[name] or name
    result[canonical] = value
  end
  if seed and seed['攻击'] ~= nil and seed['攻击白字'] == nil and seed['攻击绿字'] == nil then
    result['攻击白字'] = seed['攻击']
    result['攻击'] = 0
  end
  if seed and seed['生命'] ~= nil and seed['生命白字'] == nil and seed['生命绿字'] == nil then
    result['生命白字'] = seed['生命']
    result['生命'] = 0
  end
  if seed and seed['护甲'] ~= nil and seed['护甲白字'] == nil and seed['护甲绿字'] == nil then
    result['护甲白字'] = seed['护甲']
    result['护甲'] = 0
  end
  if seed and seed['力量'] ~= nil and seed['力量白字'] == nil and seed['力量绿字'] == nil then
    result['力量白字'] = seed['力量']
    result['力量'] = 0
  end
  if seed and seed['敏捷'] ~= nil and seed['敏捷白字'] == nil and seed['敏捷绿字'] == nil then
    result['敏捷白字'] = seed['敏捷']
    result['敏捷'] = 0
  end
  if seed and seed['智力'] ~= nil and seed['智力白字'] == nil and seed['智力绿字'] == nil then
    result['智力白字'] = seed['智力']
    result['智力'] = 0
  end
  return result
end

function M.create()
  local api = {}
  local rebuild_log_counters = setmetatable({}, { __mode = 'k' })
  local mirror_attr

  local function get_storage_key(name)
    return KV_PREFIX .. tostring(name)
  end

  local function can_use_kv(hero)
    return hero and hero.kv_save and hero.kv_load
  end

  local function load_kv_number(hero, key)
    local ok, value = pcall(function()
      return hero:kv_load(key, 'number')
    end)
    if ok then
      return tonumber(value) or 0
    end

    ok, value = pcall(function()
      return hero:kv_load(key, 'integer')
    end)
    if ok then
      return tonumber(value) or 0
    end

    return nil
  end

  local function has_engine_attr(name)
    return y3 and y3.const and y3.const.UnitAttr and y3.const.UnitAttr[name] ~= nil
  end

  local function read_canonical_attr(hero, canonical)
    if can_use_kv(hero) and hero:kv_has(get_storage_key(canonical)) then
      local value = load_kv_number(hero, get_storage_key(canonical))
      if value ~= nil then
        return value
      end
    end
    return tonumber(hero:get_attr(canonical)) or 0
  end

  local function write_canonical_attr(hero, canonical, number)
    if can_use_kv(hero) then
      hero:kv_save(get_storage_key(canonical), number + 0.0)
    end
    mirror_attr(hero, canonical, number)
  end

  local function get_attack_white(hero)
    return read_canonical_attr(hero, '攻击白字')
  end

  local function get_attack_green(hero)
    return read_canonical_attr(hero, '攻击绿字')
  end

  local function get_attack_total(hero)
    local white = get_attack_white(hero)
    local green = get_attack_green(hero)
    if white ~= 0 or green ~= 0 then
      return white + green
    end
    return read_canonical_attr(hero, '攻击')
  end

  local function get_life_white(hero)
    return read_canonical_attr(hero, '生命白字')
  end

  local function get_life_green(hero)
    return read_canonical_attr(hero, '生命绿字')
  end

  local function get_life_total(hero)
    local white = get_life_white(hero)
    local green = get_life_green(hero)
    if white ~= 0 or green ~= 0 then
      return white + green
    end
    return read_canonical_attr(hero, '生命')
  end

  local function get_armor_white(hero)
    return read_canonical_attr(hero, '护甲白字')
  end

  local function get_armor_green(hero)
    return read_canonical_attr(hero, '护甲绿字')
  end

  local function get_armor_total(hero)
    local white = get_armor_white(hero)
    local green = get_armor_green(hero)
    if white ~= 0 or green ~= 0 then
      return white + green
    end
    return read_canonical_attr(hero, '护甲')
  end

  local function get_strength_white(hero)
    return read_canonical_attr(hero, '力量白字')
  end

  local function get_strength_green(hero)
    return read_canonical_attr(hero, '力量绿字')
  end

  local function get_strength_total(hero)
    local white = get_strength_white(hero)
    local green = get_strength_green(hero)
    if white ~= 0 or green ~= 0 then
      return white + green
    end
    return read_canonical_attr(hero, '力量')
  end

  local function get_agility_white(hero)
    return read_canonical_attr(hero, '敏捷白字')
  end

  local function get_agility_green(hero)
    return read_canonical_attr(hero, '敏捷绿字')
  end

  local function get_agility_total(hero)
    local white = get_agility_white(hero)
    local green = get_agility_green(hero)
    if white ~= 0 or green ~= 0 then
      return white + green
    end
    return read_canonical_attr(hero, '敏捷')
  end

  local function get_intelligence_white(hero)
    return read_canonical_attr(hero, '智力白字')
  end

  local function get_intelligence_green(hero)
    return read_canonical_attr(hero, '智力绿字')
  end

  local function get_intelligence_total(hero)
    local white = get_intelligence_white(hero)
    local green = get_intelligence_green(hero)
    if white ~= 0 or green ~= 0 then
      return white + green
    end
    return read_canonical_attr(hero, '智力')
  end

  mirror_attr = function(hero, name, value)
    if not hero or not hero.set_attr then
      return
    end
    if not y3 or not y3.const or not y3.const.UnitAttr then
      hero:set_attr(name, value or 0)
      return
    end
    if not has_engine_attr(name) then
      return
    end
    hero:set_attr(name, value or 0)
  end

  local function sync_engine_max_hp(hero, value)
    if not hero or not hero.set_attr then
      return
    end
    if not y3 or not y3.const or not y3.const.UnitAttr then
      return
    end
    if not has_engine_attr('最大生命') then
      return
    end
    hero:set_attr('最大生命', value or 1)
  end

  function api.normalize_name(name)
    return Defs.aliases[name] or name
  end

  function api.get_attr(hero, name)
    if not hero or not name then
      return 0
    end
    local canonical = api.normalize_name(name)
    if canonical == '攻击' then
      return get_attack_total(hero)
    end
    if canonical == '生命' then
      return get_life_total(hero)
    end
    if canonical == '护甲' then
      return get_armor_total(hero)
    end
    if canonical == '力量' then
      return get_strength_total(hero)
    end
    if canonical == '敏捷' then
      return get_agility_total(hero)
    end
    if canonical == '智力' then
      return get_intelligence_total(hero)
    end
    return read_canonical_attr(hero, canonical)
  end

  function api.set_attr(hero, name, value)
    if not hero or not name then
      return
    end
    local canonical = api.normalize_name(name)
    local number = tonumber(value) or 0
    if canonical == '攻击' then
      local white = get_attack_white(hero)
      write_canonical_attr(hero, '攻击绿字', number - white)
      write_canonical_attr(hero, '攻击', number)
      return
    end
    if canonical == '生命' then
      local white = get_life_white(hero)
      write_canonical_attr(hero, '生命绿字', number - white)
      write_canonical_attr(hero, '生命', number)
      return
    end
    if canonical == '护甲' then
      local white = get_armor_white(hero)
      write_canonical_attr(hero, '护甲绿字', number - white)
      write_canonical_attr(hero, '护甲', number)
      return
    end
    if canonical == '力量' then
      local white = get_strength_white(hero)
      write_canonical_attr(hero, '力量绿字', number - white)
      write_canonical_attr(hero, '力量', number)
      return
    end
    if canonical == '敏捷' then
      local white = get_agility_white(hero)
      write_canonical_attr(hero, '敏捷绿字', number - white)
      write_canonical_attr(hero, '敏捷', number)
      return
    end
    if canonical == '智力' then
      local white = get_intelligence_white(hero)
      write_canonical_attr(hero, '智力绿字', number - white)
      write_canonical_attr(hero, '智力', number)
      return
    end
    write_canonical_attr(hero, canonical, number)
  end

  function api.add_attr(hero, name, value)
    if not hero or not name or value == nil or value == 0 then
      return
    end
    local canonical = api.normalize_name(name)
    local number = tonumber(value) or 0
    if canonical == '攻击' then
      local green = get_attack_green(hero)
      write_canonical_attr(hero, '攻击绿字', green + number)
      return
    end
    if canonical == '生命' then
      local green = get_life_green(hero)
      write_canonical_attr(hero, '生命绿字', green + number)
      return
    end
    if canonical == '护甲' then
      local green = get_armor_green(hero)
      write_canonical_attr(hero, '护甲绿字', green + number)
      return
    end
    if canonical == '力量' then
      local green = get_strength_green(hero)
      write_canonical_attr(hero, '力量绿字', green + number)
      return
    end
    if canonical == '敏捷' then
      local green = get_agility_green(hero)
      write_canonical_attr(hero, '敏捷绿字', green + number)
      return
    end
    if canonical == '智力' then
      local green = get_intelligence_green(hero)
      write_canonical_attr(hero, '智力绿字', green + number)
      return
    end
    api.set_attr(hero, canonical, api.get_attr(hero, canonical) + number)
  end

  function api.snapshot(hero, state)
    state = state or {}
    state.hero_attr_runtime = state.hero_attr_runtime or {}
    for name in pairs(Defs.by_name) do
      state.hero_attr_runtime[name] = api.get_attr(hero, name)
    end
    return state.hero_attr_runtime
  end

  function api.log_snapshot(hero, label, extra, state)
    if not hero then
      return
    end
    HeroAttrLog.emit(label or 'snapshot', api.snapshot(hero, state), extra)
  end

  function api.rebuild_derived_attrs(hero)
    if not hero then
      return
    end

    local strength = get_strength_total(hero)
    local agility = get_agility_total(hero)
    local intelligence = get_intelligence_total(hero)

    local final_strength = strength
      * (1 + normalize_ratio(api.get_attr(hero, '力量增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终力量增幅')))
    local final_agility = agility
      * (1 + normalize_ratio(api.get_attr(hero, '敏捷增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终敏捷增幅')))
    local final_intelligence = intelligence
      * (1 + normalize_ratio(api.get_attr(hero, '智力增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终智力增幅')))

    local attack_total = get_attack_white(hero) + get_attack_green(hero)

    local attack_value = (
      attack_total
      + final_strength * MAIN_STAT_ATTACK_FACTOR
      + final_agility * MAIN_STAT_ATTACK_FACTOR
      + final_intelligence * MAIN_STAT_ATTACK_FACTOR
    ) * (1 + normalize_ratio(api.get_attr(hero, '攻击增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终攻击')))

    local life_total = get_life_white(hero) + get_life_green(hero)
    local armor_total = get_armor_white(hero) + get_armor_green(hero)

    local life_value = (
      life_total
      + final_strength * 1.0
    ) * (1 + normalize_ratio(api.get_attr(hero, '生命增幅')))
      * (1
        + normalize_ratio(api.get_attr(hero, '最终生命'))
        + final_strength * STRENGTH_FINAL_LIFE_RATIO_PER_POINT
      )

    local armor_value = (
      armor_total
    ) * (1 + normalize_ratio(api.get_attr(hero, '护甲增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终护甲')))

    api.set_attr(hero, '最终力量', final_strength)
    api.set_attr(hero, '最终敏捷', final_agility)
    api.set_attr(hero, '最终智力', final_intelligence)
    write_canonical_attr(hero, '攻击', attack_total)
    write_canonical_attr(hero, '生命', life_total)
    write_canonical_attr(hero, '护甲', armor_total)
    write_canonical_attr(hero, '力量', strength)
    write_canonical_attr(hero, '敏捷', agility)
    write_canonical_attr(hero, '智力', intelligence)
    api.set_attr(hero, '攻击结算值', attack_value)
    api.set_attr(hero, '生命结算值', life_value)
    api.set_attr(hero, '护甲结算值', armor_value)
    sync_engine_max_hp(hero, life_value)

    local derived = {
      ['最终力量'] = final_strength,
      ['最终敏捷'] = final_agility,
      ['最终智力'] = final_intelligence,
      ['攻击结算值'] = attack_value,
      ['生命结算值'] = life_value,
      ['护甲结算值'] = armor_value,
    }

    local count = (rebuild_log_counters[hero] or 0) + 1
    rebuild_log_counters[hero] = count
    if count <= 3 or count % 20 == 0 then
      HeroAttrLog.emit('rebuild_derived_attrs', api.snapshot(hero, {}), string.format('count=%d', count))
    end

    return derived
  end

  function api.init_hero_attrs(hero, seed)
    local pack = make_default_pack(seed)
    for name, value in pairs(pack) do
      local def = Defs.by_name[name]
      if not (def and def.derived_output) then
        api.set_attr(hero, name, value)
      end
    end
    api.rebuild_derived_attrs(hero)
    HeroAttrLog.emit('init_hero_attrs', api.snapshot(hero, {}))
    return pack
  end

  function api.tick_per_second_growth(hero, dt, state)
    local seconds = tonumber(dt) or 0
    if seconds <= 0 or not hero then
      return
    end

    api.add_attr(hero, '攻击', api.get_attr(hero, '每秒攻击') * seconds)
    api.add_attr(hero, '力量', api.get_attr(hero, '每秒力量') * seconds)
    api.add_attr(hero, '敏捷', api.get_attr(hero, '每秒敏捷') * seconds)
    api.add_attr(hero, '智力', api.get_attr(hero, '每秒智力') * seconds)
    api.add_attr(hero, '生命', api.get_attr(hero, '每秒生命') * seconds)

    if state and state.resources then
      state.resources.gold = (state.resources.gold or 0) + api.get_attr(hero, '每秒金币') * seconds
      state.resources.wood = (state.resources.wood or 0) + api.get_attr(hero, '每秒木材') * seconds
    end

    api.rebuild_derived_attrs(hero)
  end

  function api.apply_kill_growth(hero, state)
    if not hero then
      return
    end

    api.add_attr(hero, '攻击', api.get_attr(hero, '杀敌攻击'))
    api.add_attr(hero, '力量', api.get_attr(hero, '杀敌力量'))
    api.add_attr(hero, '敏捷', api.get_attr(hero, '杀敌敏捷'))
    api.add_attr(hero, '智力', api.get_attr(hero, '杀敌智力'))
    api.add_attr(hero, '生命', api.get_attr(hero, '杀敌生命'))
    api.add_attr(hero, '护甲', api.get_attr(hero, '杀敌护甲'))

    if state and state.resources then
      state.resources.kill_bonus_ratio = (state.resources.kill_bonus_ratio or 0) + api.get_attr(hero, '杀敌加成')
    end

    api.rebuild_derived_attrs(hero)
  end

  function api.get_damage_multiplier(hero, damage_kind, source_kind, element)
    local multiplier = 1
    local final_agility = math.max(0, api.get_attr(hero, '最终敏捷'))
    local final_intelligence = math.max(0, api.get_attr(hero, '最终智力'))

    if damage_kind == '物理' or damage_kind == 'weapon' then
      multiplier = multiplier * (1
        + normalize_ratio(api.get_attr(hero, '物理伤害'))
        + final_agility * AGILITY_PHYSICAL_DAMAGE_RATIO_PER_POINT
      )
    elseif damage_kind == '魔法' or damage_kind == '法术' or damage_kind == 'spell' or damage_kind == 'dot' or damage_kind == 'summon' then
      multiplier = multiplier * (1
        + normalize_ratio(api.get_attr(hero, '魔法伤害'))
        + final_intelligence * INTELLIGENCE_MAGIC_DAMAGE_RATIO_PER_POINT
      )
    end

    if element == 'metal' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '金行伤害')))
    elseif element == 'wood' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '木行伤害')))
    elseif element == 'water' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '水行伤害')))
    elseif element == 'fire' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '火行伤害')))
    elseif element == 'earth' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '土行伤害')))
    end

    if source_kind == 'normal_attack' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '普攻伤害')))
    elseif source_kind == 'skill' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '技能伤害')))
    end

    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '所有伤害')))
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '最终伤害')))

    return multiplier
  end

  return api
end

return M

local Defs = require 'runtime.hero_attr_defs'

local M = {}

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
  return result
end

function M.create()
  local api = {}

  function api.normalize_name(name)
    return Defs.aliases[name] or name
  end

  function api.get_attr(hero, name)
    if not hero or not name then
      return 0
    end
    local canonical = api.normalize_name(name)
    return tonumber(hero:get_attr(canonical)) or 0
  end

  function api.set_attr(hero, name, value)
    if not hero or not name then
      return
    end
    hero:set_attr(api.normalize_name(name), value or 0)
  end

  function api.add_attr(hero, name, value)
    if not hero or not name or value == nil or value == 0 then
      return
    end
    hero:add_attr(api.normalize_name(name), value)
  end

  function api.rebuild_derived_attrs(hero)
    if not hero then
      return
    end

    local strength = api.get_attr(hero, '力量')
    local agility = api.get_attr(hero, '敏捷')
    local intelligence = api.get_attr(hero, '智力')

    local final_strength = strength
      * (1 + normalize_ratio(api.get_attr(hero, '力量增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终力量增幅')))
    local final_agility = agility
      * (1 + normalize_ratio(api.get_attr(hero, '敏捷增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终敏捷增幅')))
    local final_intelligence = intelligence
      * (1 + normalize_ratio(api.get_attr(hero, '智力增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终智力增幅')))

    local attack_value = (
      api.get_attr(hero, '攻击')
      + final_strength * 0.1
      + final_agility * 0.1
      + final_intelligence * 0.1
    ) * (1 + normalize_ratio(api.get_attr(hero, '攻击增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终攻击')))

    local life_value = (
      api.get_attr(hero, '生命')
      + final_strength * 1.0
    ) * (1 + normalize_ratio(api.get_attr(hero, '生命增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终生命')))

    local armor_value = (
      api.get_attr(hero, '护甲')
    ) * (1 + normalize_ratio(api.get_attr(hero, '护甲增幅')))
      * (1 + normalize_ratio(api.get_attr(hero, '最终护甲')))

    api.set_attr(hero, '最终力量', final_strength)
    api.set_attr(hero, '最终敏捷', final_agility)
    api.set_attr(hero, '最终智力', final_intelligence)
    api.set_attr(hero, '攻击结算值', attack_value)
    api.set_attr(hero, '生命结算值', life_value)
    api.set_attr(hero, '护甲结算值', armor_value)

    return {
      ['最终力量'] = final_strength,
      ['最终敏捷'] = final_agility,
      ['最终智力'] = final_intelligence,
      ['攻击结算值'] = attack_value,
      ['生命结算值'] = life_value,
      ['护甲结算值'] = armor_value,
    }
  end

  function api.init_hero_attrs(hero, seed)
    local pack = make_default_pack(seed)
    for name, value in pairs(pack) do
      hero:set_attr(name, value)
    end
    api.rebuild_derived_attrs(hero)
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

  function api.get_damage_multiplier(hero, damage_kind, source_kind)
    local multiplier = 1

    if damage_kind == '物理' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '物理伤害')))
    elseif damage_kind == '魔法' or damage_kind == '法术' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(hero, '魔法伤害')))
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

  function api.snapshot(hero, state)
    state.hero_attr_runtime = state.hero_attr_runtime or {}
    for name in pairs(Defs.by_name) do
      state.hero_attr_runtime[name] = api.get_attr(hero, name)
    end
    return state.hero_attr_runtime
  end

  return api
end

return M

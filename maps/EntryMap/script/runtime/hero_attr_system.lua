local AttrDefs = require 'runtime.hero_attr_defs'
local AttrLog = require 'runtime.hero_attr_log'

local M = {}

local KV_PREFIX = '__hero_attr__:'
local MAIN_STAT_ATTACK_RATIO = 5
local STRENGTH_HP_RATIO = 0.001
local AGILITY_PHYSICAL_DAMAGE_RATIO = 0.001
local INTELLIGENCE_MAGIC_DAMAGE_RATIO = 0.001

local function normalize_ratio(value)
  local number = tonumber(value) or 0
  if math.abs(number) > 1 then
    return number / 100
  end
  return number
end

local function build_initial_values(values)
  local result = {}
  for name, value in pairs(AttrDefs.default_values) do
    result[name] = value
  end
  for name, value in pairs(values or {}) do
    local normalized_name = AttrDefs.aliases[name] or name
    result[normalized_name] = value
  end

  if values and values['攻击'] ~= nil and values['攻击白字'] == nil and values['攻击绿字'] == nil then
    result['攻击白字'] = values['攻击']
    result['攻击'] = 0
  end
  if values and values['生命'] ~= nil and values['生命白字'] == nil and values['生命绿字'] == nil then
    result['生命白字'] = values['生命']
    result['生命'] = 0
  end
  if values and values['护甲'] ~= nil and values['护甲白字'] == nil and values['护甲绿字'] == nil then
    result['护甲白字'] = values['护甲']
    result['护甲'] = 0
  end
  if values and values['力量'] ~= nil and values['力量白字'] == nil and values['力量绿字'] == nil then
    result['力量白字'] = values['力量']
    result['力量'] = 0
  end
  if values and values['敏捷'] ~= nil and values['敏捷白字'] == nil and values['敏捷绿字'] == nil then
    result['敏捷白字'] = values['敏捷']
    result['敏捷'] = 0
  end
  if values and values['智力'] ~= nil and values['智力白字'] == nil and values['智力绿字'] == nil then
    result['智力白字'] = values['智力']
    result['智力'] = 0
  end

  return result
end

function M.create()
  local api = {}
  local rebuild_counts = setmetatable({}, { __mode = 'k' })
  local write_attr

  local function kv_key(name)
    return KV_PREFIX .. tostring(name)
  end

  local function can_use_kv(unit)
    return unit and unit.kv_save and unit.kv_load
  end

  local function load_number(unit, key)
    local ok, value = pcall(function()
      return unit:kv_load(key, 'number')
    end)
    if ok then
      return tonumber(value) or 0
    end

    ok, value = pcall(function()
      return unit:kv_load(key, 'integer')
    end)
    if ok then
      return tonumber(value) or 0
    end

    return nil
  end

  local function is_engine_unit_attr(name)
    return y3 and y3.const and y3.const.UnitAttr and y3.const.UnitAttr[name] ~= nil
  end

  local function read_attr(unit, name)
    if can_use_kv(unit) and unit:kv_has(kv_key(name)) then
      local value = load_number(unit, kv_key(name))
      if value ~= nil then
        return value
      end
    end
    return tonumber(unit:get_attr(name)) or 0
  end

  local function save_attr(unit, name, value)
    if can_use_kv(unit) then
      unit:kv_save(kv_key(name), value + 0.0)
    end
    write_attr(unit, name, value)
  end

  local function attack_base(unit)
    return read_attr(unit, '攻击白字')
  end

  local function attack_bonus(unit)
    return read_attr(unit, '攻击绿字')
  end

  local function attack_total(unit)
    local base = attack_base(unit)
    local bonus = attack_bonus(unit)
    if base ~= 0 or bonus ~= 0 then
      return base + bonus
    end
    return read_attr(unit, '攻击')
  end

  local function hp_base(unit)
    return read_attr(unit, '生命白字')
  end

  local function hp_bonus(unit)
    return read_attr(unit, '生命绿字')
  end

  local function hp_total(unit)
    local base = hp_base(unit)
    local bonus = hp_bonus(unit)
    if base ~= 0 or bonus ~= 0 then
      return base + bonus
    end
    return read_attr(unit, '生命')
  end

  local function armor_base(unit)
    return read_attr(unit, '护甲白字')
  end

  local function armor_bonus(unit)
    return read_attr(unit, '护甲绿字')
  end

  local function armor_total(unit)
    local base = armor_base(unit)
    local bonus = armor_bonus(unit)
    if base ~= 0 or bonus ~= 0 then
      return base + bonus
    end
    return read_attr(unit, '护甲')
  end

  local function strength_base(unit)
    return read_attr(unit, '力量白字')
  end

  local function strength_bonus(unit)
    return read_attr(unit, '力量绿字')
  end

  local function strength_total(unit)
    local base = strength_base(unit)
    local bonus = strength_bonus(unit)
    if base ~= 0 or bonus ~= 0 then
      return base + bonus
    end
    return read_attr(unit, '力量')
  end

  local function agility_base(unit)
    return read_attr(unit, '敏捷白字')
  end

  local function agility_bonus(unit)
    return read_attr(unit, '敏捷绿字')
  end

  local function agility_total(unit)
    local base = agility_base(unit)
    local bonus = agility_bonus(unit)
    if base ~= 0 or bonus ~= 0 then
      return base + bonus
    end
    return read_attr(unit, '敏捷')
  end

  local function intelligence_base(unit)
    return read_attr(unit, '智力白字')
  end

  local function intelligence_bonus(unit)
    return read_attr(unit, '智力绿字')
  end

  local function intelligence_total(unit)
    local base = intelligence_base(unit)
    local bonus = intelligence_bonus(unit)
    if base ~= 0 or bonus ~= 0 then
      return base + bonus
    end
    return read_attr(unit, '智力')
  end

  write_attr = function(unit, name, value)
    if not unit or not unit.set_attr then
      return
    end
    if not y3 or not y3.const or not y3.const.UnitAttr then
      unit:set_attr(name, value or 0)
      return
    end
    if not is_engine_unit_attr(name) then
      return
    end
    unit:set_attr(name, value or 0)
  end

  local function sync_engine_max_hp(unit, value)
    if not unit or not unit.set_attr then
      return
    end
    if not y3 or not y3.const or not y3.const.UnitAttr then
      return
    end
    if not is_engine_unit_attr('最大生命') then
      return
    end
    unit:set_attr('最大生命', value or 1)
  end

  function api.normalize_name(name)
    return AttrDefs.aliases[name] or name
  end

  function api.get_attr(unit, name)
    if not unit or not name then
      return 0
    end

    local normalized_name = api.normalize_name(name)
    if normalized_name == '攻击' then
      return attack_total(unit)
    end
    if normalized_name == '生命' then
      return hp_total(unit)
    end
    if normalized_name == '护甲' then
      return armor_total(unit)
    end
    if normalized_name == '力量' then
      return strength_total(unit)
    end
    if normalized_name == '敏捷' then
      return agility_total(unit)
    end
    if normalized_name == '智力' then
      return intelligence_total(unit)
    end

    return read_attr(unit, normalized_name)
  end

  function api.set_attr(unit, name, value)
    if not unit or not name then
      return
    end

    local normalized_name = api.normalize_name(name)
    local number = tonumber(value) or 0
    if normalized_name == '攻击' then
      local base = attack_base(unit)
      save_attr(unit, '攻击绿字', number - base)
      save_attr(unit, '攻击', number)
      return
    end
    if normalized_name == '生命' then
      local base = hp_base(unit)
      save_attr(unit, '生命绿字', number - base)
      save_attr(unit, '生命', number)
      return
    end
    if normalized_name == '护甲' then
      local base = armor_base(unit)
      save_attr(unit, '护甲绿字', number - base)
      save_attr(unit, '护甲', number)
      return
    end
    if normalized_name == '力量' then
      local base = strength_base(unit)
      save_attr(unit, '力量绿字', number - base)
      save_attr(unit, '力量', number)
      return
    end
    if normalized_name == '敏捷' then
      local base = agility_base(unit)
      save_attr(unit, '敏捷绿字', number - base)
      save_attr(unit, '敏捷', number)
      return
    end
    if normalized_name == '智力' then
      local base = intelligence_base(unit)
      save_attr(unit, '智力绿字', number - base)
      save_attr(unit, '智力', number)
      return
    end

    save_attr(unit, normalized_name, number)
  end

  function api.add_attr(unit, name, value)
    if not unit or not name or value == nil or value == 0 then
      return
    end

    local normalized_name = api.normalize_name(name)
    local number = tonumber(value) or 0
    if normalized_name == '攻击' then
      save_attr(unit, '攻击绿字', attack_bonus(unit) + number)
      return
    end
    if normalized_name == '生命' then
      save_attr(unit, '生命绿字', hp_bonus(unit) + number)
      return
    end
    if normalized_name == '护甲' then
      save_attr(unit, '护甲绿字', armor_bonus(unit) + number)
      return
    end
    if normalized_name == '力量' then
      save_attr(unit, '力量绿字', strength_bonus(unit) + number)
      return
    end
    if normalized_name == '敏捷' then
      save_attr(unit, '敏捷绿字', agility_bonus(unit) + number)
      return
    end
    if normalized_name == '智力' then
      save_attr(unit, '智力绿字', intelligence_bonus(unit) + number)
      return
    end

    api.set_attr(unit, normalized_name, api.get_attr(unit, normalized_name) + number)
  end

  function api.snapshot(unit, state)
    state = state or {}
    state.hero_attr_runtime = state.hero_attr_runtime or {}
    for name in pairs(AttrDefs.by_name) do
      state.hero_attr_runtime[name] = api.get_attr(unit, name)
    end
    return state.hero_attr_runtime
  end

  function api.log_snapshot(unit, event_name, detail, state)
    if not unit then
      return
    end
    AttrLog.emit(event_name or 'snapshot', api.snapshot(unit, state), detail)
  end

  function api.rebuild_derived_attrs(unit)
    if not unit then
      return
    end

    local strength = strength_total(unit)
    local agility = agility_total(unit)
    local intelligence = intelligence_total(unit)
    local final_strength = strength
      * (1 + normalize_ratio(api.get_attr(unit, '力量增幅')))
      * (1 + normalize_ratio(api.get_attr(unit, '最终力量增幅')))
    local final_agility = agility
      * (1 + normalize_ratio(api.get_attr(unit, '敏捷增幅')))
      * (1 + normalize_ratio(api.get_attr(unit, '最终敏捷增幅')))
    local final_intelligence = intelligence
      * (1 + normalize_ratio(api.get_attr(unit, '智力增幅')))
      * (1 + normalize_ratio(api.get_attr(unit, '最终智力增幅')))
    local attack = attack_base(unit) + attack_bonus(unit)
    local final_attack = (attack
      + final_strength * MAIN_STAT_ATTACK_RATIO
      + final_agility * MAIN_STAT_ATTACK_RATIO
      + final_intelligence * MAIN_STAT_ATTACK_RATIO)
      * (1 + normalize_ratio(api.get_attr(unit, '攻击增幅')))
      * (1 + normalize_ratio(api.get_attr(unit, '最终攻击')))
    local hp = hp_base(unit) + hp_bonus(unit)
    local armor = armor_base(unit) + armor_bonus(unit)
    local final_hp = (hp + final_strength * 1.0)
      * (1 + normalize_ratio(api.get_attr(unit, '生命增幅')))
      * (1 + normalize_ratio(api.get_attr(unit, '最终生命')) + final_strength * STRENGTH_HP_RATIO)
    local final_armor = armor
      * (1 + normalize_ratio(api.get_attr(unit, '护甲增幅')))
      * (1 + normalize_ratio(api.get_attr(unit, '最终护甲')))

    api.set_attr(unit, '最终力量', final_strength)
    api.set_attr(unit, '最终敏捷', final_agility)
    api.set_attr(unit, '最终智力', final_intelligence)
    save_attr(unit, '攻击', attack)
    save_attr(unit, '生命', hp)
    save_attr(unit, '护甲', armor)
    save_attr(unit, '力量', strength)
    save_attr(unit, '敏捷', agility)
    save_attr(unit, '智力', intelligence)
    api.set_attr(unit, '攻击结算值', final_attack)
    write_attr(unit, '物理攻击', final_attack)
    api.set_attr(unit, '生命结算值', final_hp)
    api.set_attr(unit, '护甲结算值', final_armor)
    sync_engine_max_hp(unit, final_hp)

    local derived = {
      ['最终力量'] = final_strength,
      ['最终敏捷'] = final_agility,
      ['最终智力'] = final_intelligence,
      ['攻击结算值'] = final_attack,
      ['生命结算值'] = final_hp,
      ['护甲结算值'] = final_armor,
    }
    local count = (rebuild_counts[unit] or 0) + 1
    rebuild_counts[unit] = count
    if count <= 3 or count % 20 == 0 then
      AttrLog.emit('rebuild_derived_attrs', api.snapshot(unit, {}), string.format('count=%d', count))
    end
    return derived
  end

  function api.init_hero_attrs(unit, values)
    local initial_values = build_initial_values(values)
    for name, value in pairs(initial_values) do
      local def = AttrDefs.by_name[name]
      if not (def and def.derived_output) then
        api.set_attr(unit, name, value)
      end
    end
    api.rebuild_derived_attrs(unit)
    AttrLog.emit('init_hero_attrs', api.snapshot(unit, {}))
    return initial_values
  end

  function api.tick_per_second_growth(unit, dt, state)
    local seconds = tonumber(dt) or 0
    if seconds <= 0 or not unit then
      return
    end
    api.add_attr(unit, '攻击', api.get_attr(unit, '每秒攻击') * seconds)
    api.add_attr(unit, '力量', api.get_attr(unit, '每秒力量') * seconds)
    api.add_attr(unit, '敏捷', api.get_attr(unit, '每秒敏捷') * seconds)
    api.add_attr(unit, '智力', api.get_attr(unit, '每秒智力') * seconds)
    api.add_attr(unit, '生命', api.get_attr(unit, '每秒生命') * seconds)
    if state and state.resources then
      state.resources.gold = (state.resources.gold or 0) + api.get_attr(unit, '每秒金币') * seconds
      state.resources.wood = (state.resources.wood or 0) + api.get_attr(unit, '每秒木材') * seconds
    end
    api.rebuild_derived_attrs(unit)
  end

  function api.apply_kill_growth(unit, state)
    if not unit then
      return
    end
    api.add_attr(unit, '攻击', api.get_attr(unit, '杀敌攻击'))
    api.add_attr(unit, '力量', api.get_attr(unit, '杀敌力量'))
    api.add_attr(unit, '敏捷', api.get_attr(unit, '杀敌敏捷'))
    api.add_attr(unit, '智力', api.get_attr(unit, '杀敌智力'))
    api.add_attr(unit, '生命', api.get_attr(unit, '杀敌生命'))
    api.add_attr(unit, '护甲', api.get_attr(unit, '杀敌护甲'))
    if state and state.resources then
      state.resources.kill_bonus_ratio = (state.resources.kill_bonus_ratio or 0) + api.get_attr(unit, '杀敌加成')
    end
    api.rebuild_derived_attrs(unit)
  end

  function api.get_damage_multiplier(unit, damage_type, damage_form, element)
    local multiplier = 1
    local final_agility = math.max(0, api.get_attr(unit, '最终敏捷'))
    local final_intelligence = math.max(0, api.get_attr(unit, '最终智力'))
    if damage_type == '物理' or damage_type == 'weapon' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '物理伤害')) + final_agility * AGILITY_PHYSICAL_DAMAGE_RATIO)
    elseif damage_type == '魔法' or damage_type == '法术' or damage_type == 'spell' or damage_type == 'dot' or damage_type == 'summon' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '魔法伤害')) + final_intelligence * INTELLIGENCE_MAGIC_DAMAGE_RATIO)
    end

    if element == 'metal' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '金行伤害')))
    elseif element == 'wood' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '木行伤害')))
    elseif element == 'water' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '水行伤害')))
    elseif element == 'fire' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '火行伤害')))
    elseif element == 'earth' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '土行伤害')))
    end

    if damage_form == 'normal_attack' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '普攻伤害')))
    elseif damage_form == 'skill' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '技能伤害')))
    end

    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '所有伤害')))
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '最终伤害')))
    return multiplier
  end

  return api
end

return M

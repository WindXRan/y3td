local M = {}

local KV_PREFIX = '__hero_attr__:'
local MAIN_STAT_ATTACK_RATIO = 0.5
local STRENGTH_HP_RATIO = 0.001
local ENGINE_ATTACK_ATTRS = { '攻击力', '物理攻击力', '物理攻击', '法术攻击力', '法术攻击' }

local AttrDefCsv = require 'data.tables.common.attr_defs'

local AttrDefs = {
  categories = AttrDefCsv.CATEGORIES,
  aliases = {
    ['攻击力'] = '攻击',
    ['物理攻击'] = '攻击',
    ['物理攻击力'] = '攻击',
    ['法术攻击'] = '攻击',
    ['法术攻击力'] = '攻击',
  },
  list = AttrDefCsv.list,
  by_name = AttrDefCsv.by_name,
}

local _registered_attrs = {}
local _attr_registration_order = {}

local function _register_attr_internal(name, category, order, format, extra)
  if _registered_attrs[name] then
    return false
  end
  extra = extra or {}
  extra.name = name
  extra.category = category or AttrDefs.categories.OTHER
  extra.order = order or 999
  extra.format = format or 'integer'
  if extra.persist == nil then
    extra.persist = true
  end
  _registered_attrs[name] = extra
  _attr_registration_order[#_attr_registration_order + 1] = name
  return true
end

function M.register_attr(name, category, order, format, extra)
  local ok = _register_attr_internal(name, category, order, format, extra)
  if ok then
    AttrDefs.aliases[name] = nil
  end
  return ok
end

function M.is_attr_defined(name)
  local normalized = AttrDefs.aliases[name] or name
  return _registered_attrs[normalized] ~= nil
end

function M.get_attr_def(name)
  local normalized = AttrDefs.aliases[name] or name
  return _registered_attrs[normalized]
end

function M.get_all_attr_names()
  local result = {}
  for _, name in ipairs(_attr_registration_order) do
    result[#result + 1] = name
  end
  return result
end

function M.validate_attr_name(name)
  if name == nil or name == '' then
    return false, '属性名不能为空'
  end
  local normalized = AttrDefs.aliases[name] or name
  if _registered_attrs[normalized] then
    return true, normalized
  end
  return false, '属性 [' .. tostring(name) .. '] 未在 hero_attr_system 中注册，请先调用 M.register_attr() 注册'
end

AttrDefs.default_values = {}
for _, def in ipairs(AttrDefs.list) do
  AttrDefs.default_values[def.name] = def.default or 0
  _register_attr_internal(def.name, def.category, def.order, def.format, def)
end

local function normalize_ratio(value)
  local number = tonumber(value) or 0
  if math.abs(number) > 1 then
    return number / 100
  end
  return number
end

local ATTRS_TO_SPLIT = {'攻击', '生命', '护甲', '力量', '敏捷', '智力'}

local function split_attr_to_base_bonus(result, values, attr_name)
  if values and values[attr_name] ~= nil and values[attr_name .. '白字'] == nil and values[attr_name .. '绿字'] == nil then
    result[attr_name .. '白字'] = values[attr_name]
    result[attr_name] = 0
  end
  if result[attr_name] ~= 0 and result[attr_name .. '白字'] == 0 and result[attr_name .. '绿字'] == 0 then
    result[attr_name .. '白字'] = result[attr_name]
    result[attr_name] = 0
  end
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

  for _, attr_name in ipairs(ATTRS_TO_SPLIT) do
    split_attr_to_base_bonus(result, values, attr_name)
  end

  return result
end

do
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

  local function can_try_engine_attr(name)
    if is_engine_unit_attr(name) then
      return true
    end
    return name == '攻击力' or name == '物理攻击力' or name == '法术攻击力'
  end

  local function read_attr(unit, name)
    if can_use_kv(unit) then
      local value = load_number(unit, kv_key(name))
      if value ~= nil then
        return value
      end
    end
    return tonumber(unit:get_attr(name)) or 0
  end

  local function read_engine_attr(unit, name)
    if not unit or not unit.get_attr or not can_try_engine_attr(name) then
      return 0
    end
    local ok, value = pcall(unit.get_attr, unit, name)
    if ok then
      return tonumber(value) or 0
    end
    return 0
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
    local attack = read_attr(unit, '攻击')
    if attack ~= 0 then
      return attack
    end
    for _, attr_name in ipairs(ENGINE_ATTACK_ATTRS) do
      local value = read_engine_attr(unit, attr_name)
      if value ~= 0 then
        return value
      end
    end
    return 0
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
    if not can_try_engine_attr(name) then
      return
    end
    pcall(unit.set_attr, unit, name, value or 0)
  end

  local function sync_engine_attack(unit, value)
    for _, attr_name in ipairs(ENGINE_ATTACK_ATTRS) do
      write_attr(unit, attr_name, value or 0)
    end
  end

  local function sync_engine_max_hp(unit, value)
    if not unit or not unit.set_attr then
      return
    end
    if not y3 or not y3.const or not y3.const.UnitAttr then
      return
    end
    if not is_engine_unit_attr('hp_max') then
      return
    end
    unit:set_attr('hp_max', value or 1)
  end

  function api.normalize_name(name)
    return AttrDefs.aliases[name] or name
  end

  function api.get_attr(unit, name)
    if not unit or not name then
      return 0
    end

    local normalized_name = api.normalize_name(name)
    if normalized_name ~= '攻击' and normalized_name ~= '生命' and normalized_name ~= '护甲' and normalized_name ~= '力量' and normalized_name ~= '敏捷' and normalized_name ~= '智力' then
      if not _registered_attrs[normalized_name] then
        return 0
      end
    end
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

  function api.get_attack_power(unit)
    if not unit then
      return 0
    end
    local final_attack = api.get_attr(unit, '攻击结算值')
    if final_attack > 0 then
      return final_attack
    end
    local attack = api.get_attr(unit, '攻击')
    if attack > 0 then
      return attack
    end
    for _, attr_name in ipairs(ENGINE_ATTACK_ATTRS) do
      local value = read_engine_attr(unit, attr_name)
      if value > 0 then
        return value
      end
    end
    return 0
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
    local main_stat_attack_ratio = tonumber(MAIN_STAT_ATTACK_RATIO) or 0.5
    local final_attack = (attack
          + final_strength * main_stat_attack_ratio
          + final_agility * main_stat_attack_ratio
          + final_intelligence * main_stat_attack_ratio)
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
    sync_engine_attack(unit, final_attack)
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
    return initial_values
  end

  function api.get_damage_multiplier(unit, damage_form, damage_kind, element)
    if not unit then
      return 1
    end
    local multiplier = 1
    if damage_kind == 'normal_attack' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '普攻伤害增幅')))
    elseif damage_kind == 'skill' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '技能伤害增幅')))
    end
    multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '最终伤害增幅')))
    return multiplier
  end

  function api.compute_damage(unit, base_damage, damage_meta, context)
    if not unit then
      return base_damage or 0
    end
    local target_multiplier = context and context.target_multiplier or 1
    local hero_multiplier = api.get_damage_multiplier(
      unit,
      damage_meta and damage_meta.damage_form,
      context and context.damage_kind,
      damage_meta and damage_meta.element
    )
    return (base_damage or 0) * hero_multiplier * target_multiplier
  end

  function api.log_snapshot(unit, event_name, extra_info, state)
    if not unit then
      return
    end
    local snapshot = api.snapshot(unit, state or {})
    print(string.format('[hero_attr_system] snapshot [%s]%s', 
      tostring(event_name), 
      extra_info and (' ' .. tostring(extra_info)) or ''
    ))
  end

  function api.tick_per_second_growth(unit, delta_time, state)
    if not unit or not state then
      return
    end
    local attack_per_second = api.get_attr(unit, '每秒攻击')
    if attack_per_second ~= 0 then
      api.add_attr(unit, '攻击', attack_per_second * delta_time)
    end
    local gold_per_second = api.get_attr(unit, '每秒金币')
    if gold_per_second ~= 0 then
      state.resources = state.resources or { gold = 0, wood = 0 }
      state.resources.gold = (state.resources.gold or 0) + gold_per_second * delta_time
    end
  end

  function api.apply_kill_growth(unit, state)
    if not unit then
      return
    end
    local kill_attack = api.get_attr(unit, '杀敌攻击')
    if kill_attack ~= 0 then
      api.add_attr(unit, '攻击', kill_attack)
    end
    local kill_hp = api.get_attr(unit, '杀敌生命')
    if kill_hp ~= 0 then
      api.add_attr(unit, '生命', kill_hp)
    end
  end

  _G.hero_attr_system = api
end

function M.get_defs()
  return AttrDefs
end

function M.get_registered_attr_count()
  return #_attr_registration_order
end

function M.set_main_stat_attack_ratio(ratio)
  MAIN_STAT_ATTACK_RATIO = tonumber(ratio) or 0.5
end

function M.dump_unregistered_attrs()
  local unregistered = {}
  for name in pairs(_registered_attrs) do
    local found = false
    for _, def in ipairs(AttrDefs.list) do
      if def.name == name then
        found = true
        break
      end
    end
    if not found then
      unregistered[#unregistered + 1] = name
    end
  end
  return unregistered
end

return M

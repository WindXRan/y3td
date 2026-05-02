local M = {}
local AttrLog = { enabled = false }

local KV_PREFIX = '__hero_attr__:'
local MAIN_STAT_ATTACK_RATIO = 0.5
local STRENGTH_HP_RATIO = 0.001
local AGILITY_PHYSICAL_DAMAGE_RATIO = 0.001
local INTELLIGENCE_MAGIC_DAMAGE_RATIO = 0.001
local ENGINE_ATTACK_ATTRS = { '攻击力', '物理攻击力', '物理攻击', '法术攻击力', '法术攻击' }

local function define_attr(name, category, order, format, extra)
  extra = extra or {}
  extra.name = name
  extra.category = category
  extra.order = order
  extra.format = format
  if extra.persist == nil then
    extra.persist = true
  end
  return extra
end

local AttrDefs = {
  categories = {
    DAMAGE = '伤害属性',
    DEFENSE = '防守属性',
    RESOURCE = '资源属性',
    AMPLIFY = '增幅属性',
    OTHER = '其他属性',
  },
  aliases = {
    ['攻击力'] = '攻击',
    ['物理攻击'] = '攻击',
    ['物理攻击力'] = '攻击',
    ['法术攻击'] = '攻击',
    ['法术攻击力'] = '攻击',
    ['最大生命'] = '生命',
    ['暴击率'] = '物理暴击',
    ['暴击伤害'] = '物理暴伤',
    ['命中率'] = '命中',
    ['护甲穿透'] = '护甲穿透',
    ['物理吸血'] = '物理吸血',
    ['BOSS伤害'] = '挑战伤害',
    ['精英伤害'] = '精控伤害',
    ['冻伤伤害'] = '冻结伤害',
    ['最终攻击增幅'] = '最终攻击',
    ['最终生命增幅'] = '最终生命',
    ['最终护甲增幅'] = '最终护甲',
  },
}

AttrDefs.list = {
  define_attr('攻击', AttrDefs.categories.DAMAGE, 10, 'integer', { derived_output = true, persist = false }),
  define_attr('攻击白字', AttrDefs.categories.DAMAGE, 11, 'integer'),
  define_attr('攻击绿字', AttrDefs.categories.DAMAGE, 12, 'integer'),
  define_attr('攻击范围', AttrDefs.categories.DAMAGE, 20, 'integer'),
  define_attr('攻击速度', AttrDefs.categories.DAMAGE, 25, 'integer'),
  define_attr('攻击间隔', AttrDefs.categories.DAMAGE, 30, 'fixed2'),
  define_attr('命中', AttrDefs.categories.DAMAGE, 40, 'percent', { is_ratio = true }),
  define_attr('物理暴击', AttrDefs.categories.DAMAGE, 50, 'percent', { is_ratio = true }),
  define_attr('物理暴伤', AttrDefs.categories.DAMAGE, 60, 'percent', { is_ratio = true }),
  define_attr('魔法暴击', AttrDefs.categories.DAMAGE, 70, 'percent', { is_ratio = true }),
  define_attr('魔法暴伤', AttrDefs.categories.DAMAGE, 80, 'percent', { is_ratio = true }),
  define_attr('物理伤害', AttrDefs.categories.DAMAGE, 90, 'percent', { is_ratio = true }),
  define_attr('魔法伤害', AttrDefs.categories.DAMAGE, 100, 'percent', { is_ratio = true }),
  define_attr('物理吸血', AttrDefs.categories.DAMAGE, 110, 'percent', { is_ratio = true }),
  define_attr('普攻伤害', AttrDefs.categories.DAMAGE, 120, 'percent', { is_ratio = true }),
  define_attr('技能伤害', AttrDefs.categories.DAMAGE, 130, 'percent_or_zero', { is_ratio = true }),
  define_attr('所有伤害', AttrDefs.categories.DAMAGE, 140, 'percent', { is_ratio = true }),
  define_attr('最终伤害', AttrDefs.categories.DAMAGE, 150, 'percent', { is_ratio = true }),
  define_attr('无视护甲', AttrDefs.categories.DAMAGE, 160, 'percent', { is_ratio = true }),
  define_attr('护甲穿透', AttrDefs.categories.DAMAGE, 170, 'integer'),
  define_attr('多重数量', AttrDefs.categories.DAMAGE, 180, 'integer'),
  define_attr('多重伤害', AttrDefs.categories.DAMAGE, 190, 'percent', { is_ratio = true }),
  define_attr('弹射次数', AttrDefs.categories.DAMAGE, 200, 'integer'),
  define_attr('弹射伤害', AttrDefs.categories.DAMAGE, 210, 'percent', { is_ratio = true }),
  define_attr('生命', AttrDefs.categories.DEFENSE, 10, 'integer', { derived_output = true, persist = false }),
  define_attr('生命白字', AttrDefs.categories.DEFENSE, 11, 'integer'),
  define_attr('生命绿字', AttrDefs.categories.DEFENSE, 12, 'integer'),
  define_attr('护甲', AttrDefs.categories.DEFENSE, 20, 'integer', { derived_output = true, persist = false }),
  define_attr('护甲白字', AttrDefs.categories.DEFENSE, 21, 'integer'),
  define_attr('护甲绿字', AttrDefs.categories.DEFENSE, 22, 'integer'),
  define_attr('格挡', AttrDefs.categories.DEFENSE, 30, 'integer'),
  define_attr('闪避', AttrDefs.categories.DEFENSE, 40, 'percent', { is_ratio = true }),
  define_attr('生命恢复', AttrDefs.categories.DEFENSE, 50, 'fixed1'),
  define_attr('伤害减免', AttrDefs.categories.DEFENSE, 60, 'percent', { is_ratio = true }),
  define_attr('闪避恢复', AttrDefs.categories.DEFENSE, 70, 'fixed1'),
  define_attr('杀敌恢复', AttrDefs.categories.DEFENSE, 80, 'fixed1'),
  define_attr('控制时长', AttrDefs.categories.DEFENSE, 90, 'percent', { is_ratio = true }),
  define_attr('杀敌经验', AttrDefs.categories.RESOURCE, 10, 'percent', { is_ratio = true }),
  define_attr('杀敌加成', AttrDefs.categories.RESOURCE, 20, 'percent', { is_ratio = true }),
  define_attr('杀敌木材', AttrDefs.categories.RESOURCE, 30, 'percent', { is_ratio = true }),
  define_attr('杀敌金币', AttrDefs.categories.RESOURCE, 40, 'percent', { is_ratio = true }),
  define_attr('每秒经验', AttrDefs.categories.RESOURCE, 50, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('每秒木材', AttrDefs.categories.RESOURCE, 60, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('每秒金币', AttrDefs.categories.RESOURCE, 70, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('每秒杀敌', AttrDefs.categories.RESOURCE, 80, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('力量', AttrDefs.categories.AMPLIFY, 10, 'integer', { derived_output = true, persist = false }),
  define_attr('力量白字', AttrDefs.categories.AMPLIFY, 11, 'integer'),
  define_attr('力量绿字', AttrDefs.categories.AMPLIFY, 12, 'integer'),
  define_attr('敏捷', AttrDefs.categories.AMPLIFY, 20, 'integer', { derived_output = true, persist = false }),
  define_attr('敏捷白字', AttrDefs.categories.AMPLIFY, 21, 'integer'),
  define_attr('敏捷绿字', AttrDefs.categories.AMPLIFY, 22, 'integer'),
  define_attr('智力', AttrDefs.categories.AMPLIFY, 30, 'integer', { derived_output = true, persist = false }),
  define_attr('智力白字', AttrDefs.categories.AMPLIFY, 31, 'integer'),
  define_attr('智力绿字', AttrDefs.categories.AMPLIFY, 32, 'integer'),
  define_attr('力量增幅', AttrDefs.categories.AMPLIFY, 40, 'percent', { is_ratio = true }),
  define_attr('敏捷增幅', AttrDefs.categories.AMPLIFY, 50, 'percent', { is_ratio = true }),
  define_attr('智力增幅', AttrDefs.categories.AMPLIFY, 60, 'percent', { is_ratio = true }),
  define_attr('攻击增幅', AttrDefs.categories.AMPLIFY, 70, 'percent', { is_ratio = true }),
  define_attr('生命增幅', AttrDefs.categories.AMPLIFY, 80, 'percent', { is_ratio = true }),
  define_attr('护甲增幅', AttrDefs.categories.AMPLIFY, 90, 'percent', { is_ratio = true }),
  define_attr('每秒攻击', AttrDefs.categories.AMPLIFY, 100, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('每秒力量', AttrDefs.categories.AMPLIFY, 110, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('每秒敏捷', AttrDefs.categories.AMPLIFY, 120, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('每秒智力', AttrDefs.categories.AMPLIFY, 130, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('每秒生命', AttrDefs.categories.AMPLIFY, 140, 'fixed1', { growth_kind = 'per_second' }),
  define_attr('杀敌攻击', AttrDefs.categories.AMPLIFY, 150, 'fixed2', { growth_kind = 'on_kill' }),
  define_attr('杀敌力量', AttrDefs.categories.AMPLIFY, 160, 'fixed2', { growth_kind = 'on_kill' }),
  define_attr('杀敌敏捷', AttrDefs.categories.AMPLIFY, 170, 'fixed2', { growth_kind = 'on_kill' }),
  define_attr('杀敌智力', AttrDefs.categories.AMPLIFY, 180, 'fixed2', { growth_kind = 'on_kill' }),
  define_attr('杀敌生命', AttrDefs.categories.AMPLIFY, 190, 'fixed2', { growth_kind = 'on_kill' }),
  define_attr('杀敌护甲', AttrDefs.categories.AMPLIFY, 200, 'fixed2', { growth_kind = 'on_kill' }),
  define_attr('最终力量', AttrDefs.categories.AMPLIFY, 210, 'fixed1', { derived_output = true }),
  define_attr('最终敏捷', AttrDefs.categories.AMPLIFY, 220, 'fixed1', { derived_output = true }),
  define_attr('最终智力', AttrDefs.categories.AMPLIFY, 230, 'fixed1', { derived_output = true }),
  define_attr('最终攻击', AttrDefs.categories.AMPLIFY, 240, 'percent', { is_ratio = true }),
  define_attr('最终生命', AttrDefs.categories.AMPLIFY, 250, 'percent', { is_ratio = true }),
  define_attr('最终护甲', AttrDefs.categories.AMPLIFY, 260, 'percent', { is_ratio = true }),
  define_attr('攻击结算值', AttrDefs.categories.AMPLIFY, 265, 'fixed1', { derived_output = true, persist = false }),
  define_attr('生命结算值', AttrDefs.categories.AMPLIFY, 266, 'fixed1', { derived_output = true, persist = false }),
  define_attr('护甲结算值', AttrDefs.categories.AMPLIFY, 267, 'fixed1', { derived_output = true, persist = false }),
  define_attr('最终力量增幅', AttrDefs.categories.AMPLIFY, 270, 'percent', { is_ratio = true }),
  define_attr('最终敏捷增幅', AttrDefs.categories.AMPLIFY, 280, 'percent', { is_ratio = true }),
  define_attr('最终智力增幅', AttrDefs.categories.AMPLIFY, 290, 'percent', { is_ratio = true }),
  define_attr('精控伤害', AttrDefs.categories.OTHER, 40, 'percent', { is_ratio = true }),
  define_attr('燃烧伤害', AttrDefs.categories.OTHER, 50, 'percent', { is_ratio = true }),
  define_attr('百分比恢复', AttrDefs.categories.OTHER, 60, 'percent', { is_ratio = true }),
  define_attr('穿透次数', AttrDefs.categories.OTHER, 70, 'integer'),
  define_attr('挑战伤害', AttrDefs.categories.OTHER, 110, 'percent', { is_ratio = true }),
  define_attr('冻结伤害', AttrDefs.categories.OTHER, 120, 'percent', { is_ratio = true }),
  define_attr('恢复效果', AttrDefs.categories.OTHER, 130, 'percent', { is_ratio = true }),
  define_attr('卡牌增幅', AttrDefs.categories.OTHER, 140, 'percent', { is_ratio = true }),
}

AttrDefs.by_name = {}
AttrDefs.default_values = {}
for _, def in ipairs(AttrDefs.list) do
  AttrDefs.by_name[def.name] = def
  AttrDefs.default_values[def.name] = def.default or 0
end

local LOG_ATTR_ORDER = {
  '攻击', '攻击白字', '攻击绿字', '攻击速度', '攻击范围', '生命', '护甲', '护甲白字', '护甲绿字',
  '力量', '力量白字', '力量绿字', '敏捷', '敏捷白字', '敏捷绿字', '智力', '智力白字', '智力绿字',
  '最终攻击', '最终生命', '最终护甲', '攻击结算值', '生命结算值', '护甲结算值',
}

local function round_number(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local function format_log_value(name, value)
  local number = tonumber(value) or 0
  if name == '最终攻击' or name == '最终生命' or name == '最终护甲' then
    if math.abs(number) <= 1 then
      number = number * 100
    end
    return string.format('%d%%', round_number(number))
  end
  return tostring(round_number(number))
end

function AttrLog.emit(label, snapshot, extra)
  if AttrLog.enabled ~= true then
    return
  end
  local parts = { string.format('[hero_attr] %s', tostring(label or 'snapshot')) }
  for _, name in ipairs(LOG_ATTR_ORDER) do
    parts[#parts + 1] = string.format('%s=%s', name, format_log_value(name, snapshot and snapshot[name] or 0))
  end
  if extra and extra ~= '' then
    parts[#parts + 1] = tostring(extra)
  end
  local line = table.concat(parts, ' | ')
  if log and log.info then
    log.info(line)
    return
  end
  print(line)
end

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
  if result['攻击'] ~= 0 and result['攻击白字'] == 0 and result['攻击绿字'] == 0 then
    result['攻击白字'] = result['攻击']
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

  function api.get_damage_multiplier(unit, damage_type, damage_form)
    local multiplier = 1
    local final_agility = math.max(0, api.get_attr(unit, '最终敏捷'))
    local final_intelligence = math.max(0, api.get_attr(unit, '最终智力'))
    if damage_type == '物理' or damage_type == 'weapon' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '物理伤害')) + final_agility * AGILITY_PHYSICAL_DAMAGE_RATIO)
    elseif damage_type == '魔法' or damage_type == '法术' or damage_type == 'spell' or damage_type == 'dot' or damage_type == 'summon' then
      multiplier = multiplier * (1 + normalize_ratio(api.get_attr(unit, '魔法伤害')) + final_intelligence * INTELLIGENCE_MAGIC_DAMAGE_RATIO)
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

  function api.compute_damage(unit, amount, damage_meta, context)
    damage_meta = damage_meta or {}
    context = context or {}

    local base = tonumber(amount) or 0
    if base <= 0 then
      local ratio = tonumber(damage_meta.damage_ratio or damage_meta.base_damage_ratio or context.damage_ratio) or 0
      if ratio > 0 then
        base = api.get_attack_power(unit) * ratio
      end
    end
    if base <= 0 and context.fallback_to_attack ~= false then
      base = api.get_attack_power(unit) * (tonumber(context.fallback_ratio) or 1)
    end
    if base <= 0 then
      return 0
    end

    local damage_type = damage_meta.damage_type or context.damage_type or '法术'
    local damage_form = damage_meta.damage_form or context.damage_form or (damage_type == '物理' and 'weapon' or 'spell')
    local damage_kind = context.damage_kind or context.form or 'skill'
    local multiplier = api.get_damage_multiplier(unit, damage_form or damage_type, damage_kind)
      * (tonumber(context.target_multiplier) or 1)
      * (tonumber(context.extra_multiplier) or 1)

    return math.max(1, math.floor(base * multiplier + 0.5))
  end

  return api
end

function M.set_main_stat_attack_ratio(value)
  local number = tonumber(value)
  if number == nil then
    return false
  end
  MAIN_STAT_ATTACK_RATIO = number
  return true
end

local function format_number(value, digits)
  local number = tonumber(value) or 0
  digits = digits or 0
  if digits <= 0 then
    return tostring(math.floor(number + 0.5))
  end
  local text = string.format('%.' .. tostring(digits) .. 'f', number)
  text = text:gsub('(%..-)0+$', '%1'):gsub('%.$', '')
  return text
end

local function format_panel_value(def, value)
  local format_kind = def and def.format or 'fixed1'
  if format_kind == 'integer' then
    return format_number(value, 0)
  end
  if format_kind == 'fixed2' then
    return format_number(value, 2)
  end
  if format_kind == 'fixed1' then
    return format_number(value, 1)
  end
  if format_kind == 'percent' or format_kind == 'percent_or_zero' then
    local ratio = tonumber(value) or 0
    if math.abs(ratio) <= 1 then
      ratio = ratio * 100
    end
    return format_number(ratio, 1) .. '%'
  end
  return format_number(value, 1)
end

local function panel_line(snapshot, name, label, get_fallback_value)
  local value = snapshot and snapshot[name] or nil
  if value == nil and get_fallback_value then
    value = get_fallback_value(name)
  end
  local def = AttrDefs.by_name[name] or { format = 'fixed1' }
  return string.format('%s：%s', label or name, format_panel_value(def, value))
end

function M.build_panel_chunks(snapshot, get_fallback_value)
  if not snapshot then
    return { '属性面板暂不可用' }
  end
  local lines = {
    '属性面板',
    '',
    panel_line(snapshot, '每秒攻击', '攻击成长', get_fallback_value),
    panel_line(snapshot, '每秒生命', '生命成长', get_fallback_value),
    panel_line(snapshot, '攻击范围', '攻击范围', get_fallback_value),
    panel_line(snapshot, '多重数量', '多重数量', get_fallback_value),
    panel_line(snapshot, '生命恢复', '生命恢复', get_fallback_value),
    panel_line(snapshot, '攻击速度', '攻击速度', get_fallback_value),
    panel_line(snapshot, '闪避', '闪避概率', get_fallback_value),
    panel_line(snapshot, '命中', '命中概率', get_fallback_value),
    panel_line(snapshot, '护甲穿透', '护甲穿透', get_fallback_value),
    panel_line(snapshot, '物理暴击', '物理暴击', get_fallback_value),
    panel_line(snapshot, '物理暴伤', '物理暴伤', get_fallback_value),
    panel_line(snapshot, '魔法暴击', '魔法暴击', get_fallback_value),
    panel_line(snapshot, '魔法暴伤', '魔法暴伤', get_fallback_value),
    panel_line(snapshot, '普攻伤害', '普攻伤害', get_fallback_value),
    panel_line(snapshot, '物理伤害', '物理伤害', get_fallback_value),
    panel_line(snapshot, '魔法伤害', '魔法伤害', get_fallback_value),
    panel_line(snapshot, '最终伤害', '最终伤害', get_fallback_value),
    panel_line(snapshot, '伤害减免', '伤害减免', get_fallback_value),
    panel_line(snapshot, '杀敌经验', '经验加成', get_fallback_value),
    panel_line(snapshot, '杀敌金币', '金币加成', get_fallback_value),
    panel_line(snapshot, '挑战伤害', 'BOSS增伤', get_fallback_value),
    panel_line(snapshot, '精控伤害', '精英增伤', get_fallback_value),
  }
  return { table.concat(lines, '\n') }
end

function M.get_defs()
  return AttrDefs
end

return M

local AttrEffect = require 'data.tables.skill.attreffect'
local HeroAttrDefs = require 'runtime.hero_attr_defs'

local M = {}

local POWER_COEFFICIENTS = {
  attack_weight = 1.0,
  hp_weight = 0.1,
  armor_weight = 2.0,
  str_weight = 5.0,
  agi_weight = 4.0,
  int_weight = 4.5,
  crit_weight = 3.0,
  crit_damage_weight = 2.0,
  attack_speed_weight = 2.5,
  move_speed_weight = 1.0,
  life_steal_weight = 3.5,
  block_weight = 2.5,
  dodge_weight = 2.5,
  armor_pierce_weight = 2.0,
  magic_pierce_weight = 2.0,
  damage_reflect_weight = 2.0,
}

local function get_attr_def(name)
  return HeroAttrDefs and HeroAttrDefs.by_name and HeroAttrDefs.by_name[name]
end

local function format_attr_value(name, value)
  local def = get_attr_def(name)
  if def and def.is_ratio then
    return string.format('%.1f%%', value * 100)
  end
  if value >= 10000 then
    return string.format('%.1f万', value / 10000)
  end
  return string.format('%d', math.floor(value))
end

local function build_source_rows(profile, stage_list, stage_bonus_by_mode)
  local rows = {}
  local categories = HeroAttrDefs and HeroAttrDefs.CATEGORIES or {}

  local function add_row(category, source, attr_name, value, order)
    if value and value ~= 0 then
      table.insert(rows, {
        category = category or '其他属性',
        source = source,
        attr_name = attr_name,
        value = value,
        order = order or 999,
      })
    end
  end

  local function merge_attrs_to_rows(category, source, attrs, base_order)
    if type(attrs) ~= 'table' then
      return
    end
    local order = base_order or 0
    for attr_name, value in pairs(attrs) do
      if value and value ~= 0 then
        local def = get_attr_def(attr_name)
        local attr_order = def and def.order or 999
        add_row(def and def.category or category, source, attr_name, value, order + attr_order * 0.001)
      end
    end
  end

  if profile and profile.hero_attr_bonus_stats then
    for attr_name, value in pairs(profile.hero_attr_bonus_stats) do
      if value and value ~= 0 then
        local def = get_attr_def(attr_name)
        add_row(def and def.category or '关卡奖励', '关卡奖励', attr_name, value, 1)
      end
    end
  end

  if profile and profile.hero_growth then
    local growth_attrs = {}
    for hero_id, entry in pairs(profile.hero_growth) do
      if entry.star and entry.star > 0 then
        local star_bonus = entry.star * 5
        growth_attrs['攻击白字'] = (growth_attrs['攻击白字'] or 0) + star_bonus
        growth_attrs['生命白字'] = (growth_attrs['生命白字'] or 0) + star_bonus * 20
      end
      if entry.awakened then
        growth_attrs['攻击白字'] = (growth_attrs['攻击白字'] or 0) + 50
        growth_attrs['生命白字'] = (growth_attrs['生命白字'] or 0) + 500
        growth_attrs['护甲白字'] = (growth_attrs['护甲白字'] or 0) + 10
      end
    end
    merge_attrs_to_rows('英雄养成', '星级/觉醒加成', growth_attrs, 10)
  end

  if profile and profile.hero_growth_resources then
    local resources = profile.hero_growth_resources
    if resources.awaken_stone and resources.awaken_stone > 0 then
      local bonus = math.floor(resources.awaken_stone / 10)
      if bonus > 0 then
        add_row('资源属性', '觉醒石库存：' .. resources.awaken_stone, '攻击白字', bonus, 20)
      end
    end
  end

  if profile and profile.equipment_bonus then
    merge_attrs_to_rows('装备加成', '装备强化', profile.equipment_bonus, 30)
  end

  if profile and profile.talent_bonus then
    merge_attrs_to_rows('天赋加成', '天赋系统', profile.talent_bonus, 40)
  end

  if profile and profile.shop_items then
    for item_id, item in pairs(profile.shop_items) do
      if item.owned and item.attr and item.value then
        local attrs = string.split(item.attr, '|')
        local values = string.split(item.value, '|')
        local item_name = item.name or ('道具_' .. item_id)
        for i, attr_name in ipairs(attrs) do
          local value = tonumber(values[i]) or 0
          if value ~= 0 then
            local def = get_attr_def(attr_name)
            add_row(def and def.category or '商城道具', '已购买: ' .. item_name, attr_name, value, 50)
          end
        end
      end
    end
  end

  table.sort(rows, function(a, b)
    if a.category ~= b.category then
      return a.category < b.category
    end
    if math.abs(a.order - b.order) > 0.0001 then
      return a.order < b.order
    end
    return a.attr_name < b.attr_name
  end)

  return rows
end

local function aggregate_attrs(rows)
  local aggregated = {}
  for _, row in ipairs(rows) do
    local current = aggregated[row.attr_name] or 0
    aggregated[row.attr_name] = current + row.value
  end
  return aggregated
end

local function calc_combat_power(attrs)
  if type(attrs) ~= 'table' then
    return 0
  end

  local power = 0.0

  local function add(key, weight)
    local v = tonumber(attrs[key]) or 0
    if v > 0 then
      power = power + v * (weight or 1.0)
    end
  end

  add('攻击白字', POWER_COEFFICIENTS.attack_weight)
  add('攻击绿字', POWER_COEFFICIENTS.attack_weight)
  add('生命白字', POWER_COEFFICIENTS.hp_weight)
  add('生命绿字', POWER_COEFFICIENTS.hp_weight)
  add('护甲白字', POWER_COEFFICIENTS.armor_weight)
  add('护甲绿字', POWER_COEFFICIENTS.armor_weight)
  add('力量白字', POWER_COEFFICIENTS.str_weight)
  add('力量绿字', POWER_COEFFICIENTS.str_weight)
  add('敏捷白字', POWER_COEFFICIENTS.agi_weight)
  add('敏捷绿字', POWER_COEFFICIENTS.agi_weight)
  add('智力白字', POWER_COEFFICIENTS.int_weight)
  add('智力绿字', POWER_COEFFICIENTS.int_weight)
  add('暴击概率', POWER_COEFFICIENTS.crit_weight)
  add('暴击伤害', POWER_COEFFICIENTS.crit_damage_weight)
  add('攻击速度', POWER_COEFFICIENTS.attack_speed_weight)
  add('移动速度', POWER_COEFFICIENTS.move_speed_weight)
  add('生命偷取', POWER_COEFFICIENTS.life_steal_weight)
  add('格挡概率', POWER_COEFFICIENTS.block_weight)
  add('闪避概率', POWER_COEFFICIENTS.dodge_weight)
  add('护甲穿透', POWER_COEFFICIENTS.armor_pierce_weight)
  add('法术穿透', POWER_COEFFICIENTS.magic_pierce_weight)
  add('伤害反射', POWER_COEFFICIENTS.damage_reflect_weight)

  return math.floor(power + 0.5)
end

local ATTACK_PRIMARY_ATTRS = {
  ['攻击白字'] = true,
  ['攻击绿字'] = true,
  ['物理攻击白字'] = true,
  ['物理攻击绿字'] = true,
  ['法术攻击白字'] = true,
  ['法术攻击绿字'] = true,
}

local HP_PRIMARY_ATTRS = {
  ['生命白字'] = true,
  ['生命绿字'] = true,
}

local DEFENSE_PRIMARY_ATTRS = {
  ['护甲白字'] = true,
  ['护甲绿字'] = true,
}

local CORE_ATTRS = {
  attack = ATTACK_PRIMARY_ATTRS,
  hp = HP_PRIMARY_ATTRS,
  defense = DEFENSE_PRIMARY_ATTRS,
}

local function build_summary_panel_data(profile, stage_list, stage_bonus_by_mode)
  local rows = build_source_rows(profile, stage_list, stage_bonus_by_mode)
  local aggregated = aggregate_attrs(rows)

  local combat_power = calc_combat_power(aggregated)

  local categories = {}
  for _, row in ipairs(rows) do
    if not categories[row.category] then
      categories[row.category] = {}
    end
    table.insert(categories[row.category], row)
  end

  local primary_summary = {}
  for cat_name, cat_rows in pairs(categories) do
    local cat_power = 0.0
    for _, row in ipairs(cat_rows) do
      cat_power = cat_power + math.abs(row.value)
    end
    primary_summary[cat_name] = {
      count = #cat_rows,
      power = cat_power,
    }
  end

  local top_attrs = {}
  local sorted_attrs = {}
  for attr_name, value in pairs(aggregated) do
    table.insert(sorted_attrs, { attr_name = attr_name, value = value })
  end
  table.sort(sorted_attrs, function(a, b)
    return math.abs(a.value) > math.abs(b.value)
  end)
  for i = 1, math.min(10, #sorted_attrs) do
    table.insert(top_attrs, sorted_attrs[i])
  end

  return {
    combat_power = combat_power,
    total_rows = #rows,
    categories = categories,
    aggregated = aggregated,
    top_attrs = top_attrs,
    primary_summary = primary_summary,
  }
end

function M.create(env)
  local CONFIG = env and env.CONFIG or {}
  local STATE = env and env.STATE or {}

  local OUTGAME_ATTR_BONUS_BY_STAGE_MODE = CONFIG.outgame_attr_bonus_config
    and CONFIG.outgame_attr_bonus_config.by_stage_mode
    or {}

  local STAGE_LIST = CONFIG.stages and CONFIG.stages.list or {}

  local api = {}

  function api.get_attr_summary(profile)
    return build_summary_panel_data(profile, STAGE_LIST, OUTGAME_ATTR_BONUS_BY_STAGE_MODE)
  end

  function api.get_combat_power(profile)
    local summary = build_summary_panel_data(profile, STAGE_LIST, OUTGAME_ATTR_BONUS_BY_STAGE_MODE)
    return summary.combat_power
  end

  function api.get_all_source_rows(profile)
    return build_source_rows(profile, STAGE_LIST, OUTGAME_ATTR_BONUS_BY_STAGE_MODE)
  end

  function api.get_aggregated_attrs(profile)
    local rows = build_source_rows(profile, STAGE_LIST, OUTGAME_ATTR_BONUS_BY_STAGE_MODE)
    return aggregate_attrs(rows)
  end

  function api.format_attr(name, value)
    return format_attr_value(name, value)
  end

  function api.get_power_breakdown(profile)
    local attrs = api.get_aggregated_attrs(profile)
    local breakdown = {}

    table.insert(breakdown, {
      category = '攻击属性',
      power = 0,
      attrs = {},
    })
    table.insert(breakdown, {
      category = '生命属性',
      power = 0,
      attrs = {},
    })
    table.insert(breakdown, {
      category = '防御属性',
      power = 0,
      attrs = {},
    })
    table.insert(breakdown, {
      category = '增幅属性',
      power = 0,
      attrs = {},
    })
    table.insert(breakdown, {
      category = '其他属性',
      power = 0,
      attrs = {},
    })

    local category_map = {
      ['伤害属性'] = 1,
      ['资源属性'] = 4,
      ['防守属性'] = 3,
      ['增幅属性'] = 4,
      ['其他属性'] = 5,
    }

    for attr_name, value in pairs(attrs) do
      if value and value ~= 0 then
        local def = get_attr_def(attr_name)
        local cat_idx = category_map[(def and def.category)] or 5
        local weight = 1.0

        if ATTACK_PRIMARY_ATTRS[attr_name] then
          weight = POWER_COEFFICIENTS.attack_weight
        elseif HP_PRIMARY_ATTRS[attr_name] then
          weight = POWER_COEFFICIENTS.hp_weight
        elseif DEFENSE_PRIMARY_ATTRS[attr_name] then
          weight = POWER_COEFFICIENTS.armor_weight
        end

        local attr_power = math.abs(value) * weight
        breakdown[cat_idx].power = breakdown[cat_idx].power + attr_power
        table.insert(breakdown[cat_idx].attrs, {
          attr_name = attr_name,
          value = value,
          power = attr_power,
          formatted = format_attr_value(attr_name, value),
        })
      end
    end

    for i = 1, #breakdown do
      breakdown[i].power = math.floor(breakdown[i].power + 0.5)
    end

    return breakdown
  end

  return api
end

return M
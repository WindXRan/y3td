local M = {}
local CsvLoader = require 'data.csv_loader'
local Json = require 'y3.tools.json'

M.version = '2026-04-29.bond_runtime_rules.v4_production_finish_pass'
-- 合并原独立小文件：
-- bond_draw_config.lua / bond_pick_config.lua / bond_misc_config.lua
M.draw = {
  draw_cost = 100,
  refresh_costs = {
    [1] = 40,
    [2] = 80,
    [3] = 100,
  },
  group_choice_order = {},
  group_choice_defs = {},
}

M.pick = {
  choice_count = 3,
  include_group_choices = true,
  weights = {
    node = 1,
    group = 1,
  },
}

function M.pick.get_candidate_weight(candidate)
  if candidate and candidate.id and string.sub(candidate.id, 1, 8) == '__group_' then
    return M.pick.weights.group or 1
  end
  return M.pick.weights.node or 1
end

M.misc = {
  group_labels = {},
  per_second_attr_keys = {},
  manual_color_keywords = {
    green = {
      '自适应伤害', '技能伤害', '魔法伤害', '所有伤害', '物理暴伤', '魔法暴伤', '物理暴击', '魔法暴击',
      '攻击力', '生命值', '生命恢复', '护甲', '格挡', '力量', '敏捷', '智力', '木材', '金币', '经验',
      '杀敌金币', '杀敌经验', '杀敌加成', '每秒',
    },
    cyan = {
      '%d+%.?%d*%%',
      '%d+%.?%d*',
    },
  },
}
M.presentation_defaults = {
  persistent_area_warmup = 0.05,
  instant_warmup = 0.02,
  default_fx_pulse_every = 3,
}

-- 羁绊技能：普攻触发类规则
M.bond_basic_attack = {
  ['枪炮师'] = {
    chance = 0.12,
    wave_count_default = 1,
    wave_count_with_tactical_reposition = 2,
    wave_damage_attack_ratio = 2.8,
    wave_damage_three_attr_ratio = 1.20,
    line = {
      distance = 1600,
      width = 240,
      max_targets = 'max',
      target_fx_scale = 1.08,
      target_fx_time = 0.28,
      hit_fx_scale = 0.96,
      hit_fx_time = 0.22,
      instant_hit = true,
    },
  },
  ['神射手'] = {
    chance = 0.16,
    damage_attack_ratio = 1.85,
    damage_attack_speed_ratio = 0.80,
    line_aoe_radius = 220,
    line_aoe_ratio = 0.72,
  },
  ['游侠'] = {
    chance = 0.12,
    arrow_rain = {
      radius = 420,
      tick_count = 5,
      tick_interval = 0.55,
      tick_damage_attack_ratio = 0.92,
      fx_pulse_every = 2,
    },
  },
  ['狂战士'] = {
    chance = 0.34,
    damage_attack_ratio = 0.11,
    damage_missing_hp_ratio = 0.06,
  },
  ['剑魂'] = {
    hit_count_trigger = 8,
    damage_attack_ratio = 1.8,
  },
  ['剑宗'] = {
    chance = 0.12,
    storm_radius = 420,
    tick_count = 15,
    tick_interval = 0.20,
    tick_damage_attack_ratio = 0.10,
    tick_damage_sword_intent_ratio = 2.4,
    spoke_count = 6,
    spoke_rotation_delta = 0.24,
    spoke_radius_ratio = 0.76,
    edge_scale_ratio = 0.72,
    edge_scale_floor = 0.65,
    fx_pulse_every = 3,
  },
  ['龙骑士'] = {
    trigger_floor_default = 0.08,
    trigger_floor_with_crit_card = 0.15,
  },
  ['战斗法师'] = {
    chance = 0.14,
    aoe_radius = 420,
    damage_attack_ratio = 3.35,
    damage_type = '法术',
  },
  ['魔剑士'] = {
    demon_damage_attack_ratio = 2.0,
  },
}

-- 羁绊技能：周期触发类规则
M.bond_periodic = {
  ['火法师'] = {
    interval = 2.4,
    damage_attack_ratio = 3.0,
    splash_radius = 460,
    splash_damage_attack_ratio = 1.6,
    damage_type = '法术',
  },
  ['冰霜法师'] = {
    interval = 4.0,
    storm_radius = 460,
    tick_count = 8,
    tick_interval = 0.32,
    tick_damage_attack_ratio = 0.20,
    tick_damage_max_hp_ratio = 0.01,
    fx_pulse_every = 2,
    damage_type = '法术',
  },
  ['猎人'] = {
    interval = 30.0,
    summon_duration = 23.0,
    summon_kind = 'magic_deer',
  },
  ['雷电法王'] = {
    interval = 0.75,
    bolts_per_tick = 4,
    base_target_count = 4,
    min_target_count = 1,
    max_target_count = 5,
    damage_ratio_default = 0.65,
    damage_ratio_with_talent = 0.90,
    range = 1200,
    runtime_bonus_key = 'lightning_target_count',
    card_bonus_target_count = 6,
  },
  ['骷髅法师'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
  },
}

-- 单羁绊卡：普攻触发规则
M.card_basic_attack = {
  ['BBQ'] = {
    chance = 0.12,
    aoe_radius = 380,
    damage_attack_ratio = 3.4,
    damage_type = '物理',
    visual_bond = '枪炮师',
  },
  ['穿云箭'] = {
    chance = 0.16,
    damage_attack_ratio = 1.85,
    damage_attack_speed_ratio = 0.80,
    line_aoe_radius = 220,
    line_aoe_ratio = 0.70,
    damage_type = '物理',
    visual_bond = '神射手',
  },
  ['穿甲射击'] = {
    chance = 0.16,
    damage_attack_ratio = 1.85,
    damage_attack_speed_ratio = 0.80,
    line_aoe_radius = 220,
    line_aoe_ratio = 0.70,
    damage_type = '物理',
    visual_bond = '神射手',
  },
  ['嗜血'] = {
    heal_max_hp_ratio = 0.01,
  },
  ['毒蛇钉刺'] = {
    chance = 0.14,
    aoe_radius = 420,
    damage_attack_ratio = 2.2,
    damage_type = '物理',
    visual_bond = '游侠',
  },
  ['毒箭雨'] = {
    chance = 0.12,
    visual_bond = '游侠',
  },
  ['敏锐'] = {
    chance = 0.12,
    visual_bond = '游侠',
  },
  ['坚韧'] = {
    chance = 0.12,
    visual_bond = '游侠',
  },
  ['毒前雨'] = {
    chance = 0.13,
    visual_bond = '游侠',
  },
  ['疾风弓'] = {
    stack_duration = 5.0,
    max_stacks = 10,
    attack_per_stack = 0,
    attack_speed_per_stack = 5,
  },
  ['幻影剑舞'] = {
    chance = 0.30,
    stack_duration = 5.0,
    max_stacks = 10,
    attack_per_stack = 20,
    attack_speed_per_stack = 2,
  },
  ['斩击'] = {
    hit_count_trigger = 8,
    damage_attack_ratio = 1.8,
    damage_type = '物理',
    visual_bond = '剑魂',
  },
  ['剑魂'] = {
    hit_count_trigger = 8,
    damage_attack_ratio = 1.8,
    damage_type = '物理',
    visual_bond = '剑魂',
  },
  ['狂刀斩'] = {
    chance = 0.30,
    damage_attack_ratio = 0.10,
    damage_missing_hp_ratio = 0.05,
    damage_type = '物理',
    visual_bond = '狂战士',
  },
  ['重甲精通'] = {
    chance = 0.30,
    damage_attack_ratio = 0.10,
    damage_missing_hp_ratio = 0.05,
    damage_type = '物理',
    visual_bond = '狂战士',
  },
  ['力量唤醒'] = {
    chance = 0.30,
    damage_attack_ratio = 0.10,
    damage_missing_hp_ratio = 0.05,
    damage_type = '物理',
    visual_bond = '狂战士',
  },
}

M.card_arrow_rain = {
  radius = 420,
  tick_count = 5,
  tick_interval = 0.55,
  tick_damage_attack_ratio = 0.92,
  fx_pulse_every = 2,
}

-- 单羁绊卡：周期触发规则
M.card_periodic = {
  ['连射'] = {
    multishot = 1,
  },
  ['火焰炉盾'] = {
    interval = 10.0,
    heal_max_hp_ratio = 0.20,
    visual_bond = '火法师',
  },
  ['引雷咒'] = {
    interval = 0.75,
    base_target_count = 3,
    bonus_target_count = 6,
    damage_ratio_default = 0.72,
    damage_ratio_with_talent = 0.98,
    range = 1200,
    visual_bond = '雷电法王',
  },
  ['自然之体'] = {
    interval = 30.0,
    summon_duration = 23.0,
    summon_kind = 'magic_deer',
    visual_bond = '猎人',
  },
  ['猎人'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'magic_bear',
    visual_bond = '猎人',
  },
  ['奔袭'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'magic_bear',
    visual_bond = '猎人',
  },
  ['召唤猎鹰'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'hawk',
    visual_bond = '猎人',
  },
  ['骷髅复苏'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['骷髅支配'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['骷髅恐惧'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['骷髅压制'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['骷髅审判'] = {
    interval = 30.0,
    summon_duration = 25.0,
    summon_kind = 'skeleton',
    visual_bond = '骷髅法师',
  },
  ['狂化'] = {
    cycle_interval = 2.0,
    frenzy_duration = 5.0,
    all_damage_bonus = 1.0,
    visual_bond = '狂战士',
  },
}

-- 单羁绊卡：击杀事件触发规则
M.card_kill = {
  ['入魔'] = {
    kill_threshold = 4,
    trigger_chance = 0.40,
    demon_duration = 6.0,
    visual_bond = '魔剑士',
  },
  ['中华傲决'] = {
    kill_threshold = 100,
    sword_intent_gain = 1,
    visual_bond = '剑宗',
  },
}

-- 龙骑士火龙穿透规则（由主羁绊与卡牌共同读取）
M.dragon_fireball = {
  line_distance_default = 1560,
  line_distance_with_tail_sweep = 1840,
  line_width_default = 250,
  line_width_with_tail_sweep = 360,
  width_scale_with_tail_sweep = 1.20,
  min_width = 160,
  pierce_width_ratio = 0.76,
  min_pierce_width = 140,
  tick_interval = 0.10,
}

-- 召唤物继承档案
M.summon_inherit_profiles = {
  default = {
    attack_ratio = 0.35,
    hp_ratio = 0.20,
    attack_bonus_ratio = 1.00,
    hp_bonus_ratio = 0.60,
  },
  magic_deer = {
    attack_ratio = 0.28,
    hp_ratio = 0.26,
    attack_bonus_ratio = 0.80,
    hp_bonus_ratio = 0.70,
  },
  magic_bear = {
    attack_ratio = 0.40,
    hp_ratio = 0.24,
    attack_bonus_ratio = 1.00,
    hp_bonus_ratio = 0.65,
  },
  hawk = {
    attack_ratio = 0.48,
    hp_ratio = 0.16,
    attack_bonus_ratio = 1.20,
    hp_bonus_ratio = 0.45,
  },
  skeleton = {
    attack_ratio = 0.34,
    hp_ratio = 0.22,
    attack_bonus_ratio = 0.95,
    hp_bonus_ratio = 0.60,
  },
}

-- 运行时状态效果预设
M.status_runtime_presets = {
  magic_swordsman_demon = {
    name = '入魔',
    description = '入魔：提升最终伤害并强化魔剑士输出。',
    particle_bond = '魔剑士',
    particle_scale = 1.05,
    particle_time = 9999,
    buff_refresh = 1.4,
  },
  berserker_frenzy = {
    name = '狂化',
    description = '狂化：短时间内进入爆发状态。',
    particle_bond = '狂战士',
    particle_scale = 1.00,
    particle_time = 9999,
    buff_refresh = 1.3,
  },
}

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalize_damage_type(raw)
  local value = trim(raw)
  if value == '物理' or value == '法术' then
    return value
  end
  return nil
end

local VALID_SCOPES = {
  bond_basic = true,
  bond_periodic = true,
  card_basic = true,
  card_periodic = true,
  card_kill = true,
  dragon_fireball = true,
  card_arrow_rain = true,
  basic_attack_profile = true,
}

local VALID_TRIGGER_KINDS = {
  basic_attack = true,
  periodic = true,
  kill = true,
  special = true,
}

local VALID_VALUE_TYPES = {
  number = true,
  bool = true,
  string = true,
}

local function warn(msg)
  local text = '[bond_effect_runtime_rules] ' .. tostring(msg)
  if log and log.warn then
    log.warn(text)
  else
    print(text)
  end
end

local function is_enabled(raw)
  local value = string.lower(trim(raw))
  return value == '' or value == '1' or value == 'true'
end

local function to_typed_value(raw, value_type)
  local kind = string.lower(trim(value_type))
  local value = trim(raw)
  if value == '' then
    return nil
  end
  if kind == 'number' then
    local n = tonumber(value)
    if n == nil then
      return nil, string.format('number parse failed: %s', value)
    end
    return n
  end
  if kind == 'bool' then
    local lower = string.lower(value)
    if lower == '1' or lower == 'true' then
      return true
    end
    if lower == '0' or lower == 'false' then
      return false
    end
    return nil, string.format('bool parse failed: %s', value)
  end
  if kind == 'string' then
    return value
  end
  return nil, string.format('unknown value_type: %s', tostring(value_type))
end

local function set_deep(dst, dotted_key, value)
  local key = trim(dotted_key)
  if key == '' or value == nil then
    return
  end
  local current = dst
  local last = nil
  for token in string.gmatch(key, '[^%.]+') do
    if last then
      current[last] = current[last] or {}
      if type(current[last]) ~= 'table' then
        current[last] = {}
      end
      current = current[last]
    end
    last = token
  end
  if last then
    current[last] = value
  end
end

local function to_auto_typed_value(raw)
  local value = trim(raw)
  if value == '' then
    return nil
  end
  local lower = string.lower(value)
  if lower == 'true' then
    return true
  end
  if lower == 'false' then
    return false
  end
  local number_value = tonumber(value)
  if number_value ~= nil then
    return number_value
  end
  return value
end

local function merge_table(dst, src)
  if type(dst) ~= 'table' or type(src) ~= 'table' then
    return dst
  end
  for k, v in pairs(src) do
    if type(v) == 'table' then
      local child = dst[k]
      if type(child) ~= 'table' then
        child = {}
        dst[k] = child
      end
      merge_table(child, v)
    else
      dst[k] = v
    end
  end
  return dst
end

local function decode_params_json(raw, skill_id)
  local text = trim(raw)
  if text == '' then
    return nil
  end
  local ok, parsed = pcall(Json.decode, text)
  if not ok or type(parsed) ~= 'table' then
    warn(string.format('params_json parse failed: skill_id=%s', tostring(skill_id)))
    return nil
  end
  return parsed
end

local function apply_bond_skill_rows()
  local skill_rows = CsvLoader.read_rows_optional('data_csv/bond_skills.csv')
  local param_rows = CsvLoader.read_rows_optional('data_csv/bond_skill_params.csv')
  if #skill_rows <= 0 then
    warn('bond_skills.csv missing/empty, keep lua fallback rules')
    return
  end

  local skills_by_id = {}
  local use_legacy_param_rows = false
  for _, row in ipairs(skill_rows) do
    if is_enabled(row.enabled) then
      local skill_id = trim(row.skill_id)
      if skill_id == '' then
        warn('skip row: empty skill_id')
      elseif skills_by_id[skill_id] then
        warn('duplicate skill_id: ' .. skill_id)
      else
        local scope = trim(row.scope)
        local trigger_kind = trim(row.trigger_kind)
        local damage_type = normalize_damage_type(row.damage_type)
        if not VALID_SCOPES[scope] then
          warn(string.format('invalid scope(%s) for skill_id=%s', scope, skill_id))
        elseif trigger_kind ~= '' and not VALID_TRIGGER_KINDS[trigger_kind] then
          warn(string.format('invalid trigger_kind(%s) for skill_id=%s', trigger_kind, skill_id))
        elseif trim(row.damage_type) ~= '' and damage_type == nil then
          warn(string.format('invalid damage_type(%s) for skill_id=%s', tostring(row.damage_type), skill_id))
        else
          skills_by_id[skill_id] = {
            skill_id = skill_id,
            skill_name = trim(row.skill_name),
            bond_name = trim(row.bond_name),
            scope = scope,
            trigger_kind = trigger_kind,
            damage_type = damage_type,
            visual_bond = trim(row.visual_bond),
            params = {},
          }
          local decoded = decode_params_json(row.params_json, skill_id)
          if decoded then
            skills_by_id[skill_id].params = merge_table({}, decoded)
          else
            use_legacy_param_rows = true
          end
        end
      end
    end
  end

  if use_legacy_param_rows then
    local use_long_param_rows = (#param_rows > 0 and param_rows[1].param_key ~= nil)
    if use_long_param_rows then
      for _, row in ipairs(param_rows) do
        if is_enabled(row.enabled) then
          local skill_id = trim(row.skill_id)
          local param_key = trim(row.param_key)
          local value_type = string.lower(trim(row.value_type))
          local meta = skills_by_id[skill_id]
          if skill_id == '' or param_key == '' then
            warn('skip param row with empty skill_id/param_key')
          elseif not meta then
            warn(string.format('orphan param row: skill_id=%s key=%s', skill_id, param_key))
          elseif not VALID_VALUE_TYPES[value_type] then
            warn(string.format('invalid value_type(%s) for skill_id=%s key=%s', value_type, skill_id, param_key))
          else
            local typed, err = to_typed_value(row.param_value, value_type)
            if err then
              warn(string.format('param parse error: skill_id=%s key=%s err=%s', skill_id, param_key, err))
            elseif typed ~= nil then
              set_deep(meta.params, param_key, typed)
            end
          end
        end
      end
    else
      for _, row in ipairs(param_rows) do
        if is_enabled(row.enabled) then
          local skill_id = trim(row.skill_id)
          local meta = skills_by_id[skill_id]
          if skill_id == '' then
            -- skip
          elseif not meta then
            warn(string.format('orphan wide param row: skill_id=%s', skill_id))
          else
            for key, raw in pairs(row) do
              if key ~= 'skill_id' and key ~= 'enabled' and key ~= '字段中文说明' then
                local typed = to_auto_typed_value(raw)
                if typed ~= nil then
                  set_deep(meta.params, key, typed)
                end
              end
            end
          end
        end
      end
    end
  end

  local bond_basic = {}
  local bond_periodic = {}
  local card_basic = {}
  local card_periodic = {}
  local card_kill = {}
  local card_arrow_rain = nil
  local dragon_fireball = nil
  local basic_attack_profile = nil

  for _, meta in pairs(skills_by_id) do
    local rule = meta.params or {}
    if meta.damage_type then
      rule.damage_type = meta.damage_type
    end
    if meta.visual_bond ~= '' then
      rule.visual_bond = meta.visual_bond
    end

    if meta.scope == 'bond_basic' then
      if meta.bond_name ~= '' then
        bond_basic[meta.bond_name] = rule
      else
        warn('bond_basic missing bond_name: ' .. meta.skill_id)
      end
    elseif meta.scope == 'bond_periodic' then
      if meta.bond_name ~= '' then
        bond_periodic[meta.bond_name] = rule
      else
        warn('bond_periodic missing bond_name: ' .. meta.skill_id)
      end
    elseif meta.scope == 'card_basic' then
      local key = meta.skill_name ~= '' and meta.skill_name or meta.skill_id
      card_basic[key] = rule
    elseif meta.scope == 'card_periodic' then
      local key = meta.skill_name ~= '' and meta.skill_name or meta.skill_id
      card_periodic[key] = rule
    elseif meta.scope == 'card_kill' then
      local key = meta.skill_name ~= '' and meta.skill_name or meta.skill_id
      card_kill[key] = rule
    elseif meta.scope == 'card_arrow_rain' then
      card_arrow_rain = rule
    elseif meta.scope == 'dragon_fireball' then
      dragon_fireball = rule
    elseif meta.scope == 'basic_attack_profile' then
      basic_attack_profile = rule
    end
  end

  if next(bond_basic) then
    M.bond_basic_attack = bond_basic
  end
  if next(bond_periodic) then
    M.bond_periodic = bond_periodic
  end
  if next(card_basic) then
    M.card_basic_attack = card_basic
  end
  if next(card_periodic) then
    M.card_periodic = card_periodic
  end
  if next(card_kill) then
    M.card_kill = card_kill
  end
  if type(card_arrow_rain) == 'table' and next(card_arrow_rain) then
    M.card_arrow_rain = card_arrow_rain
  end
  if type(dragon_fireball) == 'table' and next(dragon_fireball) then
    M.dragon_fireball = dragon_fireball
    if M.dragon_fireball.line_distance_default == nil
      or M.dragon_fireball.line_width_default == nil
      or M.dragon_fireball.tick_interval == nil then
      warn('dragon_fireball missing key params, fallback kept by partial merge strategy')
      M.dragon_fireball.line_distance_default = M.dragon_fireball.line_distance_default or 1560
      M.dragon_fireball.line_width_default = M.dragon_fireball.line_width_default or 250
      M.dragon_fireball.tick_interval = M.dragon_fireball.tick_interval or 0.10
    end
  end
  if type(basic_attack_profile) == 'table' and next(basic_attack_profile) then
    M.basic_attack_profile = basic_attack_profile
  end
end

apply_bond_skill_rows()

return M

local CONFIG = require 'config.entry_config'
local HeroEvolutionObjects = require 'data.tables.outgame.hero_evolutions'

local M = {}


function M.safe_get_unit_icon(unit_key)
  if not unit_key or not y3 or not y3.unit or not y3.unit.get_icon_by_key then
    return nil
  end
  local ok, icon = pcall(y3.unit.get_icon_by_key, unit_key)
  if ok then
    return icon
  end
  return nil
end

function M.safe_get_buff_icon(buff_key)
  if not buff_key or not y3 or not y3.buff or not y3.buff.get_icon_by_key then
    return nil
  end
  local ok, icon = pcall(y3.buff.get_icon_by_key, buff_key)
  if ok then
    return icon
  end
  return nil
end

function M.safe_get_buff_name(buff_key)
  if not buff_key or not y3 or not y3.buff or not y3.buff.get_name_by_key then
    return nil
  end
  local ok, name = pcall(y3.buff.get_name_by_key, buff_key)
  if ok then
    return name
  end
  return nil
end

function M.has_valid_icon(icon)
  if icon == nil then
    return false
  end
  local n = tonumber(icon)
  if n ~= nil then
    return n ~= 0
  end
  return true
end

function M.build_bottom_status_effect_entry(effect_def, snapshot)
  if not effect_def or not snapshot or snapshot.active ~= true then
    return nil
  end

  local icon
  local title
  local lines = {}

  if effect_def.source_type == 'mark' then
    local evolution_def = HeroEvolutionObjects.by_id and HeroEvolutionObjects.by_id[effect_def.source_id] or nil
    icon = evolution_def and M.safe_get_unit_icon(evolution_def.hero_unit_id) or nil
    title = evolution_def and evolution_def.name or nil
    if evolution_def and evolution_def.summary and evolution_def.summary ~= '' then
      lines[#lines + 1] = tostring(evolution_def.summary)
    end
  end

  if not icon then
    icon = M.safe_get_buff_icon(effect_def.modifier_key)
  end
  if not title or title == '' then
    title = M.safe_get_buff_name(effect_def.modifier_key) or effect_def.id or '魔法效果'
  end

  local cooldown = tonumber(snapshot.cooldown) or 0
  if cooldown > 0 then
    lines[#lines + 1] = string.format('冷却中：%.1fs', cooldown)
  end
  local counter = tonumber(snapshot.counter) or 0
  if counter > 0 then
    lines[#lines + 1] = string.format('层数：%d', math.floor(counter + 0.5))
  end
  if #lines == 0 then
    lines[#lines + 1] = '当前已激活。'
  end

  return {
    id = tostring(effect_def.id or title or 'status_effect'),
    icon = icon,
    modifier_key = tonumber(effect_def.modifier_key) or nil,
    tip_title = tostring(title or '魔法效果'),
    tip_text = table.concat(lines, '\n'),
    tip_contents = #lines > 0 and { '[效果详情]\n' .. table.concat(lines, '\n') } or {},
  }
end





function M.build_hero_buff_status_entries(limit, STATE, taken_modifier_keys)
  local entries = {}
  limit = math.max(0, tonumber(limit) or 0)
  if limit <= 0 or not STATE or not STATE.hero then
    return entries
  end
  local hero = STATE.hero
  if not (hero and hero.is_exist and hero:is_exist() and hero.get_buffs) then
    return entries
  end

  local ok, buff_list = pcall(hero.get_buffs, hero)
  if not ok or type(buff_list) ~= 'table' then
    return entries
  end

  local grouped = {}
  local ordered_keys = {}
  for _, buff in ipairs(buff_list) do
    if buff and buff.is_exist and buff:is_exist() and buff.get_key then
      local modifier_key = tonumber(buff:get_key()) or 0
      if modifier_key > 0 and not (taken_modifier_keys and taken_modifier_keys[modifier_key]) then
        local icon_visible = true
        if buff.is_icon_visible then
          local ok_visible, visible = pcall(buff.is_icon_visible, buff)
          if ok_visible then
            icon_visible = visible == true
          end
        end
        local icon = M.safe_get_buff_icon(modifier_key)
        if icon_visible and M.has_valid_icon(icon) then
          local group = grouped[modifier_key]
          if not group then
            local title = (buff.get_name and buff:get_name()) or ''
            if title == '' then
              title = M.safe_get_buff_name(modifier_key) or tostring(modifier_key)
            end
            local desc = (buff.get_description and buff:get_description()) or ''
            group = {
              key = modifier_key,
              icon = icon,
              title = tostring(title),
              desc = tostring(desc or ''),
              max_stack = 0,
              max_time = 0,
            }
            grouped[modifier_key] = group
            ordered_keys[#ordered_keys + 1] = modifier_key
          end
          local stack = (buff.get_stack and tonumber(buff:get_stack())) or 0
          if stack > group.max_stack then
            group.max_stack = stack
          end
          local left_time = (buff.get_time and tonumber(buff:get_time())) or 0
          if left_time > group.max_time then
            group.max_time = left_time
          end
        end
      end
    end
  end

  for _, modifier_key in ipairs(ordered_keys) do
    if #entries >= limit then
      break
    end
    local group = grouped[modifier_key]
    if group then
      local lines = {}
      if group.desc ~= '' then
        lines[#lines + 1] = group.desc
      end
      if group.max_stack > 1 then
        lines[#lines + 1] = string.format('层数：%d', math.floor(group.max_stack + 0.5))
      end
      if group.max_time > 0 and group.max_time < 86400 then
        lines[#lines + 1] = string.format('持续：%.1fs', group.max_time)
      end
      if #lines == 0 then
        lines[#lines + 1] = '当前已激活。'
      end
      entries[#entries + 1] = {
        id = string.format('hero_buff_%d', modifier_key),
        icon = group.icon,
        modifier_key = modifier_key,
        tip_title = group.title,
        tip_text = table.concat(lines, '\n'),
        tip_contents = #lines > 0 and { '[效果详情]\n' .. table.concat(lines, '\n') } or {},
      }
    end
  end

  return entries
end

function M.get_bottom_status_effect_entries(max_slots, STATE, auto_active_effects_system)
  local entries = {}
  local limit = math.max(0, tonumber(max_slots) or 5)
  if limit == 0 then
    return entries
  end

  local taken_modifier_keys = {}
  local function push_entry(entry)
    if not entry or #entries >= limit then
      return
    end
    entries[#entries + 1] = entry
    local modifier_key = tonumber(entry.modifier_key) or 0
    if modifier_key > 0 then
      taken_modifier_keys[modifier_key] = true
    end
  end

  if #entries < limit then
    for _, entry in ipairs(M.build_hero_buff_status_entries(limit - #entries, STATE, taken_modifier_keys)) do
      push_entry(entry)
      if #entries >= limit then
        break
      end
    end
  end

  if #entries < limit
      and auto_active_effects_system
      and auto_active_effects_system.get_effect_defs
      and auto_active_effects_system.get_effect_runtime_snapshot then
    for _, effect_def in ipairs(auto_active_effects_system.get_effect_defs() or {}) do
      if #entries >= limit then
        break
      end
      local snapshot = auto_active_effects_system.get_effect_runtime_snapshot(effect_def.id)
      push_entry(M.build_bottom_status_effect_entry(effect_def, snapshot))
    end
  end

  return entries
end

function M.resolve_damage_meta(damage)
  local function normalize_damage_type(raw)
    local value = tostring(raw or '')
    if value == '物理' then
      return '物理'
    end
    if value == '法术' or value == '魔法' then
      return '法术'
    end
    if value == '真实' then
      return '真实'
    end
    return '法术'
  end

  if type(damage) == 'table' then
    local resolved_damage_type = normalize_damage_type(damage.damage_type)
    return {
      damage_type = resolved_damage_type,
      damage_form = damage.damage_form or (resolved_damage_type == '物理' and 'weapon' or 'spell'),
      element = 'none',
      damage_label = resolved_damage_type == '物理' and '兵刃伤害' or '术法伤害',
    }
  end

  local legacy_damage_type = normalize_damage_type(damage)
  return {
    damage_type = legacy_damage_type,
    damage_form = legacy_damage_type == '物理' and 'weapon' or 'spell',
    element = 'none',
    damage_label = legacy_damage_type == '物理' and '兵刃伤害' or '术法伤害',
  }
end

function M.make_point(data)
  return y3.point.create(data.x, data.y, data.z or 0)
end

function M.round_number(value)
  return math.floor((value or 0) + 0.5)
end

function M.design_seconds(seconds)
  if CONFIG.debug_time_scale <= 0 then
    return seconds
  end
  return seconds / CONFIG.debug_time_scale
end

function M.get_player()
  return y3.player(CONFIG.player_id)
end

function M.get_enemy_player()
  return y3.player(CONFIG.enemy_player_id)
end

function M.trace_boot(message)
  if log and log.info then
    log.info('[entry_runtime] ' .. tostring(message))
  end
end

function M.infer_battle_event_style(text)
  local content = tostring(text or '')
  if content == '' then
    return '普通'
  end
  if string.find(content, '获得', 1, true)
      or string.find(content, '奖励', 1, true)
      or string.find(content, '刷新次数', 1, true)
      or string.find(content, '金币 +', 1, true)
      or string.find(content, '木材 +', 1, true)
      or string.find(content, '经验 +', 1, true) then
    return '奖励'
  end
  if string.find(content, '开始', 1, true)
      or string.find(content, '进攻', 1, true)
      or string.find(content, '警告', 1, true)
      or string.find(content, '失败', 1, true)
      or string.find(content, '不足', 1, true) then
    return '警告'
  end
  if string.find(content, '稀有', 1, true)
      or string.find(content, '史诗', 1, true)
      or string.find(content, '1星效果触发', 1, true) then
    return '稀有'
  end
  if string.find(content, '+1', 1, true)
      or string.find(content, '恢复', 1, true)
      or string.find(content, '升级', 1, true)
      or string.find(content, '解锁', 1, true) then
    return '积极'
  end
  return '普通'
end


function M.update_passive_resources(dt, STATE, resource_system)
  local rules = STATE.progression_system and STATE.progression_system.get_resource_rules and STATE.progression_system.get_resource_rules() or {}
  local gold_per_sec = math.max(0, rules.gold_per_sec or 0)
  local wood_per_sec = math.max(0, rules.wood_per_sec or 0)
  if gold_per_sec <= 0 and wood_per_sec <= 0 then
    return
  end

  local interval = math.max(0.05, CONFIG.debug_time_scale or 1.0)
  STATE.resource_income_elapsed = (STATE.resource_income_elapsed or 0) + dt

  while STATE.resource_income_elapsed >= interval do
    STATE.resource_income_elapsed = STATE.resource_income_elapsed - interval
    resource_system.add_gold(gold_per_sec)
    resource_system.add_wood(wood_per_sec)
  end
end

-- ============================================================================
-- 运行时加成注入（由 boot.lua 在 _G.get_bond_runtime_bonus 就绪后调用）
-- ============================================================================
local _get_bond_runtime_bonus = nil

function M.set_get_bond_runtime_bonus(fn)
  _get_bond_runtime_bonus = fn
end

function M.get_bond_runtime_bonus(key)
  if _get_bond_runtime_bonus then
    return _get_bond_runtime_bonus(key)
  end
  return 0
end

return M
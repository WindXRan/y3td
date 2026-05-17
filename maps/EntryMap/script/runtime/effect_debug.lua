local M = {}

local function clone_table(source)
  local result = {}
  for key, value in pairs(source or {}) do
    result[key] = value
  end
  return result
end

local function append_line(lines, text)
  if text and text ~= '' then
    lines[#lines + 1] = text
  end
end

local function bool_label(value)
  return value and '是' or '否'
end

local EFFECT_LABELS = {
  spell_burst = '奥术爆发',
  haste_reset = '急速重置',
  fighting_spirit_field = '战意力场',
  rapid_overdrive = '疾速超载',
  blood_demon_burst = '血魔爆裂',
  charge_breaker_rally = '破军振奋',
  bloodrage_stomp = '血怒践踏',
  starfire_echo = '星火回响',
}

local TRIGGER_LABELS = {
  periodic = '周期检测',
  on_kill = '击杀触发',
  on_basic_attack_count = '普攻计数触发',
  on_attack_skill_cast = '普攻技能施放触发',
}

local SOURCE_LABELS = {
  bond = '羁绊',
  mark = '英雄进化',
}

local SOURCE_ID_LABELS = {
  auto_spell_burst = '自动法术爆发路线',
  auto_haste_reset = '急速重置路线',
  auto_fighting_spirit = '战意力场路线',
  auto_rapid_overdrive = '疾速超载路线',
  auto_blood_demon_burst = '血魔爆裂路线',
  auto_charge_breaker_rally = '破军振奋路线',
  war_god_mark = '战神进化',
  storm_mark = '风暴进化',
}

local FUNCTION_HINTS = {
  spell_burst = '每隔冷却时间寻找范围内敌人，以智力倍率造成范围魔法伤害；拥有强化路线时会追加爆发次数并扩大半径。',
  haste_reset = '施放非基础普攻技能时按概率将该技能冷却清零，用于验证急速流派的技能连发。',
  fighting_spirit_field = '周期性扫过大范围敌人，以力量倍率和目标最大生命附加伤害造成物理伤害，并短暂降低护甲与物攻、尝试挂战意 Buff。',
  rapid_overdrive = '普攻计数触发后按概率给英雄短时间攻击速度加成，并尝试挂疾速超载 Buff。',
  blood_demon_burst = '英雄每损失一段生命比例时触发，治疗英雄并对近距离敌人造成最大生命比例物理伤害、眩晕和减速。',
  charge_breaker_rally = '击杀触发，为英雄提供短时间属性加成并尝试挂破军振奋 Buff。',
  bloodrage_stomp = '普攻计数触发，以英雄攻击结算值为基础对周围敌人造成范围物理伤害。',
  starfire_echo = '施放普攻技能时寻找目标发射追踪投射物，命中后造成魔法伤害。',
}

local function format_percent(value)
  if value == nil then
    return nil
  end
  return string.format('%d%%', math.floor((tonumber(value) or 0) * 100 + 0.5))
end

local function append_number_line(lines, label, value, suffix)
  if value ~= nil then
    lines[#lines + 1] = string.format('%s：%s%s', label, tostring(value), suffix or '')
  end
end

local function build_attr_lines(attr)
  local result = {}
  for key, value in pairs(attr or {}) do
    local number_value = tonumber(value) or 0
    local sign = number_value >= 0 and '+' or ''
    result[#result + 1] = string.format('%s %s%s', tostring(key), sign, tostring(value))
  end
  table.sort(result)
  return result
end

local function get_effect_display_name(def)
  if not def then
    return '未知特效'
  end
  return EFFECT_LABELS[def.id] or def.id or '未知特效'
end

local function build_effect_function_lines(def)
  if not def then
    return { '暂无功能说明。' }
  end

  local lines = {
    string.format('功能：%s', FUNCTION_HINTS[def.id] or '配置型自动特效，按触发条件执行伤害、属性、Buff 或投射物逻辑。'),
    string.format('触发方式：%s', TRIGGER_LABELS[def.trigger_type] or tostring(def.trigger_type or '-')),
    string.format(
      '来源：%s / %s',
      SOURCE_LABELS[def.source_type] or tostring(def.source_type or '-'),
      SOURCE_ID_LABELS[def.source_id] or tostring(def.source_id or '-')
    ),
  }

  append_number_line(lines, '冷却', def.cooldown, '秒')
  append_number_line(lines, '搜索范围', def.range)
  append_number_line(lines, '作用半径', def.radius)
  append_number_line(lines, '爆炸半径', def.blast_radius)
  if def.damage_ratio ~= nil then
    lines[#lines + 1] = string.format('伤害倍率：%s', tostring(def.damage_ratio))
  end
  if def.chance ~= nil then
    lines[#lines + 1] = string.format('触发概率：%s', format_percent(def.chance))
  end
  append_number_line(lines, '计数需求', def.counter_required)
  append_number_line(lines, '持续时间', def.duration, '秒')
  append_number_line(lines, '攻速加成', def.attack_speed_bonus)
  if def.heal_ratio ~= nil then
    lines[#lines + 1] = string.format('治疗比例：%s', format_percent(def.heal_ratio))
  end
  if def.extra_hp_ratio ~= nil then
    lines[#lines + 1] = string.format('额外生命伤害：%s', format_percent(def.extra_hp_ratio))
  end
  if def.armor_reduction_ratio ~= nil then
    lines[#lines + 1] = string.format('护甲削减比例：%s', format_percent(def.armor_reduction_ratio))
  end
  if def.attack_reduction_ratio ~= nil then
    lines[#lines + 1] = string.format('物攻削减比例：%s', format_percent(def.attack_reduction_ratio))
  end

  local attr_lines = build_attr_lines(def.attr)
  if #attr_lines > 0 then
    lines[#lines + 1] = '临时属性：' .. table.concat(attr_lines, '，')
  end

  return lines
end

function M.create_runtime()
  return {
    mounted_effect_ids = {},
    selected_effect_id = nil,
    logs = {},
    observing_effect_id = nil,
    observe_remaining = 0,
    observe_tick_accum = 0,
  }
end

local STATE = _G.STATE
local message = _G.message
local get_effect_defs = function() return (_G.auto_active_effects_system and _G.auto_active_effects_system.get_effect_defs()) or {} end
local get_effect_runtime_snapshot = function(id) return _G.auto_active_effects_system and _G.auto_active_effects_system.get_effect_runtime_snapshot(id) or {} end
local clear_effect_runtime = function(id) if _G.auto_active_effects_system then _G.auto_active_effects_system.clear_effect_runtime(id) end end
local get_modifier_name_by_key = function(key) return key and y3.buff.get_name_by_key(key) or nil end

  local EFFECT_LIST = get_effect_defs() or {}
  local EFFECT_BY_ID = {}
  for _, def in ipairs(EFFECT_LIST) do
    EFFECT_BY_ID[def.id] = def
  end

  local function get_runtime()
    STATE.effect_debug_runtime = STATE.effect_debug_runtime or M.create_runtime()
    return STATE.effect_debug_runtime
  end

  local function get_effect_def(effect_id)
    return effect_id and EFFECT_BY_ID[effect_id] or nil
  end

  local function get_selected_effect_id()
    local runtime = get_runtime()
    if runtime.selected_effect_id and EFFECT_BY_ID[runtime.selected_effect_id] then
      return runtime.selected_effect_id
    end
    runtime.selected_effect_id = EFFECT_LIST[1] and EFFECT_LIST[1].id or nil
    return runtime.selected_effect_id
  end

  local function push_log(action, effect_id, result, extra)
    local runtime = get_runtime()
    local def = get_effect_def(effect_id)
    local entry = {
      action = action or 'info',
      effect_id = effect_id,
      effect_name = def and def.id or effect_id or 'none',
      result = result or 'ok',
      extra = extra or '',
    }
    runtime.logs[#runtime.logs + 1] = entry
    while #runtime.logs > 24 do
      table.remove(runtime.logs, 1)
    end
    return entry
  end

  local function format_log(entry)
    local parts = {
      string.format('%s | %s | %s', entry.effect_name or 'none', entry.action or 'info', entry.result or 'ok'),
    }
    if entry.extra and entry.extra ~= '' then
      parts[#parts + 1] = entry.extra
    end
    return table.concat(parts, ' | ')
  end

  local function is_effect_mounted(effect_id)
    return get_runtime().mounted_effect_ids[effect_id] == true
  end

  local function select_effect(effect_id)
    if not get_effect_def(effect_id) then
      return false, '未知特效'
    end
    get_runtime().selected_effect_id = effect_id
    return true, effect_id
  end

  local function mount_effect(effect_id)
    local def = get_effect_def(effect_id or get_selected_effect_id())
    if not def then
      return false, '未知特效'
    end
    local runtime = get_runtime()
    runtime.selected_effect_id = def.id
    runtime.mounted_effect_ids[def.id] = true
    push_log('mount', def.id, 'success')
    return true, string.format('已挂载特效：%s', def.id)
  end

  local function unmount_effect(effect_id)
    local def = get_effect_def(effect_id or get_selected_effect_id())
    if not def then
      return false, '未知特效'
    end
    local runtime = get_runtime()
    runtime.mounted_effect_ids[def.id] = nil
    if clear_effect_runtime then
      clear_effect_runtime(def.id)
    end
    push_log('unmount', def.id, 'success')
    return true, string.format('已卸下特效：%s', def.id)
  end

  local function clear_mounted_effects()
    local runtime = get_runtime()
    for effect_id in pairs(runtime.mounted_effect_ids) do
      runtime.mounted_effect_ids[effect_id] = nil
      if clear_effect_runtime then
        clear_effect_runtime(effect_id)
      end
    end
    runtime.observing_effect_id = nil
    runtime.observe_remaining = 0
    runtime.observe_tick_accum = 0
    push_log('clear', nil, 'success', 'all')
    return true, '已清空全部调试挂载特效'
  end

  local function start_observe(effect_id, duration)
    local def = get_effect_def(effect_id or get_selected_effect_id())
    if not def then
      return false, '未知特效'
    end
    local runtime = get_runtime()
    runtime.selected_effect_id = def.id
    runtime.observing_effect_id = def.id
    runtime.observe_remaining = math.max(1, duration or 10)
    runtime.observe_tick_accum = 0
    push_log('observe', def.id, 'start', string.format('duration=%.1f', runtime.observe_remaining))
    return true, string.format('开始观测：%s', def.id)
  end

  local function update(dt)
    local runtime = get_runtime()
    if not runtime.observing_effect_id or runtime.observe_remaining <= 0 then
      return
    end

    runtime.observe_remaining = math.max(0, runtime.observe_remaining - (dt or 0))
    runtime.observe_tick_accum = (runtime.observe_tick_accum or 0) + (dt or 0)

    if runtime.observe_tick_accum >= 0.5 then
      runtime.observe_tick_accum = 0
      local snapshot = get_effect_runtime_snapshot(runtime.observing_effect_id) or {}
      push_log(
        'observe',
        runtime.observing_effect_id,
        snapshot.last_result or 'tick',
        string.format('cd=%.2f counter=%d', snapshot.cooldown or 0, snapshot.counter or 0)
      )
    end

    if runtime.observe_remaining <= 0 then
      push_log('observe', runtime.observing_effect_id, 'end')
      runtime.observing_effect_id = nil
      runtime.observe_tick_accum = 0
    end
  end

  local function get_effect_list_entries()
    local selected_effect_id = get_selected_effect_id()
    local entries = {}
    for _, def in ipairs(EFFECT_LIST) do
      local snapshot = get_effect_runtime_snapshot(def.id) or {}
      entries[#entries + 1] = {
        id = def.id,
        name = get_effect_display_name(def),
        trigger_type = def.trigger_type,
        mounted = is_effect_mounted(def.id),
        selected = selected_effect_id == def.id,
        active = snapshot.active == true,
        cooldown = snapshot.cooldown or 0,
        last_result = snapshot.last_result or 'none',
      }
    end
    return entries
  end

  local function get_selected_effect_model()
    local effect_id = get_selected_effect_id()
    local def = get_effect_def(effect_id)
    if not def then
      return nil
    end
    local snapshot = clone_table(get_effect_runtime_snapshot(effect_id) or {})
    return {
      def = def,
      snapshot = snapshot,
      name = get_effect_display_name(def),
      function_lines = build_effect_function_lines(def),
      mounted = is_effect_mounted(effect_id),
    }
  end

  local function build_selected_detail_lines()
    local model = get_selected_effect_model()
    if not model then
      return { '暂无特效' }
    end

    local def = model.def
    local snapshot = model.snapshot
    local lines = {
      string.format('名称：%s（%s）', model.name or def.id, def.id),
      string.format('来源：%s / %s', tostring(def.source_type), tostring(def.source_id)),
      string.format('触发：%s', tostring(def.trigger_type)),
      string.format('已挂载：%s', bool_label(model.mounted)),
      string.format('可生效：%s', bool_label(snapshot.active == true)),
      string.format('冷却：%.2f', snapshot.cooldown or 0),
      string.format('计数：%d', snapshot.counter or 0),
      string.format('最近结果：%s', snapshot.last_result or 'none'),
    }

    for _, line in ipairs(model.function_lines or {}) do
      lines[#lines + 1] = line
    end

    if snapshot.last_reason and snapshot.last_reason ~= '' then
      lines[#lines + 1] = string.format('失败原因：%s', snapshot.last_reason)
    end

    append_line(lines, string.format('伤害系数：%s', tostring(def.damage_ratio or def.primary_ratio or '-')))
    append_line(lines, string.format('范围：%s', tostring(def.range or def.radius or '-')))
    append_line(lines, string.format('冷却配置：%s', tostring(def.cooldown or '-')))
    append_line(lines, string.format('计数需求：%s', tostring(def.counter_required or '-')))
    local last_modifier_apply = snapshot.last_modifier_apply or {}
    local modifier_key = def.modifier_key or last_modifier_apply.modifier_key
    local modifier_name = modifier_key and get_modifier_name_by_key and get_modifier_name_by_key(modifier_key) or nil
    if modifier_key then
      append_line(lines, string.format('modifier_key：%s / %s', tostring(modifier_key), tostring(modifier_name or '-')))
      append_line(lines, string.format('Buff资源：%s / %s', tostring(modifier_key), tostring(modifier_name or '-')))
    else
      append_line(lines, 'modifier_key：-')
      append_line(lines, 'Buff资源：-')
    end
    if last_modifier_apply.reason and last_modifier_apply.reason ~= '' then
      append_line(lines, string.format(
        '最近挂Buff：%s (%s)',
        bool_label(last_modifier_apply.success == true),
        tostring(last_modifier_apply.reason)
      ))
    else
      append_line(lines, '最近挂Buff：-')
    end

    return lines
  end

  local function get_recent_logs(limit)
    local runtime = get_runtime()
    local result = {}
    local start_index = math.max(1, #runtime.logs - math.max(1, limit or 8) + 1)
    for index = #runtime.logs, start_index, -1 do
      result[#result + 1] = format_log(runtime.logs[index])
    end
    if #result == 0 then
      result[1] = '暂无调试日志'
    end
    return result
  end

  local function print_logs(limit)
    for _, line in ipairs(get_recent_logs(limit or 8)) do
      message('[effect_debug] ' .. line)
    end
  end

  local api = {
    get_runtime = get_runtime,
    get_effect_def = get_effect_def,
    get_selected_effect_id = get_selected_effect_id,
    select_effect = select_effect,
    is_effect_mounted = is_effect_mounted,
    mount_effect = mount_effect,
    unmount_effect = unmount_effect,
    clear_mounted_effects = clear_mounted_effects,
    start_observe = start_observe,
    update = update,
    push_log = push_log,
    get_effect_list_entries = get_effect_list_entries,
    get_selected_effect_model = get_selected_effect_model,
    get_effect_display_name = function(effect_id)
      return get_effect_display_name(get_effect_def(effect_id))
    end,
    build_effect_function_lines = function(effect_id)
      return build_effect_function_lines(get_effect_def(effect_id))
    end,
    build_selected_detail_lines = build_selected_detail_lines,
    get_recent_logs = get_recent_logs,
    print_logs = print_logs,
  }
  _G.effect_debug_system = api

return M

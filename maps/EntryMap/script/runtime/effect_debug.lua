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

function M.create(env)
  local STATE = env.STATE
  local message = env.message
  local get_effect_defs = env.get_effect_defs
  local get_effect_runtime_snapshot = env.get_effect_runtime_snapshot
  local clear_effect_runtime = env.clear_effect_runtime
  local get_modifier_name_by_key = env.get_modifier_name_by_key

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
      entries[#entries + 1] = {
        id = def.id,
        trigger_type = def.trigger_type,
        mounted = is_effect_mounted(def.id),
        selected = selected_effect_id == def.id,
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
      string.format('名称：%s', def.id),
      string.format('来源：%s / %s', tostring(def.source_type), tostring(def.source_id)),
      string.format('触发：%s', tostring(def.trigger_type)),
      string.format('已挂载：%s', bool_label(model.mounted)),
      string.format('可生效：%s', bool_label(snapshot.active == true)),
      string.format('冷却：%.2f', snapshot.cooldown or 0),
      string.format('计数：%d', snapshot.counter or 0),
      string.format('最近结果：%s', snapshot.last_result or 'none'),
    }

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

  return {
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
    build_selected_detail_lines = build_selected_detail_lines,
    get_recent_logs = get_recent_logs,
    print_logs = print_logs,
  }
end

return M

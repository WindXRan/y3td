---@class BuffSystem
--- 纯 Lua Buff 运行时：管理 Buff/Debuff 的施加、移除、计时、DOT 和 UI 图标显示
local M = {}

local STATE = nil
local y3 = nil
local GameAPI = nil
local GameTables = nil
local CustomHealthBars = nil

local function get_unit_key_text(unit)
  if type(unit) == 'table' then
    if type(unit.get_id) == 'function' then
      local ok, id = pcall(unit.get_id, unit)
      if ok and id ~= nil then
        return tostring(id)
      end
    end
    if unit.handle ~= nil then
      return tostring(unit.handle)
    end
  end
  if unit ~= nil then
    return tostring(unit)
  end
  return nil
end

local function is_live_unit(unit)
  return unit and unit.is_exist and unit:is_exist()
end

---@class BuffInstance
---@field template table       buff_templates 中的配置条目
---@field remain_time number   剩余时间（秒），-1=永久
---@field stacks integer      当前层数
---@field cycle_accum number   DOT 周期累加器
---@field source table|nil    施加者 unit

---初始化
---@param env table { STATE, y3, GameTables }
function M.init(env)
  STATE = env.STATE
  y3 = env.y3
  GameAPI = rawget(_G, 'GameAPI')
  GameTables = env.GameTables

  if not STATE.buff_instances then
    STATE.buff_instances = {}
  end
end

---获取单位 Buff 实例表
---@param unit table
---@return table<string, BuffInstance>
local function get_unit_buffs(unit)
  if not unit or not unit.is_exist or not unit:is_exist() then
    return nil
  end
  local key = get_unit_key_text(unit)
  if not key then
    return nil
  end
  STATE.buff_instances[key] = STATE.buff_instances[key] or {}
  return STATE.buff_instances[key]
end

---查找 Buff 模板
---@param template_id string
---@return table|nil
local function find_template(template_id)
  if not GameTables or not GameTables.buff_templates then
    return nil
  end
  return GameTables.buff_templates.by_id[template_id]
end

---应用 Buff 到单位
---@param unit table        目标单位
---@param template_id string Buff 模板 ID（如 "burn", "slow"）
---@param duration number|nil 持续时间（秒），nil 则用模板默认值
---@param stacks integer|nil 初始层数，nil 则用模板默认值
---@param source table|nil 施加者
---@return BuffInstance|nil
function M.apply_buff(unit, template_id, duration, stacks, source)
  print('[buff_system] apply_buff called: unit=' .. tostring(unit and unit.handle) .. ' template=' .. tostring(template_id) .. ' duration=' .. tostring(duration) .. ' stacks=' .. tostring(stacks))
  local template = find_template(template_id)
  if not template then
    print('[buff_system] apply_buff FAIL: template not found for ' .. tostring(template_id))
    return nil
  end

  local unit_buffs = get_unit_buffs(unit)
  if not unit_buffs then
    return nil
  end

  duration = duration or template.duration
  stacks = stacks or 1
  stacks = math.min(stacks, template.max_stacks)

  local existing = unit_buffs[template_id]
  if existing then
    -- 同类型 Buff 已存在：刷新时间，叠加层数
    if duration > 0 then
      existing.remain_time = math.max(existing.remain_time, duration)
    end
    existing.stacks = math.min(existing.stacks + stacks, template.max_stacks)
    existing.source = source or existing.source
    existing.source_key = get_unit_key_text(existing.source)
    existing.target = unit or existing.target
    M.refresh_unit_buff_icons(unit)
    return existing
  end

  local source_key = get_unit_key_text(source)
  local instance = {
    template = template,
    remain_time = (duration > 0) and duration or -1,
    stacks = stacks,
    cycle_accum = 0,
    target = unit,
    source = source,
    source_key = source_key,
  }
  unit_buffs[template_id] = instance

  -- 应用初始属性修改
  M.apply_attr_change(unit, template, instance.stacks)

  -- 刷新图标
  M.refresh_unit_buff_icons(unit)

  return instance
end

---移除 Buff
---@param unit table
---@param template_id string
function M.remove_buff(unit, template_id)
  local unit_buffs = get_unit_buffs(unit)
  if not unit_buffs then
    return
  end

  local instance = unit_buffs[template_id]
  if not instance then
    return
  end

  -- 还原属性修改
  M.remove_attr_change(unit, instance.template, instance.stacks)

  unit_buffs[template_id] = nil

  -- 清理空表
  local empty = true
  for _ in pairs(unit_buffs) do
    empty = false
    break
  end
  if empty then
    local key = get_unit_key_text(unit)
    STATE.buff_instances[key] = nil
  end

  M.refresh_unit_buff_icons(unit)
end

---应用属性修改
---@param unit table
---@param template table
---@param stacks integer
function M.apply_attr_change(unit, template, stacks)
  if not template.attr_name or template.attr_name == '' then
    return
  end
  if template.attr_value == 0 then
    return
  end
  local value = template.attr_value * (stacks or 1)
  local ok, err = pcall(unit.add_attr, unit, template.attr_name, value, '增益')
  if not ok then
    print(string.format('[buff_system] attr apply failed: %s %s=%d | %s',
      template.id, template.attr_name, value, tostring(err)))
  end
end

---还原属性修改
---@param unit table
---@param template table
---@param stacks integer
function M.remove_attr_change(unit, template, stacks)
  if not template.attr_name or template.attr_name == '' then
    return
  end
  if template.attr_value == 0 then
    return
  end
  local value = template.attr_value * (stacks or 1)
  pcall(unit.add_attr, unit, template.attr_name, -value, '增益')
end

---主循环驱动
---@param dt number 帧间隔（秒）
function M.tick(dt)
  if not STATE then
    return
  end
  if not STATE._buff_tick_guard then
    STATE._buff_tick_guard = true
    print('[buff_system] first tick called, STATE.buff_instances=' .. tostring(STATE.buff_instances ~= nil))
  end

  local instances = STATE.buff_instances
  local expired = {}

  for unit_key, unit_buffs in pairs(instances) do
    for template_id, inst in pairs(unit_buffs) do
      -- 更新剩余时间
      if inst.remain_time > 0 then
        inst.remain_time = inst.remain_time - dt
        if inst.remain_time <= 0 then
          expired[#expired + 1] = { unit_key = unit_key, template_id = template_id }
        end
      end

      -- DOT 心跳处理
      local template = inst.template
      if template.effect_category == 'dot' and template.cycle_time > 0 then
        inst.cycle_accum = inst.cycle_accum + dt
        while inst.cycle_accum >= template.cycle_time do
          inst.cycle_accum = inst.cycle_accum - template.cycle_time
          M.tick_dot(unit_key, inst)
        end
      end

      -- 生命恢复心跳处理
      if template.id == 'hp_regen' and template.cycle_time > 0 then
        inst.cycle_accum = inst.cycle_accum + dt
        while inst.cycle_accum >= template.cycle_time do
          inst.cycle_accum = inst.cycle_accum - template.cycle_time
          M.tick_regen(unit_key, inst)
        end
      end
    end
  end

  -- 清理过期 Buff
  for _, item in ipairs(expired) do
    local unit_buffs = instances[item.unit_key]
    if unit_buffs and unit_buffs[item.template_id] then
      local inst = unit_buffs[item.template_id]
      -- 还原属性
      M.remove_attr_change_by_key(item.unit_key, inst)
      unit_buffs[item.template_id] = nil
    end
  end
end

---通过 unit_key 查找 unit（仅活着）
---@param unit_key string
---@return table|nil
local function find_unit_by_key(unit_key)
  if STATE.enemy_info_map then
    for unit_entry, info in pairs(STATE.enemy_info_map) do
      local info_unit = type(info) == 'table' and info.unit or nil
      if get_unit_key_text(info_unit) == unit_key then
        if is_live_unit(info_unit) then
          return info_unit
        end
        return nil
      end

      if get_unit_key_text(unit_entry) == unit_key then
        local unit = info_unit or unit_entry
        if is_live_unit(unit) then
          return unit
        end
        return nil
      end
    end
  end
  if get_unit_key_text(STATE.hero) == unit_key then
    if is_live_unit(STATE.hero) then
      return STATE.hero
    end
    return nil
  end
  return nil
end

local function resolve_instance_unit(unit_key, inst)
  if inst and is_live_unit(inst.target) then
    return inst.target
  end
  return find_unit_by_key(unit_key)
end

---DOT 伤害 tick
---@param unit_key string
---@param inst BuffInstance
function M.tick_dot(unit_key, inst)
  local template = inst.template
  if template.attr_value and template.attr_value ~= 0 then
    local unit = resolve_instance_unit(unit_key, inst)
    if unit and unit.is_exist and unit:is_exist() then
      local damage_per_stack = math.abs(template.attr_value)
      local total_damage = damage_per_stack * inst.stacks
      
      if STATE.hero and STATE.hero:is_exist() and unit == STATE.hero then
        print(string.format('[buff_system] DOT伤害跳过英雄自身: target_key=%s damage=%s',
          tostring(unit_key), tostring(total_damage)))
        return
      end
      
      local source = nil
      if inst.source_key then
        source = find_unit_by_key(inst.source_key)
      end
      if not source then
        source = STATE.hero
      end
      if source and source.is_exist and source:is_exist() and source.damage then
        if template.id == 'burn' then
          inst.dot_debug_count = (inst.dot_debug_count or 0) + 1
          if inst.dot_debug_count <= 3 then
            print(string.format('[buff_system] burn dot tick: target_key=%s damage=%s stacks=%s source_key=%s',
              tostring(unit_key), tostring(total_damage), tostring(inst.stacks), tostring(inst.source_key)))
          end
        end
        local ok, err = pcall(source.damage, source, {
          target = unit,
          damage = total_damage,
          type = '法术',
          source_unit = source,
          text_type = 'magic',
          text_track = 934269508,
          common_attack = false,
          no_miss = true,
        })
        if not ok then
          print(string.format('[buff_system] dot damage failed: %s target_key=%s damage=%s | %s',
            tostring(template.id), tostring(unit_key), tostring(total_damage), tostring(err)))
        end
      else
        print(string.format('[buff_system] dot fallback skipped for hero: %s target_key=%s damage=%s',
          tostring(template.id), tostring(unit_key), tostring(total_damage)))
      end
    elseif template.id == 'burn' then
      inst.dot_debug_count = (inst.dot_debug_count or 0) + 1
      if inst.dot_debug_count <= 3 then
        print('[buff_system] burn dot skip: target not found or dead, target_key=' .. tostring(unit_key))
      end
    end
  end
end

---生命恢复 tick
---@param unit_key string
---@param inst BuffInstance
function M.tick_regen(unit_key, inst)
  local template = inst.template
  if template.attr_value and template.attr_value > 0 then
    local unit = resolve_instance_unit(unit_key, inst)
    if unit and unit.is_exist and unit:is_exist() then
      local heal = template.attr_value * inst.stacks
      pcall(unit.add_hp, unit, heal)
    end
  end
end

---还原过期 Buff 的属性
---@param unit_key string
---@param inst BuffInstance
function M.remove_attr_change_by_key(unit_key, inst)
  local template = inst.template
  if not template.attr_name or template.attr_name == '' then
    return
  end
  if template.attr_value == 0 then
    return
  end
  local unit = resolve_instance_unit(unit_key, inst)
  if unit then
    local value = template.attr_value * inst.stacks
    pcall(unit.add_attr, unit, template.attr_name, -value, '增益')
  end
end

---获取单位所有活跃 Buff 的汇总信息（给 HUD 使用）
---@param unit table
---@return table[] entries
function M.get_unit_buff_entries(unit)
  local entries = {}
  local unit_buffs = get_unit_buffs(unit)
  if not unit_buffs then
    return entries
  end

  for template_id, inst in pairs(unit_buffs) do
    local template = inst.template
    entries[#entries + 1] = {
      id = template.id,
      key = template.modifier_key or 0,
      name = template.name,
      description = template.description,
      buff_type = template.buff_type,
      icon = template.icon_id or 100008,
      stacks = inst.stacks,
      max_stacks = template.max_stacks,
      remain_time = inst.remain_time,
      is_debuff = template.modifier_effect_type == 2,
      attr_name = template.attr_name,
      attr_value = template.attr_value,
    }
  end

  return entries
end

---获取 Buff 图标 ID 列表（用于 UI 显示）
---@param unit table
---@param max_slots integer 最大图标数
---@return integer[] icon_ids
function M.get_unit_buff_icons(unit, max_slots)
  max_slots = max_slots or 5
  local icons = {}
  local entries = M.get_unit_buff_entries(unit)

  -- 优先显示 debuff
  table.sort(entries, function(a, b)
    if a.is_debuff ~= b.is_debuff then
      return a.is_debuff
    end
    return a.remain_time > b.remain_time
  end)

  for i = 1, math.min(#entries, max_slots) do
    icons[#icons + 1] = entries[i].icon
  end

  return icons
end

---刷新单个单位的血条 Buff 图标
---@param unit table
function M.refresh_unit_buff_icons(unit)
  if not unit or not unit.is_exist or not unit:is_exist() then
    return
  end
  if not GameAPI then
    return
  end

  local entries = M.get_unit_buff_entries(unit)
  local max_show = math.min(#entries, 5)

  -- 尝试用 billboard picture 节点显示图标（需要血条模板有 buff_icon_1~5 节点）
  for i = 1, 5 do
    local node_name = 'buff_icon_' .. tostring(i)
    if i <= max_show then
      local icon_id = entries[i].icon or 100008
      pcall(GameAPI.set_billboard_picture, unit.handle, node_name, icon_id, nil)
    else
      pcall(GameAPI.set_billboard_picture, unit.handle, node_name, 0, nil)
    end
  end
end

---移除单位所有 Buff
---@param unit table
function M.clear_unit_buffs(unit)
  local unit_buffs = get_unit_buffs(unit)
  if not unit_buffs then
    return
  end

  for template_id, inst in pairs(unit_buffs) do
    M.remove_attr_change(unit, inst.template, inst.stacks)
  end

  local key = get_unit_key_text(unit)
  STATE.buff_instances[key] = nil
  M.refresh_unit_buff_icons(unit)
end

---检查单位是否有指定 Buff
---@param unit table
---@param template_id string
---@return boolean
function M.unit_has_buff(unit, template_id)
  local unit_buffs = get_unit_buffs(unit)
  if not unit_buffs then
    return false
  end
  return unit_buffs[template_id] ~= nil
end

---获取 Buff 剩余时间
---@param unit table
---@param template_id string
---@return number|nil
function M.get_buff_remain_time(unit, template_id)
  local unit_buffs = get_unit_buffs(unit)
  if not unit_buffs then
    return nil
  end
  local inst = unit_buffs[template_id]
  if not inst then
    return nil
  end
  return inst.remain_time
end

return M

local BattleSystem = {}

local battlefield = require 'runtime.combat.battlefield.init'

BattleSystem.battlefield = battlefield

BattleSystem.update = battlefield.update
BattleSystem.force_spawn_boss = battlefield.force_spawn_boss
BattleSystem.execute_enemy = battlefield.execute_enemy
BattleSystem.get_current_wave = battlefield.get_current_wave
BattleSystem.get_boss_name = battlefield.get_boss_name
BattleSystem.spawn_enemy = battlefield.spawn_enemy
BattleSystem.create_hero = battlefield.create_hero
BattleSystem.is_active_enemy = battlefield.is_active_enemy
BattleSystem.get_enemy_runtime_info = battlefield.get_enemy_runtime_info
BattleSystem.is_boss_runtime_enemy = battlefield.is_boss_runtime_enemy
BattleSystem.is_elite_runtime_enemy = battlefield.is_elite_runtime_enemy

local CONFIG = require 'config.entry_config'
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers

local STATE = _G.STATE
local message = _G.message or print
local is_battle_active = function() return _G.STATE.session_phase == 'battle' end
local get_enemy_player = BootHelpers.get_enemy_player
local has_unit_data = function(unit_id) local bfs = _G.battlefield_system; return bfs and bfs.has_unit_data and bfs.has_unit_data(unit_id) or false end

local function ensure_auto_acceptance_runtime()
  STATE.battle_auto_acceptance = STATE.battle_auto_acceptance or {
    phase_started = false,
    spawned = false,
    dummy_unit_id = nil,
    units = {},
    unit_slots = {},
    target_hp = 9999999999,
    spawn_count = 10,
    spawn_radius = 520,
    spawn_front_distance = 760,
    spawn_row_spacing = 170,
  }
  return STATE.battle_auto_acceptance
end

local function is_n0_stage_active()
  return false
end

local function pick_dummy_unit_id()
  local candidates = {}
  if CONFIG and CONFIG.unit_ids then
    for _, unit_id in pairs(CONFIG.unit_ids.main_monsters or {}) do
      candidates[#candidates + 1] = unit_id
    end
    for _, unit_id in pairs(CONFIG.unit_ids.bosses or {}) do
      candidates[#candidates + 1] = unit_id
    end
  end
  for _, unit_id in ipairs(candidates) do
    local id = tonumber(unit_id)
    if id and id > 0 and (not has_unit_data or has_unit_data(id)) then
      return id
    end
  end
  return nil
end

local function clear_runtime_units(runtime)
  for _, unit in ipairs(runtime.units or {}) do
    if STATE.all_enemies and STATE.all_enemies.remove_unit then
      pcall(function() STATE.all_enemies:remove_unit(unit) end)
    end
    if unit and unit.is_exist and unit:is_exist() then
      pcall(function() unit:remove() end)
    end
  end
  runtime.units = {}
  runtime.unit_slots = {}
  runtime.spawned = false
end

local function spawn_dummy_targets(runtime)
  local y3 = _G.y3
  local enemy_player = get_enemy_player and get_enemy_player()
  if not enemy_player or not y3 or not y3.unit or not y3.unit.create_unit then
    return false
  end
  local unit_id = runtime.dummy_unit_id or pick_dummy_unit_id()
  if not unit_id then
    message('[auto_acceptance] 未找到可用靶子单位ID，跳过靶子生成。')
    return false
  end
  runtime.dummy_unit_id = unit_id

  local center = STATE.defense_point or (STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and STATE.hero.get_point and STATE.hero:get_point())
  if not center then return false end

  clear_runtime_units(runtime)
  local count = math.max(1, tonumber(runtime.spawn_count) or 10)
  local front_distance = math.max(320, tonumber(runtime.spawn_front_distance) or tonumber(runtime.spawn_radius) or 760)
  local row_spacing = math.max(80, tonumber(runtime.spawn_row_spacing) or 170)
  local forward, side = 0, math.pi * 0.5
  local cx, cy, cz = center.get_x and center:get_x() or 0, center.get_y and center:get_y() or 0, center.get_z and center:get_z() or 0
  local front_x, front_y = cx + math.cos(forward) * front_distance, cy + math.sin(forward) * front_distance

  for i = 1, count do
    local lateral = (i - (count + 1) * 0.5) * row_spacing
    local x, y = front_x + math.cos(side) * lateral, front_y + math.sin(side) * lateral
    local ok, unit = pcall(y3.unit.create_unit, enemy_player, unit_id, y3.point.create(x, y, cz), 180)
    if ok and unit and unit.is_exist and unit:is_exist() then
      pcall(function()
        unit:set_name('验收靶子')
        unit:set_attr('生命', runtime.target_hp)
        unit:set_attr('hp_max', runtime.target_hp)
        unit:set_hp(runtime.target_hp)
      end)
      if STATE.all_enemies and STATE.all_enemies.add_unit then
        pcall(function() STATE.all_enemies:add_unit(unit) end)
      end
      runtime.units[#runtime.units + 1] = unit
      runtime.unit_slots[#runtime.units] = { x = x, y = y, z = cz or 0 }
    end
  end
  runtime.spawned = #runtime.units > 0
  if runtime.spawned then
    message(string.format('[auto_acceptance] N0靶子已生成：count=%d unit_id=%s', #runtime.units, tostring(unit_id)))
  end
  return runtime.spawned
end

local function is_dummy_unit(runtime, unit)
  for _, dummy in ipairs(runtime.units or {}) do
    if dummy == unit then return true end
  end
  return false
end

local function purge_non_dummy_enemies(runtime)
  if not STATE or not STATE.all_enemies or not STATE.all_enemies.pick then return end
  for _, unit in ipairs(STATE.all_enemies:pick() or {}) do
    if unit and unit.is_exist and unit:is_exist() and not is_dummy_unit(runtime, unit) then
      pcall(function()
        if unit.set_hp then unit:set_hp(0)
        elseif unit.kill then unit:kill()
        elseif unit.remove then unit:remove()
        end
      end)
    end
  end
end

local function sustain_dummy_targets(runtime)
  local y3 = _G.y3
  for index = #runtime.units, 1, -1 do
    local unit = runtime.units[index]
    if not unit or not unit.is_exist or not unit:is_exist() then
      table.remove(runtime.units, index)
      table.remove(runtime.unit_slots, index)
    else
      pcall(function()
        unit:set_attr('生命', runtime.target_hp)
        unit:set_attr('hp_max', runtime.target_hp)
        unit:set_hp(runtime.target_hp)
        local slot = runtime.unit_slots and runtime.unit_slots[index]
        if slot and y3 and y3.point and y3.point.create and unit.set_point then
          unit:set_point(y3.point.create(slot.x, slot.y, slot.z or 0))
        end
        if unit.stop then unit:stop() end
      end)
    end
  end
end

local function update_auto_acceptance(dt)
  local runtime = ensure_auto_acceptance_runtime()

  if not is_battle_active() or not is_n0_stage_active() then
    if runtime.phase_started then
      clear_runtime_units(runtime)
      runtime.phase_started = false
    end
    return
  end

  if not runtime.phase_started then
    runtime.phase_started = true
    spawn_dummy_targets(runtime)
    message('[auto_acceptance] N0验收靶场已激活')
  end

  if not runtime.spawned then spawn_dummy_targets(runtime) end
  purge_non_dummy_enemies(runtime)
  sustain_dummy_targets(runtime)
end

local auto_acceptance_api = {
  update = update_auto_acceptance,
  spawn_dummy_targets = function()
    local runtime = ensure_auto_acceptance_runtime()
    runtime.dummy_unit_id = runtime.dummy_unit_id or pick_dummy_unit_id()
    return spawn_dummy_targets(runtime)
  end,
  clear_dummy_targets = function()
    clear_runtime_units(ensure_auto_acceptance_runtime())
  end,
}
BattleSystem.auto_acceptance = auto_acceptance_api
_G.battle_auto_acceptance_system = auto_acceptance_api
_G.SYSTEM = _G.SYSTEM or {}
_G.SYSTEM.battle_auto_acceptance = auto_acceptance_api



local function contains_any(content, patterns)
  for _, pattern in ipairs(patterns or {}) do
    if string.find(content, pattern, 1, true) then
      return true
    end
  end
  return false
end

local function is_debug_or_empty(text)
  local content = tostring(text or '')
  if content == ''
    or string.find(content, '[DEBUG]', 1, true) then
    return true
  end
  return false
end

local function infer_board_spec(text, style)
  if is_debug_or_empty(text) then
    return nil
  end
  local content = tostring(text or '')

  if contains_any(content, {
    '游戏胜利',
    '游戏失败',
  }) then
    return {
      priority = 220,
      duration = 4.8,
    }
  end

  if contains_any(content, {
    '结算：',
    ' 登场。',
    ' 被击败，立即切换到 ',
  }) then
    return {
      priority = 180,
      duration = 3.8,
    }
  end

  if contains_any(content, {
    ' 开始，持续 ',
    ' 失败。',
    '升级至',
    '2选1',
    '2 选 1',
    '3选1',
    '3 选 1',
    '按 1 / 2 选择',
    '按 1 / 2 / 3 选择',
    '获得一次',
    '英雄选择',
    '奖励已发放。',
    '已选择强化',
    '技能更新：',
    '已开启战术卡流派：',
    '已解锁战术卡：',
    ' 已完成。',
  }) then
    return {
      priority = 130,
      duration = 3.0,
    }
  end

  if style == 'warning' and contains_any(content, {
    '不足',
    '警告',
    '创建失败',
    '刷怪失败',
  }) then
    return {
      priority = 100,
      duration = 2.4,
    }
  end

  return nil
end

local function infer_marquee_spec(text)
  if is_debug_or_empty(text) then
    return nil
  end
  local content = tostring(text or '')

  if contains_any(content, {
    '游戏胜利',
    '游戏失败',
  }) then
    return {
      priority = 320,
      duration = 6.6,
    }
  end

  if contains_any(content, {
    ' 登场。',
    ' 被击败，立即切换到 ',
  }) then
    return {
      priority = 260,
      duration = 5.4,
    }
  end

  if contains_any(content, {
    '奖励已发放。',
  }) then
    return {
      priority = 220,
      duration = 4.8,
    }
  end

  return nil
end

local function route_battle_event(text, style)
  local prompt_system = _G.get_message_prompt_system and _G.get_message_prompt_system() or nil
  local content = tostring(text or '')
  if string.find(content, '金币不足', 1, true) then
    local hud = _G.get_hud_system and _G.get_hud_system() or nil
    if hud and hud.show_insufficient_gold_tip then
      hud.show_insufficient_gold_tip()
    end
  end
  if not prompt_system then
    return
  end

  local board = infer_board_spec(text, style)
  if board and prompt_system.push_board then
    prompt_system.push_board(text, board.priority, {
      duration = board.duration,
    })
  end

  local marquee = infer_marquee_spec(text)
  if marquee and prompt_system.push_marquee then
    prompt_system.push_marquee(text, marquee.priority, {
      duration = marquee.duration,
    })
  end
end

local function push_battle_event(text, style, duration)
  local final_style = style or (_G.infer_battle_event_style and _G.infer_battle_event_style(text))
  local prompt_system = _G.get_message_prompt_system and _G.get_message_prompt_system() or nil
  if prompt_system and prompt_system.push_list then
    prompt_system.push_list(text, nil, {
      style = final_style,
      duration = duration,
    })
  end
  if STATE.session_phase ~= 'battle' then
    return nil
  end
  route_battle_event(text, final_style)
  if not STATE.battle_event_feed then
    STATE.battle_event_feed = (_G.create_battle_event_feed_runtime and _G.create_battle_event_feed_runtime()) or {}
  end
  return (_G.BattleEventFeedSystem and _G.BattleEventFeedSystem.push_event(STATE.battle_event_feed, text, {
    now = STATE.runtime_elapsed or 0,
    style = final_style,
    duration = duration,
  })) or nil
end

local event_prompts_api = {
  push_battle_event = push_battle_event,
}
BattleSystem.event_prompts = event_prompts_api

return BattleSystem
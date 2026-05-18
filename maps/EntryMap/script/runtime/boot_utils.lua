-- boot_utils.lua — 运行时工具函数集合
-- 工具函数直接注册到 _G，简化调用

-- 核心模块导出
_G.BondSystem = require 'runtime.bonds_chain'
_G.BootCombat = require 'runtime.boot_combat'
_G.AudioResources = require 'data.tables.audio_resources'

-- 区域相关工具
local AreaUtils = {}

AreaUtils.get_area = function(area_id)
  local debug_tools_system = _G.debug_tools_system
  if debug_tools_system and debug_tools_system.get_area then
    local area = debug_tools_system.get_area(area_id)
    if area then
      return area
    end
  end
  return _G.CONFIG and _G.CONFIG.areas and _G.CONFIG.areas[area_id]
end

AreaUtils.random_point_in_area = function(area_id)
  local area = AreaUtils.get_area(area_id)
  if not area then
    return _G.STATE.defense_point
  end
  local x = math.random(area.x_min, area.x_max)
  local y = math.random(area.y_min, area.y_max)
  return y3.point.create(x, y, area.z or 0)
end

_G.AreaUtils = AreaUtils

-- 属性相关工具
local AttrUtils = {}

AttrUtils.set_attr_pack = function(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end
  for attr_name, value in pairs(attr_pack) do
    if value ~= nil then
      unit:set_attr(attr_name, value)
    end
  end
end

AttrUtils.get_attr_pack = function(unit, attr_names)
  if not unit or not attr_names then
    return {}
  end
  local pack = {}
  for _, name in ipairs(attr_names) do
    pack[name] = unit:get_attr(name)
  end
  return pack
end

_G.AttrUtils = AttrUtils

-- 物品相关工具
local ItemUtils = {}

ItemUtils.can_afford_item = function(item_id, count)
  local STATE = _G.STATE
  if not STATE or not STATE.inventory then
    return false
  end
  local owned = STATE.inventory:get_item_count(item_id) or 0
  return owned >= (count or 1)
end

ItemUtils.consume_item = function(item_id, count)
  local STATE = _G.STATE
  if not STATE or not STATE.inventory then
    return false
  end
  if not ItemUtils.can_afford_item(item_id, count) then
    return false
  end
  return STATE.inventory:consume_item(item_id, count or 1)
end

_G.ItemUtils = ItemUtils

-- 玩家相关工具
local PlayerUtils = {}

PlayerUtils.get_player = function()
  if _G.STATE and _G.STATE.player then
    return _G.STATE.player
  end
  if y3 and y3.player and y3.player.get_main_player then
    return y3.player.get_main_player()
  end
  return nil
end

PlayerUtils.get_player_name = function()
  local player = PlayerUtils.get_player()
  if player and player.get_name then
    return player:get_name()
  end
  return 'Player'
end

_G.PlayerUtils = PlayerUtils
_G.get_player = PlayerUtils.get_player

-- 战斗相关工具
_G.get_skill_damage_modifier = function()
  local STATE = _G.STATE
  if not STATE then
    return 1.0
  end
  local bonus = 0
  local buff_runtime = STATE.buff_runtime
  if buff_runtime and buff_runtime.get_total_bonus then
    bonus = buff_runtime.get_total_bonus('skill_damage') or 0
  end
  local weapon_bonus = STATE.equipment and STATE.equipment.weapon_damage_bonus or 0
  return 1.0 + bonus + weapon_bonus
end

_G.get_hero_attack_damage = function()
  local hero = _G.STATE and _G.STATE.hero
  if not hero then
    return 0
  end
  local base = hero:get_attr('attack_damage') or 0
  local modifier = _G.get_skill_damage_modifier()
  return base * modifier
end

-- 消息输出
local BattleEventPrompts = require 'runtime.battle_event_prompts'
local BootHelpers = require 'runtime.boot_helpers'
local GearUpgrades = require 'runtime.gear_upgrades'
local battle_event_prompts_instance

_G.message = function(text)
  if log and log.info then
    log.info('[entry_runtime] ' .. tostring(text))
  end
  local STATE = _G.STATE
  if STATE and STATE.session_phase == 'battle' then
    if not battle_event_prompts_instance then
      battle_event_prompts_instance = BattleEventPrompts.create({
        STATE = STATE,
        BattleEventFeedSystem = require 'runtime.battle_event_feed',
        create_battle_event_feed_runtime = function()
          return require 'runtime.battle_event_feed'.create_runtime()
        end,
        infer_battle_event_style = BootHelpers.infer_battle_event_style,
        GearUpgrades = GearUpgrades,
        CONFIG = _G.CONFIG,
        get_message_prompt_system = function()
          return STATE.message_prompt_system
        end,
        get_audio_system = function()
          return _G.audio_system
        end,
        get_hud_system = function()
          return _G.hud_system
        end,
        get_inventory_panel_system = function()
          return STATE.inventory_panel_system
        end,
        message = _G.message,
        ensure_round_choice_available = _G.ensure_round_choice_available,
        sync_gear_runtime_effects = _G.sync_gear_runtime_effects,
      })
    end
    battle_event_prompts_instance.push_battle_event(text)
    return
  end
  local player = _G.get_player()
  if player and player.display_message then
    player:display_message(text)
  end
end

-- 治疗英雄
_G.heal_hero = function(amount)
  if amount <= 0 then return end
  local STATE = _G.STATE
  if not STATE or not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then return end
  local before = STATE.hero:get_hp()
  STATE.hero:add_hp(amount)
  if STATE.hero:get_hp() > before then
    _G.message(string.format('急救生效，英雄生命恢复至 %.0f。', STATE.hero:get_hp()))
  end
end

-- 创建羁绊环境
_G.create_bond_env = function()
  return {
    STATE = _G.STATE,
    message = _G.message,
    round_number = _G.round_number,
    y3 = y3,
    hero_attr_system = _G.hero_attr_system,
    heal_hero = _G.heal_hero,
    sync_basic_attack_ability = _G.sync_basic_attack_ability,
    is_active_enemy = _G.is_active_enemy,
    get_enemy_runtime_info = _G.get_enemy_runtime_info,
    is_boss_runtime_enemy = _G.is_boss_runtime_enemy,
    is_elite_runtime_enemy = _G.is_elite_runtime_enemy,
    get_enemies_in_range = _G.get_enemies_in_range,
    deal_skill_damage = _G.deal_skill_damage,
    emit_damage_debug = function(visual)
      _G.emit_damage_debug_visual(visual, nil)
    end,
    reserve_formula_damage = _G.BootCombat and _G.BootCombat.reserve_formula_damage,
    basic_attack_damage_type = _G.ATTACK_SKILL_DEFS and _G.ATTACK_SKILL_DEFS.basic_attack.damage_type,
    get_player = _G.get_player,
  }
end

-- 处理战斗结束
_G.handle_battle_finished = function(result)
  local audio_system = _G.audio_system
  if audio_system and audio_system.handle_battle_finished then
    audio_system.handle_battle_finished(result)
  end
  local battlefield_system = _G.battlefield_system
  if battlefield_system and battlefield_system.cleanup_battle_units then
    battlefield_system.cleanup_battle_units()
  end
  if _G.set_battle_hud_visible then
    _G.set_battle_hud_visible(false)
  end

  local result_panel_system = _G.result_panel_system
  local outgame_system = _G.outgame_system

  local function finish_outgame_transition()
    local reset_func = _G.RuntimeEntry and _G.RuntimeEntry._session_bundle
        and _G.RuntimeEntry._session_bundle.reset_battle_state
    if reset_func then
      reset_func()
    end
    local STATE = _G.STATE
    if STATE then
      STATE.session_phase = 'outgame'
      STATE.game_finished = true
      STATE.last_battle_result = result
    end
    if _G.enforce_runtime_ui_phase then
      _G.enforce_runtime_ui_phase(false)
    end
    if outgame_system and outgame_system.enter_outgame then
      outgame_system.enter_outgame(result)
    end
    if result_panel_system and result_panel_system.hide then
      result_panel_system.hide()
    end
  end

  if result_panel_system and result_panel_system.show then
    local STATE = _G.STATE
    local gold = STATE and STATE.resources and STATE.resources.gold or 0
    local hp = STATE and STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and STATE.hero:get_hp() or 0
    result_panel_system.show({
      is_win = result.is_win,
      reached_wave_index = result.reached_wave_index,
      gold = gold,
      hp = hp,
    }, finish_outgame_transition)
  else
    finish_outgame_transition()
  end
end

-- 区域伤害计算
_G.get_enemies_in_range = function(center, radius, except_unit, max_count)
  local result = {}
  local selector = y3.selector.create()
      :is_enemy(_G.get_player())
      :in_range(center, radius)
      :sort_type('由近到远')

  if max_count and max_count > 0 then
    selector:count(max_count + (except_unit and 1 or 0))
  end

  local picked = selector:pick()

  for _, unit in ipairs(picked) do
    if unit ~= except_unit and unit ~= _G.STATE.hero and _G.is_active_enemy(unit) then
      result[#result + 1] = unit
    end
  end

  return result
end

-- 链状伤害目标
_G.get_chain_targets = function(initial_target, radius, max_bounce)
  if not initial_target then
    return {}
  end
  local targets = {initial_target}
  local visited = {[initial_target] = true}
  local bounce = 0
  local max_bounce = max_bounce or 3

  while bounce < max_bounce and #targets > 0 do
    local current = targets[#targets]
    local nearby = _G.get_enemies_in_range(current:get_point(), radius, current, 1)
    if #nearby > 0 and not visited[nearby[1]] then
      visited[nearby[1]] = true
      targets[#targets + 1] = nearby[1]
      bounce = bounce + 1
    else
      break
    end
  end

  return targets
end

-- 投射物创建辅助
_G.create_projectile = function(params)
  if not y3 or not y3.projectile then
    return nil
  end
  local ok, proj = pcall(y3.projectile.create, params)
  if ok and proj then
    return proj
  end
  return nil
end

-- 粒子效果创建
_G.create_particle = function(target, particle_id, scale, duration, height)
  if not y3 or not y3.particle then
    return nil
  end
  local ok, particle = pcall(y3.particle.create, target, particle_id, {
    scale = scale or 1.0,
    duration = duration or 1.0,
    height = height or 0,
  })
  if ok and particle then
    return particle
  end
  return nil
end

-- 音效播放
_G.play_sound = function(sound_id, position, volume)
  if not y3 or not y3.sound then
    return nil
  end
  local player = _G.get_player()
  if not player then
    return nil
  end
  local ok, sound = pcall(y3.sound.play_3d, player, sound_id, position, {
    ensure = true,
    height = 0,
    volume = volume or 100,
  })
  if ok and sound then
    return sound
  end
  return nil
end

-- 相机控制
_G.apply_fixed_camera_mode = function(enabled)
  local player = _G.get_player()
  if not player or not y3.camera then
    return false
  end

  if enabled == true then
    local STATE = _G.STATE
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
      return false
    end
    if y3.camera.set_tps_follow_unit then
      y3.camera.set_tps_follow_unit(player, STATE.hero, 0, 0, -60, 300, 0, 220, 1800)
    elseif y3.camera.set_camera_follow_unit then
      y3.camera.set_camera_follow_unit(player, STATE.hero, 0, 0, 220)
    end
    if y3.camera.disable_camera_move then
      y3.camera.disable_camera_move(player)
    end
    if y3.camera.set_moving_with_mouse then
      y3.camera.set_moving_with_mouse(player, false)
    end
    if y3.camera.set_mouse_move_camera_speed then
      y3.camera.set_mouse_move_camera_speed(player, 0)
    end
    if y3.camera.set_keyboard_move_camera_speed then
      y3.camera.set_keyboard_move_camera_speed(player, 0)
    end
    if y3.camera.set_max_distance then
      y3.camera.set_max_distance(player, 1800)
    end
    if y3.camera.set_distance then
      y3.camera.set_distance(player, 1800, 0)
    end
    if player.set_mouse_wheel then
      player:set_mouse_wheel(false)
    end
    return true
  end

  if y3.camera.cancel_tps_follow_unit then
    y3.camera.cancel_tps_follow_unit(player)
  end
  if y3.camera.cancel_camera_follow_unit then
    y3.camera.cancel_camera_follow_unit(player)
  end
  if y3.camera.enable_camera_move then
    y3.camera.enable_camera_move(player)
  end
  if y3.camera.set_moving_with_mouse then
    y3.camera.set_moving_with_mouse(player, true)
  end
  if player.set_mouse_wheel then
    player:set_mouse_wheel(true)
  end
  return true
end

_G.sync_fixed_camera_mode = function(enabled)
  local player = _G.get_player()
  if not player or not y3 or not y3.camera then
    return
  end
  local is_fixed = false
  if y3.camera.is_tps_follow then
    is_fixed = y3.camera.is_tps_follow(player)
  elseif y3.camera.is_camera_follow then
    is_fixed = y3.camera.is_camera_follow(player)
  end
  if is_fixed ~= (enabled == true) then
    _G.apply_fixed_camera_mode(enabled)
  end
end

_G.toggle_fixed_camera = function()
  local player = _G.get_player()
  if not player or not y3 or not y3.camera then
    return false
  end
  local is_fixed = false
  if y3.camera.is_tps_follow then
    is_fixed = y3.camera.is_tps_follow(player)
  elseif y3.camera.is_camera_follow then
    is_fixed = y3.camera.is_camera_follow(player)
  end
  return _G.apply_fixed_camera_mode(not is_fixed)
end

-- UI 阶段控制
local function set_ui_root_visible(path, visible)
  local player = _G.get_player()
  if not player or not y3 or not y3.ui or not y3.ui.get_ui then
    return false
  end
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui or (ui.is_removed and ui:is_removed()) then
    return false
  end
  if ui.set_visible then
    ui:set_visible(visible == true)
    return true
  end
  return false
end

_G.enforce_runtime_ui_phase = function(is_battle)
  if is_battle == true then
    local hidden_in_battle = {
      'outgame',
      'ArchivePanel',
      'ArchivePageProfile',
      'ArchivePageEquipment',
      'ArchivePageUniversal',
      'ArchivePageChest',
      'ArchivePagePool',
      'LoadingPanel',
      'LogoPanel',
      'win',
      'loss',
      'CommonTip',
      'SceneUI',
    }
    for _, path in ipairs(hidden_in_battle) do
      set_ui_root_visible(path, false)
    end
    return
  end

  local visible_in_outgame = {
    'outgame',
    'ArchivePanel',
  }
  for _, path in ipairs(visible_in_outgame) do
    set_ui_root_visible(path, true)
  end
end

-- BootHelpers 模块（原 boot_helpers.lua）
local CONFIG = require 'config.entry_config'
local HeroEvolutionObjects = require 'data.tables.outgame.hero_evolutions'

local BootHelpers = {}

function BootHelpers.safe_get_unit_icon(unit_key)
  if not unit_key or not y3 or not y3.unit or not y3.unit.get_icon_by_key then
    return nil
  end
  local ok, icon = pcall(y3.unit.get_icon_by_key, unit_key)
  if ok then
    return icon
  end
  return nil
end

function BootHelpers.safe_get_buff_icon(buff_key)
  if not buff_key or not y3 or not y3.buff or not y3.buff.get_icon_by_key then
    return nil
  end
  local ok, icon = pcall(y3.buff.get_icon_by_key, buff_key)
  if ok then
    return icon
  end
  return nil
end

function BootHelpers.safe_get_buff_name(buff_key)
  if not buff_key or not y3 or not y3.buff or not y3.buff.get_name_by_key then
    return nil
  end
  local ok, name = pcall(y3.buff.get_name_by_key, buff_key)
  if ok then
    return name
  end
  return nil
end

function BootHelpers.has_valid_icon(icon)
  if icon == nil then
    return false
  end
  local n = tonumber(icon)
  if n ~= nil then
    return n ~= 0
  end
  return true
end

function BootHelpers.build_bottom_status_effect_entry(effect_def, snapshot)
  if not effect_def or not snapshot or snapshot.active ~= true then
    return nil
  end

  local icon
  local title
  local lines = {}

  if effect_def.source_type == 'mark' then
    local evolution_def = HeroEvolutionObjects.by_id and HeroEvolutionObjects.by_id[effect_def.source_id] or nil
    icon = evolution_def and BootHelpers.safe_get_unit_icon(evolution_def.hero_unit_id) or nil
    title = evolution_def and evolution_def.name or nil
    if evolution_def and evolution_def.summary and evolution_def.summary ~= '' then
      lines[#lines + 1] = tostring(evolution_def.summary)
    end
  end

  if not icon then
    icon = BootHelpers.safe_get_buff_icon(effect_def.modifier_key)
  end
  if not title or title == '' then
    title = BootHelpers.safe_get_buff_name(effect_def.modifier_key) or effect_def.id or '魔法效果'
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

function BootHelpers.build_hero_buff_status_entries(limit, STATE, taken_modifier_keys)
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
        local icon = BootHelpers.safe_get_buff_icon(modifier_key)
        if icon_visible and BootHelpers.has_valid_icon(icon) then
          local group = grouped[modifier_key]
          if not group then
            local title = (buff.get_name and buff:get_name()) or ''
            if title == '' then
              title = BootHelpers.safe_get_buff_name(modifier_key) or tostring(modifier_key)
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

function BootHelpers.get_bottom_status_effect_entries(max_slots, STATE, auto_active_effects_system)
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
    for _, entry in ipairs(BootHelpers.build_hero_buff_status_entries(limit - #entries, STATE, taken_modifier_keys)) do
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
      push_entry(BootHelpers.build_bottom_status_effect_entry(effect_def, snapshot))
    end
  end

  return entries
end

function BootHelpers.resolve_damage_meta(damage)
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

function BootHelpers.make_point(data)
  return y3.point.create(data.x, data.y, data.z or 0)
end

function BootHelpers.round_number(value)
  return math.floor((value or 0) + 0.5)
end

function BootHelpers.design_seconds(seconds)
  if CONFIG.debug_time_scale <= 0 then
    return seconds
  end
  return seconds / CONFIG.debug_time_scale
end

function BootHelpers.get_player()
  return y3.player(CONFIG.player_id)
end

function BootHelpers.get_enemy_player()
  return y3.player(CONFIG.enemy_player_id)
end

function BootHelpers.trace_boot(message)
  if log and log.info then
    log.info('[entry_runtime] ' .. tostring(message))
  end
end

function BootHelpers.infer_battle_event_style(text)
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

function BootHelpers.update_passive_resources(dt, STATE, resource_system)
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

local _get_bond_runtime_bonus = nil

function BootHelpers.set_get_bond_runtime_bonus(fn)
  _get_bond_runtime_bonus = fn
end

function BootHelpers.get_bond_runtime_bonus(key)
  if _get_bond_runtime_bonus then
    return _get_bond_runtime_bonus(key)
  end
  return 0
end

_G.BootHelpers = BootHelpers

-- 注册全局函数
_G.make_point = BootHelpers.make_point
_G.round_number = BootHelpers.round_number
_G.design_seconds = BootHelpers.design_seconds
_G.get_enemy_player = BootHelpers.get_enemy_player
_G.infer_battle_event_style = BootHelpers.infer_battle_event_style
_G.update_passive_resources = function(dt)
  local STATE = _G.STATE
  if not STATE or not _G.resource_system then return end
  BootHelpers.update_passive_resources(dt, STATE, _G.resource_system)
end


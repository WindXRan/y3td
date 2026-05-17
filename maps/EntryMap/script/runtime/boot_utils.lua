-- boot_utils.lua — 运行时工具函数集，全部直接挂 _G
-- 自初始化模块，require 时设置所有 _G.xxx
-- 各函数仅在调用时读取 _G，不依赖模块加载顺序

_G.get_area = function(area_id)
  local debug_tools_system = _G.debug_tools_system
  if debug_tools_system and debug_tools_system.get_area then
    local area = debug_tools_system.get_area(area_id)
    if area then
      return area
    end
  end
  return _G.CONFIG and _G.CONFIG.areas and _G.CONFIG.areas[area_id]
end

_G.random_point_in_area = function(area_id)
  local area = _G.get_area(area_id)
  if not area then
    return _G.STATE.defense_point
  end
  local x = math.random(area.x_min, area.x_max)
  local y = math.random(area.y_min, area.y_max)
  return y3.point.create(x, y, area.z or 0)
end

_G.set_attr_pack = function(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end
  for attr_name, value in pairs(attr_pack) do
    if value ~= nil then
      unit:set_attr(attr_name, value)
    end
  end
end

_G.add_attr_pack = function(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end
  for attr_name, value in pairs(attr_pack) do
    if value ~= nil and value ~= 0 then
      unit:add_attr(attr_name, value)
    end
  end
end

_G.snapshot_hero_attrs = function()
  local STATE = _G.STATE
  if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
    return nil
  end
  return _G.hero_attr_system.snapshot(STATE.hero, STATE)
end

_G.build_runtime_attr_dialog_chunks = function()
  local snapshot = _G.snapshot_hero_attrs()
  if snapshot and _G.hero_attr_system and _G.hero_attr_system.log_snapshot then
    _G.hero_attr_system.log_snapshot(_G.STATE.hero, 'show_runtime_attr_dialog', nil, _G.STATE)
  end
  return {}
end

_G.show_runtime_attr_dialog = function()
  local STATE = _G.STATE
  local attr_tips_panel = STATE.attr_tips_panel
  if attr_tips_panel and attr_tips_panel.toggle then
    local visible = attr_tips_panel.toggle()
    if visible ~= nil then
      return visible
    end
  end
  local hud = _G.hud_system
  if hud and hud.toggle_attr_panel then
    local visible = hud.toggle_attr_panel()
    if visible ~= nil then
      return visible
    end
  end
  local chunks = _G.build_runtime_attr_dialog_chunks()
  for index, text in ipairs(chunks) do
    y3.ltimer.wait((index - 1) * 0.08, function()
      _G.get_player():display_message(text)
    end)
  end
end

local BondSystem = require 'runtime.bonds_chain'

_G.update_bond_effects = function(dt)
  BondSystem.update_effects(_G.create_bond_env(), dt)
end

_G.get_bond_runtime_bonus = function(key)
  local STATE = _G.STATE
  local evolution_runtime = STATE.evolution_runtime
  local evolution_bonus = 0
  if evolution_runtime and evolution_runtime.applied and evolution_runtime.applied.runtime then
    evolution_bonus = evolution_runtime.applied.runtime[key] or 0
  end
  return BondSystem.get_runtime_bonus(STATE, key) + evolution_bonus
end

-- BootCombat 转发
local BootCombat = require 'runtime.boot_combat'
_G.get_enemies_in_range = BootCombat.get_enemies_in_range
_G.get_enemies_on_line = BootCombat.get_enemies_on_line
_G.get_hero_point = BootCombat.get_hero_point

_G.emit_damage_debug_visual = BootCombat.emit_damage_debug_visual
_G.deal_skill_damage = BootCombat.deal_skill_damage
_G.get_hero_attack = BootCombat.get_hero_attack
_G.get_current_hero = BootCombat.get_current_hero
_G.get_primary_target = BootCombat.get_primary_target
_G.spawn_particle = BootCombat.spawn_particle
_G.launch_projectile_from_hero = BootCombat.launch_projectile_from_hero

_G.is_active_enemy = function(unit)
  local battlefield_system = _G.battlefield_system
  return battlefield_system and battlefield_system.is_active_enemy(unit) or false
end

_G.get_current_wave = function()
  local battlefield_system = _G.battlefield_system
  return battlefield_system and battlefield_system.get_current_wave()
end

_G.get_boss_name = function(wave)
  local battlefield_system = _G.battlefield_system
  return battlefield_system and battlefield_system.get_boss_name(wave)
end

_G.show_runtime_status = function()
  local STATE = _G.STATE
  if STATE.session_phase ~= 'battle' then
    local stage_name = STATE.current_stage_def and
        (STATE.current_stage_def.display_label or STATE.current_stage_def.display_name) or '未选择'
    local mode_name = STATE.current_mode_def and STATE.current_mode_def.display_name or '标准模式'
    _G.message(string.format('当前处于局外选关阶段：%s %s。', stage_name, mode_name))
    return
  end

  local wave = _G.get_current_wave()
  local wave_text = wave and wave.name or '未开始'
  local boss_text = '无'
  if STATE.active_wave then
    if STATE.active_wave.boss_spawned then
      boss_text = _G.get_boss_name(STATE.active_wave.wave) .. ' 已登场'
    else
      local remain = math.max(0, STATE.active_wave.wave.boss_spawn_sec - STATE.active_wave.elapsed)
      boss_text = string.format('Boss倒计时 %.1f', remain)
    end
  end

  local challenge_count = 0
  for _ in pairs(STATE.active_challenges) do
    challenge_count = challenge_count + 1
  end

  local challenge_charge_text = ''
  if STATE.challenge_charge_map then
    local parts = {}
    for _, challenge_id in ipairs({ 'gold_trial', 'wood_trial', 'exp_trial' }) do
      local def = _G.CONFIG.challenges and _G.CONFIG.challenges[challenge_id]
      if def then
        parts[#parts + 1] = string.format(
          '%s %d/%d',
          tostring(def.hotkey or challenge_id),
          tonumber(STATE.challenge_charge_map[challenge_id]) or 0,
          _G.CONFIG.challenge_rules.max_charges or 0
        )
      end
    end
    challenge_charge_text = table.concat(parts, ' ')
  else
    challenge_charge_text = string.format('%d/%d', STATE.challenge_charges, _G.CONFIG.challenge_rules.max_charges)
  end

  local reward_system = _G.reward_system
  _G.message(string.format(
    '状态：%s，%s，英雄 %s，敌人数 %d，金币 %d，木材 %d，挑战次数 %s，进行中挑战 %d，待领奖励 %d。',
    wave_text,
    boss_text,
    _G.progression_system.get_hero_progress_text(),
    STATE.total_enemy_alive,
    STATE.resources.gold,
    STATE.resources.wood,
    challenge_charge_text,
    challenge_count,
    reward_system and reward_system.get_reward_queue_count() or 0
  ))
end

_G.get_hud_system = function()
  return _G.hud_system
end

_G.get_runtime_hud_system_fn = function()
  return _G.hud_system
end

_G.set_battle_hud_visible = function(visible)
  local hud = _G.hud_system
  if hud and hud.set_visible then
    return hud.set_visible(visible)
  end
  return false
end

_G.sync_basic_attack_ability = function()
  local attack_skills_system = _G.attack_skills_system
  return attack_skills_system and attack_skills_system.sync_basic_attack_ability()
end

_G.debug_message = function(text)
  local debug_tools_system = _G.debug_tools_system
  return debug_tools_system and debug_tools_system.debug_message(text)
end

_G.show_debug_hotkey_help = function()
  local debug_tools_system = _G.debug_tools_system
  return debug_tools_system and debug_tools_system.show_debug_hotkey_help()
end

_G.get_enemy_runtime_info = function(unit)
  local battlefield_system = _G.battlefield_system
  return battlefield_system and battlefield_system.get_enemy_runtime_info(unit)
end

_G.is_boss_runtime_enemy = function(info)
  local battlefield_system = _G.battlefield_system
  return battlefield_system and battlefield_system.is_boss_runtime_enemy(info)
end

_G.is_elite_runtime_enemy = function(info)
  local battlefield_system = _G.battlefield_system
  return battlefield_system and battlefield_system.is_elite_runtime_enemy(info)
end

_G.show_attack_skill_loadout = function()
  local attack_skills_system = _G.attack_skills_system
  return attack_skills_system and attack_skills_system.show_attack_skill_loadout()
end

_G.unlock_attack_skill = function(skill_id)
  local CONFIG = _G.CONFIG
  if CONFIG.attack_skill_deprecated and skill_id ~= 'basic_attack' then
    return nil, nil, false
  end
  local STATE = _G.STATE
  local attack_skills_system = _G.attack_skills_system
  local skill, slot, is_new = attack_skills_system and attack_skills_system.unlock_attack_skill(skill_id)
  if is_new and STATE.evolution_runtime and STATE.evolution_runtime.applied then
    local bonus = STATE.evolution_runtime.applied.attack_skill or {}
    local factor = 1
    if bonus.damage_ratio and bonus.damage_ratio ~= 0 then
      skill.damage_ratio = math.max(0, (skill.damage_ratio or 0) + bonus.damage_ratio * factor)
    end
    if bonus.repeat_count and bonus.repeat_count ~= 0 then
      skill.repeat_count = math.max(1, (skill.repeat_count or 1) + bonus.repeat_count * factor)
    end
    if bonus.range_bonus and bonus.range_bonus ~= 0 then
      skill.range_bonus = math.max(0, (skill.range_bonus or 0) + bonus.range_bonus * factor)
    end
    if bonus.cooldown_reduction and bonus.cooldown_reduction ~= 0 then
      skill.cooldown_reduction = math.max(0, (skill.cooldown_reduction or 0) + bonus.cooldown_reduction * factor)
    end
  end
  return skill, slot, is_new
end

_G.has_bond_route_tag = function(tag)
  return BondSystem.has_route_tag(_G.STATE, tag)
end

_G.is_debug_effect_mounted = function(effect_id)
  local STATE = _G.STATE
  return STATE.effect_debug_runtime
      and STATE.effect_debug_runtime.mounted_effect_ids
      and STATE.effect_debug_runtime.mounted_effect_ids[effect_id] == true
      or false
end

_G.notify_bond_attack_skill_cast = function(skill, target)
  return BondSystem.notify_attack_skill_cast(_G.create_bond_env(), skill, target)
end

_G.notify_auto_active_basic_attack = function(target)
  local auto_active_effects_system = _G.auto_active_effects_system
  if auto_active_effects_system then
    auto_active_effects_system.handle_basic_attack_cast(target)
  end
end

_G.notify_auto_active_skill_cast = function(skill, target)
  local auto_active_effects_system = _G.auto_active_effects_system
  if auto_active_effects_system then
    auto_active_effects_system.handle_attack_skill_cast(skill, target)
  end
end

_G.play_basic_attack_sound = function(source_unit)
  local audio_system = _G.audio_system
  return audio_system and audio_system.play_basic_attack and audio_system.play_basic_attack(source_unit) or nil
end

_G.play_attack_skill_sound = function(skill, source_anchor, stage)
  local audio_system = _G.audio_system
  return audio_system and audio_system.play_attack_skill and
      audio_system.play_attack_skill(skill, source_anchor, stage) or nil
end

_G.play_ui_click = function()
  local audio_system = _G.audio_system
  return audio_system and audio_system.play_ui_click and audio_system.play_ui_click() or nil
end

local AudioResources = require 'data.tables.audio_resources'
local AUDIO_SCENES = AudioResources.AUDIO_SCENES or {}

_G.play_enemy_death_sound = function(unit, info, death_point)
  local audio_system = _G.audio_system
  local is_boss = info and info.kind == 'boss'
  if audio_system and audio_system.play_enemy_death then
    local played = audio_system.play_enemy_death(unit, is_boss, death_point)
    if played then return played end
  end
  if not death_point or not y3 or not y3.sound then return nil end
  local player = _G.get_player()
  if not player then return nil end
  local death_scene = is_boss and AUDIO_SCENES.boss_death_heavy or AUDIO_SCENES.enemy_death_heavy
  local death_id = type(death_scene) == 'table' and tonumber(death_scene[1]) or nil
  if not death_id then return nil end
  local ok, sound = pcall(y3.sound.play_3d, player, death_id, death_point, { ensure = true, height = 0, volume = 100 })
  if ok and sound then return sound end
  return nil
end

_G.create_offset_point = function(_, base_point, angle, distance, z)
  if not base_point then return nil end
  local dir = tonumber(angle) or 0
  local travel = tonumber(distance) or 0
  if y3 and y3.point and y3.point.get_point_offset_vector then
    local ok, point = pcall(y3.point.get_point_offset_vector, base_point, dir, travel)
    if ok and point then return point end
  end
  if y3 and y3.point and y3.point.create and base_point.get_x and base_point.get_y then
    local x = base_point:get_x() + math.cos(dir) * travel
    local y = base_point:get_y() + math.sin(dir) * travel
    return y3.point.create(x, y, z or (base_point.get_z and base_point:get_z() or 0))
  end
  return nil
end

local BattleEventPrompts = require 'runtime.battle_event_prompts'
local GearUpgrades = require 'runtime.gear_upgrades'
local BootHelpers = require 'runtime.boot_helpers'

local battle_event_prompts_instance

_G.try_upgrade_growth_weapon = function()
  if not battle_event_prompts_instance then
    battle_event_prompts_instance = BattleEventPrompts.create({
      STATE = _G.STATE,
      BattleEventFeedSystem = require 'runtime.battle_event_feed',
      create_battle_event_feed_runtime = function()
        return require 'runtime.battle_event_feed'.create_runtime()
      end,
      infer_battle_event_style = BootHelpers.infer_battle_event_style,
      GearUpgrades = GearUpgrades,
      CONFIG = _G.CONFIG,
      get_message_prompt_system = function()
        return _G.STATE.message_prompt_system
      end,
      get_audio_system = function()
        return _G.audio_system
      end,
      get_hud_system = function()
        return _G.hud_system
      end,
      get_inventory_panel_system = function()
        return _G.STATE.inventory_panel_system
      end,
      message = _G.message,
      ensure_round_choice_available = _G.ensure_round_choice_available,
      sync_gear_runtime_effects = _G.sync_gear_runtime_effects,
    })
  end
  return battle_event_prompts_instance.try_upgrade_growth_weapon()
end

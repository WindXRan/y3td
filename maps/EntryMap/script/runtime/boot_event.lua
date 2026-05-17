-- boot_event.lua — 消息/治疗/战斗结束/羁绊环境，自初始化模块
-- require 时设置 _G.message / heal_hero / handle_battle_finished / create_bond_env

local BattleEventPrompts = require 'runtime.battle_event_prompts'
local BootHelpers = require 'runtime.boot_helpers'
local GearUpgrades = require 'runtime.gear_upgrades'
local BootCombat = require 'runtime.boot_combat'

local battle_event_prompts_instance

_G.message = function(text)
  if log and log.info then
    log.info('[entry_runtime] ' .. tostring(text))
  end
  local STATE = _G.STATE
  if STATE.session_phase == 'battle' then
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
  _G.get_player():display_message(text)
end
_G.heal_hero = function(amount)
  if amount <= 0 then return end
  local STATE = _G.STATE
  if not STATE.hero or not STATE.hero:is_exist() then return end
  local before = STATE.hero:get_hp()
  STATE.hero:add_hp(amount)
  if STATE.hero:get_hp() > before then
    _G.message(string.format('急救生效，英雄生命恢复至 %.0f。', STATE.hero:get_hp()))
  end
end

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
    reserve_formula_damage = BootCombat.reserve_formula_damage,
    basic_attack_damage_type = _G.ATTACK_SKILL_DEFS.basic_attack.damage_type,
    get_player = _G.get_player,
  }
end

_G.handle_battle_finished = function(result)
  local audio_system = _G.audio_system
  if audio_system and audio_system.handle_battle_finished then
    audio_system.handle_battle_finished(result)
  end
  local battlefield_system = _G.battlefield_system
  if battlefield_system and battlefield_system.cleanup_battle_units then
    battlefield_system.cleanup_battle_units()
  end
  _G.set_battle_hud_visible(false)

  local result_panel_system = _G.result_panel_system
  local outgame_system = _G.outgame_system

  local function finish_outgame_transition()
    local reset_func = _G.RuntimeEntry._session_bundle
        and _G.RuntimeEntry._session_bundle.reset_battle_state
    if reset_func then
      reset_func()
    end
    local STATE = _G.STATE
    STATE.session_phase = 'outgame'
    STATE.game_finished = true
    STATE.last_battle_result = result
    _G.enforce_runtime_ui_phase(false)
    if outgame_system then
      outgame_system.enter_outgame(result)
    end
    if result_panel_system then
      result_panel_system.hide()
    end
  end

  if result_panel_system then
    local STATE = _G.STATE
    local gold = STATE.resources and STATE.resources.gold or 0
    local hp = STATE.hero and STATE.hero:is_exist() and STATE.hero:get_hp() or 0
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

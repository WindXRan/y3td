--[[
消息系统模块
职责：统一处理游戏内消息显示，支持战斗中事件提示和普通消息
]]

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local log = env.log
  local GearUpgrades = env.GearUpgrades
  local BootHelpers = env.BootHelpers
  
  local api = {}
  
  -- 缓存 BattleEventPrompts 工厂
  local BattleEventPromptsFactory = nil
  
  local function lazy_init_battle_event_prompts()
    if not BattleEventPromptsFactory then
      BattleEventPromptsFactory = require 'runtime.battle_event_prompts'
    end
    return BattleEventPromptsFactory.create({
      STATE = STATE,
      BattleEventFeedSystem = require 'runtime.battle_event_feed',
      create_battle_event_feed_runtime = function()
        return require 'runtime.battle_event_feed'.create_runtime()
      end,
      infer_battle_event_style = BootHelpers.infer_battle_event_style,
      GearUpgrades = GearUpgrades,
      CONFIG = CONFIG,
      get_message_prompt_system = function()
        return STATE.message_prompt_system
      end,
      get_audio_system = function()
        return env.audio_system
      end,
      get_hud_system = function()
        return _G.hud_system
      end,
      get_inventory_panel_system = function()
        return STATE.inventory_panel_system
      end,
      message = api.message,
      ensure_round_choice_available = env.ensure_round_choice_available,
      sync_gear_runtime_effects = env.sync_gear_runtime_effects,
    })
  end
  
  function api.message(text)
    -- 日志记录
    if log and log.info then
      log.info('[entry_runtime] ' .. tostring(text))
    end
    
    -- 战斗中显示事件提示
    if STATE.session.phase == 'battle' then
      local BattleEventPrompts = lazy_init_battle_event_prompts()
      BattleEventPrompts.push_battle_event(text)
      return
    end
    
    -- 非战斗状态显示普通消息
    local get_player = env.get_player
    if get_player then
      get_player():display_message(text)
    end
  end
  
  return api
end

return M

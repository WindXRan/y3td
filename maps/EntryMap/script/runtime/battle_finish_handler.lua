--[[
战斗结束处理器模块
职责：处理战斗结束后的清理、结果展示和状态转换
]]

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local BootServices = env.BootServices
  local audio_system = env.audio_system
  
  local api = {}
  
  local function finish_outgame_transition(result)
    local reset_func = env._session_bundle and env._session_bundle.reset_battle_state
    if reset_func then
      reset_func()
    end
    STATE.session.phase = 'outgame'
    STATE.session.game_finished = true
    STATE.session.last_battle_result = result
    
    if env.enforce_runtime_ui_phase then
      env.enforce_runtime_ui_phase(false)
    end
    
    local outgame_system = BootServices.get_service('outgame_system')
    if outgame_system then
      outgame_system.enter_outgame(result)
    end
    
    local result_panel_system = BootServices.get_service('result_panel_system')
    if result_panel_system then
      result_panel_system.hide()
    end
  end
  
  function api.handle_battle_finished(result)
    -- 通知音频系统
    if audio_system and audio_system.handle_battle_finished then
      audio_system.handle_battle_finished(result)
    end
    
    -- 清理战斗单位
    local battlefield_system = BootServices.get_service('battlefield_system')
    if battlefield_system and battlefield_system.cleanup_battle_units then
      battlefield_system.cleanup_battle_units()
    end
    
    -- 隐藏战斗 HUD
    local runtime_hud_system = BootServices.get_service('runtime_hud_system')
    if runtime_hud_system and runtime_hud_system.set_battle_hud_visible then
      runtime_hud_system.set_battle_hud_visible(false)
    end
    
    -- 显示结果面板或直接切换到 outgame
    local result_panel_system = BootServices.get_service('result_panel_system')
    if result_panel_system then
      local gold = STATE.battle.resources and STATE.battle.resources.gold or 0
      local hp = STATE.battle.hero and STATE.battle.hero:is_exist() and STATE.battle.hero:get_hp() or 0
      result_panel_system.show({
        is_win = result.is_win,
        reached_wave_index = result.reached_wave_index,
        gold = gold,
        hp = hp,
      }, function()
        finish_outgame_transition(result)
      end)
    else
      finish_outgame_transition(result)
    end
  end
  
  return api
end

return M

--[[
挑战管理模块
职责：管理游戏中的挑战系统（挑战启动、完成处理等）
]]

local M = {}

function M.create(env)
  local STATE = env.STATE
  local BootServices = env.BootServices
  local audio_system = env.audio_system
  local reward_system = env.reward_system
  local mainline_task_system = env.mainline_task_system
  local ensure_round_choice_available = env.ensure_round_choice_available
  
  local api = {}
  
  -- 尝试启动挑战
  function api.try_start_challenge(challenge_id)
    -- 检查是否有待处理的回合选择
    if not ensure_round_choice_available(nil) then
      return nil
    end
    
    -- 委托给战场系统处理
    local battlefield_system = BootServices.get_service('battlefield_system')
    return battlefield_system and battlefield_system.try_start_challenge(challenge_id)
  end
  
  -- 启动主线任务挑战
  function api.start_mainline_task_challenge(task)
    local battlefield_system = BootServices.get_service('battlefield_system')
    return battlefield_system and battlefield_system.start_mainline_task_challenge and
        battlefield_system.start_mainline_task_challenge(task) or nil
  end
  
  -- 处理挑战开始事件
  function api.on_challenge_started(instance)
    -- 通知音频系统
    if audio_system and audio_system.handle_challenge_started then
      audio_system.handle_challenge_started(instance)
    end
    
    -- 通知奖励系统
    if reward_system and reward_system.handle_challenge_started then
      return reward_system.handle_challenge_started(instance)
    end
    
    return nil
  end
  
  -- 处理挑战完成事件
  function api.on_challenge_finished(instance, is_success)
    -- 通知音频系统
    if audio_system and audio_system.handle_challenge_finished then
      audio_system.handle_challenge_finished(instance, is_success)
    end
    
    -- 通知主线任务系统
    if mainline_task_system and mainline_task_system.handle_challenge_finished then
      mainline_task_system.handle_challenge_finished(instance, is_success)
    end
    
    -- 通知奖励系统
    if reward_system and reward_system.handle_challenge_finished then
      return reward_system.handle_challenge_finished(instance, is_success)
    end
    
    return nil
  end
  
  return api
end

return M

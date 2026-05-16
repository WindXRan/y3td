--[[
奖励管理模块
职责：处理游戏中的奖励发放逻辑
]]

local M = {}

function M.create(env)
  local STATE = env.STATE
  local progression_system = env.progression_system
  
  local api = {}
  
  function api.award_rewards(reward, source_text, silent)
    if not reward then
      return
    end
    
    -- 发放金币奖励
    if reward.gold and reward.gold > 0 then
      STATE.battle.resources.gold = STATE.battle.resources.gold + reward.gold
    end
    
    -- 发放木材奖励
    if reward.wood and reward.wood > 0 then
      STATE.battle.resources.wood = STATE.battle.resources.wood + reward.wood
    end
    
    -- 发放经验奖励
    if reward.exp and reward.exp > 0 then
      progression_system.grant_hero_exp(reward.exp)
    end
    
    -- 如果不需要静默模式，可以在这里添加通知逻辑
    -- 目前通知逻辑在调用方处理，保持与原逻辑一致
    if silent then
      return
    end
  end
  
  return api
end

return M

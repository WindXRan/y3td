--[[
相机管理模块
职责：管理相机模式切换（固定视角/自由视角）
]]

local M = {}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local BootServices = env.BootServices
  
  local api = {}
  
  local function get_player()
    return env.get_player and env.get_player() or nil
  end
  
  function api.apply_fixed_camera_mode(enabled)
    local player = get_player()
    if not player or not y3.camera then
      return false
    end

    if enabled == true then
      -- 检查英雄是否存在
      if not STATE.battle.hero or not STATE.battle.hero.is_exist or not STATE.battle.hero:is_exist() then
        return false
      end
      
      -- TPS 第三人称跟随英雄
      if y3.camera.set_tps_follow_unit then
        y3.camera.set_tps_follow_unit(player, STATE.battle.hero, 0, 0, -60, 300, 0, 220, 1800)
      elseif y3.camera.set_camera_follow_unit then
        y3.camera.set_camera_follow_unit(player, STATE.battle.hero, 0, 0, 220)
      end
      
      -- 禁用相机移动
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

    -- 恢复自由视角
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
  
  function api.sync_fixed_camera_mode()
    return api.apply_fixed_camera_mode(STATE.fixed_camera_enabled == true)
  end
  
  function api.toggle_fixed_camera()
    STATE.fixed_camera_enabled = not (STATE.fixed_camera_enabled == true)
    local ok = api.sync_fixed_camera_mode()
    
    local message = BootServices.get_service('message')
    if message then
      if STATE.fixed_camera_enabled then
        message(ok and '已切换为固定视角（F12 可切换）。' or '已设为固定视角：等待英雄创建后生效。')
      else
        message('已切换为自由视角（F12 可切换）。')
      end
    end
    
    return STATE.fixed_camera_enabled
  end
  
  return api
end

return M

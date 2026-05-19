-- boot_camera.lua — 相机控制，自初始化模块
-- require 时设置 _G.apply_fixed_camera_mode / sync_fixed_camera_mode / toggle_fixed_camera

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
    -- TPS 第三人称跟随英雄
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

_G.sync_fixed_camera_mode = function()
  return _G.apply_fixed_camera_mode(_G.STATE.fixed_camera_enabled == true)
end

_G.toggle_fixed_camera = function()
  local STATE = _G.STATE
  STATE.fixed_camera_enabled = not (STATE.fixed_camera_enabled == true)
  local ok = _G.sync_fixed_camera_mode()
  local message = _G.message
  if message then
    if STATE.fixed_camera_enabled then
      message(ok and '已切换为固定视角（F12 可切换）。' or '已设为固定视角：等待英雄创建后生效。')
    else
      message('已切换为自由视角（F12 可切换）。')
    end
  end
  return STATE.fixed_camera_enabled
end

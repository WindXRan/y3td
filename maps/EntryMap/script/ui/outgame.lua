local M = {}

_G.is_outgame_ui_alive = function(ui)
  if not ui then return false end
  return ui.start_button and true or false
end

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local play_ui_click = env.play_ui_click

  local api = {}

  local function refresh_ui()
  end

  function api.set_ui_visible(visible)
    if y3 and y3.ui then
      local player = y3.player(1)
      local panel = y3.ui.get_ui(player, 'OutgamePanel')
      if panel then
        panel:set_visible(visible)
      end
    end
  end

  function api.apply_battle_result(result)
    return true
  end

  function api.start_selected_stage()
    if STATE.session_phase ~= 'outgame' then
      return false
    end

    local ok = env.stage_runtime
      and env.stage_runtime.start_selected_stage
      and env.stage_runtime.start_selected_stage()
    if ok then
      api.set_ui_visible(false)
      return true
    end

    api.set_ui_visible(true)
    refresh_ui()
    return false
  end

  function api.refresh_ui()
    if not is_outgame_ui_alive(STATE.outgame_ui) then
      return
    end
    refresh_ui()
  end

  function api.enter_outgame()
    STATE.session_phase = 'outgame'
    message('[outgame] 进入局外界面')
    
    api.set_ui_visible(true)
    
    if y3 and y3.ui then
      local player = y3.player(1)
      local start_button = y3.ui.get_ui(player, 'OutgamePanel.bg.button_start')
      if start_button then
        start_button:add_fast_event('左键-点击', function()
          if play_ui_click then
            play_ui_click()
          end
          message('[outgame] 点击开始游戏')
          api.start_selected_stage()
        end)
        message('[outgame] 开始游戏按钮已绑定')
      else
        message('[outgame] 未找到开始游戏按钮')
      end
    end
  end

  M.api = api
  return api
end

return M
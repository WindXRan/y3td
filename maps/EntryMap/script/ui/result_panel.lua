local M = {}

function M.create(env)
  local y3 = env.y3
  local get_player = env.get_player

  local root = y3.local_ui.create('ResultPanel')
  local result_data = nil
  local return_callback = nil

  root:on_refresh('title_TEXT', function(ui)
    if result_data then
      ui:set_text(result_data.is_win and '胜利！' or '失败…')
    end
  end)

  root:on_refresh('wave_stat_TEXT', function(ui)
    if result_data then
      ui:set_text(string.format('到达波次：%d', result_data.reached_wave_index or 0))
    end
  end)

  root:on_refresh('gold_stat_TEXT', function(ui)
    if result_data then
      ui:set_text(string.format('金币：%d', result_data.gold or 0))
    end
  end)

  root:on_refresh('kills_stat_TEXT', function(ui)
    if result_data then
      ui:set_text(string.format('击杀：%d', result_data.kills or 0))
    end
  end)

  root:on_refresh('hp_stat_TEXT', function(ui)
    if result_data then
      ui:set_text(string.format('剩余生命：%.0f', result_data.hp or 0))
    end
  end)

  root:on_refresh('return_btn_text', function(ui)
    ui:set_text('返回局外')
  end)

  root:on_event('return_btn', '左键-按下', function()
    if return_callback then
      return_callback()
    end
  end)

  local function show(data, cb)
    result_data = data
    return_callback = cb
    root:refresh('*')
    local player = get_player and get_player() or nil
    if player then
      local panel = y3.ui.get_ui(player, 'ResultPanel')
      if panel then
        panel:set_visible(true)
      end
    end
  end

  local function hide()
    local player = get_player and get_player() or nil
    if player then
      local panel = y3.ui.get_ui(player, 'ResultPanel')
      if panel then
        panel:set_visible(false)
      end
    end
  end

  return {
    show = show,
    hide = hide,
  }
end

return M

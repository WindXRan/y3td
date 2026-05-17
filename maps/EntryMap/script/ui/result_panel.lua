local M = {}

local function is_ui_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

local function safe_get_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if ok and is_ui_alive(ui) then
    return ui
  end
  return nil
end

local function safe_set_visible(ui, visible)
  if is_ui_alive(ui) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

local function safe_set_text(ui, text)
  if is_ui_alive(ui) and ui.set_text then
    ui:set_text(text or '')
  end
end

function M.create(env)
  local y3 = env and env.y3 or _G.y3 or y3
  local get_player = env and env.get_player or _G.get_player or function() return nil end

  local root = nil
  local result_data = nil
  local return_callback = nil

  -- 安全地尝试创建 UI
  local ok, created_root = pcall(y3.local_ui.create, 'ResultPanel')
  if ok and is_ui_alive(created_root) then
    root = created_root
    
    root:on_refresh('title_TEXT', function(ui)
      if result_data then
        safe_set_text(ui, result_data.is_win and '胜利！' or '失败…')
      end
    end)

    root:on_refresh('wave_stat_TEXT', function(ui)
      if result_data then
        safe_set_text(ui, string.format('到达波次：%d', result_data.reached_wave_index or 0))
      end
    end)

    root:on_refresh('gold_stat_TEXT', function(ui)
      if result_data then
        safe_set_text(ui, string.format('金币：%d', result_data.gold or 0))
      end
    end)

    root:on_refresh('kills_stat_TEXT', function(ui)
      if result_data then
        safe_set_text(ui, string.format('击杀：%d', result_data.kills or 0))
      end
    end)

    root:on_refresh('hp_stat_TEXT', function(ui)
      if result_data then
        safe_set_text(ui, string.format('剩余生命：%.0f', result_data.hp or 0))
      end
    end)

    root:on_refresh('return_btn_text', function(ui)
      safe_set_text(ui, '返回局外')
    end)

    root:on_event('return_btn', '左键-按下', function()
      if return_callback then
        return_callback()
      end
    end)
  end

  local function show(data, cb)
    result_data = data
    return_callback = cb
    
    if root and is_ui_alive(root) then
      local ok_refresh, _ = pcall(function()
        root:refresh('*')
      end)
    end
    
    local player = get_player and get_player() or nil
    if player then
      local panel = safe_get_ui(y3, player, 'ResultPanel')
      if panel then
        safe_set_visible(panel, true)
      end
    end
  end

  local function hide()
    local player = get_player and get_player() or nil
    if player then
      local panel = safe_get_ui(y3, player, 'ResultPanel')
      if panel then
        safe_set_visible(panel, false)
      end
    end
  end

  local api = {
    show = show,
    hide = hide,
  }
  _G.result_panel_system = api
  return api
end

return M

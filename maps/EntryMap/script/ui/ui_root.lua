local M = {}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function resolve_first_ui(y3, player, paths)
  for _, path in ipairs(paths or {}) do
    local ui = resolve_ui(y3, player, path)
    if ui then
      return ui
    end
  end
  return nil
end

local function resolve_child(ui, path)
  if not ui or type(ui.get_child) ~= 'function' then
    return nil
  end
  local ok, child = pcall(ui.get_child, ui, path)
  if not ok or not child then
    return nil
  end
  return child
end

local Utils = require 'runtime.utils'

local function is_alive(ui)
  return Utils.is_ui_alive(ui)
end

function M.resolve_ui(y3, player, path)
  return resolve_ui(y3, player, path)
end

function M.resolve_first_ui(y3, player, paths)
  return resolve_first_ui(y3, player, paths)
end

function M.resolve_child(ui, path)
  return resolve_child(ui, path)
end

function M.is_alive(ui)
  return is_alive(ui)
end

function M.get_overlay_parent(y3, player)
  return resolve_first_ui(y3, player, {
    'GameHUD.main',
    'GameHUD',
    'CommonTip.bg',
    'CommonTip',
    'top',
    'panel_1',
    'panel',
    'bottom_bg',
    'SceneUI',
  })
end

function M.get_top_sheet(y3, player)
  return resolve_ui(y3, player, 'top')
end

function M.get_top_root(y3, player)
  return resolve_first_ui(y3, player, {
    'top.top',
    'top',
  })
end

function M.get_bottom_sheet(y3, player)
  return resolve_ui(y3, player, 'bottom_bg')
end

function M.get_bottom_root(y3, player)
  return resolve_first_ui(y3, player, {
    'bottom_bg.bottom_bg',
    'bottom_bg',
  })
end

function M.get_talk_root(y3, player)
  return resolve_ui(y3, player, 'talk_sys_panel')
end

function M.get_message_root(y3, player)
  return resolve_ui(y3, player, '消息提示')
end

function M.get_inventory_root(y3, player)
  return resolve_first_ui(y3, player, {
    '背包系统.背包系统',
    '背包系统',
  })
end

return M

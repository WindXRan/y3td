--[[
UI 阶段管理模块
职责：管理战斗/非战斗状态下的 UI 显示/隐藏
]]

local M = {}

function M.create(env)
  local y3 = env.y3
  
  local api = {}
  
  local function get_player()
    return env.get_player and env.get_player() or nil
  end
  
  local function set_ui_root_visible(path, visible)
    local player = get_player()
    if not player or not y3 or not y3.ui or not y3.ui.get_ui then
      return false
    end
    local ok, ui = pcall(y3.ui.get_ui, player, path)
    if not ok or not ui or (ui.is_removed and ui:is_removed()) then
      return false
    end
    if ui.set_visible then
      ui:set_visible(visible == true)
      return true
    end
    return false
  end
  
  -- 战斗状态下需要隐藏的 UI
  local HIDDEN_IN_BATTLE = {
    'outgame',
    'ArchivePanel',
    'ArchivePageProfile',
    'ArchivePageEquipment',
    'ArchivePageUniversal',
    'ArchivePageChest',
    'ArchivePagePool',
    'LoadingPanel',
    'LogoPanel',
    'win',
    'loss',
    'CommonTip',
    'SceneUI',
  }
  
  -- 非战斗状态下需要隐藏的 UI
  local HIDDEN_OUTSIDE_BATTLE = {
    'top',
    'GameHUD',
    'BattleHUD',
    'BattleBottomHUD',
    'bottom_bg',
    'Choice_Panel',
    'BondSwallowPanel',
    'CommonTip',
    'SceneUI',
    'LoadingPanel',
    'LogoPanel',
    'win',
    'loss',
    'panel_1',
    'panel',
  }
  
  function api.enforce_runtime_ui_phase(is_battle)
    if is_battle == true then
      for _, path in ipairs(HIDDEN_IN_BATTLE) do
        set_ui_root_visible(path, false)
      end
      return
    end
    
    for _, path in ipairs(HIDDEN_OUTSIDE_BATTLE) do
      set_ui_root_visible(path, false)
    end
  end
  
  -- 暴露内部函数供外部使用
  api.set_ui_root_visible = set_ui_root_visible
  
  return api
end

return M

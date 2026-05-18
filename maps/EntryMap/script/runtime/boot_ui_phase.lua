-- boot_ui_phase.lua — 战斗/局外 UI 显隐控制，自初始化模块
-- require 时设置 _G.enforce_runtime_ui_phase

local function set_ui_root_visible(path, visible)
  local player = _G.get_player()
  if not player or not y3 or not y3.ui then
    return false
  end
  local py_ui = GameAPI.get_comp_by_absolute_path(player.handle, path)
  if not py_ui then
    return false
  end
  local ui = y3.ui.get_by_handle(player, py_ui)
  if not ui or (ui.is_removed and ui:is_removed()) then
    return false
  end
  if ui.set_visible then
    ui:set_visible(visible == true)
    return true
  end
  return false
end

_G.enforce_runtime_ui_phase = function(is_battle)
  if is_battle == true then
    local hidden_in_battle = {
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
    for _, path in ipairs(hidden_in_battle) do
      set_ui_root_visible(path, false)
    end
    return
  end

  local hidden_outside_battle = {
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
  for _, path in ipairs(hidden_outside_battle) do
    set_ui_root_visible(path, false)
  end
end

-- ui_system.lua — UI系统统一入口
-- 合并了 hud, ui_helpers
-- 提供统一的UI系统 API

local UISystem = {}

local runtime_hud = require 'ui.runtime_hud'
local ui_helpers = require 'runtime.ui.runtime_ui_helpers'

UISystem.hud = runtime_hud
UISystem.helpers = ui_helpers

-- 从 hud 转发
UISystem.create_hud = runtime_hud.create
UISystem.toggle_attr_panel = runtime_hud.toggle_attr_panel

-- 从 ui_helpers 转发
UISystem.refresh_choice_panel = ui_helpers.refresh_choice_panel
UISystem.install_panel_systems = ui_helpers.install_panel_systems
UISystem.create_choice_panel = ui_helpers.create_choice_panel
UISystem.create_reward_panel = ui_helpers.create_reward_panel

return UISystem

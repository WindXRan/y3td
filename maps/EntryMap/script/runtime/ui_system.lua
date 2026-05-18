-- ui_system.lua — UI系统统一入口
-- 合并了 hud, ui_helpers, growth_weapon_tip, result_panel
-- 提供统一的UI系统 API

local UISystem = {}

local runtime_hud = require 'ui.runtime_hud'
local ui_helpers = require 'runtime.runtime_ui_helpers'
local growth_weapon_tip = require 'ui.growth_weapon_item_tip'
local result_panel = require 'ui.result_panel'

UISystem.hud = runtime_hud
UISystem.helpers = ui_helpers
UISystem.growth_tip = growth_weapon_tip
UISystem.result = result_panel

-- 从 hud 转发
UISystem.create_hud = runtime_hud.create
UISystem.toggle_attr_panel = runtime_hud.toggle_attr_panel

-- 从 ui_helpers 转发
UISystem.refresh_choice_panel = ui_helpers.refresh_choice_panel
UISystem.install_panel_systems = ui_helpers.install_panel_systems
UISystem.create_choice_panel = ui_helpers.create_choice_panel
UISystem.create_reward_panel = ui_helpers.create_reward_panel

-- 从 result_panel 转发
UISystem.create_result = result_panel.create
UISystem.show_result = result_panel.show

return UISystem

-- debug_system.lua — 调试系统统一入口
-- 合并了 debug_actions, debug_tools, effect_debug
-- 提供统一的调试系统 API

local DebugSystem = {}

local debug_actions = require 'runtime.debug_actions'
local debug_tools = require 'runtime.debug_tools'
local effect_debug = require 'runtime.effect_debug'

DebugSystem.actions = debug_actions
DebugSystem.tools = debug_tools
DebugSystem.effects = effect_debug

-- 从 debug_actions 转发
DebugSystem.register_hotkeys = debug_actions.register_hotkeys
DebugSystem.handle_input = debug_actions.handle_input

-- 从 debug_tools 转发
DebugSystem.debug_message = debug_tools.debug_message
_G.debug_message = debug_tools.debug_message
DebugSystem.show_debug_hotkey_help = debug_tools.show_debug_hotkey_help
DebugSystem.get_area = debug_tools.get_area
DebugSystem.toggle_debug_overlay = debug_tools.toggle_debug_overlay

-- 从 effect_debug 转发
DebugSystem.update = effect_debug.update
DebugSystem.mount_effect = effect_debug.mount_effect
DebugSystem.unmount_effect = effect_debug.unmount_effect
DebugSystem.is_effect_mounted = effect_debug.is_effect_mounted
DebugSystem.refresh_effects = effect_debug.refresh_effects

-- GM 存根
DebugSystem.gm_bond_effects = {
  ensure_board = function() end,
  toggle_board = function() end,
  refresh_board = function() end,
}

return DebugSystem

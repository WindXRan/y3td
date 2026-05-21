local DebugSystem = {}

local debug_actions = require 'runtime.debug.debug_actions'
local debug_tools = require 'runtime.debug.debug_tools'

DebugSystem.actions = debug_actions
DebugSystem.tools = debug_tools

DebugSystem.register_hotkeys = debug_actions.register_hotkeys
DebugSystem.handle_input = debug_actions.handle_input

DebugSystem.debug_message = debug_tools.debug_message
_G.debug_message = debug_tools.debug_message
DebugSystem.show_debug_hotkey_help = debug_tools.show_debug_hotkey_help
DebugSystem.get_area = debug_tools.get_area
DebugSystem.toggle_debug_overlay = debug_tools.toggle_debug_overlay

return DebugSystem

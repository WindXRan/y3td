-- outgame_system.lua — 局外系统统一入口
-- 合并了 outgame, session_state, hero_selection_range
-- 提供统一的局外系统 API

local OutgameSystem = {}

local session_state = require 'runtime.outgame.session_state'
local outgame = require 'ui.outgame'
local hero_selection_range = require 'runtime.heroes.hero_selection_range'

OutgameSystem.session = session_state
OutgameSystem.outgame = outgame
OutgameSystem.hero_range = hero_selection_range

-- 从 session_state 转发
OutgameSystem.create_session = session_state.create
OutgameSystem.start_selected_stage = session_state.start_selected_stage
OutgameSystem.is_battle_active = session_state.is_battle_active
OutgameSystem.reset_session_state = session_state.reset_session_state
OutgameSystem.reset_battle_state = session_state.reset_battle_state

-- 从 outgame 转发
OutgameSystem.create_outgame = outgame.create

-- 从 hero_selection_range 转发
OutgameSystem.get_hero_selection_range = hero_selection_range.get_hero_selection_range
OutgameSystem.set_hero_selection_range = hero_selection_range.set_hero_selection_range

return OutgameSystem

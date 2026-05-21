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

-- 从 outgame 转发
OutgameSystem.create_outgame = outgame.create

-- 从 hero_selection_range 转发
OutgameSystem.get_hero_selection_range = hero_selection_range.get_hero_selection_range
OutgameSystem.set_hero_selection_range = hero_selection_range.set_hero_selection_range

return OutgameSystem

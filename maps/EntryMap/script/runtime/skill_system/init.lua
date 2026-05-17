--[[
skill_system/init.lua
技能系统统一入口
整合了原羁绊系统和技能系统
]]

local modifiers = require 'runtime.skill_system.modifiers'
local activation = require 'runtime.skill_system.activation'

local M = {}

M.modifiers = modifiers
M.activation = activation

M.register_modifier = modifiers.register_modifier
M.unregister_modifier = modifiers.unregister_modifier
M.get_modifier = modifiers.get_modifier
M.get_hero_modifiers = modifiers.get_hero_modifiers
M.execute_effect = modifiers.execute_effect
M.get_modifier_list = modifiers.get_modifier_list
M.sync_with_bond_system = modifiers.sync_with_bond_system

M.activate_modifier_bond = activation.debug_activate_modifier_bond
M.activate_modifier_bond_effects = activation.activate_modifier_bond_effects
M.sync_attr_bonuses_to_hero = activation.sync_attr_bonuses_to_hero

M.create = modifiers.create

return M

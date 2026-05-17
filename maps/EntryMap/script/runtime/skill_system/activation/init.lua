--[[
skill_system/activation/init.lua
Activation模块入口
]]

local triggers = require 'runtime.skill_system.activation.triggers'

local M = {}

M.activate_modifier_bond_effects = triggers.activate_modifier_bond_effects
M.get_modifier_card = triggers.get_modifier_card
M.sync_attr_bonuses_to_hero = triggers.sync_attr_bonuses_to_hero
M.get_owned_modifier_bond_count = triggers.get_owned_modifier_bond_count
M.get_required_modifier_bond_count = triggers.get_required_modifier_bond_count
M.clear_active_modifier_bond_effects = triggers.clear_active_modifier_bond_effects
M.debug_activate_modifier_bond = triggers.debug_activate_modifier_bond

return M

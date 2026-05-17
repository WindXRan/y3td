--[[
skill_system/modifiers/init.lua
Modifiers模块入口
]]

local modifier_pool = require 'runtime.skill_system.modifiers.modifier_pool'
local effects = require 'runtime.skill_system.modifiers.effects'

local M = {}

M.registry = modifier_pool.registry
M.CardEffectState = modifier_pool.CardEffectState

M.register_modifier = modifier_pool.register_modifier
M.unregister_modifier = modifier_pool.unregister_modifier
M.get_modifier = modifier_pool.get_modifier
M.get_hero_modifiers = modifier_pool.get_hero_modifiers
M.get_modifier_by_id = modifier_pool.get_modifier_by_id
M.get_modifier_list = modifier_pool.get_modifier_list
M.sync_with_bond_system = modifier_pool.sync_with_bond_system
M.create = modifier_pool.create

M.EFFECT_CONFIG = effects.EFFECT_CONFIG
M.execute_effect = effects.execute_effect
M.handle_chain = effects.handle_chain
M.handle_splash = effects.handle_splash
M.handle_execute = effects.handle_execute
M.handle_medbot = effects.handle_medbot
M.handle_artillery = effects.handle_artillery
M.handle_strike = effects.handle_strike
M.create_projectile = effects.create_projectile
M.fire_projectile = effects.fire_projectile
M.create_summon = effects.create_summon
M.get_damage_template = effects.get_damage_template
M.apply_damage = effects.apply_damage
M.apply_heal = effects.apply_heal
M.play_effect = effects.play_effect
M.play_sound = effects.play_sound

return M

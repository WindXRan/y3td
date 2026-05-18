local M = {}

local NewModifiers = require 'runtime.skill_system.modifiers'
local ModifierPool = require 'data.tables.bond.bond_modifier_pool'

M.registry = NewModifiers.registry

M.register_modifier = NewModifiers.register_modifier
M.unregister_modifier = NewModifiers.unregister_modifier
M.get_modifier = NewModifiers.get_modifier
M.get_hero_modifiers = NewModifiers.get_hero_modifiers
M.execute_effect = NewModifiers.execute_effect
M.get_modifier_list = NewModifiers.get_modifier_list
M.sync_with_bond_system = NewModifiers.sync_with_bond_system

function M.get_modifier_by_id(id)
  return id and ModifierPool.by_id[id] or nil
end

function M.ensure_effect_state(runtime, bond_name)
  runtime.modifier_pool_effect_state = runtime.modifier_pool_effect_state or {}
  runtime.modifier_pool_effect_state[bond_name] = runtime.modifier_pool_effect_state[bond_name] or {
    bond_name = bond_name, cooldown = 0, counter = 0, elapsed = 0
  }
  return runtime.modifier_pool_effect_state[bond_name]
end

function M.init() return { get_stats = function() return {} end, sync = function() end } end
function M.trigger_modifier_basic_attack_effect() end
function M.trigger_modifier_card_basic_attack_effects() end
function M.trigger_modifier_periodic_effect() end
function M.trigger_modifier_card_periodic_effects() end
function M.handle_modifier_enemy_kill() end
function M.clear_runtime_status_effects() end

return M
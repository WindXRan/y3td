local M = {}

local ModifierPool = require 'data.tables.bond.bond_modifier_pool'
local effects = require 'runtime.skill_system.modifiers.effects'

M.registry = {}
M.EFFECT_CONFIG = effects.EFFECT_CONFIG

local CardEffectState = {
  IDLE = 'idle', ACTIVATING = 'activating', ACTIVE = 'active', COOLDOWN = 'cooldown', EXPIRED = 'expired'
}
M.CardEffectState = CardEffectState

local ModifierInstance = {}
ModifierInstance.__index = ModifierInstance

function ModifierInstance.new(entry, hero)
  local self = setmetatable({}, ModifierInstance)
  self.id, self.name, self.archetype, self.tier, self.weight, self.hero = entry.id, entry.name, entry.archetype, entry.tier, entry.weight, hero
  self.state, self.cooldown, self.duration, self.stack = CardEffectState.IDLE, 0, 0, 1
  return self
end

function ModifierInstance:activate()
  if self.state == CardEffectState.COOLDOWN then return false end
  self.state = CardEffectState.ACTIVATING
  return true
end

function ModifierInstance:update(dt)
  if self.state == CardEffectState.ACTIVATING then
    self.state = CardEffectState.ACTIVE
  elseif self.state == CardEffectState.ACTIVE then
    self.duration = self.duration - dt
    if self.duration <= 0 then self.state, self.cooldown = CardEffectState.COOLDOWN, 5 end
  elseif self.state == CardEffectState.COOLDOWN then
    self.cooldown = self.cooldown - dt
    if self.cooldown <= 0 then self.state = CardEffectState.IDLE end
  end
end

function ModifierInstance:get_state() return self.state end
function ModifierInstance:is_ready() return self.state == CardEffectState.IDLE end

function M.register_modifier(hero, modifier_id)
  if not hero or not modifier_id then return false end
  local entry = ModifierPool.by_id[modifier_id]
  if not entry then return false end
  
  local instance = ModifierInstance.new(entry, hero)
  local key = 'modifier_' .. modifier_id
  M.registry[hero] = M.registry[hero] or {}
  M.registry[hero][key] = instance
  return true
end

function M.unregister_modifier(hero, modifier_id)
  if not hero or not modifier_id or not M.registry[hero] then return end
  local key = 'modifier_' .. modifier_id
  M.registry[hero][key] = nil
  if not next(M.registry[hero]) then M.registry[hero] = nil end
end

function M.get_modifier(hero, modifier_id)
  if not hero or not modifier_id or not M.registry[hero] then return nil end
  return M.registry[hero]['modifier_' .. modifier_id]
end

function M.get_hero_modifiers(hero) return hero and M.registry[hero] or {} end
function M.get_modifier_by_id(id) return id and ModifierPool.by_id[id] or nil end
function M.get_modifier_list() return ModifierPool.list end

function M.sync_with_bond_system(state)
  if not state or not state.bond_runtime or not state.bond_runtime.equipped then return end
  for _, entry in ipairs(state.bond_runtime.equipped) do
    if entry and entry.modifier_id then
      M.register_modifier(state.hero, entry.modifier_id)
    end
  end
end

local function create_core_effects()
  local api = {}
  api.on_chain, api.on_splash, api.on_execute, api.on_strike = function() end, function() end, function() end, function() end
  api.get_stats, api.sync = function() return {} end, function() end
  return api
end

local function create_special_effects()
  local api = {}
  api.on_hunter_first_hit, api.on_reserve_formula_damage = function() end, function() end
  api.get_special_effect = function() return nil end
  return api
end

function M.create(env)
  local api, special, core = {}, create_special_effects(), create_core_effects()
  api.on_chain, api.on_splash, api.on_execute, api.on_strike = function(t) return core.on_chain(t) end, function(t) return core.on_splash(t) end, function(t) return core.on_execute(t) end, function(t) return core.on_strike(t) end
  api.on_hunter_first_hit, api.on_reserve_formula_damage = function(t) return special.on_hunter_first_hit(t) end, function(d) return special.on_reserve_formula_damage(d) end
  api.get_special_effect, api.get_stats, api.sync = function(n) return special.get_special_effect(n) end, function() return core.get_stats() end, function(h, s) core.sync(h, s) end
  return api
end

M.execute_effect = effects.execute_effect
M.handle_chain = effects.handle_chain
M.handle_splash = effects.handle_splash
M.handle_execute = effects.handle_execute
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
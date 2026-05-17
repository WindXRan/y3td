local M = {}

--[[
skill_system/modifiers/modifier_pool.lua
迁移自: runtime/bond_modifier_effects.lua
职责:
  1. Modifier实例管理(注册/注销/查询)
  2. Modifier状态机(IDLE/ACTIVATING/ACTIVE/COOLDOWN/EXPIRED)
  3. Modifier效果执行分发
依赖:
  data.tables.bond.bond_modifier_pool
  runtime.bond_modifier_special_effects
  runtime.bond_modifier_core_effects
]]

M.registry = {}

local ModifierPool = require 'data.tables.bond.bond_modifier_pool'
local SpecialEffects = require 'runtime.bond_modifier_special_effects'
local CoreEffects = require 'runtime.bond_modifier_core_effects'

local CardEffectState = {
  IDLE = 'idle',
  ACTIVATING = 'activating',
  ACTIVE = 'active',
  COOLDOWN = 'cooldown',
  EXPIRED = 'expired',
}
M.CardEffectState = CardEffectState

local ModifierInstance = {}
ModifierInstance.__index = ModifierInstance

function ModifierInstance.new(entry, hero)
  local self = setmetatable({}, ModifierInstance)
  self.id = entry.id
  self.name = entry.name
  self.archetype = entry.archetype
  self.tier = entry.tier
  self.weight = entry.weight
  self.hero = hero
  self.state = CardEffectState.IDLE
  self.cooldown = 0
  self.duration = 0
  self.stack = 1
  return self
end

function ModifierInstance:activate()
  if self.state == CardEffectState.COOLDOWN then
    return false
  end
  self.state = CardEffectState.ACTIVATING
  return true
end

function ModifierInstance:update(dt)
  if self.state == CardEffectState.ACTIVATING then
    self.state = CardEffectState.ACTIVE
  elseif self.state == CardEffectState.ACTIVE then
    self.duration = self.duration - dt
    if self.duration <= 0 then
      self.state = CardEffectState.COOLDOWN
      self.cooldown = 5
    end
  elseif self.state == CardEffectState.COOLDOWN then
    self.cooldown = self.cooldown - dt
    if self.cooldown <= 0 then
      self.state = CardEffectState.IDLE
    end
  end
end

function ModifierInstance:get_state()
  return self.state
end

function ModifierInstance:is_ready()
  return self.state == CardEffectState.IDLE
end

function M.register_modifier(hero, modifier_id)
  if not hero or not modifier_id then return false end

  local entry = ModifierPool.by_id[modifier_id]
  if not entry then return false end

  local instance = ModifierInstance.new(entry, hero)
  local key = 'modifier_' .. modifier_id

  if not M.registry[hero] then
    M.registry[hero] = {}
  end
  M.registry[hero][key] = instance

  return true
end

function M.unregister_modifier(hero, modifier_id)
  if not hero or not modifier_id then return end

  if not M.registry[hero] then return end
  local key = 'modifier_' .. modifier_id
  M.registry[hero][key] = nil

  if not next(M.registry[hero]) then
    M.registry[hero] = nil
  end
end

function M.get_modifier(hero, modifier_id)
  if not hero or not modifier_id then return nil end
  if not M.registry[hero] then return nil end
  local key = 'modifier_' .. modifier_id
  return M.registry[hero][key]
end

function M.get_hero_modifiers(hero)
  if not hero then return {} end
  return M.registry[hero] or {}
end

function M.get_modifier_by_id(id)
  if not id then return nil end
  return ModifierPool.by_id[id]
end

function M.get_modifier_list()
  return ModifierPool.list
end

function M.sync_with_bond_system(state)
  if not state or not state.bond_runtime then return end
  if not state.bond_runtime.equipped then return end

  for _, entry in ipairs(state.bond_runtime.equipped) do
    if entry and entry.modifier_id then
      local hero = state.hero
      if hero then
        M.register_modifier(hero, entry.modifier_id)
      end
    end
  end
end

function M.create(env)
  local api = {}

  local special = SpecialEffects.create(env)
  local core = CoreEffects.create(env)

  function api.on_chain(trigger)
    return core.on_chain(trigger)
  end

  function api.on_splash(trigger)
    return core.on_splash(trigger)
  end

  function api.on_execute(trigger)
    return core.on_execute(trigger)
  end

  function api.on_medbot(trigger)
    return core.on_medbot(trigger)
  end

  function api.on_artillery(trigger)
    return core.on_artillery(trigger)
  end

  function api.on_strike(trigger)
    return core.on_strike(trigger)
  end

  function api.on_hunter_first_hit(target)
    return special.on_hunter_first_hit(target)
  end

  function api.on_reserve_formula_damage(data)
    return special.on_reserve_formula_damage(data)
  end

  function api.get_special_effect(name)
    return special.get_special_effect(name)
  end

  function api.get_stats()
    return core.get_stats()
  end

  function api.sync(hero, hero_attr_system)
    core.sync(hero, hero_attr_system)
  end

  return api
end

return M

local M = {}

local BondModifierPool = require 'data.tables.bond.bond_modifier_pool'
local BondModifierEffects = require 'runtime.bond_modifier_effects'
local BondBonusPack = require 'runtime.bond_bonus_pack'

local copy_bonus_pack = BondBonusPack.copy

function M.activate_modifier_bond_effects(state, bond_name)
  if not state or not bond_name then return {} end
  local runtime = state.bond_runtime
  if not runtime then return {} end
  
  local effect_id = 'initial_bond_set_' .. tostring(bond_name)
  if runtime.modifier_pool_active_effects[effect_id] then return {} end
  
  runtime.modifier_pool_active_effects[effect_id] = true
  return { bond_name }
end

function M.get_modifier_card(state, card_id)
  if not state or not card_id then return nil end
  local runtime = state.bond_runtime
  if not runtime or not runtime.modifier_card_ids then return nil end
  return runtime.modifier_card_ids[card_id] and { id = card_id, owned = true } or nil
end

function M.sync_attr_bonuses_to_hero(env)
  if not env or not env.STATE then return end
  local state = env.STATE
  local runtime = state.bond_runtime
  if not runtime then return end
  
  local hero = state.hero
  if not hero or not hero:is_exist() then return end
  
  local hero_attr_system = env.hero_attr_system
  if not hero_attr_system then return end
  
  for card_id, attr_pack in pairs(runtime.modifier_card_attr_bonuses or {}) do
    if attr_pack and next(attr_pack) then
      for attr_name, value in pairs(attr_pack) do
        hero_attr_system.add_attr(hero, attr_name, value)
      end
    end
  end
  
  hero_attr_system.rebuild_derived_attrs(hero)
end

function M.get_owned_modifier_bond_count(runtime, bond_name)
  if not runtime or not bond_name then return 0 end
  local count = 0
  for _, card in ipairs(BondModifierPool.list or {}) do
    if card.bond_name == bond_name and runtime.modifier_card_ids and runtime.modifier_card_ids[card.id] then
      count = count + 1
    end
  end
  return count
end

function M.get_required_modifier_bond_count(bond_name)
  if not bond_name then return 0 end
  local required_ids = {}
  for _, card in ipairs(BondModifierPool.list or {}) do
    if card.bond_name == bond_name and card.ghost_card then
      required_ids[card.id] = true
    end
  end
  return #required_ids
end

function M.clear_active_modifier_bond_effects(runtime)
  if not runtime then return end
  runtime.modifier_pool_active_effects = {}
  runtime.modifier_card_effect_ids = {}
  runtime.modifier_effects_disabled = true
end

function M.debug_activate_modifier_bond(env, bond_name, grant_missing_cards)
  local state = env and env.STATE
  if not state then return false, 'STATE未初始化' end
  
  local runtime = state.bond_runtime or {}
  state.bond_runtime = runtime
  
  runtime.modifier_card_ids = runtime.modifier_card_ids or {}
  runtime.modifier_card_attr_bonuses = runtime.modifier_card_attr_bonuses or {}
  runtime.modifier_pool_active_effects = runtime.modifier_pool_active_effects or {}
  runtime.modifier_effects_disabled = runtime.modifier_effects_disabled or false
  
  local granted_count = 0
  if grant_missing_cards == true then
    for _, card in ipairs(BondModifierPool.list or {}) do
      if card.bond_name == bond_name and not runtime.modifier_card_ids[card.id] then
        runtime.modifier_card_ids[card.id] = true
        runtime.modifier_card_attr_bonuses[card.id] = copy_bonus_pack(card.attr_pack or {})
        granted_count = granted_count + 1
      end
    end
  end
  
  local effect_id = 'initial_bond_set_' .. tostring(bond_name)
  if runtime.modifier_pool_active_effects[effect_id] == true then
    if granted_count > 0 then M.sync_attr_bonuses_to_hero(env) end
    if env and env.setup_basic_attack_ability then env.setup_basic_attack_ability() end
    if env and env.sync_basic_attack_ability then env.sync_basic_attack_ability() end
    return true, '技能已激活: ' .. tostring(bond_name)
  end
  
  local activated_names = M.activate_modifier_bond_effects(state, bond_name)
  if #activated_names > 0 then
    M.sync_attr_bonuses_to_hero(env)
    if env and env.setup_basic_attack_ability then env.setup_basic_attack_ability() end
    if env and env.sync_basic_attack_ability then env.sync_basic_attack_ability() end
    return true, '技能激活成功: ' .. tostring(bond_name)
  end
  
  local owned_count = M.get_owned_modifier_bond_count(runtime, bond_name)
  local need_count = M.get_required_modifier_bond_count(bond_name)
  return false, string.format('技能未集齐，无法激活：%s（%d/%d）', tostring(bond_name), owned_count, need_count)
end

return M
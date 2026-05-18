local M = {}

local modifiers = require 'runtime.skill_system.modifiers'
local activation = require 'runtime.skill_system.activation'
local Skills = require 'runtime.skills'
local SkillFramework = require 'runtime.skill_framework'
local BondEffectRuntimeRules = require 'data.tables.bond.bond_effect_runtime_rules'

local skill_registry = {}
local hero_skills = {}

local BOND_TO_ELEMENT = {
  ['枪炮师'] = 'physical', ['神射手'] = 'physical', ['游侠'] = 'physical', ['狂战士'] = 'physical',
  ['剑魂'] = 'physical', ['剑宗'] = 'arcane', ['龙骑士'] = 'fire', ['战斗法师'] = 'arcane',
  ['魔剑士'] = 'shadow', ['火法师'] = 'fire', ['冰霜法师'] = 'ice', ['雷电法王'] = 'lightning',
  ['猎人'] = 'wind', ['骷髅法师'] = 'shadow',
}

function M.init()
  skill_registry = {}
  local framework_skills = { 'sf_projectile', 'sf_area' }
  
  for _, id in ipairs(framework_skills) do
    local skill = Skills.build_framework_skill(id)
    if skill then skill_registry[skill.id] = skill end
  end
  
  for _, id in ipairs(framework_skills) do
    for _, tier in ipairs(Skills.list_framework_tiers()) do
      local skill = Skills.build_framework_skill_tier(id, tier)
      if skill then skill_registry[skill.id] = skill end
    end
  end
  
  for bond_name, rules in pairs(BondEffectRuntimeRules.bond_basic_attack) do
    local skill = M.build_bond_skill(bond_name)
    if skill then skill_registry[skill.id] = skill end
  end
  
  for bond_name, rules in pairs(BondEffectRuntimeRules.bond_periodic) do
    local skill = M.build_bond_skill(bond_name)
    if skill then skill_registry[skill.id] = skill end
  end
  
  return #skill_registry
end

function M.register_skill(skill_def)
  if not skill_def or not skill_def.id then return false, 'Invalid skill definition' end
  local normalized = SkillFramework.normalize_skill(skill_def)
  skill_registry[normalized.id] = normalized
  return true, normalized.id
end

function M.get_skill(id) return skill_registry[tostring(id)] end

function M.get_all_skills()
  local result = {}
  for _, skill in pairs(skill_registry) do result[#result + 1] = skill end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

function M.get_skill_ids()
  local result = {}
  for id, _ in pairs(skill_registry) do result[#result + 1] = id end
  table.sort(result)
  return result
end

function M.execute_skill(hero, skill_id, target, context)
  local skill = M.get_skill(skill_id)
  if not skill then return false, string.format('Skill not found: %s', tostring(skill_id)) end
  local ctx = context or { source = hero, target = target, skill = skill, timestamp = os.clock() }
  return modifiers.execute_effect(hero, skill_id, target, ctx)
end

function M.grant_skill(hero, skill_id)
  local hero_key = tostring(hero and hero.get_id and hero:get_id() or 'unknown')
  hero_skills[hero_key] = hero_skills[hero_key] or {}
  for _, id in ipairs(hero_skills[hero_key]) do
    if id == skill_id then return false, 'Skill already granted' end
  end
  hero_skills[hero_key][#hero_skills[hero_key] + 1] = skill_id
  return true, skill_id
end

function M.revoke_skill(hero, skill_id)
  local hero_key = tostring(hero and hero.get_id and hero:get_id() or 'unknown')
  local skills = hero_skills[hero_key]
  if not skills then return false, 'Hero has no skills' end
  for i, id in ipairs(skills) do
    if id == skill_id then table.remove(skills, i) return true, skill_id end
  end
  return false, 'Skill not found'
end

function M.get_hero_skills(hero)
  local hero_key = tostring(hero and hero.get_id and hero:get_id() or 'unknown')
  local result = {}
  for _, id in ipairs(hero_skills[hero_key] or {}) do
    local skill = M.get_skill(id)
    if skill then result[#result + 1] = skill end
  end
  return result
end

function M.build_element_skill(element, pattern, tier, overrides)
  return Skills.build_element_skill(element, pattern, tier, overrides)
end

function M.build_framework_skill(id, visual)
  return Skills.build_framework_skill(id, visual)
end

function M.build_bond_skill(bond_name, override)
  local rules = BondEffectRuntimeRules.bond_basic_attack[bond_name] or BondEffectRuntimeRules.bond_periodic[bond_name]
  if not rules then return nil end
  
  local element = BOND_TO_ELEMENT[bond_name] or 'arcane'
  local vfx = Skills.get_element_vfx(element) or {}
  
  local skill_def = {
    id = string.format('bond_%s', bond_name),
    name = string.format('%s技能', bond_name),
    damage_type = rules.damage_type or '法术',
  }
  
  if rules.chance then
    skill_def.pattern = 'projectile'
    skill_def.target_mode = 'unit'
    skill_def.hit_model = {
      range = rules.line and rules.line.distance or 1200,
      width = rules.line and rules.line.width or 200,
      max_hits = rules.line and rules.line.max_targets == 'max' and 0 or (rules.line and rules.line.max_targets or 0),
    }
    skill_def.scale = { attack_ratio = rules.wave_damage_attack_ratio or rules.damage_attack_ratio or 2.0 }
  elseif rules.interval then
    if rules.splash_radius or rules.storm_radius then
      skill_def.pattern = 'area'
      skill_def.target_mode = 'point'
      skill_def.hit_model = { radius = rules.splash_radius or rules.storm_radius or 300 }
      skill_def.scale = {
        attack_ratio = rules.damage_attack_ratio or 2.0,
        splash_ratio = rules.splash_damage_attack_ratio or 0.6,
      }
      skill_def.timeline = {
        duration = rules.tick_count and (rules.tick_count * (rules.tick_interval or 0.3)) or 2.0,
        tick_interval = rules.tick_interval or 0.3,
      }
    else
      skill_def.pattern = 'projectile'
      skill_def.target_mode = 'unit'
      skill_def.hit_model = { range = rules.range or 1200, bounce = rules.base_target_count or 3 }
      skill_def.scale = {
        attack_ratio = rules.damage_ratio_default or rules.damage_attack_ratio or 1.5,
        bounce_ratio = 0.75,
      }
    end
    skill_def.resource = { cooldown = rules.interval or 5.0 }
  end
  
  skill_def.visual = vfx
  if override then for k, v in pairs(override) do skill_def[k] = v end end
  
  return Skills.build_framework_skill('sf_projectile', skill_def.visual)
end

function M.get_bond_skill_ids()
  local ids = {}
  for bond_name, _ in pairs(BondEffectRuntimeRules.bond_basic_attack) do
    ids[#ids + 1] = string.format('bond_%s', bond_name)
  end
  for bond_name, _ in pairs(BondEffectRuntimeRules.bond_periodic) do
    ids[#ids + 1] = string.format('bond_%s', bond_name)
  end
  return ids
end

function M.register_bond_skills(skill_registry)
  for bond_name, rules in pairs(BondEffectRuntimeRules.bond_basic_attack) do
    local skill = M.build_bond_skill(bond_name)
    if skill then skill_registry.register(skill) end
  end
  for bond_name, rules in pairs(BondEffectRuntimeRules.bond_periodic) do
    local skill = M.build_bond_skill(bond_name)
    if skill then skill_registry.register(skill) end
  end
end

function M.get_element_vfx(element) return Skills.get_element_vfx(element) end

M.modifiers = modifiers
M.activation = activation
M.skills = Skills
M.framework = SkillFramework
M.BOND_TO_ELEMENT = BOND_TO_ELEMENT

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

return M
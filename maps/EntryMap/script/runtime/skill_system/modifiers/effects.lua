local M = {}

local EFFECT_CONFIG = {
  chain = { name = '闪电链', max_targets = 5, damage_reduction = 0.15, chain_range = 400 },
  splash = { name = '溅射', radius = 250, damage_ratio = 0.5 },
  execute = { name = '处决', hp_threshold = 0.2, damage_multiplier = 2.5 },
  strike = { name = '强力一击', chance = 0.2, damage_multiplier = 2.0 },
}
M.EFFECT_CONFIG = EFFECT_CONFIG

local function get_attack_value(hero)
  if not hero then return 0 end
  local attr = hero.get_attr and hero:get_attr()
  return attr and attr.attack or 0
end

function M.create_projectile(source, target, config)
  return { source = source, target = target, speed = config.speed or 1200, on_impact = config.on_impact }
end

function M.fire_projectile(proj) if proj and proj.on_impact then proj.on_impact(proj.target) end end

function M.create_summon(owner, position, config)
  return { owner = owner, position = position, unit_type = config.unit_type, duration = config.duration }
end

function M.get_damage_template(modifier_id)
  local entry = require 'data.tables.bond.bond_modifier_pool'.by_id[modifier_id]
  if not entry then return nil end
  local config = EFFECT_CONFIG[entry.archetype]
  return {
    base_damage = 0,
    damage_type = config and config.damage_type or 'physical',
    damage_source = 'attack',
    modifier = config and config.damage_multiplier or 1.0,
  }
end

function M.execute_effect(hero, modifier_id, target, context)
  if not hero or not modifier_id then return end
  local instance = require 'runtime.skill_system.modifiers'.get_modifier(hero, modifier_id)
  if not instance or not instance:activate() then return end
  
  local config = EFFECT_CONFIG[instance.archetype]
  if not config then return end
  
  if instance.archetype == 'chain' then
    M.handle_chain(hero, target, config, context)
  elseif instance.archetype == 'splash' then
    M.handle_splash(hero, target, config, context)
  elseif instance.archetype == 'execute' then
    M.handle_execute(hero, target, config, context)
  elseif instance.archetype == 'strike' then
    M.handle_strike(hero, target, config, context)
  end
end

function M.handle_chain(hero, target, config, ctx)
  if not target then return end
  local damage = get_attack_value(hero)
  local targets = { target }
  for i, t in ipairs(targets) do
    M.apply_damage(hero, t, damage * (1 - (config.damage_reduction or 0.15)) ^ (i - 1), 'chain', ctx)
  end
end

function M.handle_splash(hero, target, config, ctx)
  if not target then return end
  local damage = get_attack_value(hero) * (config.damage_ratio or 0.5)
  for _, t in ipairs({ target }) do
    M.apply_damage(hero, t, damage, 'splash', ctx)
  end
end

function M.handle_execute(hero, target, config, ctx)
  if not target then return end
  local damage = get_attack_value(hero) * (config.damage_multiplier or 2.5)
  M.apply_damage(hero, target, damage, 'execute', ctx)
end

function M.handle_strike(hero, target, config, ctx)
  if not target then return end
  if math.random() < (config.chance or 0.2) then
    M.apply_damage(hero, target, get_attack_value(hero) * (config.damage_multiplier or 2.0), 'strike', ctx)
  end
end

local y3 = _G.y3 or y3

function M.apply_damage(source, target, amount, damage_type, context)
  if not source or not target or not target.is_exist or not target:is_exist() then return end
  local deal = _G.deal_skill_damage or function() end
  deal(target, amount, { damage_type = damage_type or '物理' }, context and context.visual)
end

function M.apply_heal(source, target, amount)
  if not source or not target or not target.is_exist or not target:is_exist() then return end
  if target.add_hp then target:add_hp(amount) end
end

function M.play_effect(effect_id, position)
  if effect_id and position and y3 and y3.particle and y3.particle.create then
    y3.particle.create(effect_id, position)
  end
end

function M.play_sound(sound_id)
  if sound_id and y3 and y3.audio and y3.audio.play then
    y3.audio.play(sound_id)
  end
end

return M
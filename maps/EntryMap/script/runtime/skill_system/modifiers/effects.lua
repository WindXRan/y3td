local M = {}

--[[
skill_system/modifiers/effects.lua
迁移自: runtime/bond_modifier_effects.lua 中的效果处理函数
职责:
  - 各archetype效果处理(chain/splash/execute/medbot/artillery/strike)
  - 伤害/治疗应用
  - 特效/音效播放
]]

local EFFECT_CONFIG = {
  chain = {
    name = '闪电链',
    description = '攻击时释放闪电链，最多弹射N个目标',
    max_targets = 5,
    damage_reduction = 0.15,
    chain_range = 400,
    chain_effect = 'ChainLightningEffect',
    chain_sound = 'ChainLightningSound',
  },
  splash = {
    name = '溅射',
    description = '攻击造成范围伤害',
    radius = 250,
    damage_ratio = 0.5,
    splash_effect = 'SplashEffect',
    splash_sound = 'SplashSound',
  },
  execute = {
    name = '处决',
    description = '对低血量目标造成额外伤害',
    hp_threshold = 0.2,
    damage_multiplier = 2.5,
    execute_effect = 'ExecuteEffect',
    execute_sound = 'ExecuteSound',
  },
  medbot = {
    name = '医疗机器人',
    description = '攻击时召唤医疗机器人治疗友军',
    heal_ratio = 0.3,
    heal_range = 500,
    medbot_unit = 'MedBotUnit',
    medbot_effect = 'MedBotSpawnEffect',
    medbot_sound = 'MedBotSpawnSound',
  },
  artillery = {
    name = '火炮',
    description = '对远处目标造成额外范围伤害',
    min_range = 600,
    damage_ratio = 0.8,
    radius = 300,
    artillery_effect = 'ArtilleryEffect',
    artillery_sound = 'ArtillerySound',
  },
  strike = {
    name = '强力一击',
    description = '普通攻击有概率造成额外伤害',
    chance = 0.2,
    damage_multiplier = 2.0,
    strike_effect = 'StrikeEffect',
    strike_sound = 'StrikeSound',
  },
}
M.EFFECT_CONFIG = EFFECT_CONFIG

local VISUAL_CONFIG = {
  projectile_speed = 1200,
  projectile_model = 'ProjectileModel',
  impact_effect = 'ImpactEffect',
  impact_sound = 'ImpactSound',
  trail_effect = 'TrailEffect',
}

local function get_hero_attr(hero)
  if not hero then return nil end
  if hero.get_attr then
    return hero:get_attr()
  end
  return nil
end

local function get_attack_value(hero)
  if not hero then return 0 end
  local attr = get_hero_attr(hero)
  if attr and attr.attack then
    return attr.attack
  end
  return 0
end

local function get_distance(a, b)
  if not a or not b then return 0 end
  local pos_a = a:get_position()
  local pos_b = b:get_position()
  if pos_a and pos_b then
    local dx = pos_a.x - pos_b.x
    local dz = pos_a.z - pos_b.z
    return math.sqrt(dx * dx + dz * dz) or 0
  end
  return 0
end

function M.create_projectile(source, target, config)
  local projectile = {
    source = source,
    target = target,
    speed = config.speed or VISUAL_CONFIG.projectile_speed,
    model = config.model or VISUAL_CONFIG.projectile_model,
    trail = config.trail or VISUAL_CONFIG.trail_effect,
    on_impact = config.on_impact,
  }
  return projectile
end

function M.fire_projectile(projectile)
  if not projectile then return end
  if projectile.on_impact then
    projectile.on_impact(projectile.target)
  end
end

function M.create_summon(owner, position, config)
  local summon = {
    owner = owner,
    position = position,
    unit_type = config.unit_type,
    duration = config.duration,
    on_spawn = config.on_spawn,
    on_expire = config.on_expire,
  }
  return summon
end

function M.get_damage_template(modifier_id)
  local ModifierPool = require 'data.tables.bond.bond_modifier_pool'
  local entry = ModifierPool.by_id[modifier_id]
  if not entry then return nil end

  local template = {
    base_damage = 0,
    damage_type = 'physical',
    damage_source = 'attack',
    modifier = 1.0,
  }

  local config = EFFECT_CONFIG[entry.archetype]
  if config then
    template.damage_type = config.damage_type or 'physical'
    template.modifier = config.damage_multiplier or 1.0
  end

  return template
end

function M.execute_effect(hero, modifier_id, target, context)
  if not hero or not modifier_id then return end

  local ModifierPool = require 'skill_system.modifiers.modifier_pool'
  local instance = ModifierPool.get_modifier(hero, modifier_id)
  if not instance then return end

  if not instance:activate() then return end

  local archetype = instance.archetype
  local config = EFFECT_CONFIG[archetype]

  if not config then return end

  if archetype == 'chain' then
    M.handle_chain(hero, target, config, context)
  elseif archetype == 'splash' then
    M.handle_splash(hero, target, config, context)
  elseif archetype == 'execute' then
    M.handle_execute(hero, target, config, context)
  elseif archetype == 'medbot' then
    M.handle_medbot(hero, target, config, context)
  elseif archetype == 'artillery' then
    M.handle_artillery(hero, target, config, context)
  elseif archetype == 'strike' then
    M.handle_strike(hero, target, config, context)
  end
end

function M.handle_chain(hero, target, config, context)
  if not target then return end

  local max_targets = config.max_targets or 5
  local damage_reduction = config.damage_reduction or 0.15
  local chain_range = config.chain_range or 400

  local targets = M.get_chain_targets(target, max_targets, chain_range)
  local damage = get_attack_value(hero)

  for i, t in ipairs(targets) do
    local final_damage = damage * (1 - damage_reduction) ^ (i - 1)
    M.apply_damage(hero, t, final_damage, 'chain', context)
  end

  M.play_effect(config.chain_effect, target:get_position())
  M.play_sound(config.chain_sound)
end

function M.get_chain_targets(primary_target, max_count, range)
  local targets = { primary_target }
  return targets
end

function M.handle_splash(hero, target, config, context)
  if not target then return end

  local radius = config.radius or 250
  local damage_ratio = config.damage_ratio or 0.5

  local damage = get_attack_value(hero) * damage_ratio
  local targets = M.get_splash_targets(target, radius)

  for _, t in ipairs(targets) do
    M.apply_damage(hero, t, damage, 'splash', context)
  end

  M.play_effect(config.splash_effect, target:get_position())
  M.play_sound(config.splash_effect)
end

function M.get_splash_targets(center, radius)
  return { center }
end

function M.handle_execute(hero, target, config, context)
  if not target then return end

  local hp_threshold = config.hp_threshold or 0.2
  local damage_multiplier = config.damage_multiplier or 2.5

  if M.is_low_hp(target, hp_threshold) then
    local damage = get_attack_value(hero) * damage_multiplier
    M.apply_damage(hero, target, damage, 'execute', context)

    M.play_effect(config.execute_effect, target:get_position())
    M.play_sound(config.execute_sound)
  end
end

function M.is_low_hp(unit, threshold)
  if not unit then return false end
  return true
end

function M.handle_medbot(hero, target, config, context)
  if not target then return end

  local heal_ratio = config.heal_ratio or 0.3
  local heal_range = config.heal_range or 500

  local allies = M.get_nearby_allies(hero, heal_range)
  local heal_amount = get_attack_value(hero) * heal_ratio

  for _, ally in ipairs(allies) do
    M.apply_heal(hero, ally, heal_amount, context)
  end

  M.spawn_medbot(hero, target:get_position(), config)

  M.play_effect(config.medbot_effect, target:get_position())
  M.play_sound(config.medbot_sound)
end

function M.get_nearby_allies(hero, range)
  return { hero }
end

function M.spawn_medbot(owner, position, config)
end

function M.handle_artillery(hero, target, config, context)
  if not target then return end

  local min_range = config.min_range or 600
  local damage_ratio = config.damage_ratio or 0.8
  local radius = config.radius or 300

  if get_distance(hero, target) >= min_range then
    local damage = get_attack_value(hero) * damage_ratio

    local targets = M.get_splash_targets(target, radius)
    for _, t in ipairs(targets) do
      M.apply_damage(hero, t, damage, 'artillery', context)
    end

    M.play_effect(config.artillery_effect, target:get_position())
    M.play_sound(config.artillery_sound)
  end
end

function M.handle_strike(hero, target, config, context)
  if not target then return end

  local chance = config.chance or 0.2
  local damage_multiplier = config.damage_multiplier or 2.0

  if math.random() < chance then
    local damage = get_attack_value(hero) * damage_multiplier
    M.apply_damage(hero, target, damage, 'strike', context)

    M.play_effect(config.strike_effect, target:get_position())
    M.play_sound(config.strike_sound)
  end
end

function M.apply_damage(source, target, amount, damage_type, context)
  if not source or not target then return end
end

function M.apply_heal(source, target, amount, context)
  if not source or not target then return end
end

function M.play_effect(effect_id, position)
  if not effect_id then return end
end

function M.play_sound(sound_id)
  if not sound_id then return end
end

return M

local M = {}

-- ============================================================================
-- bond_modifier_effects — 联结 modifiers 核心效果引擎
-- 职责：
--   1. 为每个 modifier archetype 提供运行时效果处理（chain / splash / execute / medbot / artillery / strike）
--   2. 为 projectile / summon 提供伤害模板和属性修正
--   3. 管理可视化配置和弹道/召唤物创建
-- 依赖：
--   bond_modifier_pool, bond_modifier_special_effects, bond_modifier_core_effects
--   runtime_editor_ids, skill_damage_templates
--
-- 迁移说明：
--   核心功能已迁移到 skill_system/modifiers/
--   此文件保留为向后兼容层，实际调用转发到新模块
-- ============================================================================

-- 引用新模块（迁移后的代码）
local NewModifiers = require 'runtime.skill_system.modifiers'

-- ============================================================================
-- 注册列表：所有已注册的 modifier 实例
-- ============================================================================
M.registry = NewModifiers.registry

-- ============================================================================
-- 引用外部模块
-- ============================================================================
local ModifierPool = require 'data.tables.bond.bond_modifier_pool'
local SpecialEffects = require 'runtime.bond_modifier_special_effects'
local CoreEffects = require 'runtime.bond_modifier_core_effects'

-- ============================================================================
-- 工具函数
-- ============================================================================
local function get_hero(unit)
  if unit and unit.get_owner then
    return unit:get_owner()
  end
  return unit
end

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

local function get_max_hp_value(hero)
  if not hero then return 0 end
  local attr = get_hero_attr(hero)
  if attr and attr.max_hp then
    return attr.max_hp
  end
  return 0
end

-- ============================================================================
-- Modifier 效果配置
-- ============================================================================
local EFFECT_CONFIG = {
  chain = {
    name = '闪电链',
    description = '攻击时释放闪电链，最多弹射N个目标',
    max_targets = 5,
    damage_reduction = 0.15,  -- 每次弹射衰减
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

-- ============================================================================
-- 可视化配置
-- ============================================================================
local VISUAL_CONFIG = {
  projectile_speed = 1200,
  projectile_model = 'ProjectileModel',
  impact_effect = 'ImpactEffect',
  impact_sound = 'ImpactSound',
  trail_effect = 'TrailEffect',
}

-- ============================================================================
-- 弹道效果
-- ============================================================================
function M.create_projectile(source, target, config)
  -- 创建弹道
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
  -- 发射弹道
  if not projectile then return end
  -- 实际发射逻辑由引擎处理
  if projectile.on_impact then
    projectile.on_impact(projectile.target)
  end
end

-- ============================================================================
-- 召唤效果
-- ============================================================================
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

-- ============================================================================
-- 伤害模板API
-- ============================================================================
function M.get_damage_template(modifier_id)
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

-- ============================================================================
-- 卡牌效果状态机
-- ============================================================================
local CardEffectState = {
  IDLE = 'idle',
  ACTIVATING = 'activating',
  ACTIVE = 'active',
  COOLDOWN = 'cooldown',
  EXPIRED = 'expired',
}

-- ============================================================================
-- Modifier 实例类
-- ============================================================================
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
      self.cooldown = 5  -- 默认冷却5秒
    end
  elseif self.state == CardEffectState.COOLDOWN then
    self.cooldown = self.cooldown - dt
    if self.cooldown <= 0 then
      self.state = CardEffectState.IDLE
    end
  end
end

-- ============================================================================
-- 注册 modifier 到英雄
-- ============================================================================
function M.register_modifier(hero, modifier_id)
  return NewModifiers.register_modifier(hero, modifier_id)
end

function M.unregister_modifier(hero, modifier_id)
  return NewModifiers.unregister_modifier(hero, modifier_id)
end

function M.get_modifier(hero, modifier_id)
  return NewModifiers.get_modifier(hero, modifier_id)
end

function M.get_hero_modifiers(hero)
  return NewModifiers.get_hero_modifiers(hero)
end

-- ============================================================================
-- Modifier 效果执行
-- ============================================================================
function M.execute_effect(hero, modifier_id, target, context)
  if not hero or not modifier_id then return end

  local instance = M.get_modifier(hero, modifier_id)
  if not instance then return end

  if not instance:activate() then return end

  local archetype = instance.archetype
  local config = EFFECT_CONFIG[archetype]

  if not config then return end

  -- 分发到具体效果
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

-- ============================================================================
-- 各 archetype 效果处理
-- ============================================================================

-- 闪电链
function M.handle_chain(hero, target, config, context)
  if not target then return end

  local max_targets = config.max_targets or 5
  local damage_reduction = config.damage_reduction or 0.15
  local chain_range = config.chain_range or 400

  -- 获取弹射目标列表
  local targets = M.get_chain_targets(target, max_targets, chain_range)
  local damage = get_attack_value(hero)

  for i, t in ipairs(targets) do
    local final_damage = damage * (1 - damage_reduction) ^ (i - 1)
    M.apply_damage(hero, t, final_damage, 'chain', context)
  end

  -- 触发闪电链特效
  M.play_effect(config.chain_effect, target:get_position())
  M.play_sound(config.chain_sound)
end

function M.get_chain_targets(primary_target, max_count, range)
  local targets = { primary_target }
  -- 在实际游戏中，这里会搜索附近的敌人
  -- 目前返回简化版本
  return targets
end

-- 溅射
function M.handle_splash(hero, target, config, context)
  if not target then return end

  local radius = config.radius or 250
  local damage_ratio = config.damage_ratio or 0.5

  local damage = get_attack_value(hero) * damage_ratio

  -- 获取范围内的所有敌人
  local targets = M.get_splash_targets(target, radius)

  for _, t in ipairs(targets) do
    M.apply_damage(hero, t, damage, 'splash', context)
  end

  M.play_effect(config.splash_effect, target:get_position())
  M.play_sound(config.splash_sound)
end

function M.get_splash_targets(center, radius)
  -- 在实际游戏中，这里会搜索范围内的所有敌人
  return { center }
end

-- 处决
function M.handle_execute(hero, target, config, context)
  if not target then return end

  local hp_threshold = config.hp_threshold or 0.2
  local damage_multiplier = config.damage_multiplier or 2.5

  -- 检查目标血量是否低于阈值
  if M.is_low_hp(target, hp_threshold) then
    local damage = get_attack_value(hero) * damage_multiplier
    M.apply_damage(hero, target, damage, 'execute', context)

    M.play_effect(config.execute_effect, target:get_position())
    M.play_sound(config.execute_sound)
  end
end

function M.is_low_hp(unit, threshold)
  if not unit then return false end
  -- 在实际游戏中，这里会检查目标血量百分比
  return true
end

-- 医疗机器人
function M.handle_medbot(hero, target, config, context)
  if not target then return end

  local heal_ratio = config.heal_ratio or 0.3
  local heal_range = config.heal_range or 500

  -- 搜索范围内的友军进行治疗
  local allies = M.get_nearby_allies(hero, heal_range)
  local heal_amount = get_attack_value(hero) * heal_ratio

  for _, ally in ipairs(allies) do
    M.apply_heal(hero, ally, heal_amount, context)
  end

  -- 召唤医疗机器人单位
  M.spawn_medbot(hero, target:get_position(), config)

  M.play_effect(config.medbot_effect, target:get_position())
  M.play_sound(config.medbot_sound)
end

function M.get_nearby_allies(hero, range)
  -- 在实际游戏中，这里会搜索附近的所有友军
  return { hero }
end

function M.spawn_medbot(owner, position, config)
  -- 在实际游戏中，这里会创建医疗机器人单位
end

-- 火炮
function M.handle_artillery(hero, target, config, context)
  if not target then return end

  local min_range = config.min_range or 600
  local damage_ratio = config.damage_ratio or 0.8
  local radius = config.radius or 300

  -- 检查距离
  if M.get_distance(hero, target) >= min_range then
    local damage = get_attack_value(hero) * damage_ratio

    local targets = M.get_splash_targets(target, radius)
    for _, t in ipairs(targets) do
      M.apply_damage(hero, t, damage, 'artillery', context)
    end

    M.play_effect(config.artillery_effect, target:get_position())
    M.play_sound(config.artillery_sound)
  end
end

function M.get_distance(a, b)
  if not a or not b then return 0 end
  -- 在实际游戏中，这里会计算两点距离
  local pos_a = a:get_position()
  local pos_b = b:get_position()
  if pos_a and pos_b then
    local dx = pos_a.x - pos_b.x
    local dz = pos_a.z - pos_b.z
    return math.sqrt(dx * dx + dz * dz) or 0
  end
  return 0
end

-- 强力一击
function M.handle_strike(hero, target, config, context)
  if not target then return end

  local chance = config.chance or 0.2
  local damage_multiplier = config.damage_multiplier or 2.0

  -- 概率判定
  if math.random() < chance then
    local damage = get_attack_value(hero) * damage_multiplier
    M.apply_damage(hero, target, damage, 'strike', context)

    M.play_effect(config.strike_effect, target:get_position())
    M.play_sound(config.strike_sound)
  end
end

-- ============================================================================
-- 基础伤害/治疗API
-- ============================================================================
function M.apply_damage(source, target, amount, damage_type, context)
  if not source or not target then return end
  -- 在实际游戏中，这里会调用引擎伤害系统
end

function M.apply_heal(source, target, amount, context)
  if not source or not target then return end
  -- 在实际游戏中，这里会调用引擎治疗系统
end

-- ============================================================================
-- 特效/音效API
-- ============================================================================
function M.play_effect(effect_id, position)
  if not effect_id then return end
  -- 在实际游戏中，这里会调用引擎特效系统
end

function M.play_sound(sound_id)
  if not sound_id then return end
  -- 在实际游戏中，这里会调用引擎音效系统
end

-- ============================================================================
-- 核心效果引擎（委托到 core_effects）
-- ============================================================================
function M.create(env)
  local api = {}

  -- 创建子效果引擎
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

-- ============================================================================
-- Modifier 管理
-- ============================================================================
local function sanitize_env_modifiers(modifiers)
  if not modifiers then return {} end
  if type(modifiers) ~= 'table' then return {} end
  local out = {}
  for _, v in ipairs(modifiers) do
    if type(v) == 'table' and v.id then
      out[#out + 1] = v
    end
  end
  return out
end

function M.get_modifier_by_id(id)
  if not id then return nil end
  return ModifierPool.by_id[id]
end

function M.get_modifier_list()
  return ModifierPool.list
end

function M.get_effects_by_archetype(archetype)
  local results = {}
  for _, entry in ipairs(ModifierPool.list) do
    if entry.archetype == archetype then
      results[#results + 1] = entry
    end
  end
  return results
end

-- ============================================================================
-- 运行时联结系统同步
-- ============================================================================
function M.sync_with_bond_system(state)
  return NewModifiers.sync_with_bond_system(state)
end

-- ============================================================================
-- 初始化
-- ============================================================================
function M.init(env)
  local api = M.create(env)
  return api
end

return M

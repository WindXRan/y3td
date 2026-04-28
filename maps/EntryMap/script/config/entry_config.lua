local battle_base = require 'entry_data.battle_base_config'
local battlefield_scene = require 'entry_data.battlefield_scene_config'
local battlefield_unit_config = require 'entry_data.battlefield_unit_config'
local global_rules = battle_base.global_rules
local hero_init_stats = battle_base.hero_init_stats
local debug_hero_bonus_stats = battle_base.debug_hero_bonus_stats
local debug_apply_hero_bonus_on_spawn = battle_base.debug_apply_hero_bonus_on_spawn
local hero_progression = battle_base.progression_rules
local hero_level_progression = battle_base.hero_level_progression
local resource_rules = battle_base.resource_rules
local challenge_rules = battle_base.challenge_rules

local DEBUG_TIME_SCALE = y3.game.is_debug_mode()
  and global_rules.debug_time_scale_debug
  or global_rules.debug_time_scale_release

local function scale(seconds)
  return seconds * DEBUG_TIME_SCALE
end

local function clamp_scale(value, default)
  local number = tonumber(value)
  if number == nil or number <= 0 then
    return default
  end
  return number
end

local function scale_positive_int(value, scale_value, default)
  local number = tonumber(value)
  if number == nil or number <= 0 then
    return default
  end
  return math.max(1, math.floor(number * scale_value + 0.5))
end

local ENEMY_MOVE_SPEED_SCALE = clamp_scale(global_rules.enemy_move_speed_scale, 1.0)
local ENEMY_SPAWN_BATCH_SCALE = clamp_scale(global_rules.enemy_spawn_batch_scale, 1.0)
local ENEMY_ALIVE_CAP_SCALE = clamp_scale(global_rules.enemy_alive_cap_scale, 1.0)
local TOTAL_ENEMY_SOFT_CAP_SCALE = clamp_scale(global_rules.total_enemy_soft_cap_scale, 1.0)

local WaveObjects = require 'entry_objects.waves'
local ChallengeObjects = require 'entry_objects.challenges'
local StageObjects = require 'entry_objects.stages'
local StageModeObjects = require 'entry_objects.stage_modes'
local MainlineTaskRewardObjects = require 'data.object_tables.mainline_task_rewards'
local ok_treasure_catalog, TreasureCatalogObjects = pcall(require, 'entry_objects.treasure_catalog')
if not ok_treasure_catalog or type(TreasureCatalogObjects) ~= 'table' then
  TreasureCatalogObjects = { list = {}, by_id = {} }
end
local ok_treasure_compat, TreasureCatalogCompatObjects = pcall(require, 'data.object_tables.treasure_catalog_compat')
if not ok_treasure_compat or type(TreasureCatalogCompatObjects) ~= 'table' then
  TreasureCatalogCompatObjects = {}
end
local OutgameAttrBonusConfig = require 'data.object_tables.outgame_attr_bonus_config'
local GearUpgradeConfig = require 'data.object_tables.gear_upgrade_config'
local SkillRuntimeTuning = require 'data.object_tables.skill_runtime_tuning'

local M = {
  debug_time_scale = DEBUG_TIME_SCALE,
  debug_auto_unlock_attack_skills_on_stage_start = y3.game.is_debug_mode(),
  enemy_hit_reaction_enabled = false,
  enemy_death_reaction_enabled = false,
  damage_hit_effect_enabled = false,
  player_id = global_rules.player_id,
  enemy_player_id = global_rules.enemy_player_id,
  total_enemy_soft_cap = scale_positive_int(global_rules.total_enemy_soft_cap, TOTAL_ENEMY_SOFT_CAP_SCALE, 40),
  enemy_move_speed_scale = ENEMY_MOVE_SPEED_SCALE,
  enemy_spawn_batch_scale = ENEMY_SPAWN_BATCH_SCALE,
  enemy_alive_cap_scale = ENEMY_ALIVE_CAP_SCALE,
  hero_init_stats = hero_init_stats,
  debug_hero_bonus_stats = debug_hero_bonus_stats,
  debug_apply_hero_bonus_on_spawn = debug_apply_hero_bonus_on_spawn,
  hero_progression = hero_progression,
  hero_level_progression = hero_level_progression,
  resource_rules = resource_rules,

  -- 当前地图里尚未发现专门的主线怪/Boss物编，这里先用现成英雄单位做临时替身，
  -- 目的是先把 5 波主线、Boss 和挑战流程跑通，后续再替换成正式怪物资源。
  temp_unit_labels = battlefield_unit_config.temp_unit_labels,

  unit_ids = {
    hero = battlefield_unit_config.fixed_unit_ids.hero,
    main_monsters = {},
    bosses = {},
  },

  points = battlefield_scene.points,

  areas = battlefield_scene.areas,

  main_enemy_slow_zones = battlefield_scene.main_enemy_slow_zones,

  challenge_rules = {
    max_charges = challenge_rules.max_charges,
    initial_charges = challenge_rules.initial_charges,
    recover_sec = scale(challenge_rules.recover_sec),
  },

  save_slots = battlefield_scene.save_slots,

  waves = WaveObjects.list,

  challenges = ChallengeObjects.by_id,
  stages = StageObjects,
  stage_modes = StageModeObjects,
  mainline_task_rewards = MainlineTaskRewardObjects,
  treasure_catalog = TreasureCatalogObjects,
  treasure_catalog_compat = TreasureCatalogCompatObjects,
  outgame_attr_bonus_config = OutgameAttrBonusConfig,
  gear_upgrade_config = GearUpgradeConfig,
  skill_runtime_tuning = SkillRuntimeTuning,
  attack_skill_runtime_tuning = SkillRuntimeTuning.attack or {},
  bond_skill_runtime_tuning = SkillRuntimeTuning.bond or {},
}

for _, wave in ipairs(M.waves) do
  M.unit_ids.main_monsters[wave.id] = wave.main_unit_id
  M.unit_ids.bosses[wave.id] = wave.boss_unit_id
end

return M

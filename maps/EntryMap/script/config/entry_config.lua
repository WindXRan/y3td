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

local WaveObjects = require 'entry_objects.waves'
local ChallengeObjects = require 'entry_objects.challenges'
local StageObjects = require 'entry_objects.stages'
local StageModeObjects = require 'entry_objects.stage_modes'
local MainlineTaskRewardObjects = require 'data.object_tables.mainline_task_rewards'
local TreasureCatalogObjects = require 'entry_objects.treasure_catalog'
local TreasureCatalogCompatObjects = require 'data.object_tables.treasure_catalog_compat'
local OutgameAttrBonusConfig = require 'data.object_tables.outgame_attr_bonus_config'
local GearUpgradeConfig = require 'data.object_tables.gear_upgrade_config'

local M = {
  debug_time_scale = DEBUG_TIME_SCALE,
  debug_auto_unlock_attack_skills_on_stage_start = y3.game.is_debug_mode(),
  player_id = global_rules.player_id,
  enemy_player_id = global_rules.enemy_player_id,
  total_enemy_soft_cap = global_rules.total_enemy_soft_cap,
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
}

for _, wave in ipairs(M.waves) do
  M.unit_ids.main_monsters[wave.id] = wave.main_unit_id
  M.unit_ids.bosses[wave.id] = wave.boss_unit_id
end

return M

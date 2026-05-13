local GameTables = require 'data.game_tables'
local battle_base = GameTables.battle_base_config
local battlefield_scene = GameTables.battlefield_scene_config
local battlefield_unit_config = GameTables.battlefield_unit_config
local monster_type_config = GameTables.monster_type_config
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

local WaveObjects = GameTables.waves
local ChallengeObjects = GameTables.challenges
local StageObjects = GameTables.stages
local StageModeObjects = GameTables.stage_modes
local MainlineTaskRewardObjects = GameTables.mainline_task_rewards
local HeroRoster = GameTables.hero_roster
local OutgameAttrBonusConfig = require 'data.tables.outgame.outgame_attr_bonus_config'
local OutgameTopEntryList = require 'data.tables.outgame.outgame_top_entry_list'
local OutgameArchiveRankingTabs = require 'data.tables.outgame.archive_ranking_tabs'
local OutgameDetailConfig = require 'data.tables.outgame.outgame_detail_config'
local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'
local GearUpgradeConfig = require 'data.tables.economy.gear_upgrade_config'
local SkillRuntimeTuning = require 'data.tables.skill.skill_runtime_tuning'
local ATTACK_SKILL_DEPRECATED = true

local M = {
  debug_time_scale = DEBUG_TIME_SCALE,
  attack_skill_deprecated = ATTACK_SKILL_DEPRECATED,
  debug_auto_unlock_attack_skills_on_stage_start = (not ATTACK_SKILL_DEPRECATED) and y3.game.is_debug_mode(),
  enemy_hit_reaction_enabled = false,
  enemy_death_reaction_enabled = true,
  enemy_main_death_reaction_enabled = true,
  enemy_main_death_sound_enabled = true,
  damage_hit_effect_enabled = false,
  monster_type_config = monster_type_config,
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

  unit_ids = {
    hero = battlefield_unit_config.fixed_unit_ids.hero,
    main_monsters = {},
    bosses = {},
  },
  hero_fallback_unit_id = battlefield_unit_config.fixed_unit_ids.hero,
  fixed_enemy_spawn_unit_id = battlefield_unit_config.fixed_unit_ids.enemy,

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
  outgame_attr_bonus_config = OutgameAttrBonusConfig,
  outgame_top_entry_list = OutgameTopEntryList,
  outgame_archive_ranking_tabs = OutgameArchiveRankingTabs,
  outgame_detail_config = OutgameDetailConfig,
  archive_tab_definitions = ArchiveTabDefinitions,
  GameTables = GameTables,
  gear_upgrade_config = GearUpgradeConfig,
  skill_runtime_tuning = SkillRuntimeTuning,
  attack_skill_runtime_tuning = SkillRuntimeTuning.attack or {},
  bond_skill_runtime_tuning = SkillRuntimeTuning.bond or {},
}

for _, wave in ipairs(M.waves) do
  if wave and wave.id ~= nil and wave.id ~= '' then
    M.unit_ids.main_monsters[wave.id] = wave.main_template_unit_id
    M.unit_ids.bosses[wave.id] = wave.boss_template_unit_id
  end
end

return M




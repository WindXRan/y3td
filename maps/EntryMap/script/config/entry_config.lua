local battle_base = require 'entry_data.battle_base_config'
local global_rules = battle_base.global_rules
local hero_init_stats = battle_base.hero_init_stats
local debug_hero_bonus_stats = battle_base.debug_hero_bonus_stats
local hero_progression = battle_base.progression_rules
local resource_rules = battle_base.resource_rules
local challenge_rules = battle_base.challenge_rules

local DEBUG_TIME_SCALE = y3.game.is_debug_mode()
  and global_rules.debug_time_scale_debug
  or global_rules.debug_time_scale_release

local function scale(seconds)
  return seconds * DEBUG_TIME_SCALE
end

local function segment(start_sec, interval_sec)
  return {
    start_sec = scale(start_sec),
    interval_sec = scale(interval_sec),
  }
end

local function challenge_batch(time_sec, count)
  return {
    time_sec = scale(time_sec),
    count = count,
  }
end

local WaveObjects = require 'entry_objects.waves'
local ChallengeObjects = require 'entry_objects.challenges'
local StageObjects = require 'entry_objects.stages'
local StageModeObjects = require 'entry_objects.stage_modes'

local M = {
  debug_time_scale = DEBUG_TIME_SCALE,
  player_id = global_rules.player_id,
  enemy_player_id = global_rules.enemy_player_id,
  total_enemy_soft_cap = global_rules.total_enemy_soft_cap,
  hero_init_stats = hero_init_stats,
  debug_hero_bonus_stats = debug_hero_bonus_stats,
  hero_progression = hero_progression,
  resource_rules = resource_rules,

  -- 当前地图里尚未发现专门的主线怪/Boss物编，这里先用现成英雄单位做临时替身，
  -- 目的是先把 5 波主线、Boss 和挑战流程跑通，后续再替换成正式怪物资源。
  temp_unit_labels = {
    hero = '关羽',
    wave_1_main = '刘备',
    wave_2_main = '孟获',
    wave_3_main = '孙尚香',
    wave_4_main = '赵云',
    wave_5_main = '吕布',
    wave_1_boss = '张飞',
    wave_2_boss = '孙策',
    wave_3_boss = '黄月英',
    wave_4_boss = '吕布',
    wave_5_boss = '赵云',
    gold_trial = '孙尚香',
    wood_trial = '孟获',
    exp_trial = '黄忠',
    treasure_trial_boss = '吕布',
    treasure_trial_guard = '刘备',
  },

  unit_ids = {
    hero = 134274912,
    main_monsters = {},
    bosses = {},
    challenges = {
      gold = 134242543,
      wood = 134224570,
      exp = 134275571,
      treasure_boss = 134228855,
      treasure_guard = 134241735,
    },
  },

  points = {
    hero_spawn = { x = -1200, y = 0, z = 0 },
    defense_point = { x = -1050, y = 0, z = 0 },
  },

  areas = {
    main_spawn_wave_1 = { x_min = 1200, x_max = 1480, y_min = -180, y_max = 180, z = 0 },
    main_spawn_wave_2 = { x_min = 1200, x_max = 1480, y_min = -220, y_max = 220, z = 0 },
    main_spawn_wave_3 = { x_min = 1220, x_max = 1500, y_min = -260, y_max = 260, z = 0 },
    main_spawn_wave_4 = { x_min = 1240, x_max = 1520, y_min = -300, y_max = 300, z = 0 },
    main_spawn_wave_5 = { x_min = 1260, x_max = 1540, y_min = -320, y_max = 320, z = 0 },

    boss_spawn_wave_1 = { x_min = 1120, x_max = 1260, y_min = -90, y_max = 90, z = 0 },
    boss_spawn_wave_2 = { x_min = 1140, x_max = 1280, y_min = -110, y_max = 110, z = 0 },
    boss_spawn_wave_3 = { x_min = 1160, x_max = 1300, y_min = -130, y_max = 130, z = 0 },
    boss_spawn_wave_4 = { x_min = 1180, x_max = 1320, y_min = -150, y_max = 150, z = 0 },
    boss_spawn_wave_5 = { x_min = 1200, x_max = 1340, y_min = -170, y_max = 170, z = 0 },

    challenge_spawn_top = { x_min = 1180, x_max = 1450, y_min = 220, y_max = 420, z = 0 },
    challenge_spawn_mid = { x_min = 1220, x_max = 1490, y_min = -80, y_max = 120, z = 0 },
    challenge_spawn_bottom = { x_min = 1180, x_max = 1450, y_min = -420, y_max = -220, z = 0 },
    challenge_treasure_elite_spawn = { x_min = 1240, x_max = 1380, y_min = -60, y_max = 60, z = 0 },
  },

  challenge_rules = {
    max_charges = challenge_rules.max_charges,
    initial_charges = challenge_rules.initial_charges,
    recover_sec = scale(challenge_rules.recover_sec),
  },

  save_slots = {
    outgame_profile = 1,
  },

  waves = WaveObjects.list,

  challenges = ChallengeObjects.by_id,
  stages = StageObjects,
  stage_modes = StageModeObjects,
}

for _, wave in ipairs(M.waves) do
  M.unit_ids.main_monsters[wave.id] = wave.main_unit_id
  M.unit_ids.bosses[wave.id] = wave.boss_unit_id
end

return M

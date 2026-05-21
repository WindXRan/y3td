local CsvLoader = require 'data.csv_loader'
local MonsterTypeConfig = require 'data.tables.battle.monster_type_config'
local hero_attr_config = require 'data.tables.hero.hero_attr_config'
local hero_level_progression = require 'data.tables.hero.hero_level_progression'

local DEFAULT_HERO_INIT_STATS = {
  ['生命基础值'] = 1000,
  ['攻击基础值'] = 100,
  ['护甲基础值'] = 50,
  ['攻击'] = 0,
  ['生命'] = 0,
  ['护甲'] = 0,
}

local M = {}

local function to_number(value, default)
  local num = tonumber(value)
  return num ~= nil and num or default
end

local function to_boolean(value)
  if value == nil or value == '' then return false end
  return value == 'true' or value == 'TRUE' or value == '1'
end

local DEBUG_TIME_SCALE = y3.game.is_debug_mode() and 0.2 or 1.0
local function scale(seconds) return seconds * DEBUG_TIME_SCALE end

local function clamp_scale(value, default)
  local number = tonumber(value)
  return (number and number > 0) and number or default
end

local function scale_positive_int(value, scale_value, default)
  local number = tonumber(value)
  if not number or number <= 0 then return default end
  return math.max(1, math.floor(number * scale_value + 0.5))
end

local battle_base_config = {
  global_rules = {},
  hero_init_stats = hero_attr_config.hero_init_stats or DEFAULT_HERO_INIT_STATS,
  debug_hero_bonus_stats = hero_attr_config.debug_hero_bonus_stats or {},
  debug_apply_hero_bonus_on_spawn = false,
  progression_rules = {},
  hero_level_progression = hero_level_progression,
  resource_rules = {},
  challenge_rules = {},
}

local base_config_rows = CsvLoader.read_rows({path = 'data_csv/battle_base_config.csv'})
for _, row in ipairs(base_config_rows) do
  local key, value = row['key'], row['value']
  if key and key ~= '' and key ~= '__字段说明__' then
    if key == 'debug_time_scale_debug' then
      battle_base_config.global_rules.debug_time_scale_debug = to_number(value, 0.2)
    elseif key == 'debug_time_scale_release' then
      battle_base_config.global_rules.debug_time_scale_release = to_number(value, 1.0)
    elseif key == 'enemy_player_id' then
      battle_base_config.global_rules.enemy_player_id = to_number(value, 31)
    elseif key == 'enemy_move_speed_scale' then
      battle_base_config.global_rules.enemy_move_speed_scale = to_number(value, 0.48)
    elseif key == 'enemy_spawn_batch_scale' then
      battle_base_config.global_rules.enemy_spawn_batch_scale = to_number(value, 1.5)
    elseif key == 'enemy_alive_cap_scale' then
      battle_base_config.global_rules.enemy_alive_cap_scale = to_number(value, 1.5)
    elseif key == 'player_id' then
      battle_base_config.global_rules.player_id = to_number(value, 1)
    elseif key == 'total_enemy_soft_cap_scale' then
      battle_base_config.global_rules.total_enemy_soft_cap_scale = to_number(value, 1.5)
    elseif key == 'total_enemy_soft_cap' then
      battle_base_config.global_rules.total_enemy_soft_cap = to_number(value, 40)
    elseif key == 'debug_apply_hero_bonus_on_spawn' then
      battle_base_config.debug_apply_hero_bonus_on_spawn = to_boolean(value)
    elseif key == 'engine_exp_cap_level' then
      battle_base_config.progression_rules.engine_exp_cap_level = to_number(value, 1)
    elseif key == 'max_level' then
      battle_base_config.progression_rules.max_level = to_number(value, 60)
    elseif key == 'post_cap_exp_base' then
      battle_base_config.progression_rules.post_cap_exp_base = to_number(value, 320)
    elseif key == 'post_cap_exp_step' then
      battle_base_config.progression_rules.post_cap_exp_step = to_number(value, 55)
    elseif key == 'hero_level_attack_growth' then
      battle_base_config.progression_rules.hero_level_attack_growth = to_number(value, 6)
    elseif key == 'hero_level_hp_growth' then
      battle_base_config.progression_rules.hero_level_hp_growth = to_number(value, 60)
    elseif key == 'hero_level_all_attr_growth' then
      battle_base_config.progression_rules.hero_level_all_attr_growth = to_number(value, 2)
    elseif key == 'main_stat_attack_ratio' then
      battle_base_config.progression_rules.main_stat_attack_ratio = to_number(value, 0.5)
    elseif key == 'gold_per_sec' then
      battle_base_config.resource_rules.gold_per_sec = to_number(value, 2)
    elseif key == 'initial_gold' then
      battle_base_config.resource_rules.initial_gold = to_number(value, 0)
    elseif key == 'initial_wood' then
      battle_base_config.resource_rules.initial_wood = to_number(value, 500)
    elseif key == 'wood_per_sec' then
      battle_base_config.resource_rules.wood_per_sec = to_number(value, 1)
    elseif key == 'challenge_initial_charges' then
      battle_base_config.challenge_rules.initial_charges = to_number(value, 1)
    elseif key == 'challenge_max_charges' then
      battle_base_config.challenge_rules.max_charges = to_number(value, 3)
    elseif key == 'challenge_recover_sec' then
      battle_base_config.challenge_rules.recover_sec = scale(to_number(value, 105))
    end
  end
end

local global_rules = battle_base_config.global_rules
local hero_init_stats = battle_base_config.hero_init_stats
local debug_hero_bonus_stats = battle_base_config.debug_hero_bonus_stats
local debug_apply_hero_bonus_on_spawn = battle_base_config.debug_apply_hero_bonus_on_spawn
local hero_progression = battle_base_config.progression_rules
local hero_level_progression = battle_base_config.hero_level_progression
local resource_rules = battle_base_config.resource_rules
local challenge_rules = battle_base_config.challenge_rules

local DEBUG_TIME_SCALE_VALUE = y3.game.is_debug_mode()
  and global_rules.debug_time_scale_debug
  or global_rules.debug_time_scale_release

local ENEMY_MOVE_SPEED_SCALE = clamp_scale(global_rules.enemy_move_speed_scale, 1.0)
local ENEMY_SPAWN_BATCH_SCALE = clamp_scale(global_rules.enemy_spawn_batch_scale, 1.0)
local ENEMY_ALIVE_CAP_SCALE = clamp_scale(global_rules.enemy_alive_cap_scale, 1.0)
local TOTAL_ENEMY_SOFT_CAP_SCALE = clamp_scale(global_rules.total_enemy_soft_cap_scale, 1.0)

local battlefield_scene_config = { points = {}, areas = {}, main_enemy_slow_zones = {}, save_slots = {} }
local scene_rows = CsvLoader.read_rows({path = 'data_csv/battlefield_scene_config.csv'})
for _, row in ipairs(scene_rows) do
  local type, id = row['type'], row['id']
  if type and type ~= '' and type ~= '__字段说明__' then
    if type == 'point' then
      battlefield_scene_config.points[id] = { x = to_number(row['x'], 0), y = to_number(row['y'], 0), z = to_number(row['z'], 0) }
    elseif type == 'area' then
      battlefield_scene_config.areas[id] = { x_min = to_number(row['x_min'], 0), x_max = to_number(row['x_max'], 0), y_min = to_number(row['y_min'], 0), y_max = to_number(row['y_max'], 0), z = to_number(row['z'], 0) }
    elseif type == 'slow_zone' then
      battlefield_scene_config.main_enemy_slow_zones[#battlefield_scene_config.main_enemy_slow_zones + 1] = { area_id = id, speed_factor = to_number(row['speed_factor'], 1.0) }
    elseif type == 'save_slot' then
      battlefield_scene_config.save_slots[id] = to_number(row['x'], 1)
    end
  end
end

local battlefield_unit_config = { fixed_unit_ids = {}, fixed_model_ids = {} }
local unit_rows = CsvLoader.read_rows({path = 'data_csv/battlefield_unit_config.csv'})
for _, row in ipairs(unit_rows) do
  local type = row['type']
  local unit_id = to_number(row['unit_id'])
  local model_id = to_number(row['model_id'])
  if type and type ~= '' and type ~= '__字段说明__' then
    battlefield_unit_config.fixed_unit_ids[type] = unit_id
    if model_id then battlefield_unit_config.fixed_model_ids[type] = model_id end
  end
end

local function list_to_map(list, key)
  local out = {}
  key = key or 'id'
  for _, row in ipairs(list or {}) do
    local k = row and row[key]
    if k ~= nil and k ~= '' then out[k] = row end
  end
  return out
end

local function process_csv_rows(csv_path, order_key, builder)
  local rows = CsvLoader.read_rows({path = csv_path})
  local list = {}
  for _, row in ipairs(rows) do list[#list + 1] = builder(row) end
  if order_key then
    table.sort(list, function(a, b) return (a[order_key] or 0) < (b[order_key] or 0) end)
  end
  return { list = list, by_id = list_to_map(list) }
end

local function to_optional_number(raw)
  if raw == nil or raw == '' then return nil end
  return tonumber(raw) or raw
end

local function listnum(raw)
  if raw == nil or raw == '' then return nil end
  local t = {}
  for part in tostring(raw):gmatch('[^|,]+') do
    local n = tonumber(part); if n and n > 0 then t[#t + 1] = n end
  end
  return #t > 0 and t or nil
end

local function build_reward(row, prefix)
  return { exp = tonumber(row[prefix .. '_exp']) or 0, gold = tonumber(row[prefix .. '_gold']) or 0, wood = tonumber(row[prefix .. '_wood']) or 0 }
end

local function build_attr_overrides(row, prefix)
  local r = {}
  if tonumber(row[prefix .. '_hp_max']) then r['最大生命'] = tonumber(row[prefix .. '_hp_max']) end
  if tonumber(row[prefix .. '_attack']) then r['攻击'] = tonumber(row[prefix .. '_attack']) end
  if tonumber(row[prefix .. '_armor']) then r['护甲'] = tonumber(row[prefix .. '_armor']) end
  return next(r) and r or nil
end

local function split_mode_ids(raw)
  local mode_ids = {}
  for mode_id in tostring(raw or ''):gmatch('[^|]+') do
    if mode_id ~= '' then mode_ids[#mode_ids + 1] = mode_id end
  end
  if #mode_ids == 0 then mode_ids[1] = 'standard' end
  return mode_ids
end

local WaveObjects = process_csv_rows('data_csv/waves.csv', 'index', function(row)
  local seg = {}
  for i = 1, 3 do
    local s, it = row['segment' .. i .. '_start_sec'], row['segment' .. i .. '_interval_sec']
    if s ~= '' and it ~= '' then seg[#seg + 1] = { start_sec = scale(tonumber(s) or 0), interval_sec = scale(tonumber(it) or 0) } end
  end
  return {
    id = row.id, index = tonumber(row.index) or 0, name = row.name,
    spawn_area_id = row.spawn_area_id, boss_spawn_area_id = row.boss_spawn_area_id,
    boss_spawn_sec = scale(tonumber(row.boss_spawn_sec) or 0),
    batch_min = tonumber(row.batch_min) or 0, batch_max = tonumber(row.batch_max) or 0, max_alive = tonumber(row.max_alive) or 0,
    spawn_segments = seg, post_boss_interval_sec = scale(tonumber(row.post_boss_interval_sec) or 0),
    main_attr_overrides = build_attr_overrides(row, 'main'), boss_attr_overrides = build_attr_overrides(row, 'boss'),
    main_spawn_hp = to_optional_number(row.main_spawn_hp) or tonumber(row.main_hp_max), boss_spawn_hp = tonumber(row.boss_hp_max),
    main_kill_reward = build_reward(row, 'main_kill_reward'), boss_kill_reward = build_reward(row, 'boss_kill_reward'),
    main_model_id = tonumber(row.main_model_id) or nil, boss_model_id = tonumber(row.boss_model_id) or nil,
    main_template_unit_id = tonumber(row.main_template_unit_id) or nil, boss_template_unit_id = tonumber(row.boss_template_unit_id) or nil,
    main_extra_ability_ids = listnum(row.main_extra_ability_ids), boss_extra_ability_ids = listnum(row.boss_extra_ability_ids),
  }
end)

local ChallengeObjects = process_csv_rows('data_csv/challenges.csv', 'order_index', function(row)
  local count = tonumber(row.batch_count) or 0
  return {
    id = row.id, name = row.name,
    hotkey = row.hotkey ~= '' and row.hotkey or nil,
    duration_sec = scale(tonumber(row.duration_sec) or 0), recover_sec = scale(tonumber(row.recover_sec) or 0),
    cost_charge = tonumber(row.cost_charge) or 0, spawn_area_id = row.spawn_area_id,
    reward = { gold = tonumber(row.reward_gold) or 0, wood = tonumber(row.reward_wood) or 0, exp = tonumber(row.reward_exp) or 0, special = row.reward_special ~= '' and row.reward_special or nil },
    kill_reward = { gold = tonumber(row.kill_reward_gold) or 0, wood = tonumber(row.kill_reward_wood) or 0, exp = tonumber(row.kill_reward_exp) or 0, special = row.kill_reward_special ~= '' and row.kill_reward_special or nil },
    unit_id = to_optional_number(row.unit_id), boss_unit_id = to_optional_number(row.boss_unit_id), guard_unit_id = to_optional_number(row.guard_unit_id),
    batches = count > 0 and { { time_sec = scale(tonumber(row.batch_time_sec) or 0), count = count } } or {},
    order_index = tonumber(row.order_index) or 0,
  }
end)

local roster_rows = CsvLoader.read_rows({path = 'data_csv/hero_roster.csv'})
local hero_list, initial = {}, nil
for _, row in ipairs(roster_rows) do
  local e = {
    id = row.id, order_index = tonumber(row.order_index) or 0, rarity = row.rarity, name = row.name,
    model_id = to_optional_number(row.model_id),
    is_initial_hero = ({ ['1'] = true, ['true'] = true, ['yes'] = true })[string.lower(tostring(row.is_initial_hero or ''))] == true,
    skill_id = row.skill_id, summary = row.summary, bg = row.bg,
    talent_skill = row.talent_skill or row.summary or '',
    icon = to_optional_number(row.icon),
  }
  hero_list[#hero_list + 1] = e
  if e.is_initial_hero and not initial then initial = e end
end
table.sort(hero_list, function(a, b)
  if (a.order_index or 0) == (b.order_index or 0) then return tostring(a.id or '') < tostring(b.id or '') end
  return (a.order_index or 0) < (b.order_index or 0)
end)
if not initial then for _, e in ipairs(hero_list) do if e.is_initial_hero then initial = e break end end end
local HeroRoster = { list = hero_list, by_id = list_to_map(hero_list), initial_hero = initial }

local OutgameTopEntryList = require 'data.tables.outgame.outgame_top_entry_list'
local OutgameArchiveRankingTabs = pcall(require, 'data.tables.outgame.outgame_archive_ranking_tabs') and require('data.tables.outgame.outgame_archive_ranking_tabs') or {}
local OutgameDetailConfig = pcall(require, 'data.tables.outgame.outgame_detail_config') and require('data.tables.outgame.outgame_detail_config') or {}
local ArchiveTabDefinitions = pcall(require, 'data.tables.archive_tab_definitions') and require('data.tables.archive_tab_definitions') or {}
local GearUpgradeConfig = pcall(require, 'data.tables.economy.gear_upgrade_config') and require('data.tables.economy.gear_upgrade_config') or {}
local SkillRuntimeTuning = pcall(require, 'data.tables.skill.skill_runtime_tuning') and require('data.tables.skill.skill_runtime_tuning') or {}
local ATTACK_SKILL_DEPRECATED = false

M.debug_time_scale = DEBUG_TIME_SCALE_VALUE
M.attack_skill_deprecated = ATTACK_SKILL_DEPRECATED
M.debug_auto_unlock_attack_skills_on_stage_start = (not ATTACK_SKILL_DEPRECATED) and y3.game.is_debug_mode()
M.enemy_hit_reaction_enabled = false
M.enemy_death_reaction_enabled = true
M.enemy_main_death_reaction_enabled = true
M.enemy_main_death_sound_enabled = true
M.damage_hit_effect_enabled = false
M.monster_type_config = MonsterTypeConfig
M.player_id = global_rules.player_id
M.enemy_player_id = global_rules.enemy_player_id
M.total_enemy_soft_cap = scale_positive_int(global_rules.total_enemy_soft_cap, TOTAL_ENEMY_SOFT_CAP_SCALE, 40)
M.enemy_move_speed_scale = ENEMY_MOVE_SPEED_SCALE
M.enemy_spawn_batch_scale = ENEMY_SPAWN_BATCH_SCALE
M.enemy_alive_cap_scale = ENEMY_ALIVE_CAP_SCALE
M.hero_init_stats = hero_init_stats
M.debug_hero_bonus_stats = debug_hero_bonus_stats
M.debug_apply_hero_bonus_on_spawn = debug_apply_hero_bonus_on_spawn
M.hero_progression = hero_progression
M.hero_level_progression = hero_level_progression
M.resource_rules = resource_rules

M.unit_ids = {
  hero = battlefield_unit_config.fixed_unit_ids.hero,
  hero_model = battlefield_unit_config.fixed_model_ids.hero,
  main_monsters = {},
  bosses = {},
}
M.hero_fallback_unit_id = battlefield_unit_config.fixed_unit_ids.hero
M.fixed_enemy_spawn_unit_id = battlefield_unit_config.fixed_unit_ids.enemy

M._debug = {
  fixed_unit_ids_hero = battlefield_unit_config.fixed_unit_ids.hero,
  fixed_model_ids_hero = battlefield_unit_config.fixed_model_ids.hero,
}

M.points = battlefield_scene_config.points
M.areas = battlefield_scene_config.areas
M.main_enemy_slow_zones = battlefield_scene_config.main_enemy_slow_zones

M.challenge_rules = {
  max_charges = challenge_rules.max_charges,
  initial_charges = challenge_rules.initial_charges,
  recover_sec = scale(challenge_rules.recover_sec),
}

M.save_slots = battlefield_scene_config.save_slots
M.waves = WaveObjects.list
M.challenges = ChallengeObjects.by_id
M.outgame_top_entry_list = OutgameTopEntryList
M.outgame_archive_ranking_tabs = OutgameArchiveRankingTabs
M.outgame_detail_config = OutgameDetailConfig
M.archive_tab_definitions = ArchiveTabDefinitions
M.gear_upgrade_config = GearUpgradeConfig
M.skill_runtime_tuning = SkillRuntimeTuning
M.attack_skill_runtime_tuning = SkillRuntimeTuning.attack or {}

for _, wave in ipairs(M.waves) do
  if wave and wave.id ~= nil and wave.id ~= '' then
    M.unit_ids.main_monsters[wave.id] = wave.main_template_unit_id
    M.unit_ids.bosses[wave.id] = wave.boss_template_unit_id
  end
end

return M
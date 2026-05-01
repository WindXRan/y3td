package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local CsvLoader = require 'data.csv_loader'
local attreffect = require 'data.tables.attreffect'
local waves = (require 'data.game_tables').waves
local challenges = (require 'data.game_tables').challenges
local battlefield_scene_config = (require 'data.game_tables').battlefield_scene_config
local battle_base_config = (require 'data.game_tables').battle_base_config
local stages = (require 'data.game_tables').stages
local stage_modes = (require 'data.game_tables').stage_modes
local hero_attr_defs = require 'runtime.hero_attr_defs'

local hero_attr_rows = CsvLoader.read_rows('data_csv/hero_attr_config.csv')
local hero_init_rows = CsvLoader.read_rows('data_csv/hero_init_stats.csv')
local hero_level_progression_rows = CsvLoader.read_rows('data_csv/hero_level_progression.csv')
local gear_upgrade_slot_rows = CsvLoader.read_rows('data_csv/gear_upgrade_slots.csv')
local gear_upgrade_level_rows = CsvLoader.read_rows('data_csv/gear_upgrade_levels.csv')

local seen_hero_attr_keys = {}
for _, row in ipairs(hero_attr_rows) do
  assert(row.scope ~= nil and row.scope ~= '', 'expected hero_attr_config scope')
  assert(row.key ~= nil and row.key ~= '', 'expected hero_attr_config key')
  local scoped_key = row.scope .. '::' .. row.key
  assert(seen_hero_attr_keys[scoped_key] == nil, 'expected unique hero_attr_config scoped key: ' .. scoped_key)
  seen_hero_attr_keys[scoped_key] = true
end

local seen_hero_init_keys = {}
for _, row in ipairs(hero_init_rows) do
  assert(row.key ~= nil and row.key ~= '', 'expected hero_init_stats key')
  assert(row.value ~= nil and row.value ~= '', 'expected hero_init_stats value')
  assert(seen_hero_init_keys[row.key] == nil, 'expected unique hero_init_stats key: ' .. tostring(row.key))
  seen_hero_init_keys[row.key] = true
end

local expected_level = 1
for _, row in ipairs(hero_level_progression_rows) do
  assert(row.level ~= nil and row.level ~= '', 'expected hero_level_progression level')
  assert(tonumber(row.level) == expected_level, 'expected hero_level_progression levels to stay continuous from 1')
  assert(row.order_index ~= nil and row.order_index ~= '', 'expected hero_level_progression order_index')
  assert(tonumber(row.order_index) == expected_level, 'expected hero_level_progression order_index to match level')
  assert(row.exp_to_next ~= nil and row.exp_to_next ~= '', 'expected hero_level_progression exp_to_next')
  assert(row.all_attr_bonus ~= nil and row.all_attr_bonus ~= '', 'expected hero_level_progression all_attr_bonus')
  assert(row.all_element_damage_bonus ~= nil and row.all_element_damage_bonus ~= '', 'expected hero_level_progression all_element_damage_bonus')
  expected_level = expected_level + 1
end
assert(expected_level == 61, 'expected hero_level_progression to cover levels 1-60')

assert(type(battle_base_config.global_rules) == 'table', 'expected battle_base_config.global_rules')
assert(type(battle_base_config.progression_rules) == 'table', 'expected battle_base_config.progression_rules')
assert(type(battle_base_config.resource_rules) == 'table', 'expected battle_base_config.resource_rules')
assert(type(battle_base_config.challenge_rules) == 'table', 'expected battle_base_config.challenge_rules')
assert(type(battle_base_config.hero_level_progression) == 'table', 'expected battle_base_config.hero_level_progression')

local stage_ids = {}
for _, stage in ipairs(stages.list or {}) do
  stage_ids[stage.stage_id] = true
end

local mode_ids = {}
for _, mode in ipairs(stage_modes.list or {}) do
  mode_ids[mode.mode_id] = true
end

local seen_outgame_attr_bonus_keys = {}
for source_id, bucket in pairs(attreffect.by_source.outgame_bonus or {}) do
  local stage_id, mode_id = tostring(source_id):match('^(.-):(.-)$')
  assert(stage_id ~= nil and stage_ids[stage_id] == true, 'expected outgame_bonus stage to exist: ' .. tostring(source_id))
  assert(mode_id ~= nil and mode_ids[mode_id] == true, 'expected outgame_bonus mode to exist: ' .. tostring(source_id))
  for _, row in ipairs(bucket.ordered or {}) do
    assert(row.effect_kind == 'attr', 'expected outgame_bonus rows to stay attr-only')
    assert(hero_attr_defs.by_name[row.effect_key] ~= nil, 'expected outgame attr key to exist: ' .. tostring(row.effect_key))
    local scoped_key = stage_id .. '::' .. mode_id .. '::' .. row.effect_key
    assert(seen_outgame_attr_bonus_keys[scoped_key] == nil, 'expected unique outgame_bonus scoped key: ' .. scoped_key)
    seen_outgame_attr_bonus_keys[scoped_key] = true
  end
end

local seen_gear_slots = {}
for _, row in ipairs(gear_upgrade_slot_rows) do
  assert(row.slot ~= nil and row.slot ~= '', 'expected gear_upgrade_slots slot')
  assert(seen_gear_slots[row.slot] == nil, 'expected unique gear_upgrade_slots slot: ' .. tostring(row.slot))
  seen_gear_slots[row.slot] = true
  assert(row.order_index ~= nil and row.order_index ~= '', 'expected gear_upgrade_slots order_index')
  assert(row.display_name ~= nil and row.display_name ~= '', 'expected gear_upgrade_slots display_name')
  assert(row.max_level ~= nil and row.max_level ~= '', 'expected gear_upgrade_slots max_level')
  assert(row.affix_choice_count ~= nil and row.affix_choice_count ~= '', 'expected gear_upgrade_slots affix_choice_count')
  assert(row.item_key ~= nil and row.item_key ~= '', 'expected gear_upgrade_slots item_key')
end
assert(seen_gear_slots.weapon == true, 'expected gear_upgrade_slots to keep weapon slot')
assert(next(seen_gear_slots, 'weapon') == nil, 'expected gear_upgrade_slots to keep only one slot')

local expected_gear_level = 1
for _, row in ipairs(gear_upgrade_level_rows) do
  assert(row.level ~= nil and row.level ~= '', 'expected gear_upgrade_levels level')
  assert(tonumber(row.level) == expected_gear_level, 'expected gear_upgrade_levels levels to stay continuous from 1')
  assert(row.order_index ~= nil and row.order_index ~= '', 'expected gear_upgrade_levels order_index')
  assert(tonumber(row.order_index) == expected_gear_level, 'expected gear_upgrade_levels order_index to match level')
  assert(row.gold_cost ~= nil and row.gold_cost ~= '', 'expected gear_upgrade_levels gold_cost')
  assert(row.is_affix_node ~= nil and row.is_affix_node ~= '', 'expected gear_upgrade_levels is_affix_node')
  expected_gear_level = expected_gear_level + 1
end
assert(expected_gear_level == 101, 'expected gear_upgrade_levels to cover levels 1-100')

local scene_area_ids = {}
local scene_point_ids = {}
local scene_save_slot_ids = {}
for point_id, _ in pairs(battlefield_scene_config.points or {}) do
  assert(scene_point_ids[point_id] == nil, 'expected unique battlefield point id: ' .. tostring(point_id))
  scene_point_ids[point_id] = true
end
for area_id, _ in pairs(battlefield_scene_config.areas or {}) do
  assert(scene_area_ids[area_id] == nil, 'expected unique battlefield area id: ' .. tostring(area_id))
  scene_area_ids[area_id] = true
end
for _, zone in ipairs(battlefield_scene_config.main_enemy_slow_zones or {}) do
  assert(zone.area_id ~= nil and zone.area_id ~= '', 'expected slow_zone area_id')
  assert(scene_area_ids[zone.area_id] == true, 'expected slow_zone area_id to point at area: ' .. tostring(zone.area_id))
end
for slot_id, _ in pairs(battlefield_scene_config.save_slots or {}) do
  assert(scene_save_slot_ids[slot_id] == nil, 'expected unique save_slot id: ' .. tostring(slot_id))
  scene_save_slot_ids[slot_id] = true
end

for _, wave in ipairs(waves.list or {}) do
  assert(wave.spawn_area_id ~= nil and wave.spawn_area_id ~= '', 'expected wave spawn_area_id: ' .. tostring(wave.id))
  assert(battlefield_scene_config.areas[wave.spawn_area_id] ~= nil, 'expected wave spawn area to exist in battlefield_scene_config: ' .. tostring(wave.spawn_area_id))
  assert(wave.boss_spawn_area_id ~= nil and wave.boss_spawn_area_id ~= '', 'expected wave boss_spawn_area_id: ' .. tostring(wave.id))
  assert(battlefield_scene_config.areas[wave.boss_spawn_area_id] ~= nil, 'expected wave boss spawn area to exist in battlefield_scene_config: ' .. tostring(wave.boss_spawn_area_id))
end

for _, challenge in ipairs(challenges.list or {}) do
  assert(challenge.spawn_area_id ~= nil and challenge.spawn_area_id ~= '', 'expected challenge spawn_area_id: ' .. tostring(challenge.id))
  assert(battlefield_scene_config.areas[challenge.spawn_area_id] ~= nil, 'expected challenge spawn area to exist in battlefield_scene_config: ' .. tostring(challenge.spawn_area_id))
end

print('[OK] config catalog consistency smoke passed')



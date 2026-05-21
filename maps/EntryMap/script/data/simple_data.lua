local CsvLoader = require 'data.csv_loader'
local M = {}

function M.to_number(value, default)
  local num = tonumber(value)
  return num ~= nil and num or default
end

function M.to_boolean(value)
  if value == nil or value == '' then return false end
  return value == 'true' or value == 'TRUE' or value == '1'
end

function M.to_optional_number(raw)
  if raw == nil or raw == '' then return nil end
  return tonumber(raw) or raw
end

function M.list_to_map(list, key)
  local out = {}
  key = key or 'id'
  for _, row in ipairs(list or {}) do
    local k = row and row[key]
    if k ~= nil and k ~= '' then out[k] = row end
  end
  return out
end

function M.split_mode_ids(raw)
  local mode_ids = {}
  for mode_id in tostring(raw or ''):gmatch('[^|]+') do
    if mode_id ~= '' then mode_ids[#mode_ids + 1] = mode_id end
  end
  if #mode_ids == 0 then mode_ids[1] = 'standard' end
  return mode_ids
end

function M.listnum(raw)
  if raw == nil or raw == '' then return nil end
  local t = {}
  for part in tostring(raw):gmatch('[^|,]+') do
    local n = tonumber(part); if n and n > 0 then t[#t + 1] = n end
  end
  return #t > 0 and t or nil
end

function M.build_attr_overrides(row, prefix)
  local r = {}
  if tonumber(row[prefix .. '_hp_max']) then r['最大生命'] = tonumber(row[prefix .. '_hp_max']) end
  if tonumber(row[prefix .. '_attack']) then r['攻击'] = tonumber(row[prefix .. '_attack']) end
  if tonumber(row[prefix .. '_armor']) then r['护甲'] = tonumber(row[prefix .. '_armor']) end
  return next(r) and r or nil
end

function M.build_reward(row, prefix)
  return {
    exp = tonumber(row[prefix .. '_exp']) or 0,
    gold = tonumber(row[prefix .. '_gold']) or 0,
    wood = tonumber(row[prefix .. '_wood']) or 0
  }
end

function M.process_csv_rows(csv_path, order_key, builder)
  local rows = CsvLoader.read_rows({path = csv_path})
  local list = {}
  for _, row in ipairs(rows) do list[#list + 1] = builder(row) end
  if order_key then
    table.sort(list, function(a, b) return (a[order_key] or 0) < (b[order_key] or 0) end)
  end
  return { list = list, by_id = M.list_to_map(list) }
end

function M.load_battle_base_config(hero_attr_config, hero_level_progression)
  local config = {
    global_rules = {},
    hero_init_stats = hero_attr_config.hero_init_stats,
    debug_hero_bonus_stats = hero_attr_config.debug_hero_bonus_stats,
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
        config.global_rules.debug_time_scale_debug = M.to_number(value, 0.2)
      elseif key == 'debug_time_scale_release' then
        config.global_rules.debug_time_scale_release = M.to_number(value, 1.0)
      elseif key == 'enemy_player_id' then
        config.global_rules.enemy_player_id = M.to_number(value, 31)
      elseif key == 'enemy_move_speed_scale' then
        config.global_rules.enemy_move_speed_scale = M.to_number(value, 0.48)
      elseif key == 'enemy_spawn_batch_scale' then
        config.global_rules.enemy_spawn_batch_scale = M.to_number(value, 1.5)
      elseif key == 'enemy_alive_cap_scale' then
        config.global_rules.enemy_alive_cap_scale = M.to_number(value, 1.5)
      elseif key == 'player_id' then
        config.global_rules.player_id = M.to_number(value, 1)
      elseif key == 'total_enemy_soft_cap_scale' then
        config.global_rules.total_enemy_soft_cap_scale = M.to_number(value, 1.5)
      elseif key == 'total_enemy_soft_cap' then
        config.global_rules.total_enemy_soft_cap = M.to_number(value, 40)
      elseif key == 'debug_apply_hero_bonus_on_spawn' then
        config.debug_apply_hero_bonus_on_spawn = M.to_boolean(value)
      elseif key == 'engine_exp_cap_level' then
        config.progression_rules.engine_exp_cap_level = M.to_number(value, 1)
      elseif key == 'max_level' then
        config.progression_rules.max_level = M.to_number(value, 60)
      elseif key == 'post_cap_exp_base' then
        config.progression_rules.post_cap_exp_base = M.to_number(value, 320)
      elseif key == 'post_cap_exp_step' then
        config.progression_rules.post_cap_exp_step = M.to_number(value, 55)
      elseif key == 'hero_level_attack_growth' then
        config.progression_rules.hero_level_attack_growth = M.to_number(value, 6)
      elseif key == 'hero_level_hp_growth' then
        config.progression_rules.hero_level_hp_growth = M.to_number(value, 60)
      elseif key == 'hero_level_all_attr_growth' then
        config.progression_rules.hero_level_all_attr_growth = M.to_number(value, 2)
      elseif key == 'main_stat_attack_ratio' then
        config.progression_rules.main_stat_attack_ratio = M.to_number(value, 0.5)
      elseif key == 'gold_per_sec' then
        config.resource_rules.gold_per_sec = M.to_number(value, 2)
      elseif key == 'initial_gold' then
        config.resource_rules.initial_gold = M.to_number(value, 0)
      elseif key == 'initial_wood' then
        config.resource_rules.initial_wood = M.to_number(value, 500)
      elseif key == 'wood_per_sec' then
        config.resource_rules.wood_per_sec = M.to_number(value, 1)
      elseif key == 'challenge_initial_charges' then
        config.challenge_rules.initial_charges = M.to_number(value, 1)
      elseif key == 'challenge_max_charges' then
        config.challenge_rules.max_charges = M.to_number(value, 3)
      elseif key == 'challenge_recover_sec' then
        local scale = (y3 and y3.game and y3.game.is_debug_mode and y3.game.is_debug_mode()) and 0.2 or 1.0
        config.challenge_rules.recover_sec = M.to_number(value, 105) * scale
      end
    end
  end
  return config
end

function M.load_battlefield_scene_config()
  local config = { points = {}, areas = {}, main_enemy_slow_zones = {}, save_slots = {} }
  local scene_rows = CsvLoader.read_rows({path = 'data_csv/battlefield_scene_config.csv'})
  for _, row in ipairs(scene_rows) do
    local type, id = row['type'], row['id']
    if type and type ~= '' and type ~= '__字段说明__' then
      if type == 'point' then
        config.points[id] = { x = M.to_number(row['x'], 0), y = M.to_number(row['y'], 0), z = M.to_number(row['z'], 0) }
      elseif type == 'area' then
        config.areas[id] = { x_min = M.to_number(row['x_min'], 0), x_max = M.to_number(row['x_max'], 0), y_min = M.to_number(row['y_min'], 0), y_max = M.to_number(row['y_max'], 0), z = M.to_number(row['z'], 0) }
      elseif type == 'slow_zone' then
        config.main_enemy_slow_zones[#config.main_enemy_slow_zones + 1] = { area_id = id, speed_factor = M.to_number(row['speed_factor'], 1.0) }
      elseif type == 'save_slot' then
        config.save_slots[id] = M.to_number(row['x'], 1)
      end
    end
  end
  return config
end

function M.load_battlefield_unit_config()
  local config = { fixed_unit_ids = {}, fixed_model_ids = {} }
  local unit_rows = CsvLoader.read_rows({path = 'data_csv/battlefield_unit_config.csv'})
  for _, row in ipairs(unit_rows) do
    local type = row['type']
    local unit_id = M.to_number(row['unit_id'])
    local model_id = M.to_number(row['model_id'])
    if type and type ~= '' and type ~= '__字段说明__' then
      config.fixed_unit_ids[type] = unit_id
      if model_id then config.fixed_model_ids[type] = model_id end
    end
  end
  return config
end

local function scale(seconds)
  local DEBUG_TIME_SCALE = ((y3 and y3.game and y3.game.is_debug_mode and y3.game.is_debug_mode()) and 0.2) or 1.0
  return (seconds or 0) * DEBUG_TIME_SCALE
end

function M.load_waves()
  return M.process_csv_rows('data_csv/waves.csv', 'index', function(row)
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
      main_attr_overrides = M.build_attr_overrides(row, 'main'), boss_attr_overrides = M.build_attr_overrides(row, 'boss'),
      main_spawn_hp = M.to_optional_number(row.main_spawn_hp) or tonumber(row.main_hp_max), boss_spawn_hp = tonumber(row.boss_hp_max),
      main_kill_reward = M.build_reward(row, 'main_kill_reward'), boss_kill_reward = M.build_reward(row, 'boss_kill_reward'),
      main_model_id = tonumber(row.main_model_id) or nil, boss_model_id = tonumber(row.boss_model_id) or nil,
      main_template_unit_id = tonumber(row.main_template_unit_id) or nil, boss_template_unit_id = tonumber(row.boss_template_unit_id) or nil,
      main_extra_ability_ids = M.listnum(row.main_extra_ability_ids), boss_extra_ability_ids = M.listnum(row.boss_extra_ability_ids),
    }
  end)
end

function M.load_challenges()
  return M.process_csv_rows('data_csv/challenges.csv', 'order_index', function(row)
    local count = tonumber(row.batch_count) or 0
    return {
      id = row.id, name = row.name,
      hotkey = row.hotkey ~= '' and row.hotkey or nil,
      duration_sec = scale(tonumber(row.duration_sec) or 0), recover_sec = scale(tonumber(row.recover_sec) or 0),
      cost_charge = tonumber(row.cost_charge) or 0, spawn_area_id = row.spawn_area_id,
      reward = { gold = tonumber(row.reward_gold) or 0, wood = tonumber(row.reward_wood) or 0, exp = tonumber(row.reward_exp) or 0, special = row.reward_special ~= '' and row.reward_special or nil },
      kill_reward = { gold = tonumber(row.kill_reward_gold) or 0, wood = tonumber(row.kill_reward_wood) or 0, exp = tonumber(row.kill_reward_exp) or 0, special = row.kill_reward_special ~= '' and row.kill_reward_special or nil },
      unit_id = M.to_optional_number(row.unit_id), boss_unit_id = M.to_optional_number(row.boss_unit_id), guard_unit_id = M.to_optional_number(row.guard_unit_id),
      batches = count > 0 and { { time_sec = scale(tonumber(row.batch_time_sec) or 0), count = count } } or {},
      order_index = tonumber(row.order_index) or 0,
    }
  end)
end

function M.load_hero_roster()
  local roster_rows = CsvLoader.read_rows({path = 'data_csv/hero_roster.csv'})
  local hero_list, initial = {}, nil
  for _, row in ipairs(roster_rows) do
    local e = {
      id = row.id, order_index = tonumber(row.order_index) or 0, rarity = row.rarity, name = row.name,
      model_id = M.to_optional_number(row.model_id),
      is_initial_hero = ({ ['1'] = true, ['true'] = true, ['yes'] = true })[string.lower(tostring(row.is_initial_hero or ''))] == true,
      skill_id = row.skill_id, summary = row.summary, bg = row.bg,
      talent_skill = row.talent_skill or row.summary or '',
      icon = M.to_optional_number(row.icon),
    }
    hero_list[#hero_list + 1] = e
    if e.is_initial_hero and not initial then initial = e end
  end
  table.sort(hero_list, function(a, b)
    if (a.order_index or 0) == (b.order_index or 0) then return tostring(a.id or '') < tostring(b.id or '') end
    return (a.order_index or 0) < (b.order_index or 0)
  end)
  if not initial then for _, e in ipairs(hero_list) do if e.is_initial_hero then initial = e break end end end
  return { list = hero_list, by_id = M.list_to_map(hero_list), initial_hero = initial }
end

M.CsvLoader = CsvLoader

return M
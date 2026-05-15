local CsvLoader = require 'data.csv_loader'
local AttrEffect = require 'data.tables.skill.attreffect'
local BuffTemplates = require 'data.tables.skill.buff_templates'
local MonsterMaintask = require 'data.tables.battle.monster_maintask'
local MonsterTypeConfig = require 'data.tables.battle.monster_type_config'
local hero_attr_config = require 'data.tables.hero.hero_attr_config'
local hero_level_progression = require 'data.tables.hero.hero_level_progression'

local M = {}

local function list_to_map(list, key)
  local out = {}
  key = key or 'id'
  for _, row in ipairs(list or {}) do
    local k = row and row[key]
    if k ~= nil and k ~= '' then
      out[k] = row
    end
  end
  return out
end

local function to_optional_number(raw)
  if raw == nil or raw == '' then return nil end
  return tonumber(raw) or raw
end

local function split_mode_ids(raw)
  local mode_ids = {}
  for mode_id in tostring(raw or ''):gmatch('[^|]+') do
    if mode_id ~= '' then mode_ids[#mode_ids + 1] = mode_id end
  end
  if #mode_ids == 0 then mode_ids[1] = 'standard' end
  return mode_ids
end

local DEBUG_TIME_SCALE = ((y3 and y3.game and y3.game.is_debug_mode and y3.game.is_debug_mode()) and 0.2) or 1.0
local function scale(seconds) return (seconds or 0) * DEBUG_TIME_SCALE end

local function build_attr_overrides(row, prefix)
  local r = {}
  if tonumber(row[prefix .. '_hp_max']) then r['最大生命'] = tonumber(row[prefix .. '_hp_max']) end
  if tonumber(row[prefix .. '_attack']) then r['攻击'] = tonumber(row[prefix .. '_attack']) end
  if tonumber(row[prefix .. '_armor']) then r['护甲'] = tonumber(row[prefix .. '_armor']) end
  return next(r) and r or nil
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
  return { 
    exp = tonumber(row[prefix .. '_exp']) or 0, 
    gold = tonumber(row[prefix .. '_gold']) or 0, 
    wood = tonumber(row[prefix .. '_wood']) or 0 
  }
end

local function process_csv_rows(csv_path, order_key, builder)
  local rows = CsvLoader.read_rows({path = csv_path})
  local list = {}
  for _, row in ipairs(rows) do
    list[#list + 1] = builder(row)
  end
  if order_key then
    table.sort(list, function(a, b) return (a[order_key] or 0) < (b[order_key] or 0) end)
  end
  return { list = list, by_id = list_to_map(list) }
end

local function to_boolean(value)
  if value == nil or value == '' then
    return false
  end
  return value == 'true' or value == 'TRUE' or value == '1'
end

local function to_number(value, default)
  local num = tonumber(value)
  if num == nil then
    return default
  end
  return num
end

M.battle_base_config = {
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
  local key = row['key']
  if key and key ~= '' and key ~= '__字段说明__' then
    local value = row['value']
    if key == 'debug_time_scale_debug' then
      M.battle_base_config.global_rules.debug_time_scale_debug = to_number(value, 0.2)
    elseif key == 'debug_time_scale_release' then
      M.battle_base_config.global_rules.debug_time_scale_release = to_number(value, 1.0)
    elseif key == 'enemy_player_id' then
      M.battle_base_config.global_rules.enemy_player_id = to_number(value, 31)
    elseif key == 'enemy_move_speed_scale' then
      M.battle_base_config.global_rules.enemy_move_speed_scale = to_number(value, 0.48)
    elseif key == 'enemy_spawn_batch_scale' then
      M.battle_base_config.global_rules.enemy_spawn_batch_scale = to_number(value, 1.5)
    elseif key == 'enemy_alive_cap_scale' then
      M.battle_base_config.global_rules.enemy_alive_cap_scale = to_number(value, 1.5)
    elseif key == 'player_id' then
      M.battle_base_config.global_rules.player_id = to_number(value, 1)
    elseif key == 'total_enemy_soft_cap_scale' then
      M.battle_base_config.global_rules.total_enemy_soft_cap_scale = to_number(value, 1.5)
    elseif key == 'total_enemy_soft_cap' then
      M.battle_base_config.global_rules.total_enemy_soft_cap = to_number(value, 40)
    elseif key == 'debug_apply_hero_bonus_on_spawn' then
      M.battle_base_config.debug_apply_hero_bonus_on_spawn = to_boolean(value)
    elseif key == 'engine_exp_cap_level' then
      M.battle_base_config.progression_rules.engine_exp_cap_level = to_number(value, 1)
    elseif key == 'max_level' then
      M.battle_base_config.progression_rules.max_level = to_number(value, 60)
    elseif key == 'post_cap_exp_base' then
      M.battle_base_config.progression_rules.post_cap_exp_base = to_number(value, 320)
    elseif key == 'post_cap_exp_step' then
      M.battle_base_config.progression_rules.post_cap_exp_step = to_number(value, 55)
    elseif key == 'hero_level_attack_growth' then
      M.battle_base_config.progression_rules.hero_level_attack_growth = to_number(value, 6)
    elseif key == 'hero_level_hp_growth' then
      M.battle_base_config.progression_rules.hero_level_hp_growth = to_number(value, 60)
    elseif key == 'hero_level_all_attr_growth' then
      M.battle_base_config.progression_rules.hero_level_all_attr_growth = to_number(value, 2)
    elseif key == 'main_stat_attack_ratio' then
      M.battle_base_config.progression_rules.main_stat_attack_ratio = to_number(value, 0.5)
    elseif key == 'gold_per_sec' then
      M.battle_base_config.resource_rules.gold_per_sec = to_number(value, 2)
    elseif key == 'initial_gold' then
      M.battle_base_config.resource_rules.initial_gold = to_number(value, 0)
    elseif key == 'initial_wood' then
      M.battle_base_config.resource_rules.initial_wood = to_number(value, 500)
    elseif key == 'wood_per_sec' then
      M.battle_base_config.resource_rules.wood_per_sec = to_number(value, 1)
    elseif key == 'challenge_initial_charges' then
      M.battle_base_config.challenge_rules.initial_charges = to_number(value, 1)
    elseif key == 'challenge_max_charges' then
      M.battle_base_config.challenge_rules.max_charges = to_number(value, 3)
    elseif key == 'challenge_recover_sec' then
      M.battle_base_config.challenge_rules.recover_sec = scale(to_number(value, 105))
    end
  end
end

M.battlefield_scene_config = {
  points = {},
  areas = {},
  main_enemy_slow_zones = {},
  save_slots = {},
}

local scene_rows = CsvLoader.read_rows({path = 'data_csv/battlefield_scene_config.csv'})
for _, row in ipairs(scene_rows) do
  local type = row['type']
  local id = row['id']
  if type and type ~= '' and type ~= '__字段说明__' then
    if type == 'point' then
      M.battlefield_scene_config.points[id] = {
        x = to_number(row['x'], 0),
        y = to_number(row['y'], 0),
        z = to_number(row['z'], 0),
      }
    elseif type == 'area' then
      M.battlefield_scene_config.areas[id] = {
        x_min = to_number(row['x_min'], 0),
        x_max = to_number(row['x_max'], 0),
        y_min = to_number(row['y_min'], 0),
        y_max = to_number(row['y_max'], 0),
        z = to_number(row['z'], 0),
      }
    elseif type == 'slow_zone' then
      M.battlefield_scene_config.main_enemy_slow_zones[#M.battlefield_scene_config.main_enemy_slow_zones + 1] = {
        area_id = id,
        speed_factor = to_number(row['speed_factor'], 1.0),
      }
    elseif type == 'save_slot' then
      M.battlefield_scene_config.save_slots[id] = to_number(row['x'], 1)
    end
  end
end

M.battlefield_unit_config = {
  fixed_unit_ids = {},
  fixed_model_ids = {},  -- 新增：存储模型ID
}

local unit_rows = CsvLoader.read_rows({path = 'data_csv/battlefield_unit_config.csv'})
print('[game_tables] Loaded battlefield_unit_config.csv rows:', #unit_rows)
for _, row in ipairs(unit_rows) do
  local type = row['type']
  local unit_id = to_number(row['unit_id'])
  local model_id = to_number(row['model_id'])  -- 新增：读取模型ID
  print('[game_tables] Processing unit row:', type, unit_id, model_id)
  if type and type ~= '' and type ~= '__字段说明__' then
    M.battlefield_unit_config.fixed_unit_ids[type] = unit_id
    if model_id then
      M.battlefield_unit_config.fixed_model_ids[type] = model_id  -- 新增：存储模型ID
      print('[game_tables] Set fixed_model_ids[' .. type .. '] =', model_id)
    end
  end
end
print('[game_tables] battlefield_unit_config:', M.battlefield_unit_config)

M.waves = process_csv_rows('data_csv/waves.csv', 'index', function(row)
  local seg = {}
  for i = 1, 3 do
    local s = row['segment' .. i .. '_start_sec']
    local it = row['segment' .. i .. '_interval_sec']
    if s ~= '' and it ~= '' then 
      seg[#seg + 1] = { 
        start_sec = scale(tonumber(s) or 0), 
        interval_sec = scale(tonumber(it) or 0) 
      } 
    end
  end
  return {
    id = row.id,
    index = tonumber(row.index) or 0,
    name = row.name,
    spawn_area_id = row.spawn_area_id,
    boss_spawn_area_id = row.boss_spawn_area_id,
    boss_spawn_sec = scale(tonumber(row.boss_spawn_sec) or 0),
    batch_min = tonumber(row.batch_min) or 0,
    batch_max = tonumber(row.batch_max) or 0,
    max_alive = tonumber(row.max_alive) or 0,
    spawn_segments = seg,
    post_boss_interval_sec = scale(tonumber(row.post_boss_interval_sec) or 0),
    main_attr_overrides = build_attr_overrides(row, 'main'),
    boss_attr_overrides = build_attr_overrides(row, 'boss'),
    main_spawn_hp = to_optional_number(row.main_spawn_hp),
    main_kill_reward = build_reward(row, 'main_kill_reward'),
    boss_kill_reward = build_reward(row, 'boss_kill_reward'),
    main_model_id = tonumber(row.main_model_id) or nil,
    boss_model_id = tonumber(row.boss_model_id) or nil,
    main_template_unit_id = tonumber(row.main_template_unit_id) or nil,
    boss_template_unit_id = tonumber(row.boss_template_unit_id) or nil,
    main_extra_ability_ids = listnum(row.main_extra_ability_ids),
    boss_extra_ability_ids = listnum(row.boss_extra_ability_ids),
  }
end)

M.challenges = process_csv_rows('data_csv/challenges.csv', 'order_index', function(row)
  local count = tonumber(row.batch_count) or 0
  return {
    id = row.id,
    name = row.name,
    hotkey = row.hotkey ~= '' and row.hotkey or nil,
    duration_sec = scale(tonumber(row.duration_sec) or 0),
    recover_sec = scale(tonumber(row.recover_sec) or 0),
    cost_charge = tonumber(row.cost_charge) or 0,
    spawn_area_id = row.spawn_area_id,
    reward = { 
      gold = tonumber(row.reward_gold) or 0, 
      wood = tonumber(row.reward_wood) or 0, 
      exp = tonumber(row.reward_exp) or 0, 
      special = row.reward_special ~= '' and row.reward_special or nil 
    },
    kill_reward = { 
      gold = tonumber(row.kill_reward_gold) or 0, 
      wood = tonumber(row.kill_reward_wood) or 0, 
      exp = tonumber(row.kill_reward_exp) or 0, 
      special = row.kill_reward_special ~= '' and row.kill_reward_special or nil 
    },
    unit_id = to_optional_number(row.unit_id),
    boss_unit_id = to_optional_number(row.boss_unit_id),
    guard_unit_id = to_optional_number(row.guard_unit_id),
    batches = count > 0 and { { time_sec = scale(tonumber(row.batch_time_sec) or 0), count = count } } or {},
    order_index = tonumber(row.order_index) or 0,
  }
end)

M.stages = process_csv_rows('data_csv/stages.csv', 'order_index', function(row)
  return {
    id = row.id,
    stage_id = row.stage_id,
    display_name = row.display_name,
    order_index = tonumber(row.order_index) or 0,
    content_source_stage_id = row.content_source_stage_id,
    mode_ids = split_mode_ids(row.mode_ids),
    preview_note = row.preview_note ~= '' and row.preview_note or nil,
    n0_activation_mode = row.n0_activation_mode ~= '' and row.n0_activation_mode or nil,
    n0_single_bond = row.n0_single_bond ~= '' and row.n0_single_bond or nil,
    n0_opening_no_cooldown = row.n0_opening_no_cooldown ~= '' and row.n0_opening_no_cooldown or nil,
    n0_disable_mainline_spawn = row.n0_disable_mainline_spawn ~= '' and row.n0_disable_mainline_spawn or nil,
  }
end)

M.stage_modes = process_csv_rows('data_csv/stage_modes.csv', 'order_index', function(row)
  return {
    id = row.id,
    mode_id = row.mode_id,
    order_index = tonumber(row.order_index) or 0,
    display_name = row.display_name,
    unlock_rule = row.unlock_rule,
    ui_badge_text = row.ui_badge_text,
    battle_config_key = row.battle_config_key,
    result_bucket = row.result_bucket,
  }
end)

local roster_rows = CsvLoader.read_rows({path = 'data_csv/hero_roster.csv'})
local hero_list, initial = {}, nil
for _, row in ipairs(roster_rows) do
  local e = {
    id = row.id,
    order_index = tonumber(row.order_index) or 0,
    rarity = row.rarity,
    name = row.name,
    model_id = to_optional_number(row.model_id),
    is_initial_hero = ({ ['1'] = true, ['true'] = true, ['yes'] = true })
    [string.lower(tostring(row.is_initial_hero or ''))] == true,
    skill_id = row.skill_id,
    summary = row.summary,
    bg = row.bg,
    talent_skill = row.talent_skill or row.summary or '',
    icon = to_optional_number(row.icon),
  }
  hero_list[#hero_list + 1] = e
  if e.is_initial_hero and not initial then initial = e end
end
table.sort(hero_list,
  function(a, b)
    if (a.order_index or 0) == (b.order_index or 0) then return tostring(a.id or '') < tostring(b.id or '') end
    return (a.order_index or 0) < (b.order_index or 0)
  end)
if not initial then for _, e in ipairs(hero_list) do if e.is_initial_hero then
      initial = e
      break
    end end end
M.hero_roster = { list = hero_list, by_id = list_to_map(hero_list), initial_hero = initial }

local reward_rows = CsvLoader.read_rows({path = 'data_csv/mainline_task_rewards.csv'})
local effect_rows = AttrEffect.by_source.mainline_task or {}
local csv_by_id = list_to_map(reward_rows)
local LEGACY_ATTR = { ['生命'] = 'hp', ['生命恢复'] = 'hp_regen', ['护甲'] = 'armor', ['格挡'] = 'block', ['攻击'] = 'attack',
  ['攻击范围'] = 'attack_range', ['攻击速度'] = 'attack_speed_pct', ['力量'] = 'strength', ['敏捷'] = 'agility', ['智力'] =
'intelligence', ['全属性'] = 'all_attributes', ['力量增幅'] = 'strength_growth_pct', ['敏捷增幅'] = 'agility_growth_pct', ['智力增幅'] =
'intelligence_growth_pct', ['攻击增幅'] = 'attack_growth_pct', ['物理伤害'] = 'physical_damage_pct', ['魔法伤害'] =
'magic_damage_pct', ['普攻伤害'] = 'basic_attack_damage_pct', ['技能伤害'] = 'skill_damage_pct', ['所有伤害'] = 'all_damage_pct',
  ['物理暴击'] = 'physical_crit_pct', ['物理暴伤'] = 'physical_crit_damage_pct', ['魔法暴击'] = 'magic_crit_pct', ['魔法暴伤'] =
'magic_crit_damage_pct' }
local LEGACY_RUNTIME = { ['每秒金币'] = 'gold_per_sec', ['每秒木材'] = 'wood_per_sec', ['每秒经验'] = 'exp_per_sec', ['杀敌数'] =
'kill_count', ['每秒杀敌'] = 'kill_per_sec', ['每秒力量'] = 'strength_per_sec', ['每秒敏捷'] = 'agility_per_sec', ['每秒智力'] =
'intelligence_per_sec', ['杀敌金币'] = 'kill_gold_pct', ['杀敌经验'] = 'kill_exp_pct', ['杀敌木材'] = 'kill_wood_pct', ['精英伤害'] =
'elite_damage_pct', ['挑战伤害'] = 'challenge_damage_pct' }
local LEGACY_SPECIAL = { hero_card_count = 'hero_card' }
local function reward_lines(row, id)
  local lines, bucket = {}, effect_rows[id]
  for index = 1, 3 do
    local prefix = 'reward_' .. index .. '_'
    local t, k, v = row[prefix .. 'type'], row[prefix .. 'key'], tonumber(row[prefix .. 'value'])
    if t ~= '' and k ~= '' and v ~= nil then lines[#lines + 1] = { slot = index, type = t, key = k, value = v } end
  end
  for _, effect in ipairs(bucket and bucket.ordered or {}) do
    if effect.effect_kind == 'attr' then
      local attr_key = LEGACY_ATTR[effect.effect_key]
      if attr_key then
        lines[#lines + 1] = { slot = effect.order_index, type = 'attr', key = attr_key, value = effect.value }
      else
        lines[#lines + 1] = { slot = effect.order_index, type = 'runtime', key = assert(LEGACY_RUNTIME
        [effect.effect_key]), value = effect.value }
      end
    elseif effect.effect_kind == 'resource' then
      lines[#lines + 1] = { slot = effect.order_index, type = 'resource', key = effect.effect_key, value = effect.value }
    elseif effect.effect_kind == 'state' then
      lines[#lines + 1] = { slot = effect.order_index, type = 'special', key = assert(LEGACY_SPECIAL[effect.effect_key]), value =
      effect.value }
    end
  end
  table.sort(lines,
    function(a, b)
      if (a.slot or 0) == (b.slot or 0) then return tostring(a.type or '') < tostring(b.type or '') end
      return (a.slot or 0) < (b.slot or 0)
    end)
  return lines
end
local mainline_list = {}
local source_rows = (#MonsterMaintask.list > 0) and MonsterMaintask.list or reward_rows
for _, source_row in ipairs(source_rows) do
  local monster_row = source_row.source == 'monster_maintask' and source_row or MonsterMaintask.by_id[source_row.id]
  local row = csv_by_id[source_row.id] or source_row
  local chapter_id, order_index = tostring(source_row.id or ''):match('^(%d+)%-(%d+)$')
  mainline_list[#mainline_list + 1] = {
    id = source_row.id,
    chapter_id = tonumber(row.chapter_id) or tonumber(chapter_id) or 0,
    order_index = tonumber(row.order_index) or tonumber(order_index) or 0,
    title_text = row.title_text or ('主线' .. tostring(source_row.id)),
    objective_text = monster_row and monster_row.objective_text or row.objective_text,
    target_count = monster_row and monster_row.target_count or tonumber(row.target_count) or 0,
    time_limit = tonumber(row.time_limit) or 60,
    spawn_unit_id = monster_row and monster_row.spawn_unit_id or to_optional_number(row.spawn_unit_id),
    spawn_area_id = row.spawn_area_id ~= '' and row.spawn_area_id or nil,
    is_boss_task = monster_row and monster_row.is_boss_task or row.is_boss_task == 'true',
    monster_name = monster_row and monster_row.monster_name or nil,
    attr_overrides = monster_row and monster_row.attr_overrides or nil,
    display_attrs = monster_row and monster_row.display_attrs or nil,
    monster_maintask_reward_text = monster_row and monster_row.reward_text or nil,
    monster_maintask_reward_value_text = monster_row and monster_row.reward_value_text or nil,
    reward_lines = reward_lines(row, source_row.id),
  }
end
table.sort(mainline_list,
  function(a, b)
    if (a.chapter_id or 0) == (b.chapter_id or 0) then return (a.order_index or 0) < (b.order_index or 0) end
    return (a.chapter_id or 0) < (b.chapter_id or 0)
  end)
M.mainline_task_rewards = { list = mainline_list, by_id = list_to_map(mainline_list) }
M.buff_templates = BuffTemplates
M.monster_type_config = MonsterTypeConfig

return M
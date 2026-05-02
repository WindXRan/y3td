local CsvLoader = require 'data.csv_loader'
local AttrEffect = require 'data.tables.skill.attreffect'
local MonsterMaintask = require 'data.tables.battle.monster_maintask'
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

M.battle_base_config = {
  global_rules = {
    debug_time_scale_debug = 0.2,
    debug_time_scale_release = 1.0,
    enemy_player_id = 31,
    enemy_move_speed_scale = 1.0,
    enemy_spawn_batch_scale = 1.5,
    enemy_alive_cap_scale = 1.5,
    player_id = 1,
    total_enemy_soft_cap_scale = 1.5,
    total_enemy_soft_cap = 40,
  },
  hero_init_stats = hero_attr_config.hero_init_stats,
  debug_hero_bonus_stats = hero_attr_config.debug_hero_bonus_stats,
  debug_apply_hero_bonus_on_spawn = false,
  progression_rules = {
    engine_exp_cap_level = 1,
    max_level = 60,
    post_cap_exp_base = 320,
    post_cap_exp_step = 55,
    hero_level_attack_growth = 6,
    hero_level_hp_growth = 60,
    hero_level_all_attr_growth = 2,
    main_stat_attack_ratio = 0.5,
  },
  hero_level_progression = hero_level_progression,
  resource_rules = { gold_per_sec = 2, initial_gold = 0, initial_wood = 0, wood_per_sec = 1 },
  challenge_rules = { initial_charges = 1, max_charges = 3, recover_sec = 105 },
}

M.battlefield_scene_config = {
  points = {
    hero_spawn = { x = -1200, y = 0, z = 0 },
    defense_point = { x = -1050, y = 0, z = 0 },
  },
  areas = {
    main_spawn_wave_1 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    main_spawn_wave_2 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    main_spawn_wave_3 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    main_spawn_wave_4 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    main_spawn_wave_5 = { x_min = 1660, x_max = 1840, y_min = -1040, y_max = 1040, z = 0 },
    boss_spawn_wave_1 = { x_min = 1520, x_max = 1660, y_min = -90, y_max = 90, z = 0 },
    boss_spawn_wave_2 = { x_min = 1540, x_max = 1680, y_min = -110, y_max = 110, z = 0 },
    boss_spawn_wave_3 = { x_min = 1560, x_max = 1700, y_min = -130, y_max = 130, z = 0 },
    boss_spawn_wave_4 = { x_min = 1580, x_max = 1720, y_min = -150, y_max = 150, z = 0 },
    boss_spawn_wave_5 = { x_min = 1600, x_max = 1740, y_min = -170, y_max = 170, z = 0 },
    mid_slow_lane_outer = { x_min = -220, x_max = 260, y_min = -520, y_max = 520, z = 0 },
    mid_slow_lane_inner = { x_min = -760, x_max = 40, y_min = -420, y_max = 420, z = 0 },
    hero_front_slow_lane = { x_min = -1220, x_max = -700, y_min = -320, y_max = 320, z = 0 },
    challenge_spawn_top = { x_min = 1580, x_max = 1850, y_min = 220, y_max = 420, z = 0 },
    challenge_spawn_mid = { x_min = 1620, x_max = 1890, y_min = -80, y_max = 120, z = 0 },
    challenge_spawn_bottom = { x_min = 1580, x_max = 1850, y_min = -420, y_max = -220, z = 0 },
    challenge_treasure_elite_spawn = { x_min = 1640, x_max = 1780, y_min = -60, y_max = 60, z = 0 },
  },
  main_enemy_slow_zones = {
    { area_id = 'mid_slow_lane_outer', speed_factor = 0.64 },
    { area_id = 'mid_slow_lane_inner', speed_factor = 0.46 },
    { area_id = 'hero_front_slow_lane', speed_factor = 0.30 },
  },
  save_slots = { outgame_profile = 1 },
}

M.battlefield_unit_config = {
  fixed_unit_ids = { hero = 134245850, enemy = 134278989 },
}

-- waves
local wave_rows = CsvLoader.read_rows('data_csv/waves.csv')
local waves_list = {}
for _, row in ipairs(wave_rows) do
  local seg = {}
  for i = 1, 3 do
    local s = row['segment' .. i .. '_start_sec']
    local it = row['segment' .. i .. '_interval_sec']
    if s ~= '' and it ~= '' then seg[#seg + 1] = { start_sec = scale(tonumber(s) or 0), interval_sec = scale(tonumber(it) or 0) } end
  end
  local function reward(prefix)
    return { exp = tonumber(row[prefix .. '_exp']) or 0, gold = tonumber(row[prefix .. '_gold']) or 0, wood = tonumber(row[prefix .. '_wood']) or 0 }
  end
  local function listnum(raw)
    if raw == nil or raw == '' then return nil end
    local t = {}
    for part in tostring(raw):gmatch('[^|,]+') do local n = tonumber(part); if n and n > 0 then t[#t + 1] = n end end
    return #t > 0 and t or nil
  end
  waves_list[#waves_list + 1] = {
    id = row.id, index = tonumber(row.index) or 0, name = row.name, spawn_area_id = row.spawn_area_id, boss_spawn_area_id = row.boss_spawn_area_id,
    boss_spawn_sec = scale(tonumber(row.boss_spawn_sec) or 0), batch_min = tonumber(row.batch_min) or 0, batch_max = tonumber(row.batch_max) or 0,
    max_alive = tonumber(row.max_alive) or 0, spawn_segments = seg, post_boss_interval_sec = scale(tonumber(row.post_boss_interval_sec) or 0),
    main_attr_overrides = (function() local r={} if tonumber(row.main_hp_max) then r['最大生命']=tonumber(row.main_hp_max) end if tonumber(row.main_attack) then r['攻击']=tonumber(row.main_attack) end if tonumber(row.main_armor) then r['护甲']=tonumber(row.main_armor) end return next(r) and r or nil end)(),
    boss_attr_overrides = (function() local r={} if tonumber(row.boss_hp_max) then r['最大生命']=tonumber(row.boss_hp_max) end if tonumber(row.boss_attack) then r['攻击']=tonumber(row.boss_attack) end if tonumber(row.boss_armor) then r['护甲']=tonumber(row.boss_armor) end return next(r) and r or nil end)(),
    main_spawn_hp = to_optional_number(row.main_spawn_hp), main_kill_reward = reward('main_kill_reward'), boss_kill_reward = reward('boss_kill_reward'),
    main_model_id = tonumber(row.main_model_id) or nil, boss_model_id = tonumber(row.boss_model_id) or nil,
    main_template_unit_id = tonumber(row.main_template_unit_id) or nil, boss_template_unit_id = tonumber(row.boss_template_unit_id) or nil,
    main_extra_ability_ids = listnum(row.main_extra_ability_ids), boss_extra_ability_ids = listnum(row.boss_extra_ability_ids),
  }
end
table.sort(waves_list, function(a,b) return (a.index or 0) < (b.index or 0) end)
M.waves = { list = waves_list, by_id = list_to_map(waves_list) }

-- challenges
local challenge_rows = CsvLoader.read_rows('data_csv/challenges.csv')
local challenges_list = {}
for _, row in ipairs(challenge_rows) do
  challenges_list[#challenges_list + 1] = {
    id = row.id, name = row.name, hotkey = row.hotkey ~= '' and row.hotkey or nil,
    duration_sec = scale(tonumber(row.duration_sec) or 0), recover_sec = scale(tonumber(row.recover_sec) or 0),
    cost_charge = tonumber(row.cost_charge) or 0, spawn_area_id = row.spawn_area_id,
    reward = { gold = tonumber(row.reward_gold) or 0, wood = tonumber(row.reward_wood) or 0, exp = tonumber(row.reward_exp) or 0, special = row.reward_special ~= '' and row.reward_special or nil },
    kill_reward = { gold = tonumber(row.kill_reward_gold) or 0, wood = tonumber(row.kill_reward_wood) or 0, exp = tonumber(row.kill_reward_exp) or 0, special = row.kill_reward_special ~= '' and row.kill_reward_special or nil },
    unit_id = to_optional_number(row.unit_id), boss_unit_id = to_optional_number(row.boss_unit_id), guard_unit_id = to_optional_number(row.guard_unit_id),
    batches = (function() local count = tonumber(row.batch_count) or 0; return count > 0 and { { time_sec = scale(tonumber(row.batch_time_sec) or 0), count = count } } or {} end)(),
    order_index = tonumber(row.order_index) or 0,
  }
end
table.sort(challenges_list, function(a,b) return (a.order_index or 0) < (b.order_index or 0) end)
M.challenges = { list = challenges_list, by_id = list_to_map(challenges_list) }

-- stages / modes
local stage_rows = CsvLoader.read_rows('data_csv/stages.csv')
local stages_list = {}
for _, row in ipairs(stage_rows) do
  stages_list[#stages_list + 1] = {
    id = row.id, stage_id = row.stage_id, display_name = row.display_name, order_index = tonumber(row.order_index) or 0,
    content_source_stage_id = row.content_source_stage_id, mode_ids = split_mode_ids(row.mode_ids),
    preview_note = row.preview_note ~= '' and row.preview_note or nil,
    n0_activation_mode = row.n0_activation_mode ~= '' and row.n0_activation_mode or nil,
    n0_single_bond = row.n0_single_bond ~= '' and row.n0_single_bond or nil,
    n0_opening_no_cooldown = row.n0_opening_no_cooldown ~= '' and row.n0_opening_no_cooldown or nil,
    n0_disable_mainline_spawn = row.n0_disable_mainline_spawn ~= '' and row.n0_disable_mainline_spawn or nil,
  }
end
table.sort(stages_list, function(a,b) return (a.order_index or 0) < (b.order_index or 0) end)
M.stages = { list = stages_list, by_id = list_to_map(stages_list) }

local mode_rows = CsvLoader.read_rows('data_csv/stage_modes.csv')
local modes_list = {}
for _, row in ipairs(mode_rows) do
  modes_list[#modes_list + 1] = {
    id = row.id, mode_id = row.mode_id, order_index = tonumber(row.order_index) or 0,
    display_name = row.display_name, unlock_rule = row.unlock_rule, ui_badge_text = row.ui_badge_text,
    battle_config_key = row.battle_config_key, result_bucket = row.result_bucket,
  }
end
table.sort(modes_list, function(a,b) return (a.order_index or 0) < (b.order_index or 0) end)
M.stage_modes = { list = modes_list, by_id = list_to_map(modes_list) }

-- hero roster
local roster_rows = CsvLoader.read_rows('data_csv/hero_roster.csv')
local hero_list, initial = {}, nil
for _, row in ipairs(roster_rows) do
  local e = {
    id = row.id, order_index = tonumber(row.order_index) or 0, rarity = row.rarity, name = row.name, title = row.title,
    unit_id = to_optional_number(row.unit_id), model_id = to_optional_number(row.model_id),
    is_initial_hero = ({['1']=true,['true']=true,['yes']=true})[string.lower(tostring(row.is_initial_hero or ''))] == true,
    skill_id = row.skill_id, summary = row.summary,
  }
  hero_list[#hero_list + 1] = e
  if e.is_initial_hero and not initial then initial = e end
end
table.sort(hero_list, function(a,b) if (a.order_index or 0)==(b.order_index or 0) then return tostring(a.id or '') < tostring(b.id or '') end return (a.order_index or 0) < (b.order_index or 0) end)
if not initial then for _, e in ipairs(hero_list) do if e.unit_id ~= nil then initial = e break end end end
local by_unit_id = {}
for _, e in ipairs(hero_list) do if e.unit_id ~= nil then by_unit_id[e.unit_id] = e end end
M.hero_roster = { list = hero_list, by_id = list_to_map(hero_list), by_unit_id = by_unit_id, initial_hero = initial }

-- mainline task rewards
local reward_rows = CsvLoader.read_rows('data_csv/mainline_task_rewards.csv')
local effect_rows = AttrEffect.by_source.mainline_task or {}
local csv_by_id = list_to_map(reward_rows)
local LEGACY_ATTR = { ['生命']='hp',['生命恢复']='hp_regen',['护甲']='armor',['格挡']='block',['攻击']='attack',['攻击范围']='attack_range',['攻击速度']='attack_speed_pct',['力量']='strength',['敏捷']='agility',['智力']='intelligence',['全属性']='all_attributes',['力量增幅']='strength_growth_pct',['敏捷增幅']='agility_growth_pct',['智力增幅']='intelligence_growth_pct',['攻击增幅']='attack_growth_pct',['物理伤害']='physical_damage_pct',['魔法伤害']='magic_damage_pct',['普攻伤害']='basic_attack_damage_pct',['技能伤害']='skill_damage_pct',['所有伤害']='all_damage_pct',['物理暴击']='physical_crit_pct',['物理暴伤']='physical_crit_damage_pct',['魔法暴击']='magic_crit_pct',['魔法暴伤']='magic_crit_damage_pct' }
local LEGACY_RUNTIME = { ['每秒金币']='gold_per_sec',['每秒木材']='wood_per_sec',['每秒经验']='exp_per_sec',['杀敌数']='kill_count',['每秒杀敌']='kill_per_sec',['每秒力量']='strength_per_sec',['每秒敏捷']='agility_per_sec',['每秒智力']='intelligence_per_sec',['杀敌金币']='kill_gold_pct',['杀敌经验']='kill_exp_pct',['杀敌木材']='kill_wood_pct',['精控伤害']='elite_damage_pct',['挑战伤害']='challenge_damage_pct' }
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
        lines[#lines + 1] = { slot = effect.order_index, type = 'runtime', key = assert(LEGACY_RUNTIME[effect.effect_key]), value = effect.value }
      end
    elseif effect.effect_kind == 'resource' then
      lines[#lines + 1] = { slot = effect.order_index, type = 'resource', key = effect.effect_key, value = effect.value }
    elseif effect.effect_kind == 'state' then
      lines[#lines + 1] = { slot = effect.order_index, type = 'special', key = assert(LEGACY_SPECIAL[effect.effect_key]), value = effect.value }
    end
  end
  table.sort(lines, function(a,b) if (a.slot or 0)==(b.slot or 0) then return tostring(a.type or '') < tostring(b.type or '') end return (a.slot or 0) < (b.slot or 0) end)
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
table.sort(mainline_list, function(a,b) if (a.chapter_id or 0)==(b.chapter_id or 0) then return (a.order_index or 0) < (b.order_index or 0) end return (a.chapter_id or 0) < (b.chapter_id or 0) end)
M.mainline_task_rewards = { list = mainline_list, by_id = list_to_map(mainline_list) }

return M


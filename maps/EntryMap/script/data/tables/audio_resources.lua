local M = {}

local function read_audio_rows()
  local ok, CsvLoader = pcall(require, 'data.csv_loader')
  if not ok or not CsvLoader or not CsvLoader.read_rows then
    return {}
  end
  local rows_ok, rows = pcall(CsvLoader.read_rows, {path = 'data_csv/audio.csv'})
  if rows_ok and type(rows) == 'table' then
    return rows
  end
  return {}
end

local function load_audio_ids()
  local ids = {}
  for _, row in ipairs(read_audio_rows()) do
    local key = tostring(row.key or '')
    local audio_id = tostring(row.audio_id or '')
    if key ~= '' and key ~= '__字段说明__' and audio_id ~= '' then
      ids[key] = audio_id
    end
  end
  return ids
end

local function merge_defaults(ids)
  local defaults = {
    'bgm_loop',
    'battle',
    'boss',
    'ui_click',
    'ui_open',
    'ui_confirm',
    'ui_error',
    'wave_start',
    'boss_warning',
    'boss_spawn',
    'challenge_start',
    'challenge_success',
    'challenge_fail',
    'hero_low_hp',
    'defeat',
    'basic_attack',
    'attack_cast',
    'attack_impact',
    'attack_chain',
    'attack_burst',
    'attack_tick',
    'attack_charge',
    'enemy_death_heavy',
    'enemy_death_burst',
    'boss_death_heavy',
  }
  for _, key in ipairs(defaults) do
    local value = ids[key]
    if not value or tostring(value) == '' then
      error(string.format('[audio_resources] 配置缺失: audio.csv 中缺少 audio_id, key=%s', key))
    end
  end
  return ids
end

local function append_unique(target, seen, value)
  local text = tostring(value or '')
  if text == '' or seen[text] then
    return
  end
  seen[text] = true
  target[#target + 1] = text
end

local function build_candidates(ids, key_names)
  local result = {}
  local seen = {}
  for _, key_name in ipairs(key_names or {}) do
    append_unique(result, seen, ids[key_name])
  end
  return result
end

local function make_stage(ids, key_names, volume, cooldown, extra)
  local cfg = {
    ids = build_candidates(ids, key_names),
    volume = volume,
    cooldown = cooldown,
  }
  if extra then
    for key, value in pairs(extra) do
      cfg[key] = value
    end
  end
  return cfg
end

local function clone_stage_configs(source)
  local copy = {}
  for stage_name, stage_cfg in pairs(source) do
    local stage_copy = {}
    for key, value in pairs(stage_cfg) do
      stage_copy[key] = value
    end
    copy[stage_name] = stage_copy
  end
  return copy
end

M.AUDIO_IDS = merge_defaults(load_audio_ids())

M.AUDIO_USAGE = {
  [134278073] = 'enemy death sound object',
}

M.AUDIO_KEY_NAME_ALIASES = {}

M.AUDIO_SCENES = {
  bgm_loop = build_candidates(M.AUDIO_IDS, { 'bgm_loop' }),
  battle_loop = build_candidates(M.AUDIO_IDS, { 'battle' }),
  boss_loop = build_candidates(M.AUDIO_IDS, { 'boss' }),
  ui_click = build_candidates(M.AUDIO_IDS, { 'ui_click' }),
  ui_open = build_candidates(M.AUDIO_IDS, { 'ui_open' }),
  ui_confirm = build_candidates(M.AUDIO_IDS, { 'ui_confirm' }),
  ui_error = build_candidates(M.AUDIO_IDS, { 'ui_error' }),
  wave_start = build_candidates(M.AUDIO_IDS, { 'wave_start' }),
  boss_warning = build_candidates(M.AUDIO_IDS, { 'boss_warning' }),
  boss_spawn = build_candidates(M.AUDIO_IDS, { 'boss_spawn' }),
  challenge_start = build_candidates(M.AUDIO_IDS, { 'challenge_start' }),
  challenge_success = build_candidates(M.AUDIO_IDS, { 'challenge_success' }),
  challenge_fail = build_candidates(M.AUDIO_IDS, { 'challenge_fail' }),
  hero_low_hp = build_candidates(M.AUDIO_IDS, { 'hero_low_hp' }),
  defeat = build_candidates(M.AUDIO_IDS, { 'defeat' }),
  basic_attack = build_candidates(M.AUDIO_IDS, { 'basic_attack' }),
  enemy_death_heavy = build_candidates(M.AUDIO_IDS, { 'enemy_death_heavy' }),
  enemy_death_burst = build_candidates(M.AUDIO_IDS, { 'enemy_death_burst' }),
  boss_death_heavy = build_candidates(M.AUDIO_IDS, { 'boss_death_heavy', 'enemy_death_heavy' }),
}

M.ATTACK_SKILL_ELEMENT_STAGE_MAP = {
  sword_wave = 'metal_slash',
  arcane_laser = 'beam',
  arcane_ray = 'beam',
  frost_nova = 'frost_burst',
  chain_lightning = 'thunder',
  earthquake = 'earth',
  tornado = 'wind',
  electro_net = 'thunder',
  meteor = 'fire',
  hurricane = 'wind',
  fireball = 'fire',
  moon_blade = 'metal_slash',
  lotus_flame = 'fire',
  demon_seal = 'seal',
  flying_swords = 'metal_slash',
}

local common_attack_stage_configs = {
  cast = make_stage(M.AUDIO_IDS, { 'attack_cast' }, 68, 0.10, { offset_z = 35 }),
  impact = make_stage(M.AUDIO_IDS, { 'attack_impact' }, 82, 0.08, { offset_z = 32, height = 28 }),
  chain = make_stage(M.AUDIO_IDS, { 'attack_chain' }, 74, 0.10, { offset_z = 30, height = 24 }),
  burst = make_stage(M.AUDIO_IDS, { 'attack_burst' }, 86, 0.18, { height = 28 }),
  tick = make_stage(M.AUDIO_IDS, { 'attack_tick' }, 56, 0.32, { height = 20 }),
  charge = make_stage(M.AUDIO_IDS, { 'attack_charge' }, 60, 0.20, { height = 20 }),
}

M.ATTACK_SKILL_STAGE_CONFIGS = {
  metal_slash = clone_stage_configs(common_attack_stage_configs),
  beam = clone_stage_configs(common_attack_stage_configs),
  frost_burst = clone_stage_configs(common_attack_stage_configs),
  thunder = clone_stage_configs(common_attack_stage_configs),
  earth = clone_stage_configs(common_attack_stage_configs),
  wind = clone_stage_configs(common_attack_stage_configs),
  fire = clone_stage_configs(common_attack_stage_configs),
  seal = clone_stage_configs(common_attack_stage_configs),
}

return M

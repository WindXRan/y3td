local M = {}

-- 本地音效 ID 调色板（编辑器中定义的音效对象）
local LOCAL_AUDIO_IDS = {
  bgm_loop = '201330383',
  bgm_alt = '201355418',
  ui_click = '134237363',
  ui_open = '201387287',
  ui_confirm = '201387323',
  attack = '134257538',
  attack_alt = '134249714',
  impact = '134257420',
  burst = '134257799',
}

-- 编辑器音效名称别名（中文名 → 可通过 str_to_audio_key 解析）
local AUDIO_KEY_NAME_ALIASES = {
  [LOCAL_AUDIO_IDS.bgm_loop] = { 'BGM' },
  [LOCAL_AUDIO_IDS.bgm_alt] = { '场景音乐 3' },
  [LOCAL_AUDIO_IDS.ui_click] = { 'UI-招募界面关闭' },
  [LOCAL_AUDIO_IDS.ui_open] = { '打开背包' },
  [LOCAL_AUDIO_IDS.ui_confirm] = { '胜利' },
  [LOCAL_AUDIO_IDS.attack] = { '弓箭攻击（3D）' },
  [LOCAL_AUDIO_IDS.attack_alt] = { '关羽普攻' },
  [LOCAL_AUDIO_IDS.impact] = { '郭嘉1技能' },
  [LOCAL_AUDIO_IDS.burst] = { '刘备击杀' },
}

-- 合并本地音效对象与旧版资源 ID 回退链
local function prepend_audio_ids(local_ids, fallback_ids)
  local result = {}
  local seen = {}
  local function add(id)
    if id == nil then return end
    local k = tostring(id)
    if k == '' or seen[k] then return end
    seen[k] = true
    result[#result + 1] = k
  end
  if type(local_ids) == 'table' then
    for _, id in ipairs(local_ids) do add(id) end
  else
    add(local_ids)
  end
  if type(fallback_ids) == 'table' then
    for _, id in ipairs(fallback_ids) do add(id) end
  else
    add(fallback_ids)
  end
  return result
end

-- 通用音效阶段候选（供各场景复用）
local AUDIO_CUES = {
  cast = { LOCAL_AUDIO_IDS.attack, LOCAL_AUDIO_IDS.attack_alt },
  impact = { LOCAL_AUDIO_IDS.impact },
  chain = { LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.attack_alt },
  burst = { LOCAL_AUDIO_IDS.burst },
  tick = { LOCAL_AUDIO_IDS.attack_alt, LOCAL_AUDIO_IDS.attack },
  charge = { LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.attack },
}

-- 攻击技能音效阶段本地候选
local ATTACK_SKILL_LOCAL_STAGE_IDS = {
  cast = prepend_audio_ids(AUDIO_CUES.cast, { '125774', '125771' }),
  impact = prepend_audio_ids(AUDIO_CUES.impact, { '125773', '125771' }),
  chain = prepend_audio_ids(AUDIO_CUES.chain, { '125771', '125773' }),
  burst = prepend_audio_ids(AUDIO_CUES.burst, { '125773', '125771' }),
  tick = prepend_audio_ids(AUDIO_CUES.tick, { '125772', '125771' }),
  charge = prepend_audio_ids(AUDIO_CUES.charge, { '125774', '125772' }),
}

-- 预设音效场景
local AUDIO_SCENES = {
  bgm_loop = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.bgm_loop, LOCAL_AUDIO_IDS.bgm_alt }, { '103381', '122707' }
  ),
  battle_loop = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.bgm_loop, LOCAL_AUDIO_IDS.bgm_alt }, { '103381', '104672', '104675', '122707' }
  ),
  boss_loop = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.bgm_alt, LOCAL_AUDIO_IDS.bgm_loop }, { '103381', '128336', '104675', '126780' }
  ),
  ui_click = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.ui_click, LOCAL_AUDIO_IDS.ui_open }, { '134223345' }
  ),
  ui_open = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.ui_open, LOCAL_AUDIO_IDS.ui_click },
    nil
  ),
  ui_confirm = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.ui_confirm }, { '122579' }
  ),
  ui_error = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.ui_open }, { '126040' }
  ),
  wave_start = prepend_audio_ids({ LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.attack_alt }, { '125774', '123320', '126054' }),
  boss_warning = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.burst, LOCAL_AUDIO_IDS.bgm_alt }, { '125774', '126780', '126042' }
  ),
  boss_spawn = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.burst, LOCAL_AUDIO_IDS.impact }, { '125775', '126780', '126042' }
  ),
  challenge_start = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.attack_alt, LOCAL_AUDIO_IDS.impact }, { '123320', '125774', '126042' }
  ),
  challenge_success = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.ui_confirm }, { '122579' }
  ),
  challenge_fail = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.ui_open }, { '126040', '126780', '126042' }
  ),
  hero_low_hp = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.burst, LOCAL_AUDIO_IDS.bgm_alt }, { '126780', '104675', '125774' }
  ),
  defeat = prepend_audio_ids(
    { LOCAL_AUDIO_IDS.burst, LOCAL_AUDIO_IDS.bgm_alt }, { '126040', '126780', '104675' }
  ),
  basic_attack = prepend_audio_ids({ LOCAL_AUDIO_IDS.attack, LOCAL_AUDIO_IDS.attack_alt }, { '123160', '125770' }),
  enemy_death_heavy = prepend_audio_ids({ 134278073, LOCAL_AUDIO_IDS.impact }, { '126040', '125775' }),
  enemy_death_burst = prepend_audio_ids({ LOCAL_AUDIO_IDS.burst }, { '126054', '126042' }),
}

-- 攻击技能元素 → 音效阶段配置名映射
local ATTACK_SKILL_ELEMENT_STAGE_MAP = {
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

-- 音效阶段配置（音量 / 冷却 / 偏移）
local ATTACK_SKILL_STAGE_CONFIGS = {
  metal_slash = {
    cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '123160', '125770' }), volume = 68, cooldown = 0.08, offset_z = 35 },
    impact = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.impact, { '125775', '126523' }), volume = 82, cooldown = 0.08, offset_z = 32 },
    chain = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.chain, { '126523', '125775' }), volume = 74, cooldown = 0.10, offset_z = 30 },
    burst = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.burst, { '125775', '125771' }), volume = 86, cooldown = 0.18, height = 28 },
    tick = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.tick, { '126523', '123160' }), volume = 56, cooldown = 0.32, height = 20 },
    charge = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.charge, { '125774', '125771' }), volume = 60, cooldown = 0.20, height = 20 },
  },
  beam = {
    cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '125774', '125771' }), volume = 70, cooldown = 0.10, offset_z = 35 },
    impact = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.impact, { '125773', '125771' }), volume = 80, cooldown = 0.10, height = 28 },
    chain = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.chain, { '125771', '125773' }), volume = 72, cooldown = 0.12, height = 24 },
    burst = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.burst, { '125773', '125771' }), volume = 86, cooldown = 0.20, height = 32 },
    tick = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.tick, { '125772', '125771' }), volume = 58, cooldown = 0.34, height = 24 },
    charge = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.charge, { '125774', '125772' }), volume = 62, cooldown = 0.20, height = 24 },
  },
  frost_burst = {
    cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '123320', '126523' }), volume = 66, cooldown = 0.10, offset_z = 35 },
    impact = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.impact, { '123312', '126524' }), volume = 82, cooldown = 0.08, height = 28 },
    chain = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.chain, { '126524', '123312' }), volume = 72, cooldown = 0.10, height = 24 },
    burst = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.burst, { '123312', '126524' }), volume = 86, cooldown = 0.18, height = 30 },
    tick = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.tick, { '126524', '123320' }), volume = 56, cooldown = 0.32, height = 22 },
    charge = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.charge, { '123320', '126524' }), volume = 60, cooldown = 0.22, height = 22 },
  },
  thunder = {
    cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '125774', '123320' }), volume = 70, cooldown = 0.10, offset_z = 35 },
    impact = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.impact, { '125775', '125771' }), volume = 84, cooldown = 0.08, height = 30 },
    chain = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.chain, { '125771', '125775' }), volume = 78, cooldown = 0.10, height = 28 },
    burst = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.burst, { '125775', '125774' }), volume = 90, cooldown = 0.18, height = 34 },
    tick = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.tick, { '125771', '123320' }), volume = 58, cooldown = 0.26, height = 24 },
    charge = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.charge, { '125774', '125771' }), volume = 64, cooldown = 0.18, height = 24 },
  },
  earth = {
    cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '123320', '123160' }), volume = 64, cooldown = 0.12, offset_z = 35 },
    impact = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.impact, { '125775', '126040' }), volume = 84, cooldown = 0.10, height = 28 },
    chain = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.chain, { '125775', '126523' }), volume = 70, cooldown = 0.12, height = 24 },
    burst = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.burst, { '125775', '126040' }), volume = 90, cooldown = 0.22, height = 32 },
    tick = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.tick, { '126523', '123320' }), volume = 54, cooldown = 0.34, height = 22 },
    charge = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.charge, { '125774', '123320' }), volume = 60, cooldown = 0.22, height = 22 },
  },
  wind = {
    cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '126042', '123320' }), volume = 70, cooldown = 0.10, offset_z = 35 },
    impact = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.impact, { '126054', '126042' }), volume = 78, cooldown = 0.10, height = 28 },
    chain = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.chain, { '126042', '123160' }), volume = 72, cooldown = 0.10, height = 26 },
    burst = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.burst, { '126042', '126054' }), volume = 84, cooldown = 0.20, height = 30 },
    tick = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.tick, { '126042', '123320' }), volume = 58, cooldown = 0.28, height = 24 },
    charge = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.charge, { '123320', '126042' }), volume = 62, cooldown = 0.20, height = 24 },
  },
  fire = {
    cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '125770', '126054' }), volume = 70, cooldown = 0.10, offset_z = 35 },
    impact = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.impact, { '126054', '125775' }), volume = 82, cooldown = 0.08, height = 28 },
    chain = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.chain, { '126054', '125770' }), volume = 72, cooldown = 0.10, height = 24 },
    burst = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.burst, { '126042', '126054' }), volume = 90, cooldown = 0.18, height = 32 },
    tick = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.tick, { '125770', '126042' }), volume = 60, cooldown = 0.28, height = 24 },
    charge = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.charge, { '125774', '125770' }), volume = 64, cooldown = 0.18, height = 24 },
  },
  seal = {
    cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '125774', '125771' }), volume = 68, cooldown = 0.10, offset_z = 35 },
    impact = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.impact, { '125775', '125771' }), volume = 82, cooldown = 0.10, height = 28 },
    chain = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.chain, { '125771', '125775' }), volume = 70, cooldown = 0.12, height = 24 },
    burst = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.burst, { '125773', '125775' }), volume = 88, cooldown = 0.22, height = 32 },
    tick = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.tick, { '125772', '125771' }), volume = 56, cooldown = 0.32, height = 24 },
    charge = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.charge, { '125774', '125772' }), volume = 62, cooldown = 0.20, height = 24 },
  },
}

-- ============================================================
-- create(params) — 构建音频运行时，返回公共 API
-- ============================================================
function M.create(params)
  local STATE = params.STATE
  local y3 = params.y3
  local get_player = params.get_player
  local trace = params.trace or function() end
  local debug_missing_audio = params.debug_missing_audio == true

  -- ---------- 运行时状态 ----------
  local function ensure_runtime()
    if not STATE.audio_runtime then
      STATE.audio_runtime = {
        bgm_sound = nil,
        music_watchdog = nil,
        key_cache = {},
        key_alias_cache = {},
        missing_keys = {},
        playback_failures = {},
        stage_gate = {},
        music_phase = 'outgame',
        low_hp_gate = 0,
        audio_channels_ready = false,
        listener_anchor = nil,
      }
    end
    return STATE.audio_runtime
  end

  -- ---------- 通用辅助 ----------
  local function get_hero()
    local hero = STATE.hero
    if hero and hero.is_exist and hero:is_exist() then
      return hero
    end
    return nil
  end

  local function format_audio_ids(audio_ids)
    if type(audio_ids) == 'table' then
      return table.concat(audio_ids, ', ')
    end
    return tostring(audio_ids or '')
  end

  local function normalize_audio_candidates(audio_ids)
    if type(audio_ids) == 'table' then return audio_ids end
    if audio_ids ~= nil then return { audio_ids } end
    return {}
  end

  local function record_playback_failure(audio_key, message)
    local runtime = ensure_runtime()
    if runtime.playback_failures[audio_key] == true then return end
    runtime.playback_failures[audio_key] = true
    trace(message)
  end

  -- ---------- 音频通道初始化 ----------
  local function ensure_audio_channels_ready()
    local runtime = ensure_runtime()
    local player = get_player()
    if not player then return nil end
    if runtime.audio_channels_ready == true then return player end
    runtime.audio_channels_ready = true
    if GameAPI and GameAPI.set_role_all_sound_switch then
      pcall(GameAPI.set_role_all_sound_switch, player.handle, true)
    end
    if GameAPI and GameAPI.open_background_music then
      pcall(GameAPI.open_background_music, player.handle, true)
    end
    if GameAPI and GameAPI.open_battle_music then
      pcall(GameAPI.open_battle_music, player.handle, true)
    end
    if GameAPI and GameAPI.get_bgm_volume and GameAPI.set_background_music_volume then
      pcall(function()
        if (tonumber(GameAPI.get_bgm_volume()) or 0) <= 0 then
          GameAPI.set_background_music_volume(player.handle, 72)
        end
      end)
    end
    if GameAPI and GameAPI.get_battle_volume and GameAPI.set_battle_music_volume then
      pcall(function()
        if (tonumber(GameAPI.get_battle_volume()) or 0) <= 0 then
          GameAPI.set_battle_music_volume(player.handle, 80)
        end
      end)
    end
    return player
  end

  -- ---------- 句柄有效性 ----------
  local function is_sound_handle_alive(sound)
    if not sound then return false end
    if type(IsValid) == 'function' then
      local ok, is_valid = pcall(IsValid, sound)
      if ok then return is_valid == true end
    end
    return true
  end

  local function is_sound_running(sound)
    if not sound then return false end
    local t = type(sound)
    if t ~= 'table' and t ~= 'userdata' then return false end
    if type(sound.is_running) == 'function' then
      local ok, running = pcall(sound.is_running, sound)
      if ok then return running == true end
    end
    if type(sound.is_removed) == 'function' then
      local ok, removed = pcall(sound.is_removed, sound)
      if ok then return removed ~= true end
    end
    return false
  end

  -- ---------- 3D 监听器 ----------
  local function ensure_audio_listener(anchor)
    local player = ensure_audio_channels_ready()
    if not player then return nil end
    local target = anchor
    if not target or not target.is_exist or not target:is_exist() then
      target = get_hero()
    end
    if not target or not target.is_exist or not target:is_exist() then
      return player
    end
    local runtime = ensure_runtime()
    if runtime.listener_anchor == target then return player end
    if GameAPI and GameAPI.set_player_listener_to_follow_unit then
      pcall(GameAPI.set_player_listener_to_follow_unit, player.handle, target.handle)
      runtime.listener_anchor = target
    end
    return player
  end

  -- ---------- 停止音效 ----------
  local function stop_sound(sound, is_immediately)
    if not sound then return end
    local player = get_player()
    if not player then return end
    sound:stop(player, is_immediately == true)
  end

  -- ---------- 音效键解析与缓存 ----------
  local function resolve_audio_key_aliases(audio_id)
    local runtime = ensure_runtime()
    local cache_key = tostring(audio_id or '')
    if cache_key == '' then return {} end
    local cached = runtime.key_alias_cache[cache_key]
    if cached ~= nil then
      if cached == false then return {} end
      return cached
    end
    local alias_names = AUDIO_KEY_NAME_ALIASES[cache_key]
    if type(alias_names) ~= 'table' or #alias_names == 0 then
      runtime.key_alias_cache[cache_key] = false
      return {}
    end
    local result = {}
    for _, alias_name in ipairs(alias_names) do
      local ok, key = pcall(y3.game.str_to_audio_key, alias_name)
      local numeric_key = ok and tonumber(key) or nil
      if numeric_key then result[#result + 1] = numeric_key end
    end
    runtime.key_alias_cache[cache_key] = #result > 0 and result or false
    if runtime.key_alias_cache[cache_key] == false then return {} end
    return runtime.key_alias_cache[cache_key]
  end

  -- 解析单个音效 ID（数值直接用，字符串名走 str_to_audio_key + 别名）
  local function resolve_single_audio_key(raw_key)
    local runtime = ensure_runtime()
    local cache_key = tostring(raw_key or '')
    if cache_key == '' then return nil end
    local cached = runtime.key_cache[cache_key]
    if cached ~= nil then return cached or nil end
    local numeric_id = tonumber(cache_key)
    if numeric_id then
      runtime.key_cache[cache_key] = numeric_id
      return numeric_id
    end
    local ok, key = pcall(y3.game.str_to_audio_key, cache_key)
    local numeric_key = ok and tonumber(key) or nil
    if not numeric_key then
      runtime.key_cache[cache_key] = false
      return nil
    end
    runtime.key_cache[cache_key] = numeric_key
    return numeric_key
  end

  -- 解析候选列表（每个 ID 尝试直接解析 + 别名解析）
  local function resolve_audio_candidates(audio_ids, audio_label)
    local normalized = normalize_audio_candidates(audio_ids)
    local result = {}
    local seen = {}
    local function add_key(key)
      if not key then return end
      local k = tostring(key)
      if seen[k] then return end
      seen[k] = true
      result[#result + 1] = key
      if GameAPI and GameAPI.int_transform_sound_type then
        local ok, transformed_key = pcall(GameAPI.int_transform_sound_type, key)
        local numeric_transformed_key = ok and tonumber(transformed_key) or nil
        if numeric_transformed_key and not seen[tostring(numeric_transformed_key)] then
          seen[tostring(numeric_transformed_key)] = true
          result[#result + 1] = numeric_transformed_key
        end
      end
    end
    for _, audio_id in ipairs(normalized) do
      local direct_key = resolve_single_audio_key(audio_id)
      if direct_key then add_key(direct_key) end
      local alias_keys = resolve_audio_key_aliases(audio_id)
      for _, alias_key in ipairs(alias_keys) do add_key(alias_key) end
    end
    if debug_missing_audio and audio_label and #normalized > 0 and #result == 0 then
      local runtime = ensure_runtime()
      local missing_label = string.format('%s::%s', audio_label, table.concat(normalized, '|'))
      if runtime.missing_keys[missing_label] ~= true then
        runtime.missing_keys[missing_label] = true
        trace(string.format('[audio] all candidates missing for %s: %s', audio_label, table.concat(normalized, ', ')))
      end
    end
    return result
  end

  -- 尝试每个候选直到播放成功
  local function play_audio_candidates(audio_ids, audio_label, play_once)
    local candidates = resolve_audio_candidates(audio_ids, audio_label)
    local resolved_any = #candidates > 0
    for _, key in ipairs(candidates) do
      local ok, sound = pcall(play_once, key)
      if ok and sound then return sound end
    end
    if audio_label then
      local failure_type = resolved_any and 'play' or 'resolve'
      record_playback_failure(failure_type .. ':' .. audio_label,
        string.format('[audio] %s failed for %s: %s', failure_type, audio_label, format_audio_ids(audio_ids)))
    end
    return nil
  end

  -- 解析并返回首个有效音效键（不播放）
  local function resolve_audio_key(audio_ids, audio_label)
    local candidates = resolve_audio_candidates(audio_ids, audio_label)
    return candidates[1]
  end

  -- ---------- BGM 播放 ----------
  local function play_bgm(audio_ids, options, audio_label)
    local runtime = ensure_runtime()
    stop_sound(runtime.bgm_sound, true)
    runtime.bgm_sound = nil
    runtime.bgm_sound = play_audio_candidates(audio_ids, audio_label, function(key)
      local player = ensure_audio_channels_ready()
      if not player then return nil end
      return y3.sound.play(player, key, {
        loop = true,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
      })
    end)
    if runtime.bgm_sound and options and options.volume then
      local player = get_player()
      if player then runtime.bgm_sound:set_volume(player, options.volume) end
    end
    return runtime.bgm_sound
  end

  local function set_music_phase(phase)
    local runtime = ensure_runtime()
    local normalized = phase or 'outgame'
    if runtime.music_phase == normalized and is_sound_handle_alive(runtime.bgm_sound) then
      return runtime.bgm_sound
    end
    runtime.bgm_sound = nil
    runtime.music_phase = normalized
    if normalized == 'battle' then
      return play_bgm(AUDIO_SCENES.battle_loop, { fade_in = 0.5, fade_out = 0.2, volume = 62 }, 'battle_loop')
    end
    if normalized == 'boss' then
      return play_bgm(AUDIO_SCENES.boss_loop, { fade_in = 0.35, fade_out = 0.15, volume = 70 }, 'boss_loop')
    end
    return play_bgm(AUDIO_SCENES.bgm_loop, { fade_in = 0.4, fade_out = 0.2, volume = 58 }, 'bgm_loop')
  end

  -- ---------- 音乐看门狗 ----------
  local function ensure_music_watchdog()
    local runtime = ensure_runtime()
    if is_sound_running(runtime.music_watchdog) then return runtime.music_watchdog end
    runtime.music_watchdog = nil
    if not y3 or not y3.ltimer or type(y3.ltimer.loop) ~= 'function' then return nil end
    local ok, err = pcall(function()
      runtime.music_watchdog = y3.ltimer.loop(2.5, function()
        local current = ensure_runtime()
        if current.music_phase == 'result' then return end
        if is_sound_handle_alive(current.bgm_sound) then return end
        current.bgm_sound = nil
        set_music_phase(current.music_phase or 'outgame')
      end, 'audio_music_watchdog')
    end)
    if not ok then
      record_playback_failure('music_watchdog_create_failed',
        string.format('[audio] failed to create music watchdog: %s', tostring(err)))
      return nil
    end
    return runtime.music_watchdog
  end

  -- ---------- 通用 2D 播放 ----------
  local function play_audio_scene(audio_ids, options, audio_label)
    return play_audio_candidates(audio_ids, audio_label, function(key)
      local player = ensure_audio_channels_ready()
      if not player then return nil end
      return y3.sound.play(player, key, {
        loop = options and options.loop == true or false,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
      })
    end)
  end

  -- 跟随单位播放
  local function play_for_unit(audio_ids, unit, options, audio_label)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return play_audio_scene(audio_ids, options, audio_label)
    end
    return play_audio_candidates(audio_ids, audio_label, function(key)
      local player = ensure_audio_listener(unit)
      if not player then return nil end
      return y3.sound.play_with_object(player, key, unit, {
        loop = options and options.loop == true or false,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
        ensure = options and options.ensure == true or false,
        offset_x = options and options.offset_x or 0,
        offset_y = options and options.offset_y or 0,
        offset_z = options and options.offset_z or 0,
      })
    end)
  end

  -- 3D 定点播放
  local function play_audio_3d(audio_ids, point, options, audio_label)
    if not point then return play_audio_scene(audio_ids, options, audio_label) end
    return play_audio_candidates(audio_ids, audio_label, function(key)
      local player = ensure_audio_listener(get_hero())
      if not player then return nil end
      return y3.sound.play_3d(player, key, point, {
        loop = options and options.loop == true or false,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
        ensure = options and options.ensure == true or false,
        height = options and options.height or 0,
      })
    end)
  end

  -- ---------- 英雄血量 ----------
  local function get_hero_hp_ratio()
    local hero = get_hero()
    if not hero then return nil end
    local hp = tonumber(hero.get_hp and hero:get_hp() or 0) or 0
    local max_hp = 0
    if hero.get_max_hp then max_hp = tonumber(hero:get_max_hp()) or 0 end
    if max_hp <= 0 and hero.get_attr then
      max_hp = tonumber(hero:get_attr('最大生命')) or tonumber(hero:get_attr('生命')) or 0
    end
    if max_hp <= 0 then return nil end
    return hp / max_hp
  end

  -- ---------- 攻击技能音效 ----------
  local function get_skill_stage_profile(skill)
    if not skill then return 'metal_slash' end
    if skill.id and ATTACK_SKILL_ELEMENT_STAGE_MAP[skill.id] then
      return ATTACK_SKILL_ELEMENT_STAGE_MAP[skill.id]
    end
    if skill.element == 'fire' then return 'fire' end
    if skill.element == 'water' then return 'frost_burst' end
    if skill.element == 'earth' then return 'earth' end
    if skill.element == 'wood' then return 'thunder' end
    if skill.damage_form == 'weapon' then return 'metal_slash' end
    return 'beam'
  end

  local function get_skill_stage_config(skill, stage)
    local profile_name = get_skill_stage_profile(skill)
    local profile = ATTACK_SKILL_STAGE_CONFIGS[profile_name] or {}
    return profile_name, profile[stage or 'cast'] or profile.cast or {}
  end

  local function check_stage_cooldown(skill, stage, cooldown)
    cooldown = tonumber(cooldown) or 0
    if cooldown <= 0 then return false end
    local runtime = ensure_runtime()
    local now = os.clock and os.clock() or 0
    local gate_key = string.format('%s:%s', tostring(skill and skill.id or 'attack_skill'), tostring(stage or 'cast'))
    local gate_deadline = runtime.stage_gate[gate_key] or 0
    if gate_deadline > now then return true end
    runtime.stage_gate[gate_key] = now + cooldown
    return false
  end

  local function play_attack_skill(skill, source_anchor, stage)
    local stage_name = stage or 'cast'
    local profile_name, stage_config = get_skill_stage_config(skill, stage_name)
    local audio_ids = stage_config.ids or AUDIO_SCENES.basic_attack
    if check_stage_cooldown(skill, stage_name, stage_config.cooldown) then return nil end
    local audio_label = string.format('attack_skill_%s_%s', tostring(skill and skill.id or profile_name), stage_name)
    local options = {
      volume = stage_config.volume or 72,
      ensure = stage_config.ensure == true,
      offset_z = stage_config.offset_z or 35,
      height = stage_config.height or 0,
    }
    if source_anchor and type(source_anchor.is_exist) == 'function' then
      return play_for_unit(audio_ids, source_anchor, options, audio_label)
    end
    if source_anchor then
      return play_audio_3d(audio_ids, source_anchor, options, audio_label)
    end
    return play_audio_scene(audio_ids, options, audio_label)
  end

  -- ---------- 敌人死亡音效 ----------
  local function play_enemy_death(unit, is_boss, death_point)
    local heavy_sound
    if death_point then
      heavy_sound = play_audio_3d(AUDIO_SCENES.enemy_death_heavy, death_point, {
        volume = is_boss and 100 or 92,
        ensure = true,
        height = 45,
      }, 'enemy_death_heavy')
      play_audio_3d(AUDIO_SCENES.enemy_death_burst, death_point, {
        volume = is_boss and 94 or 82,
        height = 65,
      }, 'enemy_death_burst')
      return heavy_sound
    end
    heavy_sound = play_for_unit(AUDIO_SCENES.enemy_death_heavy, unit, {
      volume = is_boss and 100 or 92,
      ensure = true,
      offset_z = 45,
    }, 'enemy_death_heavy')
    play_for_unit(AUDIO_SCENES.enemy_death_burst, unit, {
      volume = is_boss and 94 or 82,
      offset_z = 65,
    }, 'enemy_death_burst')
    return heavy_sound
  end

  -- ============================
  -- 公共 API
  -- ============================

  local function ensure_music_loop()
    ensure_music_watchdog()
    return set_music_phase('outgame')
  end

  local function enter_battle()
    ensure_audio_listener(get_hero())
    ensure_music_watchdog()
    return set_music_phase('battle')
  end

  local function handle_wave_started(wave_index)
    if tonumber(wave_index) == nil then return nil end
    set_music_phase('battle')
    return play_audio_scene(AUDIO_SCENES.wave_start, {
      volume = wave_index <= 1 and 68 or 74,
    }, 'wave_start')
  end

  local function handle_boss_warning()
    return play_audio_scene(AUDIO_SCENES.boss_warning, { volume = 78 }, 'boss_warning')
  end

  local function handle_boss_spawned(boss_info)
    set_music_phase('boss')
    local unit = boss_info and boss_info.unit or get_hero()
    return play_for_unit(AUDIO_SCENES.boss_spawn, unit, {
      volume = 92,
      ensure = true,
      offset_z = 60,
    }, 'boss_spawn')
  end

  local function handle_challenge_started(instance)
    local unit = instance and instance.infos and instance.infos[1] and instance.infos[1].unit or get_hero()
    return play_for_unit(AUDIO_SCENES.challenge_start, unit, {
      volume = 72,
      offset_z = 40,
    }, 'challenge_start')
  end

  local function handle_challenge_finished(instance, is_success)
    if is_success == true then
      return play_audio_scene(AUDIO_SCENES.challenge_success, { volume = 76 }, 'challenge_success')
    end
    return play_audio_scene(AUDIO_SCENES.challenge_fail, { volume = 74 }, 'challenge_fail')
  end

  local function handle_hero_be_hurt()
    local hp_ratio = get_hero_hp_ratio()
    if not hp_ratio or hp_ratio > 0.35 then return nil end
    local runtime = ensure_runtime()
    local now = os.clock and os.clock() or 0
    if runtime.low_hp_gate and runtime.low_hp_gate > now then return nil end
    runtime.low_hp_gate = now + 4.0
    return play_audio_scene(AUDIO_SCENES.hero_low_hp, { volume = 58 }, 'hero_low_hp')
  end

  local function handle_battle_finished(result)
    local runtime = ensure_runtime()
    stop_sound(runtime.bgm_sound, true)
    runtime.bgm_sound = nil
    runtime.music_phase = 'result'
    if result and result.is_win == true then
      return play_audio_scene(AUDIO_SCENES.ui_confirm, { volume = 92 }, 'ui_confirm')
    end
    return play_audio_scene(AUDIO_SCENES.defeat, { volume = 84 }, 'defeat')
  end

  local function play_ui_click()
    return play_audio_scene(AUDIO_SCENES.ui_click, { volume = 74 }, 'ui_click')
  end

  local function play_ui_error()
    return play_audio_scene(AUDIO_SCENES.ui_error, { volume = 76 }, 'ui_error')
  end

  local function play_panel_open()
    return play_audio_scene(AUDIO_SCENES.ui_open, { volume = 70 }, 'ui_open')
  end

  local function play_confirm()
    return play_audio_scene(AUDIO_SCENES.ui_confirm, { volume = 68 }, 'ui_confirm')
  end

  local function play_victory()
    return play_audio_scene(AUDIO_SCENES.ui_confirm, { volume = 92 }, 'ui_confirm')
  end

  local function play_defeat()
    return play_audio_scene(AUDIO_SCENES.defeat, { volume = 84 }, 'defeat')
  end

  local function play_basic_attack(unit)
    return play_for_unit(AUDIO_SCENES.basic_attack, unit, { volume = 66 }, 'basic_attack')
  end

  return {
    ensure_music_loop = ensure_music_loop,
    enter_battle = enter_battle,
    handle_wave_started = handle_wave_started,
    handle_boss_warning = handle_boss_warning,
    handle_boss_spawned = handle_boss_spawned,
    handle_challenge_started = handle_challenge_started,
    handle_challenge_finished = handle_challenge_finished,
    handle_hero_be_hurt = handle_hero_be_hurt,
    handle_battle_finished = handle_battle_finished,
    play_ui_click = play_ui_click,
    play_ui_error = play_ui_error,
    play_panel_open = play_panel_open,
    play_confirm = play_confirm,
    play_victory = play_victory,
    play_defeat = play_defeat,
    play_basic_attack = play_basic_attack,
    play_attack_skill = play_attack_skill,
    play_enemy_death = play_enemy_death,
  }
end

return M

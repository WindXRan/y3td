local M = {}

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

local function prepend_audio_ids(local_ids, fallback_ids)
  local merged = {}
  local seen = {}

  local function push(id)
    if id == nil then
      return
    end
    local value = tostring(id)
    if value == '' or seen[value] then
      return
    end
    seen[value] = true
    merged[#merged + 1] = value
  end

  if type(local_ids) == 'table' then
    for _, id in ipairs(local_ids) do
      push(id)
    end
  else
    push(local_ids)
  end

  if type(fallback_ids) == 'table' then
    for _, id in ipairs(fallback_ids) do
      push(id)
    end
  else
    push(fallback_ids)
  end

  return merged
end

local ATTACK_SKILL_LOCAL_STAGE_IDS = {
  cast = { LOCAL_AUDIO_IDS.attack, LOCAL_AUDIO_IDS.attack_alt },
  impact = { LOCAL_AUDIO_IDS.impact },
  chain = { LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.attack_alt },
  burst = { LOCAL_AUDIO_IDS.burst },
  tick = { LOCAL_AUDIO_IDS.attack_alt, LOCAL_AUDIO_IDS.attack },
  charge = { LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.attack },
}

local AUDIO_IDS = {
  bgm_loop = prepend_audio_ids({ LOCAL_AUDIO_IDS.bgm_loop, LOCAL_AUDIO_IDS.bgm_alt }, { '103381', '122707' }), -- 主题音乐 / 氛围_神秘的_融合
  battle_loop = prepend_audio_ids({ LOCAL_AUDIO_IDS.bgm_loop, LOCAL_AUDIO_IDS.bgm_alt }, { '103381', '104672', '104675', '122707' }), -- 主题音乐 / 氛围循环
  boss_loop = prepend_audio_ids({ LOCAL_AUDIO_IDS.bgm_alt, LOCAL_AUDIO_IDS.bgm_loop }, { '103381', '128336', '104675', '126780' }), -- 主题音乐 / Boss 压迫氛围
  ui_click = prepend_audio_ids({ LOCAL_AUDIO_IDS.ui_click, LOCAL_AUDIO_IDS.ui_open }, { '134223345' }), -- 点击 / 面板反馈
  ui_open = prepend_audio_ids({ LOCAL_AUDIO_IDS.ui_open, LOCAL_AUDIO_IDS.ui_click }, nil), -- 打开背包
  ui_confirm = prepend_audio_ids({ LOCAL_AUDIO_IDS.ui_confirm }, { '122579' }), -- 胜利
  ui_error = prepend_audio_ids({ LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.ui_open }, { '126040' }), -- 反馈失败/资源不足
  wave_start = prepend_audio_ids({ LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.attack_alt }, { '125774', '123320', '126054' }), -- 开波提示
  boss_warning = prepend_audio_ids({ LOCAL_AUDIO_IDS.burst, LOCAL_AUDIO_IDS.bgm_alt }, { '125774', '126780', '126042' }), -- Boss 预警
  boss_spawn = prepend_audio_ids({ LOCAL_AUDIO_IDS.burst, LOCAL_AUDIO_IDS.impact }, { '125775', '126780', '126042' }), -- Boss 登场
  challenge_start = prepend_audio_ids({ LOCAL_AUDIO_IDS.attack_alt, LOCAL_AUDIO_IDS.impact }, { '123320', '125774', '126042' }),
  challenge_success = prepend_audio_ids({ LOCAL_AUDIO_IDS.ui_confirm }, { '122579' }),
  challenge_fail = prepend_audio_ids({ LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.ui_open }, { '126040', '126780', '126042' }),
  hero_low_hp = prepend_audio_ids({ LOCAL_AUDIO_IDS.burst, LOCAL_AUDIO_IDS.bgm_alt }, { '126780', '104675', '125774' }),
  defeat = prepend_audio_ids({ LOCAL_AUDIO_IDS.burst, LOCAL_AUDIO_IDS.bgm_alt }, { '126040', '126780', '104675' }),
  basic_attack = prepend_audio_ids({
    '134257538', -- 本地普攻音效 key
    LOCAL_AUDIO_IDS.attack_alt,
  }, {
    '123160', -- 嗖声_布料_快的
    '125770', -- 魔法_嗖声_植被
  }),
  enemy_death_heavy = prepend_audio_ids({
    '134257420', -- 本地死亡重击 key
  }, {
    '126040', -- 受击_皮革
    '125775', -- 魔法_金属_受击
  }),
  enemy_death_burst = prepend_audio_ids({
    '134257799', -- 本地死亡爆裂 key
  }, {
    '126054', -- 嗖声_布料_击中
    '126042', -- 法术_风_吹_大规模的
  }),
}

local ATTACK_SKILL_AUDIO_PROFILE_BY_ID = {
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

local ATTACK_SKILL_AUDIO_STAGE_CONFIG = {
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

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local trace = env.trace or function() end
  local debug_missing_audio = env.debug_missing_audio == true
  local play_for_player
  local play_for_unit
  local play_for_point

  local function get_runtime()
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

  local function get_player_safe()
    return get_player and get_player() or nil
  end

  local function trace_audio_once(key, text)
    local runtime = get_runtime()
    if runtime.playback_failures[key] == true then
      return
    end
    runtime.playback_failures[key] = true
    trace(text)
  end

  local function describe_audio_ids(audio_ids)
    if type(audio_ids) == 'table' then
      return table.concat(audio_ids, ', ')
    end
    return tostring(audio_ids or '')
  end

  local function normalize_audio_candidates(audio_ids)
    if type(audio_ids) == 'table' then
      return audio_ids
    end
    if audio_ids ~= nil then
      return { audio_ids }
    end
    return {}
  end

  local function ensure_audio_channels_ready()
    local runtime = get_runtime()
    local player = get_player_safe()
    if not player then
      return nil
    end
    if runtime.audio_channels_ready == true then
      return player
    end

    runtime.audio_channels_ready = true

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

  local function is_sound_handle_alive(sound)
    if not sound then
      return false
    end
    if type(IsValid) == 'function' then
      local ok, alive = pcall(IsValid, sound)
      if ok then
        return alive == true
      end
    end
    return true
  end

  local function is_timer_handle_alive(timer)
    if not timer then
      return false
    end

    local timer_type = type(timer)
    if timer_type ~= 'table' and timer_type ~= 'userdata' then
      return false
    end

    if type(timer.is_running) == 'function' then
      local ok, running = pcall(timer.is_running, timer)
      if ok then
        return running == true
      end
    end

    if type(timer.is_removed) == 'function' then
      local ok, removed = pcall(timer.is_removed, timer)
      if ok then
        return removed ~= true
      end
    end

    return false
  end

  local function ensure_audio_listener(anchor)
    local player = ensure_audio_channels_ready()
    if not player then
      return nil
    end

    local resolved_anchor = anchor
    if not resolved_anchor or not resolved_anchor.is_exist or not resolved_anchor:is_exist() then
      resolved_anchor = get_hero()
    end
    if not resolved_anchor or not resolved_anchor.is_exist or not resolved_anchor:is_exist() then
      return player
    end

    local runtime = get_runtime()
    if runtime.listener_anchor == resolved_anchor then
      return player
    end

    if GameAPI and GameAPI.set_player_listener_to_follow_unit then
      pcall(GameAPI.set_player_listener_to_follow_unit, player.handle, resolved_anchor.handle)
      runtime.listener_anchor = resolved_anchor
    end
    return player
  end

  local function stop_sound(sound, is_immediately)
    if not sound then
      return
    end
    local player = get_player_safe()
    if not player then
      return
    end
    sound:stop(player, is_immediately == true)
  end

  local function replace_loop(audio_ids, options, audio_label)
    local runtime = get_runtime()
    stop_sound(runtime.bgm_sound, true)
    runtime.bgm_sound = nil
    runtime.bgm_sound = play_for_player(audio_ids, {
      loop = true,
      fade_in = options and options.fade_in or 0,
      fade_out = options and options.fade_out or 0,
      volume = options and options.volume or 40,
    }, audio_label)
    return runtime.bgm_sound
  end

  local function get_hero()
    local hero = STATE.hero
    if hero and hero.is_exist and hero:is_exist() then
      return hero
    end
    return nil
  end

  local function get_hero_hp_ratio()
    local hero = get_hero()
    if not hero then
      return nil
    end

    local hp = tonumber(hero.get_hp and hero:get_hp() or 0) or 0
    local max_hp = 0
    if hero.get_max_hp then
      max_hp = tonumber(hero:get_max_hp()) or 0
    end
    if max_hp <= 0 and hero.get_attr then
      max_hp = tonumber(hero:get_attr('最大生命')) or tonumber(hero:get_attr('生命')) or 0
    end
    if max_hp <= 0 then
      return nil
    end
    return hp / max_hp
  end

  local function set_music_phase(phase)
    local runtime = get_runtime()
    local normalized = phase or 'outgame'
    if runtime.music_phase == normalized and is_sound_handle_alive(runtime.bgm_sound) then
      return runtime.bgm_sound
    end

    runtime.bgm_sound = nil
    runtime.music_phase = normalized
    if normalized == 'battle' then
      return replace_loop(AUDIO_IDS.battle_loop, {
        fade_in = 0.5,
        fade_out = 0.2,
        volume = 62,
      }, 'battle_loop')
    end
    if normalized == 'boss' then
      return replace_loop(AUDIO_IDS.boss_loop, {
        fade_in = 0.35,
        fade_out = 0.15,
        volume = 70,
      }, 'boss_loop')
    end
    return replace_loop(AUDIO_IDS.bgm_loop, {
      fade_in = 0.4,
      fade_out = 0.2,
      volume = 58,
    }, 'bgm_loop')
  end

  local function ensure_music_watchdog()
    local runtime = get_runtime()
    if is_timer_handle_alive(runtime.music_watchdog) then
      return runtime.music_watchdog
    end
    runtime.music_watchdog = nil
    if not y3 or not y3.ltimer or type(y3.ltimer.loop) ~= 'function' then
      return nil
    end

    local ok, watchdog = pcall(y3.ltimer.loop, 2.5, function()
      local current = get_runtime()
      if current.music_phase == 'result' then
        return
      end
      if is_sound_handle_alive(current.bgm_sound) then
        return
      end
      current.bgm_sound = nil
      set_music_phase(current.music_phase or 'outgame')
    end, 'audio_music_watchdog')
    if not ok then
      trace_audio_once('music_watchdog_create_failed', string.format('[audio] failed to create music watchdog: %s', tostring(watchdog)))
      return nil
    end
    runtime.music_watchdog = watchdog
    return runtime.music_watchdog
  end

  local function resolve_audio_key_candidate(audio_id)
    local runtime = get_runtime()
    local cache_key = tostring(audio_id or '')
    if cache_key == '' then
      return nil
    end

    local cached = runtime.key_cache[cache_key]
    if cached ~= nil then
      return cached or nil
    end

    local numeric_id = tonumber(cache_key)
    if numeric_id then
      runtime.key_cache[cache_key] = numeric_id
      return numeric_id
    end

    local ok, audio_key = pcall(y3.game.str_to_audio_key, cache_key)
    if not ok or not audio_key then
      runtime.key_cache[cache_key] = false
      return nil
    end

    runtime.key_cache[cache_key] = audio_key
    return audio_key
  end

  local function resolve_audio_key_aliases(audio_id)
    local runtime = get_runtime()
    local cache_key = tostring(audio_id or '')
    if cache_key == '' then
      return {}
    end

    local cached = runtime.key_alias_cache[cache_key]
    if cached ~= nil then
      if cached == false then
        return {}
      end
      return cached
    end

    local aliases = AUDIO_KEY_NAME_ALIASES[cache_key]
    if type(aliases) ~= 'table' or #aliases == 0 then
      runtime.key_alias_cache[cache_key] = false
      return {}
    end

    local resolved = {}
    for _, alias in ipairs(aliases) do
      local ok, audio_key = pcall(y3.game.str_to_audio_key, alias)
      if ok and audio_key then
        resolved[#resolved + 1] = audio_key
      end
    end

    runtime.key_alias_cache[cache_key] = #resolved > 0 and resolved or false
    if runtime.key_alias_cache[cache_key] == false then
      return {}
    end
    return runtime.key_alias_cache[cache_key]
  end

  local function resolve_audio_key(audio_ids, audio_label)
    local candidates = normalize_audio_candidates(audio_ids)
    local resolved = {}
    local seen = {}

    local function push_resolved(audio_key)
      if not audio_key then
        return
      end
      local token = tostring(audio_key)
      if seen[token] then
        return
      end
      seen[token] = true
      resolved[#resolved + 1] = audio_key
    end

    for _, audio_id in ipairs(candidates) do
      local audio_key = resolve_audio_key_candidate(audio_id)
      if audio_key then
        push_resolved(audio_key)
      end

      local alias_keys = resolve_audio_key_aliases(audio_id)
      for _, alias_key in ipairs(alias_keys) do
        push_resolved(alias_key)
      end
    end

    if debug_missing_audio and audio_label and #candidates > 0 and #resolved == 0 then
      local runtime = get_runtime()
      local missing_key = string.format('%s::%s', audio_label, table.concat(candidates, '|'))
      if runtime.missing_keys[missing_key] ~= true then
        runtime.missing_keys[missing_key] = true
        trace(string.format('[audio] all candidates missing for %s: %s', audio_label, table.concat(candidates, ', ')))
      end
    end

    return resolved
  end

  local function play_audio_candidates(audio_ids, audio_label, play_once)
    local resolved_candidates = resolve_audio_key(audio_ids, audio_label)
    local resolved_any = #resolved_candidates > 0

    for _, audio_key in ipairs(resolved_candidates) do
      local ok_play, sound = pcall(play_once, audio_key)
      if ok_play and sound then
        return sound
      end
    end

    if audio_label then
      local failure_type = resolved_any and 'play' or 'resolve'
      trace_audio_once(
        failure_type .. ':' .. audio_label,
        string.format('[audio] %s failed for %s: %s', failure_type, audio_label, describe_audio_ids(audio_ids))
      )
    end

    return nil
  end

  -- local function play_for_player(audio_ids, options, audio_label)
  play_for_player = function(audio_ids, options, audio_label)
    local player = ensure_audio_channels_ready()
    if not player then
      return nil
    end

    local sound = play_audio_candidates(audio_ids, audio_label, function(audio_key)
      return y3.sound.play(player, audio_key, {
        loop = options and options.loop == true or false,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
      })
    end)
    if sound and options and options.volume then
      sound:set_volume(player, options.volume)
    end
    return sound
  end

  -- local function play_for_unit(audio_ids, unit, options, audio_label)
  play_for_unit = function(audio_ids, unit, options, audio_label)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return play_for_player(audio_ids, options, audio_label)
    end

    local player = ensure_audio_listener(unit)
    if not player then
      return nil
    end

    local sound = play_audio_candidates(audio_ids, audio_label, function(audio_key)
      return y3.sound.play_with_object(player, audio_key, unit, {
        loop = options and options.loop == true or false,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
        ensure = options and options.ensure == true or false,
        offset_x = options and options.offset_x or 0,
        offset_y = options and options.offset_y or 0,
        offset_z = options and options.offset_z or 0,
      })
    end)
    if sound and options and options.volume then
      sound:set_volume(player, options.volume)
    end
    return sound
  end

  -- local function play_for_point(audio_ids, point, options, audio_label)
  play_for_point = function(audio_ids, point, options, audio_label)
    if not point then
      return play_for_player(audio_ids, options, audio_label)
    end

    local player = ensure_audio_listener(get_hero())
    if not player then
      return nil
    end

    local sound = play_audio_candidates(audio_ids, audio_label, function(audio_key)
      return y3.sound.play_3d(player, audio_key, point, {
        loop = options and options.loop == true or false,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
        ensure = options and options.ensure == true or false,
        height = options and options.height or 0,
      })
    end)
    if sound and options and options.volume then
      sound:set_volume(player, options.volume)
    end
    return sound
  end

  local function ensure_music_loop()
    ensure_music_watchdog()
    return set_music_phase('outgame')
  end

  local function play_ui_click()
    return play_for_player(AUDIO_IDS.ui_click, {
      volume = 74,
    }, 'ui_click')
  end

  local function play_panel_open()
    return play_for_player(AUDIO_IDS.ui_open, {
      volume = 70,
    }, 'ui_open')
  end

  local function play_confirm()
    return play_for_player(AUDIO_IDS.ui_confirm, {
      volume = 68,
    }, 'ui_confirm')
  end

  local function play_ui_error()
    return play_for_player(AUDIO_IDS.ui_error, {
      volume = 76,
    }, 'ui_error')
  end

  local function play_victory()
    return play_for_player(AUDIO_IDS.ui_confirm, {
      volume = 92,
    }, 'ui_confirm')
  end

  local function play_defeat()
    return play_for_player(AUDIO_IDS.defeat, {
      volume = 84,
    }, 'defeat')
  end

  local function play_basic_attack(unit)
    return play_for_unit(AUDIO_IDS.basic_attack, unit, {
      volume = 66,
    }, 'basic_attack')
  end

  local function resolve_attack_skill_audio_profile(skill)
    if not skill then
      return 'metal_slash'
    end

    local skill_id = skill.id
    if skill_id and ATTACK_SKILL_AUDIO_PROFILE_BY_ID[skill_id] then
      return ATTACK_SKILL_AUDIO_PROFILE_BY_ID[skill_id]
    end

    if skill.element == 'fire' then
      return 'fire'
    end
    if skill.element == 'water' then
      return 'frost_burst'
    end
    if skill.element == 'earth' then
      return 'earth'
    end
    if skill.element == 'wood' then
      return 'thunder'
    end
    if skill.damage_form == 'weapon' then
      return 'metal_slash'
    end
    return 'beam'
  end

  local function get_attack_skill_stage_config(skill, stage)
    local profile = resolve_attack_skill_audio_profile(skill)
    local profile_config = ATTACK_SKILL_AUDIO_STAGE_CONFIG[profile] or {}
    local stage_config = profile_config[stage or 'cast'] or profile_config.cast or {}
    return profile, stage_config
  end

  local function is_attack_skill_stage_throttled(skill, stage, cooldown)
    cooldown = tonumber(cooldown) or 0
    if cooldown <= 0 then
      return false
    end

    local runtime = get_runtime()
    local now = os.clock and os.clock() or 0
    local stage_key = string.format('%s:%s', tostring(skill and skill.id or 'attack_skill'), tostring(stage or 'cast'))
    local blocked_until = runtime.stage_gate[stage_key] or 0
    if blocked_until > now then
      return true
    end
    runtime.stage_gate[stage_key] = now + cooldown
    return false
  end

  local function play_attack_skill(skill, anchor, stage)
    local resolved_stage = stage or 'cast'
    local profile, stage_config = get_attack_skill_stage_config(skill, resolved_stage)
    local audio_ids = stage_config.ids or AUDIO_IDS.basic_attack
    if is_attack_skill_stage_throttled(skill, resolved_stage, stage_config.cooldown) then
      return nil
    end

    local label = string.format(
      'attack_skill_%s_%s',
      tostring(skill and skill.id or profile),
      resolved_stage
    )
    local options = {
      volume = stage_config.volume or 72,
      ensure = stage_config.ensure == true,
      offset_z = stage_config.offset_z or 35,
      height = stage_config.height or 0,
    }

    if anchor and type(anchor.is_exist) == 'function' then
      return play_for_unit(audio_ids, anchor, options, label)
    end
    if anchor then
      return play_for_point(audio_ids, anchor, options, label)
    end
    return play_for_player(audio_ids, options, label)
  end

  local function play_enemy_death(unit, is_boss)
    local primary = play_for_unit(AUDIO_IDS.enemy_death_heavy, unit, {
      volume = is_boss and 100 or 92,
      ensure = true,
      offset_z = 45,
    }, 'enemy_death_heavy')

    play_for_unit(AUDIO_IDS.enemy_death_burst, unit, {
      volume = is_boss and 94 or 82,
      offset_z = 65,
    }, 'enemy_death_burst')

    return primary
  end

  local function enter_battle()
    ensure_audio_listener(get_hero())
    ensure_music_watchdog()
    return set_music_phase('battle')
  end

  local function handle_wave_started(wave_index)
    if tonumber(wave_index) == nil then
      return nil
    end
    set_music_phase('battle')
    return play_for_player(AUDIO_IDS.wave_start, {
      volume = wave_index <= 1 and 68 or 74,
    }, 'wave_start')
  end

  local function handle_boss_warning()
    return play_for_player(AUDIO_IDS.boss_warning, {
      volume = 78,
    }, 'boss_warning')
  end

  local function handle_boss_spawned(boss_info)
    set_music_phase('boss')
    local anchor = boss_info and boss_info.unit or get_hero()
    return play_for_unit(AUDIO_IDS.boss_spawn, anchor, {
      volume = 92,
      ensure = true,
      offset_z = 60,
    }, 'boss_spawn')
  end

  local function handle_challenge_started(instance)
    local anchor = instance and instance.infos and instance.infos[1] and instance.infos[1].unit or get_hero()
    return play_for_unit(AUDIO_IDS.challenge_start, anchor, {
      volume = 72,
      offset_z = 40,
    }, 'challenge_start')
  end

  local function handle_challenge_finished(_, is_success)
    if is_success == true then
      return play_for_player(AUDIO_IDS.challenge_success, {
        volume = 76,
      }, 'challenge_success')
    end
    return play_for_player(AUDIO_IDS.challenge_fail, {
      volume = 74,
    }, 'challenge_fail')
  end

  local function handle_hero_be_hurt()
    local ratio = get_hero_hp_ratio()
    if not ratio or ratio > 0.35 then
      return nil
    end

    local runtime = get_runtime()
    local now = os.clock and os.clock() or 0
    if runtime.low_hp_gate and runtime.low_hp_gate > now then
      return nil
    end
    runtime.low_hp_gate = now + 4.0
    return play_for_player(AUDIO_IDS.hero_low_hp, {
      volume = 58,
    }, 'hero_low_hp')
  end

  local function handle_battle_finished(result)
    local runtime = get_runtime()
    stop_sound(runtime.bgm_sound, true)
    runtime.bgm_sound = nil
    runtime.music_phase = 'result'
    if result and result.is_win == true then
      return play_victory()
    end
    return play_defeat()
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

local M = {}

local AudioResources = require 'data.tables.audio_resources'

local AUDIO_IDS = AudioResources.AUDIO_IDS or {}
local AUDIO_SCENES = AudioResources.AUDIO_SCENES or {}
local AUDIO_KEY_NAME_ALIASES = AudioResources.AUDIO_KEY_NAME_ALIASES or {}
local ATTACK_SKILL_ELEMENT_STAGE_MAP = AudioResources.ATTACK_SKILL_ELEMENT_STAGE_MAP or {}
local ATTACK_SKILL_STAGE_CONFIGS = AudioResources.ATTACK_SKILL_STAGE_CONFIGS or {}

local function clone_list(source)
  local result = {}
  for index, value in ipairs(source or {}) do
    result[index] = value
  end
  return result
end

local function first_non_empty_list(...)
  local lists = { ... }
  for _, list in ipairs(lists) do
    if type(list) == 'table' and #list > 0 then
      return clone_list(list)
    end
  end
  return {}
end

function M.create(params)
  local STATE = params.STATE
  local y3 = params.y3
  local get_player = params.get_player
  local trace = params.trace or function() end
  local debug_missing_audio = params.debug_missing_audio == true

  local function ensure_runtime()
    if not STATE.audio_runtime then
      STATE.audio_runtime = {
        bgm_sound = nil,
        music_watchdog = nil,
        key_alias_cache = {},
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

  local function record_playback_failure(audio_key, message)
    local runtime = ensure_runtime()
    if runtime.playback_failures[audio_key] == true then
      return
    end
    runtime.playback_failures[audio_key] = true
    trace(message)
  end

  local function ensure_audio_channels_ready()
    local runtime = ensure_runtime()
    local player = get_player()
    if not player then
      return nil
    end
    if runtime.audio_channels_ready == true then
      return player
    end
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
    return player
  end

  local function ensure_audio_listener(anchor)
    local player = ensure_audio_channels_ready()
    if not player then
      return nil
    end
    local target = anchor
    if not target or not target.is_exist or not target:is_exist() then
      target = get_hero()
    end
    if not target or not target.is_exist or not target:is_exist() then
      return player
    end
    local runtime = ensure_runtime()
    if runtime.listener_anchor == target then
      return player
    end
    if GameAPI and GameAPI.set_player_listener_to_follow_unit then
      pcall(GameAPI.set_player_listener_to_follow_unit, player.handle, target.handle)
      runtime.listener_anchor = target
    end
    return player
  end

  local function is_sound_handle_alive(sound)
    if not sound then
      return false
    end
    if type(IsValid) == 'function' then
      local ok, is_valid = pcall(IsValid, sound)
      if ok then
        return is_valid == true
      end
    end
    return true
  end

  local function is_sound_running(sound)
    if not sound then
      return false
    end
    local object_type = type(sound)
    if object_type ~= 'table' and object_type ~= 'userdata' then
      return false
    end
    if type(sound.is_running) == 'function' then
      local ok, running = pcall(sound.is_running, sound)
      if ok then
        return running == true
      end
    end
    if type(sound.is_removed) == 'function' then
      local ok, removed = pcall(sound.is_removed, sound)
      if ok then
        return removed ~= true
      end
    end
    return false
  end

  local function stop_sound(sound, is_immediately)
    if not sound then
      return
    end
    local player = get_player()
    if not player then
      return
    end
    sound:stop(player, is_immediately == true)
  end

  local function resolve_audio_key_aliases(audio_id)
    local runtime = ensure_runtime()
    local cache_key = tostring(audio_id or '')
    if cache_key == '' then
      return {}
    end
    local cached = runtime.key_alias_cache[cache_key]
    if cached ~= nil then
      return cached
    end
    local aliases = AUDIO_KEY_NAME_ALIASES[cache_key]
    if type(aliases) ~= 'table' or #aliases == 0 then
      runtime.key_alias_cache[cache_key] = {}
      return {}
    end
    local result = {}
    for _, alias_name in ipairs(aliases) do
      local ok, key = pcall(y3.game.str_to_audio_key, alias_name)
      local numeric_key = ok and tonumber(key) or nil
      if numeric_key then
        result[#result + 1] = numeric_key
      end
    end
    runtime.key_alias_cache[cache_key] = result
    return result
  end

  local function resolve_audio_candidates(audio_ids, audio_label)
    local normalized = type(audio_ids) == 'table' and audio_ids or {}
    local result = {}
    local seen = {}

    local function add_key(key)
      local numeric_key = tonumber(key)
      if not numeric_key then
        return
      end
      local text = tostring(numeric_key)
      if not seen[text] then
        seen[text] = true
        result[#result + 1] = numeric_key
      end
      if GameAPI and GameAPI.int_transform_sound_type then
        local ok, transformed_key = pcall(GameAPI.int_transform_sound_type, numeric_key)
        local numeric_transformed_key = ok and tonumber(transformed_key) or nil
        if numeric_transformed_key then
          local transformed_text = tostring(numeric_transformed_key)
          if not seen[transformed_text] then
            seen[transformed_text] = true
            result[#result + 1] = numeric_transformed_key
          end
        end
      end
    end

    for _, audio_id in ipairs(normalized) do
      add_key(audio_id)
      for _, alias_key in ipairs(resolve_audio_key_aliases(audio_id)) do
        add_key(alias_key)
      end
    end

    if debug_missing_audio and audio_label and #normalized > 0 and #result == 0 then
      record_playback_failure(
        'resolve:' .. tostring(audio_label),
        string.format('[audio] resolve failed for %s: %s', tostring(audio_label), format_audio_ids(audio_ids))
      )
    end

    return result
  end

  local function play_audio_candidates(audio_ids, audio_label, play_once)
    local candidates = resolve_audio_candidates(audio_ids, audio_label)
    for _, key in ipairs(candidates) do
      local ok, sound = pcall(play_once, key)
      if ok and sound then
        return sound
      end
    end
    if audio_label then
      record_playback_failure(
        'play:' .. tostring(audio_label),
        string.format('[audio] play failed for %s: %s', tostring(audio_label), format_audio_ids(audio_ids))
      )
    end
    return nil
  end

  local function play_audio_scene(audio_ids, options, audio_label)
    return play_audio_candidates(audio_ids, audio_label, function(key)
      local player = ensure_audio_channels_ready()
      if not player then
        return nil
      end
      return y3.sound.play(player, key, {
        loop = options and options.loop == true or false,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
      })
    end)
  end

  local function play_for_unit(audio_ids, unit, options, audio_label)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return play_audio_scene(audio_ids, options, audio_label)
    end
    return play_audio_candidates(audio_ids, audio_label, function(key)
      local player = ensure_audio_listener(unit)
      if not player then
        return nil
      end
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

  local function play_audio_3d(audio_ids, point, options, audio_label)
    if not point then
      return play_audio_scene(audio_ids, options, audio_label)
    end
    return play_audio_candidates(audio_ids, audio_label, function(key)
      local player = ensure_audio_listener(get_hero())
      if not player then
        return nil
      end
      return y3.sound.play_3d(player, key, point, {
        loop = options and options.loop == true or false,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
        ensure = options and options.ensure == true or false,
        height = options and options.height or 0,
        volume = options and options.volume or 100,
      })
    end)
  end

  local function play_bgm(audio_ids, options, audio_label)
    local runtime = ensure_runtime()
    stop_sound(runtime.bgm_sound, true)
    runtime.bgm_sound = nil
    runtime.bgm_sound = play_audio_candidates(audio_ids, audio_label, function(key)
      local player = ensure_audio_channels_ready()
      if not player then
        return nil
      end
      return y3.sound.play(player, key, {
        loop = true,
        fade_in = options and options.fade_in or 0,
        fade_out = options and options.fade_out or 0,
      })
    end)
    if runtime.bgm_sound and options and options.volume then
      local player = get_player()
      if player then
        runtime.bgm_sound:set_volume(player, options.volume)
      end
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
      return play_bgm(first_non_empty_list(AUDIO_SCENES.battle_loop, AUDIO_SCENES.bgm_loop), { fade_in = 0.5, fade_out = 0.2, volume = 62 }, 'battle_loop')
    end
    if normalized == 'boss' then
      return play_bgm(first_non_empty_list(AUDIO_SCENES.boss_loop, AUDIO_SCENES.bgm_loop), { fade_in = 0.35, fade_out = 0.15, volume = 70 }, 'boss_loop')
    end
    return play_bgm(AUDIO_SCENES.bgm_loop, { fade_in = 0.4, fade_out = 0.2, volume = 58 }, 'bgm_loop')
  end

  local function ensure_music_watchdog()
    local runtime = ensure_runtime()
    if is_sound_running(runtime.music_watchdog) then
      return runtime.music_watchdog
    end
    runtime.music_watchdog = nil
    if not y3 or not y3.ltimer or type(y3.ltimer.loop) ~= 'function' then
      return nil
    end
    local ok, err = pcall(function()
      runtime.music_watchdog = y3.ltimer.loop(2.5, function()
        local current = ensure_runtime()
        if current.music_phase == 'result' then
          return
        end
        if is_sound_handle_alive(current.bgm_sound) then
          return
        end
        current.bgm_sound = nil
        set_music_phase(current.music_phase or 'outgame')
      end, 'audio_music_watchdog')
    end)
    if not ok then
      record_playback_failure(
        'music_watchdog',
        string.format('[audio] failed to create music watchdog: %s', tostring(err))
      )
      return nil
    end
    return runtime.music_watchdog
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

  local function get_skill_stage_profile(skill)
    if not skill then
      return 'metal_slash'
    end
    if skill.id and ATTACK_SKILL_ELEMENT_STAGE_MAP[skill.id] then
      return ATTACK_SKILL_ELEMENT_STAGE_MAP[skill.id]
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

  local function get_skill_stage_config(skill, stage)
    local profile_name = get_skill_stage_profile(skill)
    local profile = ATTACK_SKILL_STAGE_CONFIGS[profile_name] or ATTACK_SKILL_STAGE_CONFIGS.metal_slash or {}
    return profile_name, profile[stage or 'cast'] or profile.cast or {}
  end

  local function check_stage_cooldown(skill, stage, cooldown)
    cooldown = tonumber(cooldown) or 0
    if cooldown <= 0 then
      return false
    end
    local runtime = ensure_runtime()
    local now = os.clock and os.clock() or 0
    local gate_key = string.format('%s:%s', tostring(skill and skill.id or 'attack_skill'), tostring(stage or 'cast'))
    local gate_deadline = runtime.stage_gate[gate_key] or 0
    if gate_deadline > now then
      return true
    end
    runtime.stage_gate[gate_key] = now + cooldown
    return false
  end

  local function play_attack_skill(skill, source_anchor, stage)
    local stage_name = stage or 'cast'
    local profile_name, stage_config = get_skill_stage_config(skill, stage_name)
    local audio_ids = first_non_empty_list(stage_config.ids, AUDIO_SCENES.basic_attack)
    if check_stage_cooldown(skill, stage_name, stage_config.cooldown) then
      return nil
    end
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

  local function play_enemy_death(unit, is_boss, death_point)
    local heavy_ids = is_boss
      and first_non_empty_list(AUDIO_SCENES.boss_death_heavy, AUDIO_SCENES.enemy_death_heavy)
      or AUDIO_SCENES.enemy_death_heavy
    local burst_ids = AUDIO_SCENES.enemy_death_burst

    local heavy_sound
    if death_point then
      heavy_sound = play_audio_3d(heavy_ids, death_point, {
        volume = is_boss and 100 or 92,
        ensure = true,
        height = 45,
      }, is_boss and 'boss_death_heavy' or 'enemy_death_heavy')
      play_audio_3d(burst_ids, death_point, {
        volume = is_boss and 94 or 82,
        height = 65,
      }, 'enemy_death_burst')
      return heavy_sound
    end
    heavy_sound = play_for_unit(heavy_ids, unit, {
      volume = is_boss and 100 or 92,
      ensure = true,
      offset_z = 45,
    }, is_boss and 'boss_death_heavy' or 'enemy_death_heavy')
    play_for_unit(burst_ids, unit, {
      volume = is_boss and 94 or 82,
      offset_z = 65,
    }, 'enemy_death_burst')
    return heavy_sound
  end

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
    if tonumber(wave_index) == nil then
      return nil
    end
    set_music_phase('battle')
    return play_audio_scene(AUDIO_SCENES.wave_start, { volume = wave_index <= 1 and 68 or 74 }, 'wave_start')
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
    if not hp_ratio or hp_ratio > 0.35 then
      return nil
    end
    local runtime = ensure_runtime()
    local now = os.clock and os.clock() or 0
    if runtime.low_hp_gate and runtime.low_hp_gate > now then
      return nil
    end
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

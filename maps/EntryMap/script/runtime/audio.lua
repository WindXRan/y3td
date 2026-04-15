local M = {}

local AUDIO_IDS = {
  bgm_loop = '201355418', -- 场景音乐 3
  ui_click = '134223345', -- SFX_UI_Click_D
  ui_open = '201387287', -- 打开背包
  ui_confirm = '201387323', -- 胜利
}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local trace = env.trace or function() end

  local function get_runtime()
    if not STATE.audio_runtime then
      STATE.audio_runtime = {
        bgm_sound = nil,
        key_cache = {},
        missing_keys = {},
      }
    end
    return STATE.audio_runtime
  end

  local function resolve_audio_key(audio_id)
    local runtime = get_runtime()
    local cache_key = tostring(audio_id or '')
    if cache_key == '' then
      return nil
    end

    local cached = runtime.key_cache[cache_key]
    if cached ~= nil then
      return cached or nil
    end

    local ok, audio_key = pcall(y3.game.str_to_audio_key, cache_key)
    if not ok or not audio_key then
      runtime.key_cache[cache_key] = false
      if runtime.missing_keys[cache_key] ~= true then
        runtime.missing_keys[cache_key] = true
        trace('[audio] missing audio key ' .. cache_key)
      end
      return nil
    end

    runtime.key_cache[cache_key] = audio_key
    return audio_key
  end

  local function play_for_player(audio_id, options)
    local player = get_player and get_player() or nil
    if not player then
      return nil
    end

    local audio_key = resolve_audio_key(audio_id)
    if not audio_key then
      return nil
    end

    local sound = y3.sound.play(player, audio_key, {
      loop = options and options.loop == true or false,
      fade_in = options and options.fade_in or 0,
      fade_out = options and options.fade_out or 0,
    })
    if sound and options and options.volume then
      sound:set_volume(player, options.volume)
    end
    return sound
  end

  local function ensure_music_loop()
    local runtime = get_runtime()
    if runtime.bgm_sound then
      return runtime.bgm_sound
    end

    runtime.bgm_sound = play_for_player(AUDIO_IDS.bgm_loop, {
      loop = true,
      fade_in = 0.4,
      fade_out = 0.2,
      volume = 42,
    })
    return runtime.bgm_sound
  end

  local function play_ui_click()
    return play_for_player(AUDIO_IDS.ui_click, {
      volume = 74,
    })
  end

  local function play_panel_open()
    return play_for_player(AUDIO_IDS.ui_open, {
      volume = 70,
    })
  end

  local function play_confirm()
    return play_for_player(AUDIO_IDS.ui_confirm, {
      volume = 68,
    })
  end

  local function play_victory()
    return play_for_player(AUDIO_IDS.ui_confirm, {
      volume = 92,
    })
  end

  return {
    ensure_music_loop = ensure_music_loop,
    play_ui_click = play_ui_click,
    play_panel_open = play_panel_open,
    play_confirm = play_confirm,
    play_victory = play_victory,
  }
end

return M

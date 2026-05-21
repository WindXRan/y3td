local M = {}
local y3 = y3
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers

local AudioResources = require 'data.tables.audio_resources'
local GameEvents = require 'runtime.events.game_events'

local AUDIO_SCENES = AudioResources.AUDIO_SCENES or {}

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

local STATE = _G.STATE
local trace = _G.trace or function() end

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
  local get_player_func = _G.get_player
  if not get_player_func then
    return nil
  end
  local player = get_player_func()
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
  if GameAPI and GameAPI.set_background_music_volume then
    pcall(GameAPI.set_background_music_volume, player.handle, 100)
  end
  if GameAPI and GameAPI.set_battle_music_volume then
    pcall(GameAPI.set_battle_music_volume, player.handle, 100)
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

local function play_bgm(audio_ids, options, audio_label)
  trace('[BGM] 尝试播放BGM, label=' .. tostring(audio_label) .. ', ids=' .. table.concat(audio_ids or {}, ', '))
  local runtime = ensure_runtime()
  stop_sound(runtime.bgm_sound, true)
  runtime.bgm_sound = nil
  
  local candidates = {}
  local seen = {}
  for _, audio_id in ipairs(audio_ids or {}) do
    local key = tonumber(audio_id)
    if key and not seen[key] then
      candidates[#candidates + 1] = key
      seen[key] = true
    end
  end
  
  for _, key in ipairs(candidates) do
    trace('[BGM] 尝试播放音频key=' .. tostring(key))
    local player = ensure_audio_channels_ready()
    if not player then
      trace('[BGM] 获取玩家失败')
      return nil
    end
    local ok, sound = pcall(y3.sound.play, player, key, {
      loop = true,
      fade_in = options and options.fade_in or 0,
      fade_out = options and options.fade_out or 0,
    })
    if ok and sound then
      trace('[BGM] 成功播放音频key=' .. tostring(key))
      runtime.bgm_sound = sound
      if options and options.volume then
        local player_for_volume = get_player()
        if player_for_volume then
          sound:set_volume(player_for_volume, options.volume)
        end
      end
      return sound
    else
      trace('[BGM] y3.sound.play 返回nil, key=' .. tostring(key))
    end
  end
  
  if not runtime.bgm_sound then
    trace('[BGM] BGM播放失败, label=' .. tostring(audio_label))
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
    max_hp = tonumber(hero:get_attr('hp_max')) or tonumber(hero:get_attr('生命')) or 0
  end
  if max_hp <= 0 then
    return nil
  end
  return hp / max_hp
end

function M.ensure_music_loop()
  ensure_music_watchdog()
  return set_music_phase('outgame')
end

function M.enter_battle()
  ensure_audio_listener(get_hero())
  ensure_music_watchdog()
  return set_music_phase('battle')
end

function M.handle_wave_started(wave_index)
  if tonumber(wave_index) == nil then
    return nil
  end
  set_music_phase('battle')
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_ui_sound(AUDIO_SCENES.wave_start, { volume = wave_index <= 1 and 68 or 74 })
end

function M.handle_boss_warning()
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_ui_sound(AUDIO_SCENES.boss_warning, { volume = 78 })
end

function M.handle_boss_spawned(boss_info)
  set_music_phase('boss')
  local AudioUtils = require 'runtime.audio.audio_utils'
  local unit = boss_info and boss_info.unit or get_hero()
  return AudioUtils.play_unit_sound(AUDIO_SCENES.boss_spawn, unit, {
    volume = 92,
    ensure = true,
    offset_z = 60,
  })
end

function M.handle_hero_be_hurt()
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
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_ui_sound(AUDIO_SCENES.hero_low_hp, { volume = 58 })
end

function M.play_ui_click()
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_click()
end

function M.play_ui_error()
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_error()
end

function M.play_panel_open()
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_panel_open()
end

function M.play_confirm()
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_confirm()
end

function M.play_victory()
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_victory()
end

function M.play_defeat()
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_defeat()
end

function M.play_basic_attack(unit)
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_basic_attack(unit)
end

function M.play_enemy_death(unit, is_boss, death_point)
  local AudioUtils = require 'runtime.audio.audio_utils'
  return AudioUtils.play_enemy_death(unit, is_boss, death_point)
end

local function _subscribe_events()
    y3.game:event_on(GameEvents.BATTLE_WAVE_STARTED, function(trg, wave_index)
        M.handle_wave_started(wave_index)
    end)
    
    y3.game:event_on(GameEvents.BATTLE_BOSS_SPAWNED, function(trg, boss_info)
        M.handle_boss_spawned(boss_info)
    end)
    
    y3.game:event_on(GameEvents.BATTLE_BOSS_WARNING, function(trg, wave, remain)
        M.handle_boss_warning()
    end)
    
    y3.game:event_on(GameEvents.BATTLE_HERO_HURT, function(trg)
        M.handle_hero_be_hurt()
    end)
end

_subscribe_events()

_G.audio_system = M
_G.SYSTEM = _G.SYSTEM or {}
_G.SYSTEM.audio = M

return M
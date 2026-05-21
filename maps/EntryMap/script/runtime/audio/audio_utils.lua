local M = {}
local y3 = y3

local AudioResources = require 'data.tables.audio_resources'
local AUDIO_SCENES = AudioResources.AUDIO_SCENES or {}
local AUDIO_KEY_NAME_ALIASES = AudioResources.AUDIO_KEY_NAME_ALIASES or {}
local ATTACK_SKILL_ELEMENT_STAGE_MAP = AudioResources.ATTACK_SKILL_ELEMENT_STAGE_MAP or {}
local ATTACK_SKILL_STAGE_CONFIGS = AudioResources.ATTACK_SKILL_STAGE_CONFIGS or {}

local STATE = _G.STATE
local get_player = y3.player.get_main_player or function()
  if y3.player and y3.player.get_local_player then
    return y3.player.get_local_player()
  end
  return nil
end

local function ensure_audio_channels_ready()
  local player = get_player()
  if not player then
    return nil
  end
  if STATE and STATE.audio_runtime and STATE.audio_runtime.audio_channels_ready then
    return player
  end
  if STATE then
    STATE.audio_runtime = STATE.audio_runtime or {}
    STATE.audio_runtime.audio_channels_ready = true
  end
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

local function resolve_audio_key_aliases(audio_id)
  local cache_key = tostring(audio_id or '')
  if cache_key == '' then
    return {}
  end
  local runtime = STATE and STATE.audio_runtime
  if runtime and runtime.key_alias_cache and runtime.key_alias_cache[cache_key] ~= nil then
    return runtime.key_alias_cache[cache_key]
  end
  local aliases = AUDIO_KEY_NAME_ALIASES[cache_key]
  if type(aliases) ~= 'table' or #aliases == 0 then
    if runtime then
      runtime.key_alias_cache = runtime.key_alias_cache or {}
      runtime.key_alias_cache[cache_key] = {}
    end
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
  if runtime then
    runtime.key_alias_cache = runtime.key_alias_cache or {}
    runtime.key_alias_cache[cache_key] = result
  end
  return result
end

local function resolve_audio_candidates(audio_ids)
  local normalized = type(audio_ids) == 'table' and audio_ids or {}
  local result = {}
  local seen = {}
  for _, audio_id in ipairs(normalized) do
    local key = tonumber(audio_id)
    if key and not seen[key] then
      result[#result + 1] = key
      seen[key] = true
    end
    for _, alias_key in ipairs(resolve_audio_key_aliases(audio_id)) do
      if not seen[alias_key] then
        result[#result + 1] = alias_key
        seen[alias_key] = true
      end
    end
  end
  return result
end

local function play_audio_candidates(audio_ids, audio_label, play_once)
  local candidates = resolve_audio_candidates(audio_ids)
  for _, key in ipairs(candidates) do
    local ok, sound = pcall(play_once, key)
    if ok and sound then
      return sound
    end
  end
  if audio_label then
    local runtime = STATE and STATE.audio_runtime
    if runtime then
      runtime.playback_failures = runtime.playback_failures or {}
      if not runtime.playback_failures['play:' .. tostring(audio_label)] then
        runtime.playback_failures['play:' .. tostring(audio_label)] = true
        local trace = _G.trace or function() end
        trace(string.format('[audio] play failed for %s', tostring(audio_label)))
      end
    end
  end
  return nil
end

function M.play_ui_sound(audio_ids, options, audio_label)
  local player = ensure_audio_channels_ready()
  if not player then
    return nil
  end
  return play_audio_candidates(audio_ids, audio_label, function(key)
    return y3.sound.play(player, key, {
      loop = options and options.loop == true or false,
      fade_in = options and options.fade_in or 0,
      fade_out = options and options.fade_out or 0,
    })
  end)
end

function M.play_3d_sound(audio_ids, point, options, audio_label)
  if not point then
    return M.play_ui_sound(audio_ids, options, audio_label)
  end
  local player = ensure_audio_channels_ready()
  if not player then
    return nil
  end
  return play_audio_candidates(audio_ids, audio_label, function(key)
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

function M.play_unit_sound(audio_ids, unit, options, audio_label)
  if not unit or not unit.is_exist or not unit:is_exist() then
    return M.play_ui_sound(audio_ids, options, audio_label)
  end
  local player = ensure_audio_channels_ready()
  if not player then
    return nil
  end
  return play_audio_candidates(audio_ids, audio_label, function(key)
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

function M.play_click()
  return M.play_ui_sound(AUDIO_SCENES.ui_click, { volume = 74 })
end

function M.play_error()
  return M.play_ui_sound(AUDIO_SCENES.ui_error, { volume = 76 })
end

function M.play_panel_open()
  return M.play_ui_sound(AUDIO_SCENES.ui_open, { volume = 70 })
end

function M.play_confirm()
  return M.play_ui_sound(AUDIO_SCENES.ui_confirm, { volume = 68 })
end

function M.play_victory()
  return M.play_ui_sound(AUDIO_SCENES.ui_confirm, { volume = 92 })
end

function M.play_defeat()
  return M.play_ui_sound(AUDIO_SCENES.defeat, { volume = 84 })
end

function M.play_basic_attack(unit)
  return M.play_unit_sound(AUDIO_SCENES.basic_attack, unit, { volume = 66 })
end

function M.play_enemy_death(unit, is_boss, death_point)
  local heavy_ids = is_boss
    and ((AUDIO_SCENES.boss_death_heavy and #AUDIO_SCENES.boss_death_heavy > 0) and AUDIO_SCENES.boss_death_heavy or AUDIO_SCENES.enemy_death_heavy)
    or AUDIO_SCENES.enemy_death_heavy
  local burst_ids = AUDIO_SCENES.enemy_death_burst

  local heavy_sound
  if death_point then
    heavy_sound = M.play_3d_sound(heavy_ids, death_point, {
      volume = is_boss and 100 or 92,
      ensure = true,
      height = 45,
    }, is_boss and 'boss_death_heavy' or 'enemy_death_heavy')
    M.play_3d_sound(burst_ids, death_point, {
      volume = is_boss and 94 or 82,
      height = 65,
    }, 'enemy_death_burst')
    return heavy_sound
  end
  heavy_sound = M.play_unit_sound(heavy_ids, unit, {
    volume = is_boss and 100 or 92,
    ensure = true,
    offset_z = 45,
  }, is_boss and 'boss_death_heavy' or 'enemy_death_heavy')
  M.play_unit_sound(burst_ids, unit, {
    volume = is_boss and 94 or 82,
    offset_z = 65,
  }, 'enemy_death_burst')
  return heavy_sound
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

function M.play_attack_skill(skill, source_anchor, stage)
  local stage_name = stage or 'cast'
  local profile_name, stage_config = get_skill_stage_config(skill, stage_name)
  local audio_ids = stage_config.ids or AUDIO_SCENES.basic_attack

  local cooldown = tonumber(stage_config.cooldown) or 0
  if cooldown > 0 then
    local runtime = STATE and STATE.audio_runtime
    if runtime then
      local now = os.clock and os.clock() or 0
      local gate_key = string.format('%s:%s', tostring(skill and skill.id or 'attack_skill'), tostring(stage_name))
      local gate_deadline = runtime.stage_gate and runtime.stage_gate[gate_key] or 0
      if gate_deadline > now then
        return nil
      end
      runtime.stage_gate = runtime.stage_gate or {}
      runtime.stage_gate[gate_key] = now + cooldown
    end
  end

  local options = {
    volume = stage_config.volume or 72,
    ensure = stage_config.ensure == true,
    offset_z = stage_config.offset_z or 35,
    height = stage_config.height or 0,
  }

  if source_anchor and type(source_anchor.is_exist) == 'function' then
    return M.play_unit_sound(audio_ids, source_anchor, options)
  end
  if source_anchor then
    return M.play_3d_sound(audio_ids, source_anchor, options)
  end
  return M.play_ui_sound(audio_ids, options)
end

return M
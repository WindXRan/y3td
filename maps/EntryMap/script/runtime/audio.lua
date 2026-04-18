local M = {}

local AUDIO_IDS = {
  bgm_loop = { '201355418' }, -- 场景音乐 3（待替换有效资源）
  ui_click = { '134223345' }, -- SFX_UI_Click_D（待替换有效资源）
  ui_open = { '201387287' }, -- 打开背包（待替换有效资源）
  ui_confirm = { '201387323' }, -- 胜利（待替换有效资源）
  ui_error = { '126040', '134257420', '201387287' }, -- 反馈失败/资源不足（待替换有效资源）
  basic_attack = {
    '134257538', -- 旧普攻音效 key（当前资源库缺失）
    '123160', -- 嗖声_布料_快的
    '125770', -- 魔法_嗖声_植被
  },
  enemy_death_heavy = {
    '134257420', -- 旧死亡重击 key（当前资源库缺失）
    '126040', -- 受击_皮革
    '125775', -- 魔法_金属_受击
  },
  enemy_death_burst = {
    '134257799', -- 旧死亡爆裂 key（当前资源库缺失）
    '126054', -- 嗖声_布料_击中
    '126042', -- 法术_风_吹_大规模的
  },
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
    cast = { ids = { '123160', '125770' }, volume = 68, cooldown = 0.08, offset_z = 35 },
    impact = { ids = { '125775', '126523' }, volume = 82, cooldown = 0.08, offset_z = 32 },
    chain = { ids = { '126523', '125775' }, volume = 74, cooldown = 0.10, offset_z = 30 },
    burst = { ids = { '125775', '125771' }, volume = 86, cooldown = 0.18, height = 28 },
    tick = { ids = { '126523', '123160' }, volume = 56, cooldown = 0.32, height = 20 },
    charge = { ids = { '125774', '125771' }, volume = 60, cooldown = 0.20, height = 20 },
  },
  beam = {
    cast = { ids = { '125774', '125771' }, volume = 70, cooldown = 0.10, offset_z = 35 },
    impact = { ids = { '125773', '125771' }, volume = 80, cooldown = 0.10, height = 28 },
    chain = { ids = { '125771', '125773' }, volume = 72, cooldown = 0.12, height = 24 },
    burst = { ids = { '125773', '125771' }, volume = 86, cooldown = 0.20, height = 32 },
    tick = { ids = { '125772', '125771' }, volume = 58, cooldown = 0.34, height = 24 },
    charge = { ids = { '125774', '125772' }, volume = 62, cooldown = 0.20, height = 24 },
  },
  frost_burst = {
    cast = { ids = { '123320', '126523' }, volume = 66, cooldown = 0.10, offset_z = 35 },
    impact = { ids = { '123312', '126524' }, volume = 82, cooldown = 0.08, height = 28 },
    chain = { ids = { '126524', '123312' }, volume = 72, cooldown = 0.10, height = 24 },
    burst = { ids = { '123312', '126524' }, volume = 86, cooldown = 0.18, height = 30 },
    tick = { ids = { '126524', '123320' }, volume = 56, cooldown = 0.32, height = 22 },
    charge = { ids = { '123320', '126524' }, volume = 60, cooldown = 0.22, height = 22 },
  },
  thunder = {
    cast = { ids = { '125774', '123320' }, volume = 70, cooldown = 0.10, offset_z = 35 },
    impact = { ids = { '125775', '125771' }, volume = 84, cooldown = 0.08, height = 30 },
    chain = { ids = { '125771', '125775' }, volume = 78, cooldown = 0.10, height = 28 },
    burst = { ids = { '125775', '125774' }, volume = 90, cooldown = 0.18, height = 34 },
    tick = { ids = { '125771', '123320' }, volume = 58, cooldown = 0.26, height = 24 },
    charge = { ids = { '125774', '125771' }, volume = 64, cooldown = 0.18, height = 24 },
  },
  earth = {
    cast = { ids = { '123320', '123160' }, volume = 64, cooldown = 0.12, offset_z = 35 },
    impact = { ids = { '125775', '126040' }, volume = 84, cooldown = 0.10, height = 28 },
    chain = { ids = { '125775', '126523' }, volume = 70, cooldown = 0.12, height = 24 },
    burst = { ids = { '125775', '126040' }, volume = 90, cooldown = 0.22, height = 32 },
    tick = { ids = { '126523', '123320' }, volume = 54, cooldown = 0.34, height = 22 },
    charge = { ids = { '125774', '123320' }, volume = 60, cooldown = 0.22, height = 22 },
  },
  wind = {
    cast = { ids = { '126042', '123320' }, volume = 70, cooldown = 0.10, offset_z = 35 },
    impact = { ids = { '126054', '126042' }, volume = 78, cooldown = 0.10, height = 28 },
    chain = { ids = { '126042', '123160' }, volume = 72, cooldown = 0.10, height = 26 },
    burst = { ids = { '126042', '126054' }, volume = 84, cooldown = 0.20, height = 30 },
    tick = { ids = { '126042', '123320' }, volume = 58, cooldown = 0.28, height = 24 },
    charge = { ids = { '123320', '126042' }, volume = 62, cooldown = 0.20, height = 24 },
  },
  fire = {
    cast = { ids = { '125770', '126054' }, volume = 70, cooldown = 0.10, offset_z = 35 },
    impact = { ids = { '126054', '125775' }, volume = 82, cooldown = 0.08, height = 28 },
    chain = { ids = { '126054', '125770' }, volume = 72, cooldown = 0.10, height = 24 },
    burst = { ids = { '134257799', '126042', '126054' }, volume = 90, cooldown = 0.18, height = 32 },
    tick = { ids = { '125770', '126042' }, volume = 60, cooldown = 0.28, height = 24 },
    charge = { ids = { '125774', '125770' }, volume = 64, cooldown = 0.18, height = 24 },
  },
  seal = {
    cast = { ids = { '125774', '125771' }, volume = 68, cooldown = 0.10, offset_z = 35 },
    impact = { ids = { '125775', '125771' }, volume = 82, cooldown = 0.10, height = 28 },
    chain = { ids = { '125771', '125775' }, volume = 70, cooldown = 0.12, height = 24 },
    burst = { ids = { '125773', '125775' }, volume = 88, cooldown = 0.22, height = 32 },
    tick = { ids = { '125772', '125771' }, volume = 56, cooldown = 0.32, height = 24 },
    charge = { ids = { '125774', '125772' }, volume = 62, cooldown = 0.20, height = 24 },
  },
}

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local trace = env.trace or function() end
  local debug_missing_audio = env.debug_missing_audio == true

  local function get_runtime()
    if not STATE.audio_runtime then
      STATE.audio_runtime = {
        bgm_sound = nil,
        key_cache = {},
        missing_keys = {},
        stage_gate = {},
      }
    end
    return STATE.audio_runtime
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

    local ok, audio_key = pcall(y3.game.str_to_audio_key, cache_key)
    if not ok or not audio_key then
      runtime.key_cache[cache_key] = false
      return nil
    end

    runtime.key_cache[cache_key] = audio_key
    return audio_key
  end

  local function resolve_audio_key(audio_ids, audio_label)
    local candidates = {}
    if type(audio_ids) == 'table' then
      candidates = audio_ids
    elseif audio_ids ~= nil then
      candidates = { audio_ids }
    end

    for _, audio_id in ipairs(candidates) do
      local audio_key = resolve_audio_key_candidate(audio_id)
      if audio_key then
        return audio_key
      end
    end

    if debug_missing_audio and audio_label and #candidates > 0 then
      local runtime = get_runtime()
      local missing_key = string.format('%s::%s', audio_label, table.concat(candidates, '|'))
      if runtime.missing_keys[missing_key] ~= true then
        runtime.missing_keys[missing_key] = true
        trace(string.format('[audio] all candidates missing for %s: %s', audio_label, table.concat(candidates, ', ')))
      end
    end

    return nil
  end

  local function play_for_player(audio_ids, options, audio_label)
    local player = get_player and get_player() or nil
    if not player then
      return nil
    end

    local audio_key = resolve_audio_key(audio_ids, audio_label)
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

  local function play_for_unit(audio_ids, unit, options, audio_label)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return play_for_player(audio_ids, options, audio_label)
    end

    local player = get_player and get_player() or nil
    if not player then
      return nil
    end

    local audio_key = resolve_audio_key(audio_ids, audio_label)
    if not audio_key then
      return nil
    end

    local sound = y3.sound.play_with_object(player, audio_key, unit, {
      loop = options and options.loop == true or false,
      fade_in = options and options.fade_in or 0,
      fade_out = options and options.fade_out or 0,
      ensure = options and options.ensure == true or false,
      offset_x = options and options.offset_x or 0,
      offset_y = options and options.offset_y or 0,
      offset_z = options and options.offset_z or 0,
    })
    if sound and options and options.volume then
      sound:set_volume(player, options.volume)
    end
    return sound
  end

  local function play_for_point(audio_ids, point, options, audio_label)
    if not point then
      return play_for_player(audio_ids, options, audio_label)
    end

    local player = get_player and get_player() or nil
    if not player then
      return nil
    end

    local audio_key = resolve_audio_key(audio_ids, audio_label)
    if not audio_key then
      return nil
    end

    local sound = y3.sound.play_3d(player, audio_key, point, {
      loop = options and options.loop == true or false,
      fade_in = options and options.fade_in or 0,
      fade_out = options and options.fade_out or 0,
      ensure = options and options.ensure == true or false,
      height = options and options.height or 0,
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
    }, 'bgm_loop')
    return runtime.bgm_sound
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

  return {
    ensure_music_loop = ensure_music_loop,
    play_ui_click = play_ui_click,
    play_ui_error = play_ui_error,
    play_panel_open = play_panel_open,
    play_confirm = play_confirm,
    play_victory = play_victory,
    play_basic_attack = play_basic_attack,
    play_attack_skill = play_attack_skill,
    play_enemy_death = play_enemy_death,
  }
end

return M

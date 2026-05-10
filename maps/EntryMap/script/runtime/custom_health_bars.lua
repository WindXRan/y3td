local M = {}

local BLOOD_BAR_TYPE = {
  hero = 0x0050001,
  main = 0x0050002,
  elite = 0x0050003,
  boss = 0x0060002,
  challenge = 0x0060003,
}

local COLOR = {
  hero = '#43D779',
  main = '#E35A5A',
  elite = '#F0B84E',
  boss = '#D953FF',
  challenge = '#55B7FF',
}

local TEXT_PREFIX = {
  hero = '英雄',
  main = '敌人',
  elite = '精英',
  boss = '首领',
  challenge = '挑战',
}

local function get_monster_type_health_bar_config(info, role)
  local bar_config = nil
  if info then
    local CONFIG = rawget(_G, 'CONFIG')
    if CONFIG and CONFIG.monster_type_config then
      local monster_type = CONFIG.monster_type_config.resolve_type(info)
      local config = CONFIG.monster_type_config.get_config(monster_type)
      bar_config = config and config.health_bar or nil
    end
  end

  if bar_config then
    return bar_config
  end

  if role == 'hero' then
    return {
      bar_type = BLOOD_BAR_TYPE.hero,
      color = COLOR.hero,
      name_prefix = TEXT_PREFIX.hero,
      name_font_size = 14,
      show_text = true,
      show_name = true,
    }
  elseif role == 'challenge' then
    return {
      bar_type = BLOOD_BAR_TYPE.challenge,
      color = COLOR.challenge,
      name_prefix = TEXT_PREFIX.challenge,
      name_font_size = 14,
      show_text = true,
      show_name = true,
    }
  end

  return nil
end

local PROGRESS_NODES = {
  'hp',
  'HP',
  'health',
  'Health',
  'progress',
  'progress_1',
  'bar',
  'hp_bar',
  '血条',
  '生命',
}

local TEXT_NODES = {
  'text',
  'Text',
  'name',
  'Name',
  'label',
  'hp_text',
  '血量文本',
  '文本',
}

local function safe_call(unit, method_name, ...)
  if not unit then
    return nil
  end
  local is_valid = pcall(function()
    return unit.is_exist and unit:is_exist()
  end)
  if not is_valid then
    return nil
  end
  local ok_method, method = pcall(function()
    return unit[method_name]
  end)
  if not ok_method then
    return nil
  end
  if type(method) ~= 'function' then
    return nil
  end
  local ok, result = pcall(method, unit, ...)
  if ok then
    return result
  end
  return nil
end

local function tonumber_attr(y3, value)
  if y3 and y3.helper and y3.helper.tonumber then
    return y3.helper.tonumber(value)
  end
  return tonumber(value)
end

local function get_current_hp(unit)
  return tonumber(safe_call(unit, 'get_hp')) or 0
end

local function get_max_hp(y3, hero_attr_system, unit, role)
  if role == 'hero' and hero_attr_system and hero_attr_system.get_attr then
    local hero_max = tonumber(hero_attr_system.get_attr(unit, '生命结算值'))
        or tonumber(hero_attr_system.get_attr(unit, '最大生命'))
        or tonumber(hero_attr_system.get_attr(unit, '生命'))
    if hero_max and hero_max > 0 then
      return hero_max
    end
  end

  local attrs = { '生命结算值', '最大生命', '生命' }
  for _, attr_name in ipairs(attrs) do
    local value = tonumber_attr(y3, safe_call(unit, 'get_attr', attr_name))
    if value and value > 0 then
      return value
    end
  end
  return math.max(1, get_current_hp(unit))
end

local function resolve_role(info)
  if not info then
    return 'main'
  end
  if info.kind == 'boss' then
    return 'boss'
  end
  if info.is_elite == true or info.elite == true or info.tier == 'elite' then
    return 'elite'
  end
  if info.kind == 'challenge' then
    return 'challenge'
  end
  return 'main'
end

local function format_hp_text(role, current_hp, max_hp, info)
  local bar_config = get_monster_type_health_bar_config(info, role)
  local prefix = bar_config and bar_config.name_prefix or TEXT_PREFIX[role] or TEXT_PREFIX.main
  return string.format('%s  %.0f / %.0f', prefix, current_hp, max_hp)
end

function M.apply_unit(env, unit, role, max_hp, info)
  if not unit then
    return
  end
  local is_valid = pcall(function()
    return unit.is_exist and unit:is_exist()
  end)
  if not is_valid then
    return
  end

  role = role or 'main'
  local y3 = env and env.y3 or nil
  local gameapi = rawget(_G, 'GameAPI')
  local current_hp = get_current_hp(unit)
  max_hp = tonumber(max_hp) or get_max_hp(y3, env and env.hero_attr_system or nil, unit, role)
  max_hp = math.max(1, max_hp)
  local progress = math.max(0, math.min(1, current_hp / max_hp))

  local bar_config = get_monster_type_health_bar_config(info, role)
  local text = format_hp_text(role, current_hp, max_hp, info)
  local color = bar_config and bar_config.color or COLOR[role] or COLOR.main
  local prefix = bar_config and bar_config.name_prefix or TEXT_PREFIX[role] or TEXT_PREFIX.main
  local font_size = bar_config and bar_config.name_font_size or (role == 'boss' and 16 or 13)
  local bar_type = bar_config and bar_config.bar_type or BLOOD_BAR_TYPE[role] or BLOOD_BAR_TYPE.main
  local show_text = bar_config == nil or (bar_config and bar_config.show_text ~= false)
  local show_name = bar_config == nil or (bar_config and bar_config.show_name ~= false)

  if unit.set_health_bar_display then
    unit:set_health_bar_display(2)
  end

  safe_call(unit, 'set_blood_bar_type', bar_type)

  if gameapi and unit.handle then
    pcall(gameapi.set_billboard_visible, unit.handle, 'root', true)
    pcall(gameapi.set_billboard_visible, unit.handle, 'main', true)
    pcall(gameapi.set_billboard_visible, unit.handle, 'hp', true)
  end

  if unit.handle then
    if unit.handle.api_set_hp_bar_show_type then
      pcall(unit.handle.api_set_hp_bar_show_type, unit.handle, 2)
    end
    if unit.handle.api_set_hp_color then
      pcall(unit.handle.api_set_hp_color, unit.handle, color)
    end
    if unit.handle.api_set_bar_text_visible then
      pcall(unit.handle.api_set_bar_text_visible, unit.handle, show_text)
    end
    if unit.handle.api_set_bar_name_visible then
      pcall(unit.handle.api_set_bar_name_visible, unit.handle, show_name)
    end
    if unit.handle.api_set_bar_name then
      pcall(unit.handle.api_set_bar_name, unit.handle, prefix)
    end
    if unit.handle.api_set_bar_name_font_size then
      pcall(unit.handle.api_set_bar_name_font_size, unit.handle, font_size)
    end
    if unit.handle.api_set_hp_bar_visible then
      pcall(unit.handle.api_set_hp_bar_visible, unit.handle, true)
    end
  end

  local progress_set = false
  for _, node_name in ipairs(PROGRESS_NODES) do
    if safe_call(unit, 'set_billboard_progress', node_name, progress, nil, 0.08) then
      progress_set = true
      break
    end
  end

  if not progress_set then
    safe_call(unit, 'set_billboard_progress', 'hp_bar', progress, nil, 0.08)
  end

  local text_set = false
  if show_text then
    for _, node_name in ipairs(TEXT_NODES) do
      if safe_call(unit, 'set_blood_bar_text', node_name, text, nil, 'DFPYuanW7-GB') then
        text_set = true
        break
      end
    end

    if not text_set then
      safe_call(unit, 'set_blood_bar_text', 'text', text, nil, 'DFPYuanW7-GB')
    end
  end
end

function M.apply_enemy(env, info)
  if not info or not info.unit then
    return
  end
  local role = resolve_role(info)
  M.apply_unit(env, info.unit, role, info.max_hp, info)
end

function M.apply_hero(env, hero)
  local hero_info = { kind = 'hero' }
  M.apply_unit(env, hero, 'hero', nil, hero_info)
end

local LAST_REFRESH_TIME = 0
local REFRESH_INTERVAL = 0.5

function M.refresh_all(env)
  local current_time = 0
  if env and env.y3 and env.y3.system and env.y3.system.get_time then
    current_time = env.y3.system.get_time()
  end
  if current_time - LAST_REFRESH_TIME < REFRESH_INTERVAL then
    return
  end
  LAST_REFRESH_TIME = current_time

  local state = env and env.STATE or nil
  if not state then
    return
  end
  if state.hero then
    local hero_valid = pcall(function()
      return state.hero.is_exist and state.hero:is_exist()
    end)
    if hero_valid then
      M.apply_hero(env, state.hero)
    end
  end
  if state.enemy_info_map then
    for _, info in pairs(state.enemy_info_map) do
      if info and info.alive and info.unit then
        local unit_valid = pcall(function()
          return info.unit.is_exist and info.unit:is_exist()
        end)
        if unit_valid then
          M.apply_enemy(env, info)
        end
      end
    end
  end
end

return M
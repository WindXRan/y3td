local M = {}

local BLOOD_BAR_TYPE = {
  hero = 0x0050001,
  main = 0x0040002,
  elite = 0x0040003,
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
  if not unit or not unit.is_exist or not unit:is_exist() then
    return nil
  end
  local method = unit[method_name]
  if type(method) ~= 'function' then
    return nil
  end
  local ok, result = pcall(method, unit, ...)
  if ok then
    return result
  end
  return nil
end

local function safe_gameapi_call(gameapi, method_name, unit, ...)
  if not gameapi or not unit or not unit.is_exist or not unit:is_exist() then
    return nil
  end
  local method = gameapi[method_name]
  if type(method) ~= 'function' then
    return nil
  end
  local ok, result = pcall(method, unit.handle, ...)
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
      or tonumber(hero_attr_system.get_attr(unit, '生命'))
      or tonumber(hero_attr_system.get_attr(unit, '最大生命'))
    if hero_max and hero_max > 0 then
      return hero_max
    end
  end

  local attrs = { '生命结算值', '生命', '最大生命' }
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

local function format_hp_text(role, current_hp, max_hp)
  return string.format('%s  %.0f / %.0f', TEXT_PREFIX[role] or TEXT_PREFIX.main, current_hp, max_hp)
end

function M.apply_unit(env, unit, role, max_hp)
  if not unit or not unit.is_exist or not unit:is_exist() then
    return
  end

  role = role or 'main'
  local y3 = env and env.y3 or nil
  local gameapi = rawget(_G, 'GameAPI')
  local current_hp = get_current_hp(unit)
  max_hp = tonumber(max_hp) or get_max_hp(y3, env and env.hero_attr_system or nil, unit, role)
  max_hp = math.max(1, max_hp)
  local progress = math.max(0, math.min(1, current_hp / max_hp))
  local text = format_hp_text(role, current_hp, max_hp)

  safe_call(unit, 'set_blood_bar_type', BLOOD_BAR_TYPE[role] or BLOOD_BAR_TYPE.main)
  safe_call(unit, 'set_health_bar_display', 0)
  safe_gameapi_call(gameapi, 'set_billboard_visible', unit, 'root', true, nil)
  safe_gameapi_call(gameapi, 'set_billboard_visible', unit, 'main', true, nil)

  if unit.handle and unit.handle.api_set_hp_color then
    pcall(unit.handle.api_set_hp_color, unit.handle, COLOR[role] or COLOR.main)
  end
  if unit.handle and unit.handle.api_set_bar_text_visible then
    pcall(unit.handle.api_set_bar_text_visible, unit.handle, true)
  end
  if unit.handle and unit.handle.api_set_bar_name_visible then
    pcall(unit.handle.api_set_bar_name_visible, unit.handle, true)
  end
  if unit.handle and unit.handle.api_set_bar_name then
    pcall(unit.handle.api_set_bar_name, unit.handle, TEXT_PREFIX[role] or TEXT_PREFIX.main)
  end
  if unit.handle and unit.handle.api_set_bar_name_font_size then
    pcall(unit.handle.api_set_bar_name_font_size, unit.handle, role == 'boss' and 16 or 13)
  end

  for _, node_name in ipairs(PROGRESS_NODES) do
    safe_call(unit, 'set_billboard_progress', node_name, progress, nil, 0.08)
  end
  for _, node_name in ipairs(TEXT_NODES) do
    safe_call(unit, 'set_blood_bar_text', node_name, text, nil, 'DFPYuanW7-GB')
  end
end

function M.apply_enemy(env, info)
  if not info or not info.unit then
    return
  end
  local role = resolve_role(info)
  M.apply_unit(env, info.unit, role, info.max_hp)
end

function M.apply_hero(env, hero)
  M.apply_unit(env, hero, 'hero')
end

function M.refresh_all(env)
  local state = env and env.STATE or nil
  if not state then
    return
  end
  if state.hero and state.hero.is_exist and state.hero:is_exist() then
    M.apply_hero(env, state.hero)
  end
  if state.enemy_info_map then
    for _, info in pairs(state.enemy_info_map) do
      if info and info.alive and info.unit and info.unit.is_exist and info.unit:is_exist() then
        M.apply_enemy(env, info)
      end
    end
  end
end

return M

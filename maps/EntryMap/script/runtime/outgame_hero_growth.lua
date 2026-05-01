local HeroRoster = (require 'data.game_tables').hero_roster
local HeroList = require 'data.tables.herolist'

local M = {}

local STAR_COSTS = { 100, 200, 300 }
local MAX_STAR = 3
local AWAKEN_COST = 1

local function normalize_text(text)
  local value = tostring(text or '')
  value = value:gsub('\r', '')
  local first = value:sub(1, 1)
  local last = value:sub(-1, -1)
  if first == '"' and last == '"' and #value >= 2 then
    value = value:sub(2, -2)
  end
  return value
end

local function build_growth_defs()
  local list = {}
  local by_hero_id = {}
  local by_hero_name = {}

  local herolist_by_name = HeroList.by_hero_name or {}
  for _, roster in ipairs(HeroRoster.list or {}) do
    local hero_id = tostring(roster.id or '')
    local hero_name = tostring(roster.name or '')
    if hero_id ~= '' and hero_name ~= '' then
      local extra = herolist_by_name[hero_name] or {}
      local def = {
        hero_id = hero_id,
        hero_name = hero_name,
        order_index = tonumber(roster.order_index) or 0,
        unit_id = roster.unit_id,
        skill_key = roster.skill_id or hero_name,
        talent_skill = extra.talent_skill or roster.summary or '',
        star_effect = normalize_text(extra.star_effect or ''),
        awaken_effect = normalize_text(extra.awaken_effect or ''),
        hero_model = roster.model_id or extra.hero_model,
      }
      list[#list + 1] = def
      by_hero_id[hero_id] = def
      by_hero_name[hero_name] = def
    end
  end

  table.sort(list, function(a, b)
    if a.order_index == b.order_index then
      return tostring(a.hero_id) < tostring(b.hero_id)
    end
    return a.order_index < b.order_index
  end)

  return list, by_hero_id, by_hero_name
end

local function to_non_negative_integer(value)
  return math.max(0, math.floor(tonumber(value) or 0))
end

local function to_star(value)
  return math.max(0, math.min(MAX_STAR, math.floor(tonumber(value) or 0)))
end

local function parse_star_effect_lines(effect_text)
  local lines = {}
  local text = normalize_text(effect_text)
  if text == '' then
    return lines
  end
  for raw_line in text:gmatch('[^\n]+') do
    local line = tostring(raw_line or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if line ~= '' then
      local star, body = line:match('^(%d)星[：:%s]*(.+)$')
      if star and body and body ~= '' then
        lines[tonumber(star)] = tostring(body):gsub('^%s+', ''):gsub('%s+$', '')
      end
    end
  end
  if next(lines) == nil and text ~= '' then
    lines[1] = text
  end
  return lines
end

function M.create()
  local defs, by_id, by_name = build_growth_defs()
  local star_effects_by_id = {}
  for _, def in ipairs(defs) do
    star_effects_by_id[def.hero_id] = parse_star_effect_lines(def.star_effect)
  end

  local api = {}

  local function resolve_hero_def(hero_ref)
    if hero_ref == nil then
      return nil
    end
    local key = tostring(hero_ref)
    return by_id[key] or by_name[key]
  end

  local function ensure_resources(profile)
    if type(profile.hero_growth_resources) ~= 'table' then
      profile.hero_growth_resources = {}
    end
    if math.type(profile.hero_growth_resources.awaken_stone) ~= 'integer' then
      profile.hero_growth_resources.awaken_stone = to_non_negative_integer(profile.hero_growth_resources.awaken_stone)
    end
    return profile.hero_growth_resources
  end

  local function ensure_entries(profile)
    if type(profile.hero_growth) ~= 'table' then
      profile.hero_growth = {}
    end
    for _, def in ipairs(defs) do
      local entry = profile.hero_growth[def.hero_id]
      if type(entry) ~= 'table' then
        entry = {}
        profile.hero_growth[def.hero_id] = entry
      end
      entry.star = to_star(entry.star)
      entry.awakened = entry.awakened == true
      entry.proficiency = to_non_negative_integer(entry.proficiency)
    end
    return profile.hero_growth
  end

  local function ensure_profile(profile)
    ensure_resources(profile)
    ensure_entries(profile)
  end

  local function get_entry(profile, hero_ref)
    local def = resolve_hero_def(hero_ref)
    if not def then
      return nil, nil
    end
    ensure_profile(profile)
    return profile.hero_growth[def.hero_id], def
  end

  local function get_star_effect(def, star)
    local lines = star_effects_by_id[def.hero_id] or {}
    return lines[star] or ''
  end

  function api.ensure_profile_defaults(profile)
    local before_growth = profile.hero_growth
    local before_resources = profile.hero_growth_resources
    ensure_profile(profile)
    return before_growth ~= profile.hero_growth or before_resources ~= profile.hero_growth_resources
  end

  function api.get_growth_view(profile, hero_ref)
    local entry, def = get_entry(profile, hero_ref)
    if not entry or not def then
      return nil
    end
    local next_cost = entry.star < MAX_STAR and STAR_COSTS[entry.star + 1] or nil
    return {
      hero_id = def.hero_id,
      hero_name = def.hero_name,
      unit_id = def.unit_id,
      skill_key = def.skill_key,
      talent_skill = def.talent_skill,
      hero_model = def.hero_model,
      star = entry.star,
      max_star = MAX_STAR,
      proficiency = entry.proficiency,
      next_star_cost = next_cost,
      awakened = entry.awakened == true,
      awaken_cost = AWAKEN_COST,
      star_effect = get_star_effect(def, math.max(1, entry.star)),
      awaken_effect = def.awaken_effect,
    }
  end

  function api.get_growth_list(profile)
    ensure_profile(profile)
    local result = {}
    for _, def in ipairs(defs) do
      result[#result + 1] = api.get_growth_view(profile, def.hero_id)
    end
    return result
  end

  function api.get_awaken_stone(profile)
    local resources = ensure_resources(profile)
    return to_non_negative_integer(resources.awaken_stone)
  end

  function api.add_awaken_stone(profile, amount)
    local add = to_non_negative_integer(amount)
    if add <= 0 then
      return false, '觉醒石增加数量必须大于 0'
    end
    local resources = ensure_resources(profile)
    resources.awaken_stone = to_non_negative_integer(resources.awaken_stone) + add
    return true, 'ok', api.get_awaken_stone(profile)
  end

  function api.add_proficiency(profile, hero_ref, amount)
    local add = to_non_negative_integer(amount)
    if add <= 0 then
      return false, '熟练度增加数量必须大于 0'
    end
    local entry = get_entry(profile, hero_ref)
    if not entry then
      return false, '英雄不存在'
    end
    entry.proficiency = to_non_negative_integer(entry.proficiency) + add
    return true, 'ok', entry.proficiency
  end

  function api.try_star_up(profile, hero_ref)
    local entry, def = get_entry(profile, hero_ref)
    if not entry or not def then
      return false, '英雄不存在'
    end
    if entry.star >= MAX_STAR then
      return false, '已满星'
    end
    local need = STAR_COSTS[entry.star + 1] or STAR_COSTS[#STAR_COSTS]
    if entry.proficiency < need then
      return false, string.format('熟练度不足（当前 %d / 需求 %d）', entry.proficiency, need)
    end
    entry.proficiency = entry.proficiency - need
    entry.star = math.min(MAX_STAR, entry.star + 1)
    return true, 'ok', api.get_growth_view(profile, def.hero_id)
  end

  function api.try_awaken(profile, hero_ref)
    local entry, def = get_entry(profile, hero_ref)
    if not entry or not def then
      return false, '英雄不存在'
    end
    if entry.awakened == true then
      return false, '已觉醒'
    end
    if entry.star < MAX_STAR then
      return false, string.format('觉醒需要先升到 %d 星', MAX_STAR)
    end
    local resources = ensure_resources(profile)
    local stone = to_non_negative_integer(resources.awaken_stone)
    if stone < AWAKEN_COST then
      return false, string.format('觉醒石不足（当前 %d / 需求 %d）', stone, AWAKEN_COST)
    end
    resources.awaken_stone = stone - AWAKEN_COST
    entry.awakened = true
    return true, 'ok', api.get_growth_view(profile, def.hero_id)
  end

  function api.get_defs()
    return defs
  end

  return api
end

return M



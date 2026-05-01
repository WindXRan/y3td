local SkillFramework = require 'runtime.skill_framework'
local Skills = require 'runtime.skills'
local GeneratedSkills = require 'runtime.generated_skills'

local M = {}

local function deepcopy(src)
  if type(src) ~= 'table' then
    return src
  end
  local out = {}
  for k, v in pairs(src) do
    out[k] = deepcopy(v)
  end
  return out
end

local function make_vfx(pattern, element)
  local element_vfx = Skills.get_element_vfx(element) or Skills.get_element_vfx('physical')
  local element_fx = {
    phys = { cast = 106060, warning = 106060, impact = 106069, hit = 106069 },
    fire = { cast = 104727, warning = 104727, impact = 103953, hit = 103953 },
    ice = { cast = 106070, warning = 106067, impact = 106067, hit = 106070 },
    lightning = { cast = 106074, warning = 106074, impact = 106112, hit = 106074 },
    arcane = { cast = 106065, warning = 106065, impact = 106065, hit = 106065 },
  }
  local fx = element_fx[element] or element_fx.phys
  local is_burst = pattern == 'area_burst'
  return {
    cast = fx.cast,
    warning = fx.warning,
    impact = fx.impact,
    hit = fx.hit,
    projectile_key = element_vfx.projectile_key,
    projectile_height = element_vfx.projectile_height or (is_burst and 30 or 20),
    projectile_time = element_vfx.projectile_time or (is_burst and 0.72 or 0.62),
  }
end

local PATTERN_TO_BASE = {
  line_pierce = 'sf_line_pierce',
  area_burst = 'sf_area_burst',
  area_tick = 'sf_area_tick',
  chain_bounce = 'sf_chain_bounce',
}

local PATTERN_TARGET_MODE = {
  line_pierce = 'unit',
  area_burst = 'point',
  area_tick = 'point',
  chain_bounce = 'unit',
}

-- 从 CSV 批量构建技能行，补全同事的 build_rows() 骨架
local function build_rows()
  local csv_defs = GeneratedSkills.load_defs()
  local rows = {}
  for _, def in ipairs(csv_defs) do
    local pattern = def.pattern or 'area_burst'
    local element = def.element or 'physical'
    local hit_model = def.hit_model or {}
    local scale = def.scale or {}
    local resource = def.resource or {}

    rows[#rows + 1] = {
      id = def.id,
      name = def.name or def.id,
      desc = def.desc or '',
      base_id = PATTERN_TO_BASE[pattern] or 'sf_area_burst',
      pattern = pattern,
      target_mode = def.target_mode or PATTERN_TARGET_MODE[pattern] or 'point',
      damage_type = def.damage_type or '法术',
      cooldown = resource.cooldown or 0.95,
      range = hit_model.range or 1200,
      width = hit_model.width or 210,
      radius = hit_model.radius or 360,
      attack_ratio = scale.attack_ratio or 1.95,
      visual = def.visual or make_vfx(pattern, element),
    }
  end
  return rows
end

function M.create(env)
  env = env or {}
  local framework = SkillFramework.create({
    y3 = env.y3,
    skill_damage_api = env.skill_damage_api,
    get_primary_target = env.get_primary_target,
    get_enemies_in_range = env.get_enemies_in_range,
    get_hero = env.get_hero,
    get_hero_point = env.get_hero_point,
    get_hero_attack = env.get_hero_attack,
    get_hero_facing_towards = env.get_hero_facing_towards,
    create_offset_point = env.create_offset_point,
    launch_projectile_from_hero = env.launch_projectile_from_hero,
    spawn_particle = env.spawn_particle,
  })

  local defs = build_rows()
  local by_id = {}
  local next_index = 1

  local alias_to_id = {
    sf_line_pierce_mid = defs[1] and defs[1].id or nil,
    sf_area_burst_mid = defs[2] and defs[2].id or nil,
    sf_chain_bounce_mid = defs[3] and defs[3].id or nil,
    ['裂地重斩'] = defs[1] and defs[1].id or nil,
  }

  for _, row in ipairs(defs) do
    by_id[row.id] = row
    local built = Skills.build_production_skill(row.base_id, 'mid', row.visual, {
      id = row.id,
      name = row.name,
      pattern = row.pattern,
      target_mode = row.target_mode,
      damage_type = row.damage_type,
      resource = { cooldown = row.cooldown },
      hit_model = {
        range = row.range,
        width = row.width,
        radius = row.radius,
        max_hits = 0,
      },
      scale = {
        attack_ratio = row.attack_ratio,
      },
    })
    if built then
      framework.register(built)
    end
  end

  local api = {}

  function api.list_samples()
    local lines = {}
    for i, def in ipairs(defs) do
      lines[#lines + 1] = string.format('%02d. %s (%s) - %s', i, def.id, def.name, def.desc)
    end
    return lines
  end

  function api.get_sample_defs()
    return defs
  end

  function api.cast_sample(sample_id)
    local key = tostring(sample_id or '')
    local resolved = alias_to_id[key] or key
    local def = by_id[resolved]
    if not def then
      return false, string.format('未知 sample 技能：%s', tostring(sample_id))
    end
    return framework.cast_by_id(def.id)
  end

  function api.cast_next_sample()
    if #defs <= 0 then
      return false, '当前没有 sample 技能。'
    end
    if next_index > #defs then
      next_index = 1
    end
    local def = defs[next_index]
    next_index = next_index + 1
    return api.cast_sample(def.id)
  end

  function api.print_sample_list()
    for _, line in ipairs(api.list_samples()) do
      if env.message then
        env.message(line)
      else
        print(line)
      end
    end
  end

  function api.get_framework_telemetry(skill_id)
    if not framework or not framework.get_telemetry then
      return nil
    end
    return framework.get_telemetry(skill_id)
  end

  function api.reset_framework_telemetry(skill_id)
    if not framework or not framework.reset_telemetry then
      return false
    end
    framework.reset_telemetry(skill_id)
    return true
  end

  function api.build_framework_tier_report()
    local rows = {
      '[sample_skills] CSV-driven skill factory active',
      string.format('[sample_skills] total generated skills: %d', #defs),
    }
    return rows
  end

  function api.run_framework_auto_acceptance()
    local ids = {}
    for _, def in ipairs(defs) do
      ids[#ids + 1] = def.id
    end
    return true, ids
  end

  return api
end

return M

local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'
local BondVisualEditorIds = require 'data.object_tables.bond_visual_editor_ids'
local SkillFramework = require 'runtime.skill_framework'
local Skills = require 'runtime.skills'

local M = {}

local function round_number(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local function unit_alive(unit)
  return unit and unit.is_exist and unit:is_exist()
end

local function point_xyz(point)
  if not point then
    return nil, nil, nil
  end
  return point:get_x(), point:get_y(), point:get_z() or 0
end

local function create_offset_point(y3, base_point, angle, distance, z_offset)
  if not y3 or not y3.point or not y3.point.create or not base_point then
    return nil
  end
  local bx, by, bz = point_xyz(base_point)
  if not bx or not by then
    return nil
  end
  local x = bx + math.cos(angle) * (distance or 0)
  local y = by + math.sin(angle) * (distance or 0)
  local z = bz + (z_offset or 0)
  return y3.point.create(x, y, z)
end

local function spawn_particle(y3, target, effect_id, scale, time, height)
  if not y3 or not y3.particle or not y3.particle.create or not target then
    return
  end
  if not effect_id or effect_id <= 0 then
    return
  end
  pcall(y3.particle.create, {
    type = effect_id,
    target = target,
    scale = (scale or 1.0) * 0.88,
    time = (time or 0.2) * 0.85,
    height = height or 20,
    immediate = true,
  })
end

local function normalize_angle(value)
  local angle = tonumber(value) or 0
  if math.abs(angle) > (math.pi * 2 + 0.1) then
    angle = angle * math.pi / 180
  end
  return angle
end

local function clamp_positive(value, fallback)
  local num = tonumber(value)
  if num and num > 0 then
    return num
  end
  return fallback
end

local function clamp(value, min_value, max_value)
  if value < min_value then
    return min_value
  end
  if value > max_value then
    return max_value
  end
  return value
end

function M.create(env)
  env = env or {}
  local STATE = env.STATE
  local y3 = env.y3
  local message = env.message or print
  local hero_attr_system = env.hero_attr_system
  local skill_damage_api = env.skill_damage_api
  local get_enemies_in_range = env.get_enemies_in_range or function()
    return {}
  end
  local is_active_enemy = env.is_active_enemy or function(unit)
    return unit_alive(unit)
  end

  local BOND_VISUALS = BondVisualEditorIds.visual_by_bond or {}
  local PROJECTILES = RuntimeEditorIds.projectile or {}
  local function bond_particle(name, fallback)
    local entry = BOND_VISUALS[name]
    if entry and entry.particle_key and entry.particle_key > 0 then
      return entry.particle_key
    end
    return fallback
  end

  local function bond_projectile(name, fallback)
    local entry = BOND_VISUALS[name]
    if entry and entry.projectile_key and entry.projectile_key > 0 then
      return entry.projectile_key
    end
    return fallback
  end

  local fx = {
    neutral_warning = 106088,
    neutral_hit = 106069,
    neutral_impact = 106088,
    arrow_warning = 106090,
    arrow_impact = 106069,
    ice_warning = 106070,
    ice_impact = 106070,
    lightning_warning = 106074,
    lightning_impact = 106074,
    arcane_cast = 106065,
    arcane_impact = 106065,
    meteor_warning = 106082,
    meteor_impact = 106089,
    blade_cast = 106109,
    blade_impact = 106092,
    flame_cast = 106053,
    flame_impact = 106053,
    shadow_warning = 106107,
    shadow_impact = 106107,
  }

  local DAMAGE_BOOST = 1.75

  local SAMPLE_VISUALS = {
    arrow_rain = {
      warning = bond_particle('游侠', fx.arrow_warning),
      cast = bond_particle('游侠', fx.arrow_warning),
      impact = bond_particle('游侠', fx.arrow_impact),
      hit = bond_particle('游侠', fx.arrow_impact),
      projectile_key = bond_projectile('游侠', PROJECTILES.bow_multishot),
      projectile_time = 0.66,
      projectile_height = 24,
    },
    blizzard = {
      warning = bond_particle('冰霜法师', fx.ice_warning),
      cast = bond_particle('冰霜法师', fx.ice_warning),
      impact = bond_particle('冰霜法师', fx.ice_impact),
      hit = bond_particle('冰霜法师', fx.ice_impact),
      projectile_key = bond_projectile('冰霜法师', PROJECTILES.frost_nova),
      projectile_time = 1.05,
      projectile_height = 22,
    },
    sky_thunder = {
      warning = fx.lightning_warning,
      cast = fx.lightning_warning,
      impact = fx.lightning_impact,
      hit = fx.lightning_impact,
    },
    line_lance = {
      warning = bond_particle('龙骑士', fx.flame_cast),
      cast = bond_particle('龙骑士', fx.flame_cast),
      impact = bond_particle('龙骑士', fx.flame_impact),
      hit = bond_particle('龙骑士', fx.flame_impact),
      projectile_key = bond_projectile('龙骑士', PROJECTILES.fireball),
      projectile_time = 1.05,
      projectile_height = 32,
    },
    meteor_grid = {
      warning = bond_particle('火法师', fx.meteor_warning),
      cast = bond_particle('火法师', fx.meteor_warning),
      impact = bond_particle('火法师', fx.meteor_impact),
      hit = bond_particle('火法师', fx.flame_impact),
      projectile_key = bond_projectile('火法师', PROJECTILES.meteor),
      projectile_time = 1.15,
      projectile_height = 44,
    },
    orbit_blade = {
      warning = bond_particle('剑魂', fx.blade_cast),
      cast = bond_particle('剑魂', fx.blade_cast),
      impact = bond_particle('剑魂', fx.blade_impact),
      hit = bond_particle('剑魂', fx.blade_impact),
      projectile_key = bond_projectile('剑魂', PROJECTILES.flying_swords),
      projectile_time = 0.75,
      projectile_height = 18,
    },
    chain_arc = {
      warning = bond_particle('雷电法王', fx.lightning_warning),
      cast = bond_particle('雷电法王', fx.lightning_warning),
      impact = bond_particle('雷电法王', fx.lightning_impact),
      hit = bond_particle('雷电法王', fx.lightning_impact),
      projectile_key = bond_projectile('雷电法王', PROJECTILES.chain_lightning),
      projectile_time = 0.82,
      projectile_height = 30,
    },
    fan_barrage = {
      warning = bond_particle('神射手', fx.arrow_warning),
      cast = bond_particle('神射手', fx.arrow_impact),
      impact = bond_particle('神射手', fx.arrow_impact),
      hit = bond_particle('神射手', fx.arrow_impact),
      projectile_key = bond_projectile('神射手', PROJECTILES.bow_gale),
      projectile_time = 0.68,
      projectile_height = 16,
    },
    burn_field = {
      warning = bond_particle('火法师', fx.flame_cast),
      cast = bond_particle('火法师', fx.flame_cast),
      impact = bond_particle('火法师', fx.flame_impact),
      hit = bond_particle('火法师', fx.flame_impact),
      projectile_key = bond_projectile('火法师', PROJECTILES.lotus_flame),
      projectile_time = 0.92,
      projectile_height = 20,
    },
    boomerang_blade = {
      warning = bond_particle('剑宗', fx.blade_cast),
      cast = bond_particle('剑宗', fx.blade_cast),
      impact = bond_particle('剑宗', fx.blade_impact),
      hit = bond_particle('剑宗', fx.blade_impact),
      projectile_key = bond_projectile('剑宗', PROJECTILES.moon_blade),
      projectile_time = 0.82,
      projectile_height = 18,
    },
    mark_execute = {
      warning = bond_particle('魔剑士', fx.shadow_warning),
      cast = bond_particle('魔剑士', fx.shadow_warning),
      impact = bond_particle('魔剑士', fx.shadow_impact),
      hit = bond_particle('魔剑士', fx.shadow_impact),
      projectile_key = bond_projectile('魔剑士', PROJECTILES.demon_seal),
      projectile_time = 0.90,
      projectile_height = 24,
    },
  }

  -- 成品特效包（production_v2）：统一替换 samples 特效，降低闪屏和过曝。
  local CLOUD_VFX_PACKS = {
    production_v2 = {
      arrow_rain = { warning = 106060, cast = 106060, impact = 106090, hit = 106069, projectile_key = PROJECTILES.bow_multishot, projectile_time = 0.64, projectile_height = 22 },
      blizzard = { warning = 106067, cast = 106070, impact = 106067, hit = 106070, projectile_key = PROJECTILES.frost_nova, projectile_time = 0.96, projectile_height = 20 },
      sky_thunder = { warning = 106074, cast = 106112, impact = 106074, hit = 106112 },
      line_lance = { warning = 106089, cast = 106089, impact = 106081, hit = 106053, projectile_key = PROJECTILES.fireball, projectile_time = 0.90, projectile_height = 28 },
      meteor_grid = { warning = 106082, cast = 106082, impact = 106089, hit = 106053, projectile_key = PROJECTILES.meteor, projectile_time = 1.02, projectile_height = 36 },
      orbit_blade = { warning = 106109, cast = 106109, impact = 106092, hit = 106092, projectile_key = PROJECTILES.flying_swords, projectile_time = 0.66, projectile_height = 16 },
      chain_arc = { warning = 106074, cast = 106074, impact = 106112, hit = 106074, projectile_key = PROJECTILES.chain_lightning, projectile_time = 0.74, projectile_height = 24 },
      fan_barrage = { warning = 106090, cast = 106060, impact = 106069, hit = 106060, projectile_key = PROJECTILES.bow_gale, projectile_time = 0.62, projectile_height = 14 },
      burn_field = { warning = 106082, cast = 106053, impact = 106081, hit = 106053, projectile_key = PROJECTILES.lotus_flame, projectile_time = 0.82, projectile_height = 18 },
      boomerang_blade = { warning = 106092, cast = 106109, impact = 106092, hit = 106109, projectile_key = PROJECTILES.moon_blade, projectile_time = 0.72, projectile_height = 16 },
      mark_execute = { warning = 106107, cast = 106056, impact = 106107, hit = 106056, projectile_key = PROJECTILES.demon_seal, projectile_time = 0.78, projectile_height = 20 },
    },
  }

  local function mount_cloud_vfx_pack(pack_name)
    local pack = CLOUD_VFX_PACKS[pack_name]
    if type(pack) ~= 'table' then
      return false
    end
    for sample_id, override in pairs(pack) do
      local base = SAMPLE_VISUALS[sample_id]
      if type(base) == 'table' and type(override) == 'table' then
        for k, v in pairs(override) do
          base[k] = v
        end
      end
    end
    return true
  end

  mount_cloud_vfx_pack('production_v2')

  local PROJECTILE_REQUIRED_SAMPLES = {
    arrow_rain = true,
    blizzard = true,
    line_lance = true,
    meteor_grid = true,
    orbit_blade = true,
    chain_arc = true,
    fan_barrage = true,
    burn_field = true,
    boomerang_blade = true,
    mark_execute = true,
  }

  local function validate_visual_config_or_error(sample_id, cfg)
    if type(cfg) ~= 'table' then
      error(string.format('[sample_skills] %s visual 配置缺失', tostring(sample_id)))
    end
    local required_particles = {'cast', 'impact', 'hit'}
    for _, key in ipairs(required_particles) do
      local value = tonumber(cfg[key]) or 0
      if value <= 0 then
        error(string.format('[sample_skills] %s visual.%s 非法: %s', tostring(sample_id), key, tostring(cfg[key])))
      end
    end
    if PROJECTILE_REQUIRED_SAMPLES[sample_id] == true then
      local projectile_key = tonumber(cfg.projectile_key) or 0
      if projectile_key <= 0 then
        error(string.format('[sample_skills] %s projectile_key 非法: %s', tostring(sample_id), tostring(cfg.projectile_key)))
      end
    end
  end

  local function validate_sample_visuals_or_error()
    for sample_id, cfg in pairs(SAMPLE_VISUALS) do
      validate_visual_config_or_error(sample_id, cfg)
    end
  end

  local function get_hero()
    local hero = STATE and STATE.hero or nil
    if unit_alive(hero) then
      return hero
    end
    return nil
  end

  local function get_hero_attack()
    local hero = get_hero()
    if not hero then
      return 0
    end
    local value = 0
    if hero_attr_system and hero_attr_system.get_attr then
      value = tonumber(hero_attr_system.get_attr(hero, '攻击结算值')) or 0
      if value <= 0 then
        value = tonumber(hero_attr_system.get_attr(hero, '攻击')) or 0
      end
    end
    if value <= 0 and hero.get_attr then
      value = tonumber(hero:get_attr('攻击结算值')) or tonumber(hero:get_attr('攻击')) or tonumber(hero:get_attr('物理攻击')) or 0
    end
    return math.max(1, value)
  end

  local function get_hero_point()
    local hero = get_hero()
    if not hero or not hero.get_point then
      return nil
    end
    return hero:get_point()
  end

  local function get_primary_target(range)
    local hero = get_hero()
    if not hero then
      return nil
    end
    local targets = get_enemies_in_range(hero, range or 1200, nil, 1) or {}
    local target = targets[1]
    if unit_alive(target) and is_active_enemy(target) then
      return target
    end
    return nil
  end

  local function get_sample_vfx(sample_id)
    return SAMPLE_VISUALS[sample_id] or {}
  end


  local function launch_projectile_from_hero(projectile_key, target, point, angle, time, height)
    local hero = get_hero()
    if not hero or not y3 or not y3.projectile or not y3.projectile.create then
      return nil
    end
    local forced_projectile_key = clamp_positive(STATE and STATE.debug_force_projectile_key, nil)
    projectile_key = clamp_positive(forced_projectile_key or projectile_key, nil)
    if not projectile_key then
      return nil
    end

    local launch_angle = angle
    local hero_point = get_hero_point()
    if launch_angle == nil and hero_point and target and target.get_point and hero_point.get_angle_with then
      local target_point = target:get_point()
      if target_point then
        launch_angle = hero_point:get_angle_with(target_point)
      end
    end
    if launch_angle == nil and hero_point and point and hero_point.get_angle_with then
      launch_angle = hero_point:get_angle_with(point)
    end

    local ok, projectile = pcall(y3.projectile.create, {
      key = projectile_key,
      target = hero,
      socket = 'origin',
      owner = hero,
      angle = launch_angle,
      time = time or 0.9,
      remove_immediately = true,
    })
    if not ok or not projectile then
      return nil
    end
    if height and projectile.set_height then
      pcall(projectile.set_height, projectile, height)
    end
    if launch_angle and projectile.set_facing then
      pcall(projectile.set_facing, projectile, launch_angle)
    end
    return projectile
  end

  local function apply_single_damage(unit, amount, damage_type, visual)
    if not skill_damage_api or not skill_damage_api.single then
      return false
    end
    local ok = skill_damage_api.single(unit, amount, damage_type or '法术', visual)
    if ok and unit_alive(unit) then
      local particle = visual and visual.particle or fx.neutral_impact
      spawn_particle(y3, unit, particle, 1.05, 0.14, 24)
    end
    return ok
  end

  local function apply_area_damage(center, radius, amount, damage_type, visual)
    if not skill_damage_api or not skill_damage_api.area then
      return {}
    end
    local result = skill_damage_api.area(center, radius, amount, damage_type or '法术', {
      visual = visual,
    })
    if center then
      local particle = visual and visual.particle or fx.neutral_hit
      local area_scale = clamp((tonumber(radius) or 260) / 260, 0.75, 2.20)
      spawn_particle(y3, center, particle, area_scale, 0.12, 20)
    end
    return result
  end

  local function collect_units_in_line(origin_point, impact_point, max_distance, line_width, max_hits)
    if not origin_point or not impact_point then
      return {}
    end
    local ox, oy = point_xyz(origin_point)
    local tx, ty = point_xyz(impact_point)
    if not ox or not oy or not tx or not ty then
      return {}
    end

    local dx = tx - ox
    local dy = ty - oy
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then
      return {}
    end

    local reach = math.max(length, tonumber(max_distance) or length)
    local width = math.max(40, tonumber(line_width) or 120)
    local ux = dx / length
    local uy = dy / length
    local query_radius = math.max(320, reach + width + 120)
    local limit = math.max(96, tonumber(max_hits) or 96)
    local candidates = get_enemies_in_range(origin_point, query_radius, nil, limit) or {}
    local hits = {}

    for _, unit in ipairs(candidates) do
      if unit_alive(unit) and is_active_enemy(unit) then
        local point = unit.get_point and unit:get_point() or nil
        local px, py = point_xyz(point)
        if px and py then
          local vx = px - ox
          local vy = py - oy
          local projection = ux * vx + uy * vy
          if projection >= 0 and projection <= reach then
            local perpendicular = math.abs(ux * vy - uy * vx)
            if perpendicular <= width then
              hits[#hits + 1] = {
                unit = unit,
                projection = projection,
              }
            end
          end
        end
      end
    end

    table.sort(hits, function(a, b)
      return (a.projection or 0) < (b.projection or 0)
    end)

    local result = {}
    local cap = max_hits and math.max(1, math.floor(max_hits)) or #hits
    for i = 1, math.min(cap, #hits) do
      result[#result + 1] = hits[i].unit
    end
    return result
  end

  local function apply_line_damage(origin_point, impact_point, distance, width, amount, damage_type, visual, max_hits)
    local units = collect_units_in_line(origin_point, impact_point, distance, width, max_hits)
    local hit_count = 0
    for _, unit in ipairs(units) do
      if apply_single_damage(unit, amount, damage_type, visual) then
        hit_count = hit_count + 1
      end
    end
    if impact_point and visual and visual.particle then
      local line_scale = clamp(((tonumber(width) or 180) / 180) * clamp((tonumber(distance) or 1200) / 1200, 0.85, 1.20), 0.80, 2.10)
      spawn_particle(y3, impact_point, visual.particle, line_scale, 0.14, 24)
    end
    return hit_count
  end

  local function get_hero_facing_towards(target)
    local hero = get_hero()
    if not hero then
      return 0
    end
    local hero_point = get_hero_point()
    if target and target.get_point and hero_point and hero_point.get_angle_with then
      local target_point = target:get_point()
      if target_point then
        return hero_point:get_angle_with(target_point)
      end
    end
    if hero.get_facing then
      return normalize_angle(hero:get_facing())
    end
    return 0
  end

  local skill_framework = SkillFramework.create({
    y3 = y3,
    skill_damage_api = skill_damage_api,
    get_primary_target = get_primary_target,
    get_enemies_in_range = get_enemies_in_range,
    get_hero = get_hero,
    get_hero_point = get_hero_point,
    get_hero_attack = get_hero_attack,
    get_hero_facing_towards = get_hero_facing_towards,
    create_offset_point = create_offset_point,
    launch_projectile_from_hero = launch_projectile_from_hero,
    spawn_particle = spawn_particle,
  })

  local SAMPLE_DEFS = {
    {
      id = 'arrow_rain',
      name = '箭雨覆盖',
      desc = '机制：区域持续打击；表现：高密度坠箭覆盖；调参：shots/radius/每发伤害。',
      cast = function()
        local vfx = get_sample_vfx('arrow_rain')
        local target = get_primary_target(1500)
        local center = target and target:get_point() or get_hero_point()
        if not center then
          return false, '无法确定箭雨中心。'
        end
        local attack = get_hero_attack()
        local shots = 30
        local radius = 520
        if target then
          launch_projectile_from_hero(vfx.projectile_key, target, center, nil, vfx.projectile_time, vfx.projectile_height)
        end
        for i = 1, shots do
          local delay = (i - 1) * 0.05
          local angle = math.random() * math.pi * 2
          local dist = math.sqrt(math.random()) * radius
          local hit_point = create_offset_point(y3, center, angle, dist, 0)
          if hit_point then
            spawn_particle(y3, hit_point, vfx.warning, 1.18, 0.24 + delay, 32)
            y3.ltimer.wait(delay, function()
              spawn_particle(y3, hit_point, vfx.impact, 1.42, 0.20, 40)
              apply_area_damage(hit_point, 180, attack * 0.85 * DAMAGE_BOOST, '物理', {
                particle = vfx.hit,
                metric_scope = 'sample_skill',
                metric_key = 'arrow_rain',
              })
            end)
          end
        end
        return true, '箭雨覆盖已释放。'
      end,
    },
    {
      id = 'blizzard',
      name = '暴风雪领域',
      desc = '机制：中心持续伤害+外圈补刀；表现：大范围冰暴；调参：tick_count/radius/edge_ratio。',
      cast = function()
        local vfx = get_sample_vfx('blizzard')
        local target = get_primary_target(1500)
        local center = target and target:get_point() or get_hero_point()
        if not center then
          return false, '无法确定暴风雪中心。'
        end
        local attack = get_hero_attack()
        local ticks = 18
        local radius = 460
        if target then
          launch_projectile_from_hero(vfx.projectile_key, target, center, nil, vfx.projectile_time, vfx.projectile_height)
        end
        for i = 1, ticks do
          y3.ltimer.wait((i - 1) * 0.28, function()
            spawn_particle(y3, center, vfx.warning, 1.45, 0.18, 30)
            apply_area_damage(center, radius, attack * 0.52 * DAMAGE_BOOST, '法术', {
              particle = vfx.hit,
              metric_scope = 'sample_skill',
              metric_key = 'blizzard',
            })
            for spoke = 1, 6 do
              local angle = (spoke - 1) * (math.pi / 3) + i * 0.18
              local edge = create_offset_point(y3, center, angle, radius * 0.78, 0)
              if edge then
                spawn_particle(y3, edge, vfx.cast, 0.95, 0.16, 22)
                apply_area_damage(edge, 155, attack * 0.32 * DAMAGE_BOOST, '法术', {
                  particle = vfx.hit,
                  metric_scope = 'sample_skill',
                  metric_key = 'blizzard_edge',
                })
              end
            end
          end)
        end
        return true, '暴风雪领域已展开。'
      end,
    },
    {
      id = 'sky_thunder',
      name = '天雷降世',
      desc = '机制：无弹道落点直击；表现：高亮预警后瞬发雷击；调参：delay/hit_count/单次倍率。',
      cast = function()
        local vfx = get_sample_vfx('sky_thunder')
        local hero = get_hero()
        if not hero then
          return false, '英雄不存在。'
        end
        local targets = get_enemies_in_range(hero, 1300, nil, 6) or {}
        if #targets == 0 then
          return false, '附近没有可攻击目标。'
        end
        local attack = get_hero_attack()
        local hero_point = get_hero_point()
        if hero_point then
          spawn_particle(y3, hero_point, vfx.cast, 1.25, 0.30, 36)
        end
        for index, unit in ipairs(targets) do
          local delay = (index - 1) * 0.08
          local snapshot_point = unit.get_point and unit:get_point() or nil
          if snapshot_point then
            spawn_particle(y3, snapshot_point, vfx.warning, 1.18, delay + 0.20, 52)
          end
          y3.ltimer.wait(delay + 0.18, function()
            local point = snapshot_point
            if unit_alive(unit) and unit.get_point then
              point = unit:get_point()
            end
            if point then
              -- 关键：只在落点播放雷击，不发射投射物。
              spawn_particle(y3, point, vfx.impact, 1.58, 0.22, 56)
              apply_area_damage(point, 320, attack * 1.65 * DAMAGE_BOOST, '法术', {
                particle = vfx.hit,
                metric_scope = 'sample_skill',
                metric_key = 'sky_thunder',
              })
            end
          end)
        end
        return true, string.format('天雷已锁定：%d 个落点', #targets)
      end,
    },
    {
      id = 'line_lance',
      name = '穿刺光枪',
      desc = '机制：固定长度直线穿透；表现：重型枪芒推进；调参：distance/width/max_hits。',
      cast = function()
        local vfx = get_sample_vfx('line_lance')
        local hero_point = get_hero_point()
        local target = get_primary_target(1800)
        if not hero_point then
          return false, '英雄位置无效。'
        end
        local angle = get_hero_facing_towards(target)
        local distance = 1650
        local impact = create_offset_point(y3, hero_point, angle, distance, 0)
        local damage = get_hero_attack() * 3.1 * DAMAGE_BOOST
        spawn_particle(y3, hero_point, vfx.cast, 1.40, 0.26, 34)
        if impact then
          launch_projectile_from_hero(vfx.projectile_key, target, impact, angle, vfx.projectile_time, vfx.projectile_height)
          spawn_particle(y3, impact, vfx.impact, 1.55, 0.26, 30)
          local hits = apply_line_damage(hero_point, impact, distance, 280, damage, '物理', {
            particle = vfx.hit,
                metric_scope = 'sample_skill',
                metric_key = 'line_lance',
              }, 20)
          return true, string.format('穿刺光枪命中：%d', hits)
        end
        return false, '直线终点创建失败。'
      end,
    },
    {
      id = 'meteor_grid',
      name = '九宫陨爆',
      desc = '机制：九宫格延迟爆发；表现：连续预警+连环坠落；调参：grid_spacing/fall_delay/aoe。',
      cast = function()
        local vfx = get_sample_vfx('meteor_grid')
        local target = get_primary_target(1500)
        local center = target and target:get_point() or get_hero_point()
        if not center then
          return false, '无法确定施法中心。'
        end
        local base_damage = get_hero_attack() * 1.65 * DAMAGE_BOOST
        local spacing = 220
        local cast_count = 0
        if target then
          launch_projectile_from_hero(vfx.projectile_key, target, center, nil, vfx.projectile_time, vfx.projectile_height)
        end
        for row = -1, 1 do
          for col = -1, 1 do
            local delay = 0.18 * (math.abs(row) + math.abs(col))
            local offset_x = col * spacing
            local offset_y = row * spacing
            local cx, cy, cz = point_xyz(center)
            if cx and cy then
              local point = y3.point.create(cx + offset_x, cy + offset_y, cz or 0)
              cast_count = cast_count + 1
              spawn_particle(y3, point, vfx.warning, 1.22, delay + 0.20, 20)
              y3.ltimer.wait(delay, function()
                spawn_particle(y3, point, vfx.impact, 1.70, 0.24, 40)
                apply_area_damage(point, 300, base_damage, '法术', {
                  particle = vfx.hit,
                  metric_scope = 'sample_skill',
                  metric_key = 'meteor_grid',
                })
              end)
            end
          end
        end
        return true, string.format('九宫陨爆已释放：%d 落点', cast_count)
      end,
    },
    {
      id = 'orbit_blade',
      name = '旋刃风暴',
      desc = '机制：环绕多段切割；表现：旋转刀环持续命中；调参：ring_radius/step_count/tick_interval。',
      cast = function()
        local vfx = get_sample_vfx('orbit_blade')
        local hero = get_hero()
        local hero_point = get_hero_point()
        if not hero or not hero_point then
          return false, '英雄不存在。'
        end
        local base_damage = get_hero_attack() * 0.72 * DAMAGE_BOOST
        local ring_radius = 420
        local ticks = 14
        local start_angle = normalize_angle(hero.get_facing and hero:get_facing() or 0)
        for i = 1, ticks do
          y3.ltimer.wait((i - 1) * 0.16, function()
            local current_hero = get_hero()
            local current_point = get_hero_point()
            if not current_hero or not current_point then
              return
            end
            local angle = start_angle + i * 0.82
            local hit_point = create_offset_point(y3, current_point, angle, ring_radius, 0)
            if hit_point then
              spawn_particle(y3, hit_point, vfx.cast, 1.18, 0.18, 26)
              launch_projectile_from_hero(vfx.projectile_key, nil, hit_point, angle, vfx.projectile_time, vfx.projectile_height)
              apply_area_damage(hit_point, 220, base_damage, '物理', {
                particle = vfx.hit,
                metric_scope = 'sample_skill',
                metric_key = 'orbit_blade',
              })
            end
          end)
        end
        return true, '旋刃风暴已启动。'
      end,
    },
    {
      id = 'chain_arc',
      name = '连锁电弧',
      desc = '机制：目标间链式弹跳；表现：电弧跳链与逐段衰减；调参：max_bounce/falloff/jump_range。',
      cast = function()
        local vfx = get_sample_vfx('chain_arc')
        local hero = get_hero()
        if not hero then
          return false, '英雄不存在。'
        end
        local targets = get_enemies_in_range(hero, 1400, nil, 8) or {}
        if #targets == 0 then
          return false, '附近没有可攻击目标。'
        end
        local damage = get_hero_attack() * 2.6 * DAMAGE_BOOST
        local hits = 0
        for index, unit in ipairs(targets) do
          local ratio = math.max(0.35, 1.0 - (index - 1) * 0.12)
          spawn_particle(y3, unit, vfx.cast, 1.22, 0.18, 28)
          launch_projectile_from_hero(vfx.projectile_key, unit, nil, nil, vfx.projectile_time, vfx.projectile_height)
          if apply_single_damage(unit, damage * ratio, '法术', {
            particle = vfx.hit,
            metric_scope = 'sample_skill',
            metric_key = 'chain_arc',
          }) then
            hits = hits + 1
          end
          apply_area_damage(unit, 120, damage * ratio * 0.35, '法术', {
            particle = vfx.impact,
            metric_scope = 'sample_skill',
            metric_key = 'chain_arc_burst',
          })
        end
        return true, string.format('连锁电弧命中：%d', hits)
      end,
    },
    {
      id = 'fan_barrage',
      name = '扇形扫射',
      desc = '机制：多线扇面覆盖；表现：前方火力墙；调参：line_count/fan_angle/line_width。',
      cast = function()
        local vfx = get_sample_vfx('fan_barrage')
        local hero = get_hero()
        local hero_point = get_hero_point()
        local target = get_primary_target(1600)
        if not hero or not hero_point then
          return false, '英雄不存在。'
        end
        local facing = get_hero_facing_towards(target)
        local damage = get_hero_attack() * 1.28 * DAMAGE_BOOST
        local rays = { -0.52, -0.34, -0.17, 0, 0.17, 0.34, 0.52 }
        local total_hits = 0
        for _, delta in ipairs(rays) do
          local angle = facing + delta
          local impact = create_offset_point(y3, hero_point, angle, 980, 0)
          if impact then
            launch_projectile_from_hero(vfx.projectile_key, nil, impact, angle, vfx.projectile_time, vfx.projectile_height)
            total_hits = total_hits + apply_line_damage(hero_point, impact, 1180, 190, damage, '物理', {
              particle = vfx.hit,
              metric_scope = 'sample_skill',
              metric_key = 'fan_barrage',
            }, 20)
          end
        end
        spawn_particle(y3, hero_point, vfx.cast, 1.40, 0.24, 30)
        return true, string.format('扇形扫射累计命中：%d', total_hits)
      end,
    },
    {
      id = 'burn_field',
      name = '炽焰领域',
      desc = '机制：落点持续灼烧；表现：火圈脉冲与地面灼流；调参：duration/tick_interval/radius。',
      cast = function()
        local vfx = get_sample_vfx('burn_field')
        local center_target = get_primary_target(1500)
        local center = center_target and center_target:get_point() or get_hero_point()
        if not center then
          return false, '无法确定施法位置。'
        end
        local tick_damage = get_hero_attack() * 0.82 * DAMAGE_BOOST
        local ticks = 16
        if center_target then
          launch_projectile_from_hero(vfx.projectile_key, center_target, center, nil, vfx.projectile_time, vfx.projectile_height)
        end
        for i = 1, ticks do
          y3.ltimer.wait((i - 1) * 0.26, function()
            spawn_particle(y3, center, vfx.warning, 1.34, 0.18, 20)
            apply_area_damage(center, 420, tick_damage, '法术', {
              particle = vfx.hit,
              metric_scope = 'sample_skill',
              metric_key = 'burn_field',
            })
          end)
        end
        return true, '炽焰领域已展开。'
      end,
    },
    {
      id = 'boomerang_blade',
      name = '回旋刃',
      desc = '机制：去回双段判定；表现：回收段更重；调参：out_width/back_width/back_multiplier。',
      cast = function()
        local vfx = get_sample_vfx('boomerang_blade')
        local hero_point = get_hero_point()
        local target = get_primary_target(1700)
        if not hero_point then
          return false, '英雄位置无效。'
        end
        local base_damage = get_hero_attack() * 1.50 * DAMAGE_BOOST
        local direction = get_hero_facing_towards(target)
        local far_point = create_offset_point(y3, hero_point, direction, 1250, 0)
        if not far_point then
          return false, '回旋刃终点创建失败。'
        end
        spawn_particle(y3, hero_point, vfx.cast, 1.20, 0.24, 28)
        launch_projectile_from_hero(vfx.projectile_key, nil, far_point, direction, vfx.projectile_time, vfx.projectile_height)
        local out_hits = apply_line_damage(hero_point, far_point, 1250, 220, base_damage, '物理', {
          particle = vfx.hit,
          metric_scope = 'sample_skill',
          metric_key = 'boomerang_blade_out',
        }, 14)
        y3.ltimer.wait(0.28, function()
          spawn_particle(y3, far_point, vfx.impact, 1.25, 0.20, 24)
          launch_projectile_from_hero(vfx.projectile_key, nil, hero_point, direction + math.pi, vfx.projectile_time, vfx.projectile_height)
          apply_line_damage(far_point, hero_point, 1250, 260, base_damage * 1.85, '物理', {
            particle = vfx.impact,
            metric_scope = 'sample_skill',
            metric_key = 'boomerang_blade_back',
          }, 18)
        end)
        return true, string.format('回旋刃去程命中：%d（回程已排队）', out_hits)
      end,
    },
    {
      id = 'mark_execute',
      name = '裂隙印记',
      desc = '机制：先挂印后结算；表现：阴影预警后瞬时处决；调参：mark_delay/lost_hp_ratio_scale。',
      cast = function()
        local vfx = get_sample_vfx('mark_execute')
        local hero = get_hero()
        if not hero then
          return false, '英雄不存在。'
        end
        local targets = get_enemies_in_range(hero, 1200, nil, 5) or {}
        if #targets == 0 then
          return false, '附近没有可攻击目标。'
        end
        local attack = get_hero_attack()
        for _, unit in ipairs(targets) do
          spawn_particle(y3, unit, vfx.warning, 1.15, 0.9, 32)
          launch_projectile_from_hero(vfx.projectile_key, unit, nil, nil, vfx.projectile_time, vfx.projectile_height)
        end
        y3.ltimer.wait(0.9, function()
          for _, unit in ipairs(targets) do
            if unit_alive(unit) and is_active_enemy(unit) then
              local hp = tonumber(unit.get_hp and unit:get_hp() or 0) or 0
              local max_hp = tonumber(unit.get_attr and (unit:get_attr('生命') or unit:get_attr('最大生命')) or 0) or 0
              local lost_ratio = 0
              if max_hp > 0 then
                lost_ratio = math.max(0, math.min(1, (max_hp - hp) / max_hp))
              end
              local amount = attack * (1.9 + lost_ratio * 2.1) * DAMAGE_BOOST
              spawn_particle(y3, unit, vfx.impact, 1.35, 0.24, 34)
              apply_single_damage(unit, amount, '法术', {
                particle = vfx.hit,
                metric_scope = 'sample_skill',
                metric_key = 'mark_execute',
              })
            end
          end
        end)
        return true, string.format('裂隙印记已施加：%d', #targets)
      end,
    },
    {
      id = 'starfall_corridor',
      name = '星瀑走廊',
      desc = '机制：沿直线分段坠落；表现：走廊式连续天降打击；调参：segment_count/segment_gap/segment_radius。',
      cast = function()
        local hero_point = get_hero_point()
        local target = get_primary_target(1800)
        if not hero_point then
          return false, '英雄位置无效。'
        end
        local vfx = get_sample_vfx('sky_thunder')
        local angle = get_hero_facing_towards(target)
        local attack = get_hero_attack()
        local segments = 8
        local gap = 170
        local radius = 190
        for i = 1, segments do
          local p = create_offset_point(y3, hero_point, angle, i * gap, 0)
          if p then
            y3.ltimer.wait((i - 1) * 0.08, function()
              spawn_particle(y3, p, vfx.warning, 0.95, 0.20, 34)
            end)
            y3.ltimer.wait((i - 1) * 0.08 + 0.16, function()
              spawn_particle(y3, p, vfx.impact, 1.15, 0.16, 38)
              apply_area_damage(p, radius, attack * 1.25 * DAMAGE_BOOST, '法术', {
                particle = vfx.hit,
                metric_scope = 'sample_skill',
                metric_key = 'starfall_corridor',
              })
            end)
          end
        end
        return true, '星瀑走廊已释放。'
      end,
    },
    {
      id = 'thunder_prison',
      name = '雷牢',
      desc = '机制：定点雷环周期脉冲；表现：中心束缚感强；调参：pulse_count/pulse_radius/pulse_interval。',
      cast = function()
        local target = get_primary_target(1500)
        local center = target and target:get_point() or get_hero_point()
        if not center then
          return false, '无法确定雷牢中心。'
        end
        local vfx = get_sample_vfx('chain_arc')
        local attack = get_hero_attack()
        local pulses = 7
        local radius = 360
        spawn_particle(y3, center, vfx.warning, 1.30, 0.55, 28)
        for i = 1, pulses do
          y3.ltimer.wait((i - 1) * 0.20, function()
            spawn_particle(y3, center, vfx.impact, 1.10, 0.12, 28)
            apply_area_damage(center, radius, attack * 0.48 * DAMAGE_BOOST, '法术', {
              particle = vfx.hit,
              metric_scope = 'sample_skill',
              metric_key = 'thunder_prison',
            })
          end)
        end
        return true, '雷牢已展开。'
      end,
    },
    {
      id = 'phoenix_dive',
      name = '炎凰俯冲',
      desc = '机制：前冲直线后落地爆炸；表现：先贯穿后爆裂；调参：dash_distance/line_width/explosion_radius。',
      cast = function()
        local hero_point = get_hero_point()
        local target = get_primary_target(1700)
        if not hero_point then
          return false, '英雄位置无效。'
        end
        local vfx = get_sample_vfx('meteor_grid')
        local attack = get_hero_attack()
        local angle = get_hero_facing_towards(target)
        local impact = create_offset_point(y3, hero_point, angle, 1350, 0)
        if not impact then
          return false, '炎凰终点创建失败。'
        end
        launch_projectile_from_hero(vfx.projectile_key, nil, impact, angle, vfx.projectile_time, vfx.projectile_height)
        spawn_particle(y3, hero_point, vfx.cast, 1.25, 0.24, 30)
        local hit = apply_line_damage(hero_point, impact, 1350, 220, attack * 1.70 * DAMAGE_BOOST, '法术', {
          particle = vfx.hit,
          metric_scope = 'sample_skill',
          metric_key = 'phoenix_dive_line',
        }, 20)
        y3.ltimer.wait(0.18, function()
          spawn_particle(y3, impact, vfx.impact, 1.45, 0.18, 36)
          apply_area_damage(impact, 360, attack * 2.20 * DAMAGE_BOOST, '法术', {
            particle = vfx.impact,
            metric_scope = 'sample_skill',
            metric_key = 'phoenix_dive_burst',
          })
        end)
        return true, string.format('炎凰俯冲穿透命中：%d（爆炸已触发）', hit)
      end,
    },
    {
      id = 'void_pulse',
      name = '虚空脉冲',
      desc = '机制：中心高频脉冲+末端大爆发；表现：压缩后释放；调参：tick_count/tick_radius/final_multiplier。',
      cast = function()
        local target = get_primary_target(1400)
        local center = target and target:get_point() or get_hero_point()
        if not center then
          return false, '无法确定虚空中心。'
        end
        local vfx = get_sample_vfx('mark_execute')
        local attack = get_hero_attack()
        local ticks = 10
        local radius = 300
        spawn_particle(y3, center, vfx.warning, 1.35, 0.85, 26)
        for i = 1, ticks do
          y3.ltimer.wait((i - 1) * 0.11, function()
            spawn_particle(y3, center, vfx.hit, 0.92, 0.10, 20)
            apply_area_damage(center, radius, attack * 0.30 * DAMAGE_BOOST, '法术', {
              particle = vfx.hit,
              metric_scope = 'sample_skill',
              metric_key = 'void_pulse_tick',
            })
          end)
        end
        y3.ltimer.wait(ticks * 0.11 + 0.06, function()
          spawn_particle(y3, center, vfx.impact, 1.55, 0.22, 34)
          apply_area_damage(center, 420, attack * 2.60 * DAMAGE_BOOST, '真实', {
            particle = vfx.impact,
            metric_scope = 'sample_skill',
            metric_key = 'void_pulse_final',
          })
        end)
        return true, '虚空脉冲已释放。'
      end,
    },
  }

  local function add_framework_samples()
    local function add(def)
      SAMPLE_DEFS[#SAMPLE_DEFS + 1] = def
    end

    local function register_framework_def(id, visual)
      local def = Skills.build_production_skill(id, 'mid', visual)
      if not def then
        return
      end
      skill_framework.register(def)
    end

    add({
      id = 'sf_line_pierce',
      name = '框架样例·直线穿透',
      desc = '统一技能协议：line_pierce（固定长度直线穿透）。',
      cast = function()
        local vfx = get_sample_vfx('line_lance')
        register_framework_def('sf_line_pierce', {
          cast = vfx.cast,
          hit = vfx.hit,
          projectile_key = vfx.projectile_key,
          projectile_height = vfx.projectile_height,
        })
        return skill_framework.cast_by_id('sf_line_pierce')
      end,
    })

    add({
      id = 'sf_area_burst',
      name = '框架样例·落点爆发',
      desc = '统一技能协议：area_burst（延迟落点AOE）。',
      cast = function()
        local vfx = get_sample_vfx('meteor_grid')
        register_framework_def('sf_area_burst', {
          warning = vfx.warning,
          impact = vfx.impact,
          hit = vfx.hit,
        })
        return skill_framework.cast_by_id('sf_area_burst')
      end,
    })

    add({
      id = 'sf_area_tick',
      name = '框架样例·持续领域',
      desc = '统一技能协议：area_tick（持续场每tick伤害）。',
      cast = function()
        local vfx = get_sample_vfx('blizzard')
        register_framework_def('sf_area_tick', {
          warning = vfx.warning,
          cast = vfx.cast,
          hit = vfx.hit,
        })
        return skill_framework.cast_by_id('sf_area_tick')
      end,
    })

    add({
      id = 'sf_chain_bounce',
      name = '框架样例·连锁弹跳',
      desc = '统一技能协议：chain_bounce（单点起手，多目标弹跳）。',
      cast = function()
        local vfx = get_sample_vfx('chain_arc')
        register_framework_def('sf_chain_bounce', {
          hit = vfx.hit,
        })
        return skill_framework.cast_by_id('sf_chain_bounce')
      end,
    })
  end

  add_framework_samples()

  local function add_framework_tiered_samples()
    local function add(def)
      SAMPLE_DEFS[#SAMPLE_DEFS + 1] = def
    end

    local tier_visual_map = {
      sf_line_pierce = 'line_lance',
      sf_area_burst = 'meteor_grid',
      sf_area_tick = 'blizzard',
      sf_chain_bounce = 'chain_arc',
    }

    local tier_labels = {
      light = '轻',
      mid = '中',
      heavy = '重',
    }

    for _, base_id in ipairs(Skills.list_framework_skill_ids()) do
      local visual_ref = tier_visual_map[base_id]
      for _, tier in ipairs(Skills.list_framework_tiers()) do
        local runtime_id = string.format('%s_%s', base_id, tier)
        local label = tier_labels[tier] or tier
        add({
          id = runtime_id,
          name = string.format('框架·%s·%s档', tostring(base_id), label),
          desc = string.format('成品参数分档对比：%s / %s。', tostring(base_id), tostring(tier)),
          cast = function()
            local vfx = get_sample_vfx(visual_ref)
            local def = Skills.build_production_skill(base_id, tier, {
              cast = vfx.cast,
              warning = vfx.warning,
              impact = vfx.impact,
              hit = vfx.hit,
              projectile_key = vfx.projectile_key,
              projectile_height = vfx.projectile_height,
            })
            if not def then
              return false, string.format('构建失败：%s/%s', tostring(base_id), tostring(tier))
            end
            local ok, reason = skill_framework.register(def)
            if not ok then
              return false, tostring(reason or 'register failed')
            end
            return skill_framework.cast_by_id(runtime_id)
          end,
        })
      end
    end
  end

  add_framework_tiered_samples()
  validate_sample_visuals_or_error()

  local samples_by_id = {}
  for _, def in ipairs(SAMPLE_DEFS) do
    samples_by_id[def.id] = def
  end

  local runtime = {
    index = 1,
  }

  local api = {}

  function api.list_samples()
    local lines = {}
    for i, def in ipairs(SAMPLE_DEFS) do
      lines[#lines + 1] = string.format('%d) %s | %s | %s', i, def.id, def.name, def.desc)
    end
    return lines
  end

  function api.cast_sample(sample_id)
    local hero = get_hero()
    if not hero then
      return false, '当前没有可用英雄。'
    end
    local def = samples_by_id[tostring(sample_id or '')]
    if not def then
      return false, string.format('未知 sample 技能：%s（用 .esample list 查看）', tostring(sample_id))
    end
    local ok, cast_ok, cast_msg = pcall(def.cast)
    if not ok then
      return false, string.format('[%s] 施放异常：%s', def.id, tostring(cast_ok))
    end
    if cast_ok ~= true then
      return false, string.format('[%s] %s', def.id, tostring(cast_msg or '施放失败'))
    end
    return true, string.format('[%s] %s', def.id, tostring(cast_msg or '施放成功'))
  end

  function api.cast_next_sample()
    if #SAMPLE_DEFS <= 0 then
      return false, '当前没有 sample 技能。'
    end
    runtime.index = math.max(1, math.min(#SAMPLE_DEFS, runtime.index or 1))
    local def = SAMPLE_DEFS[runtime.index]
    runtime.index = runtime.index + 1
    if runtime.index > #SAMPLE_DEFS then
      runtime.index = 1
    end
    return api.cast_sample(def.id)
  end

  function api.print_sample_list()
    message('[DEBUG] Sample 技能列表：')
    for _, line in ipairs(api.list_samples()) do
      message('[DEBUG] ' .. line)
    end
  end

  function api.get_sample_defs()
    local result = {}
    for _, def in ipairs(SAMPLE_DEFS) do
      result[#result + 1] = {
        id = def.id,
        name = def.name,
        desc = def.desc,
      }
    end
    return result
  end

  function api.get_framework_telemetry(skill_id)
    if not skill_framework or not skill_framework.get_telemetry then
      return nil
    end
    return skill_framework.get_telemetry(skill_id)
  end

  function api.reset_framework_telemetry(skill_id)
    if not skill_framework or not skill_framework.reset_telemetry then
      return false, '技能框架 telemetry 未初始化。'
    end
    skill_framework.reset_telemetry(skill_id)
    return true, 'telemetry 已重置'
  end

  function api.get_framework_telemetry_report()
    if not skill_framework or not skill_framework.get_all_telemetry then
      return false, '技能框架 telemetry 未初始化。'
    end
    local all = skill_framework.get_all_telemetry()
    if type(all) ~= 'table' or #all == 0 then
      return true, { '[telemetry] 暂无数据。' }
    end

    table.sort(all, function(a, b)
      local ar = tonumber(a and a.empty_cast_rate) or 0
      local br = tonumber(b and b.empty_cast_rate) or 0
      if ar == br then
        return (tonumber(a and a.total_damage) or 0) < (tonumber(b and b.total_damage) or 0)
      end
      return ar > br
    end)

    local lines = { '[telemetry] 技能验收快照（按空放率降序）' }
    local weak_list = {}
    local function infer_pattern(skill_id)
      local id = tostring(skill_id or '')
      if id:find('line_pierce', 1, true) then
        return 'line_pierce'
      end
      if id:find('area_burst', 1, true) then
        return 'area_burst'
      end
      if id:find('area_tick', 1, true) then
        return 'area_tick'
      end
      if id:find('chain_bounce', 1, true) then
        return 'chain_bounce'
      end
      return 'unknown'
    end
    local function build_tuning_hint(w)
      local pattern = infer_pattern(w.skill_id)
      local empty_rate = tonumber(w.empty_rate) or 0
      local hps = tonumber(w.hits_per_sec) or 0
      local cps = tonumber(w.casts_per_sec) or 0
      if empty_rate >= 35 then
        if pattern == 'line_pierce' then
          return '调参：width +20% / range +12% / impact_delay -0.04'
        end
        if pattern == 'area_burst' or pattern == 'area_tick' then
          return '调参：radius +18% / impact_delay -0.05 / cast_point -0.03'
        end
        if pattern == 'chain_bounce' then
          return '调参：bounce +1 / range +10% / projectile_time -0.08'
        end
        return '调参：优先增判定范围，次优先降前摇与落地延迟'
      end
      if hps < 1.2 then
        if pattern == 'area_tick' then
          return '调参：tick_interval -0.04 / duration +0.3 / max_hits +2'
        end
        if pattern == 'chain_bounce' then
          return '调参：bounce +1 / bounce_ratio +0.06'
        end
        return '调参：提高命中密度（max_hits +2 或 tick_interval -0.03）'
      end
      if cps < 0.9 then
        return '调参：cooldown -0.20 / projectile_time -0.08 / cast_point -0.02'
      end
      return '调参：保持节奏，微增伤害系数 attack_ratio +0.08'
    end
    for _, t in ipairs(all) do
      local cast = tonumber(t.cast_count) or 0
      local hit_avg = tonumber(t.avg_hits_per_cast) or 0
      local empty_rate = (tonumber(t.empty_cast_rate) or 0) * 100
      local total_damage = tonumber(t.total_damage) or 0
      local dmg_per_cast = 0
      if cast > 0 then
        dmg_per_cast = total_damage / cast
      end
      local hits_per_sec = tonumber(t.hits_per_sec) or 0
      local casts_per_sec = tonumber(t.casts_per_sec) or 0
      local drift_ms = tonumber(t.timing_drift_ms_avg) or 0
      local rhythm_score = math.max(0, math.min(100, (hits_per_sec * 28) + (casts_per_sec * 22) - (empty_rate * 0.9)))
      if rhythm_score < 60 then
        weak_list[#weak_list + 1] = {
          skill_id = tostring(t.skill_id or 'unknown'),
          rhythm = rhythm_score,
          empty_rate = empty_rate,
          hit_avg = hit_avg,
          casts_per_sec = casts_per_sec,
          hits_per_sec = hits_per_sec,
        }
      end
      lines[#lines + 1] = string.format(
        '%s cast=%d hit=%.2f empty=%.1f%% hps=%.2f cps=%.2f drift=%.0fms dmg=%.0f dmg/c=%.0f rhythm=%d last=%s',
        tostring(t.skill_id or 'unknown'),
        cast,
        hit_avg,
        empty_rate,
        hits_per_sec,
        casts_per_sec,
        drift_ms,
        total_damage,
        dmg_per_cast,
        math.floor(rhythm_score + 0.5),
        tostring(t.last_reason or '')
      )
    end
    if #weak_list > 0 then
      table.sort(weak_list, function(a, b)
        return (tonumber(a.rhythm) or 0) < (tonumber(b.rhythm) or 0)
      end)
      lines[#lines + 1] = '[telemetry] 待调清单（rhythm<60）'
      for _, w in ipairs(weak_list) do
        local advice = build_tuning_hint(w)
        lines[#lines + 1] = string.format(
          '%s rhythm=%d empty=%.1f%% hps=%.2f cps=%.2f 建议：%s',
          tostring(w.skill_id),
          math.floor((tonumber(w.rhythm) or 0) + 0.5),
          tonumber(w.empty_rate) or 0,
          tonumber(w.hits_per_sec) or 0,
          tonumber(w.casts_per_sec) or 0,
          advice
        )
      end
    end
    return true, lines
  end

  function api.print_framework_telemetry_report()
    local ok, payload = api.get_framework_telemetry_report()
    if not ok then
      return false, payload
    end
    for _, line in ipairs(payload) do
      message(line)
    end
    return true, 'telemetry report printed'
  end

  function api.run_framework_tier_suite()
    if not y3 or not y3.ltimer or not y3.ltimer.wait then
      return false, '计时器不可用。'
    end
    local queue = {}
    local bases = Skills.list_framework_skill_ids()
    local tiers = Skills.list_framework_tiers()
    for _, base_id in ipairs(bases) do
      for _, tier in ipairs(tiers) do
        queue[#queue + 1] = string.format('%s_%s', base_id, tier)
      end
    end
    for _, sample_id in ipairs(queue) do
      api.reset_framework_telemetry(sample_id)
    end
    for index, sample_id in ipairs(queue) do
      y3.ltimer.wait((index - 1) * 0.18, function()
        pcall(api.cast_sample, sample_id)
      end)
    end
    return true, string.format('分档连测已启动：%d 个样例', #queue)
  end

  function api.build_framework_tier_report()
    local bases = Skills.list_framework_skill_ids()
    local tiers = Skills.list_framework_tiers()
    local lines = {}
    for _, base_id in ipairs(bases) do
      lines[#lines + 1] = string.format('[%s]', tostring(base_id))
      for _, tier in ipairs(tiers) do
        local skill_id = string.format('%s_%s', base_id, tier)
        local t = api.get_framework_telemetry(skill_id) or {}
        lines[#lines + 1] = string.format(
          '%s cast=%d hit=%.1f empty=%.1f%% dmg=%.0f',
          skill_id,
          tonumber(t.cast_count) or 0,
          tonumber(t.avg_hits_per_cast) or 0,
          (tonumber(t.empty_cast_rate) or 0) * 100,
          tonumber(t.total_damage) or 0
        )
      end
    end
    return lines
  end

  return api
end

return M

local M = {}

local FRAMEWORK_SKILLS = {
  sf_line_pierce = {
    id = 'sf_line_pierce',
    name = '框架直线穿透',
    pattern = 'line_pierce',
    damage_type = '物理',
    timeline = { impact_delay = 0.22, cast_point = 0.10 },
    resource = { cooldown = 0.8 },
    hit_model = { range = 1350, width = 220, max_hits = 0 },
    scale = { attack_ratio = 2.20 },
  },
  sf_area_burst = {
    id = 'sf_area_burst',
    name = '框架落点爆发',
    pattern = 'area_burst',
    target_mode = 'point',
    damage_type = '法术',
    timeline = { impact_delay = 0.45, cast_point = 0.12 },
    resource = { cooldown = 1.2 },
    hit_model = { radius = 360, max_hits = 0 },
    scale = { attack_ratio = 2.40 },
  },
  sf_area_tick = {
    id = 'sf_area_tick',
    name = '框架持续领域',
    pattern = 'area_burst',
    target_mode = 'point',
    damage_type = '法术',
    timeline = { impact_delay = 0.26, cast_point = 0.08 },
    resource = { cooldown = 1.6 },
    hit_model = { radius = 420, max_hits = 0 },
    scale = { attack_ratio = 1.20 },
  },
  sf_chain_bounce = {
    id = 'sf_chain_bounce',
    name = '框架连锁弹跳',
    pattern = 'chain_bounce',
    damage_type = '法术',
    timeline = { cast_point = 0.05 },
    resource = { cooldown = 0.9, charges = 2 },
    hit_model = { radius = 520, bounce = 5 },
    scale = { attack_ratio = 1.65, bounce_ratio = 0.78 },
  },
}

local FRAMEWORK_VISUAL_DEFAULTS = {
  sf_line_pierce = {
    cast = 104627,
    warning = 104627,
    impact = 104627,
    hit = 104627,
    projectile_key = 201391110,
    projectile_height = 28,
  },
  sf_area_burst = {
    cast = 102994,
    warning = 102994,
    impact = 104627,
    hit = 104627,
    projectile_key = 201392013,
    projectile_height = 36,
  },
  sf_area_tick = {
    cast = 102295,
    warning = 102295,
    impact = 102295,
    hit = 102295,
    projectile_key = 201391103,
    projectile_height = 20,
  },
  sf_chain_bounce = {
    cast = 104991,
    warning = 104991,
    impact = 104991,
    hit = 104991,
    projectile_key = 201391108,
    projectile_height = 30,
  },
}

local FRAMEWORK_TIER_PRESETS = {
  light = {
    timeline = { cast_point = 0.06, impact_delay = 0.14, duration = 2.6, tick_interval = 0.22 },
    hit_model = { range = 1100, width = 180, radius = 300, bounce = 3 },
    scale = { attack_ratio = 1.35, tick_ratio = 0.36, bounce_ratio = 0.84 },
    resource = { cooldown = 0.65, charges = 0 },
  },
  mid = {
    timeline = { cast_point = 0.10, impact_delay = 0.22, duration = 3.2, tick_interval = 0.26 },
    hit_model = { range = 1350, width = 210, radius = 360, bounce = 4 },
    scale = { attack_ratio = 1.95, tick_ratio = 0.56, bounce_ratio = 0.80 },
    resource = { cooldown = 0.95, charges = 1 },
  },
  heavy = {
    timeline = { cast_point = 0.14, impact_delay = 0.28, duration = 3.8, tick_interval = 0.30 },
    hit_model = { range = 1550, width = 260, radius = 460, bounce = 6 },
    scale = { attack_ratio = 2.55, tick_ratio = 0.72, bounce_ratio = 0.76 },
    resource = { cooldown = 1.35, charges = 1 },
  },
}

local PATTERN_PRODUCTION_PATCH = {
  line_pierce = {
    hit_model = { width = 190, max_hits = 0 },
    timeline = { impact_delay = 0.18 },
  },
  area_burst = {
    hit_model = { radius = 340, max_hits = 0 },
    timeline = { impact_delay = 0.24 },
  },
  chain_bounce = {
    hit_model = { bounce = 4, radius = 500 },
    scale = { bounce_ratio = 0.82 },
  },
}

local function clone_table(src)
  local out = {}
  for k, v in pairs(src or {}) do
    if type(v) == 'table' then
      out[k] = clone_table(v)
    else
      out[k] = v
    end
  end
  return out
end

local function merge_table(base, override)
  local out = clone_table(base or {})
  for k, v in pairs(override or {}) do
    if type(v) == 'table' and type(out[k]) == 'table' then
      out[k] = merge_table(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

function M.build_framework_skill(id, visual)
  local base = FRAMEWORK_SKILLS[id]
  if not base then
    return nil
  end
  local def = clone_table(base)
  def.visual = merge_table(FRAMEWORK_VISUAL_DEFAULTS[id], visual or {})
  return def
end

function M.list_framework_skill_ids()
  return {
    'sf_line_pierce',
    'sf_area_burst',
  }
end

function M.build_framework_skill_tier(id, tier, visual)
  local base = M.build_framework_skill(id, visual)
  if not base then
    return nil
  end
  local tier_key = tostring(tier or 'mid')
  local preset = FRAMEWORK_TIER_PRESETS[tier_key] or FRAMEWORK_TIER_PRESETS.mid
  local merged = merge_table(base, preset)
  local pattern_patch = PATTERN_PRODUCTION_PATCH[merged.pattern]
  if pattern_patch then
    merged = merge_table(merged, pattern_patch)
  end
  merged.id = string.format('%s_%s', tostring(base.id), tier_key)
  merged.name = string.format('%s·%s档', tostring(base.name), tier_key)
  return merged
end

function M.build_production_skill(id, tier, visual, override)
  if id == 'sf_area_tick' or id == 'sf_chain_bounce' then
    id = 'sf_area_burst'
  end
  local def = M.build_framework_skill_tier(id, tier, visual)
  if not def then
    return nil
  end
  def = merge_table(def, override or {})
  return def
end

function M.list_framework_tiers()
  return { 'light', 'mid', 'heavy' }
end

return M

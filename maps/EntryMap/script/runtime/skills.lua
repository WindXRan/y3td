local M = {}

-- ===== 元素→VFX 自动映射 =====
-- 根据元素主题自动选择投射物库ID和粒子特效ID。
-- 投射物来自 projectile_library (2013920xx)，粒子来自已验证的 production_v2 粒子集。
-- 注：同事的 skill_visuals.csv 按羁绊名映射，本表按元素名映射，两者互补。
local ELEMENT_VFX = {
  fire = {
    projectile_key = 201392012,   -- lib_fire_mid (speed=1500)
    projectile_time = 0.92,
    projectile_height = 32,
    cast = 104727,
    warning = 104727,
    impact = 103953,
    hit = 103953,
  },
  lightning = {
    projectile_key = 201392043,   -- lib_lightning_heavy (speed=1250)
    projectile_time = 0.82,
    projectile_height = 28,
    cast = 106074,
    warning = 106074,
    impact = 106112,
    hit = 106074,
  },
  ice = {
    projectile_key = 201392022,   -- lib_shadow_mid (speed=1480)
    projectile_time = 0.95,
    projectile_height = 22,
    cast = 106070,
    warning = 106067,
    impact = 106067,
    hit = 106070,
  },
  arcane = {
    projectile_key = 201392032,   -- lib_arcane_mid (speed=1520)
    projectile_time = 0.88,
    projectile_height = 26,
    cast = 106065,
    warning = 106065,
    impact = 106065,
    hit = 106065,
  },
  physical = {
    projectile_key = 201392002,   -- lib_phys_mid (speed=1600)
    projectile_time = 0.90,
    projectile_height = 20,
    cast = 106060,
    warning = 106060,
    impact = 106069,
    hit = 106060,
  },
  shadow = {
    projectile_key = 201392022,   -- lib_shadow_mid (speed=1480)
    projectile_time = 0.95,
    projectile_height = 24,
    cast = 106056,
    warning = 106107,
    impact = 106107,
    hit = 106056,
  },
  wind = {
    projectile_key = 134263445,   -- 龙卷风投射物
    projectile_time = 0.90,
    projectile_height = 28,
    cast = 100771,
    warning = 100771,
    impact = 100771,
    hit = 100771,
  },
}

-- pattern → framework base_skill_id 的映射
local PATTERN_TO_BASE = {
  projectile = 'sf_projectile',
  area = 'sf_area',
  line_pierce = 'sf_projectile',
  area_burst = 'sf_area',
  area_tick = 'sf_area',
  chain_bounce = 'sf_projectile',
}

local PATTERN_SUB_BEHAVIOR = {
  line_pierce = { pattern = 'projectile', sub_behavior = 'pierce' },
  chain_bounce = { pattern = 'projectile', sub_behavior = 'chain' },
  area_burst = { pattern = 'area', sub_behavior = 'burst' },
  area_tick = { pattern = 'area', sub_behavior = 'tick' },
}

local BASE_SKILL_ALIAS = {
  sf_line_pierce = 'sf_projectile',
  sf_chain_bounce = 'sf_projectile',
  sf_area_burst = 'sf_area',
  sf_area_tick = 'sf_area',
}

local BASE_SKILL_ALIAS_PATCH = {
  sf_line_pierce = { name = '框架直线穿透', sub_behavior = 'pierce', damage_type = '物理' },
  sf_chain_bounce = { name = '框架连锁弹跳', sub_behavior = 'chain' },
  sf_area_burst = { name = '框架落点爆发', sub_behavior = 'burst' },
  sf_area_tick = { name = '框架持续领域', sub_behavior = 'tick', scale = { tick_ratio = 0.58 } },
}

local FRAMEWORK_SKILLS = {
  sf_projectile = {
    id = 'sf_projectile',
    name = '框架弹道飞行',
    pattern = 'projectile',
    sub_behavior = 'base',
    damage_type = '法术',
    timeline = { impact_delay = 0.22, cast_point = 0.10 },
    resource = { cooldown = 0.8 },
    hit_model = { range = 1350, width = 220, max_hits = 0 },
    scale = { attack_ratio = 2.20 },
  },
  sf_area = {
    id = 'sf_area',
    name = '框架产生区域',
    pattern = 'area',
    sub_behavior = 'burst',
    target_mode = 'point',
    damage_type = '法术',
    timeline = { impact_delay = 0.45, cast_point = 0.12 },
    resource = { cooldown = 1.2 },
    hit_model = { radius = 360, max_hits = 0 },
    scale = { attack_ratio = 2.40 },
  },
}

local FRAMEWORK_VISUAL_DEFAULTS = {
  sf_projectile = {
    cast = 104627,
    warning = 104627,
    impact = 104627,
    hit = 104627,
    projectile_key = 201391110,
    projectile_height = 28,
  },
  sf_area = {
    cast = 102994,
    warning = 102994,
    impact = 104627,
    hit = 104627,
    projectile_height = 36,
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
  projectile = {
    hit_model = { width = 190, max_hits = 0 },
    timeline = { impact_delay = 0.18 },
  },
  area = {
    hit_model = { radius = 340, max_hits = 0 },
    timeline = { impact_delay = 0.24 },
  },
}

-- 统一 pattern → target_mode 映射，供 sample_skills 等复用
M.PATTERN_TARGET_MODE = {
  projectile = 'unit',
  area = 'point',
  line_pierce = 'unit',
  area_burst = 'point',
  area_tick = 'point',
  chain_bounce = 'unit',
}

-- 扁平 overrides 到嵌套结构的映射表
local FLAT_TO_NESTED = {
  cooldown = { 'resource', 'cooldown' },
  charges = { 'resource', 'charges' },
  attack_ratio = { 'scale', 'attack_ratio' },
  splash_ratio = { 'scale', 'splash_ratio' },
  tick_ratio = { 'scale', 'tick_ratio' },
  bounce_ratio = { 'scale', 'bounce_ratio' },
  radius = { 'hit_model', 'radius' },
  range = { 'hit_model', 'range' },
  width = { 'hit_model', 'width' },
  bounce = { 'hit_model', 'bounce' },
  max_hits = { 'hit_model', 'max_hits' },
  duration = { 'timeline', 'duration' },
  tick_interval = { 'timeline', 'tick_interval' },
  cast_point = { 'timeline', 'cast_point' },
  impact_delay = { 'timeline', 'impact_delay' },
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

local function normalize_flat_overrides(overrides)
  local out = clone_table(overrides or {})
  for flat_key, nested_path in pairs(FLAT_TO_NESTED) do
    local value = out[flat_key]
    if value ~= nil then
      local parent_key = nested_path[1]
      local child_key = nested_path[2]
      out[parent_key] = out[parent_key] or {}
      out[parent_key][child_key] = value
      out[flat_key] = nil
    end
  end
  return out
end

function M.build_framework_skill(id, visual)
  local requested_id = tostring(id or '')
  local base_id = BASE_SKILL_ALIAS[requested_id] or requested_id
  local base = FRAMEWORK_SKILLS[base_id]
  if not base then
    return nil
  end
  local def = clone_table(base)
  local alias_patch = BASE_SKILL_ALIAS_PATCH[requested_id]
  if alias_patch then
    def = merge_table(def, alias_patch)
    def.id = requested_id
  end
  def.visual = merge_table(FRAMEWORK_VISUAL_DEFAULTS[requested_id] or FRAMEWORK_VISUAL_DEFAULTS[base_id], visual or {})
  return def
end

function M.list_framework_skill_ids()
  return {
    'sf_projectile',
    'sf_area',
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

--- 根据元素+pattern+档位一键构造完整技能定义
function M.build_element_skill(element, pattern, tier, overrides)
  local legacy = PATTERN_SUB_BEHAVIOR[pattern]
  local normalized_pattern = legacy and legacy.pattern or pattern
  local base_id = PATTERN_TO_BASE[pattern] or PATTERN_TO_BASE[normalized_pattern]
  if not base_id then
    return nil
  end
  local vfx = ELEMENT_VFX[element]
  if not vfx then
    vfx = ELEMENT_VFX.physical
  end
  local patched_overrides = normalize_flat_overrides(overrides or {})
  patched_overrides.pattern = normalized_pattern
  if not patched_overrides.sub_behavior or patched_overrides.sub_behavior == '' then
    patched_overrides.sub_behavior = legacy and legacy.sub_behavior or (normalized_pattern == 'area' and 'burst' or 'base')
  end
  local def = M.build_production_skill(base_id, tier, vfx, patched_overrides)
  if def and overrides and overrides.id then
    def.id = overrides.id
  end
  if def and overrides and overrides.name then
    def.name = overrides.name
  end
  return def
end

function M.list_elements()
  local result = {}
  for k, _ in pairs(ELEMENT_VFX) do
    result[#result + 1] = k
  end
  table.sort(result)
  return result
end

function M.get_element_vfx(element)
  return ELEMENT_VFX[element]
end

-- ===== 共享映射表导出 =====
-- 供 sample_skills / generated_skills 等模块复用，避免多处维护映射
M.PATTERN_TO_BASE = PATTERN_TO_BASE
M.PATTERN_SUB_BEHAVIOR = PATTERN_SUB_BEHAVIOR

-- ===== 同事兼容接口 =====
-- 框架技能系统迁移中。以下别名供历史调用兼容，底层复用上述构建链路。
function M.build_unique_skill(id, visual)
  return M.build_framework_skill(id, visual)
end

function M.list_unique_skill_ids()
  return M.list_framework_skill_ids()
end

function M.build_unique_skill_variant(id, tier, visual)
  return M.build_framework_skill_tier(id, tier, visual)
end

function M.list_unique_tiers()
  return M.list_framework_tiers()
end

return M

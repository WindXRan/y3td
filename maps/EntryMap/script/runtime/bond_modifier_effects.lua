local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'
local BondModifierPool = require 'data.object_tables.bond_modifier_pool'
local BondVisualEditorIds = require 'data.object_tables.bond_visual_editor_ids'
local BondEffectRuntimeRules = require 'data.object_tables.bond_effect_runtime_rules'
local AttackSkillObjects = require 'data.object_tables.attack_skills'
local BondModifierSpecialEffectsFactory = require 'runtime.bond_modifier_special_effects'
local BondModifierCoreEffectsFactory = require 'runtime.bond_modifier_core_effects'
local SkillDamageTemplates = require 'runtime.skill_damage_templates'

local M = {}
local FORCE_SPECIAL_EFFECTS_100 = false
local DEFAULT_LINE_MOTION_ANGLE_OFFSET = 0
local TWO_PI = math.pi * 2

local function angle_to_radian(angle)
  local value = tonumber(angle) or 0
  if math.abs(value) > (TWO_PI + 0.001) then
    return math.rad(value)
  end
  return value
end
-- 全局视觉缩放：用于快速抑制羁绊特效光污染与闪屏。
local GLOBAL_PARTICLE_SCALE_MULTIPLIER = 0.90
local GLOBAL_AREA_SCALE_MULTIPLIER = 0.95
local get_hero_attr
local get_attack_value
local get_max_hp_value

-- 热更早期兜底：旧闭包可能在本文件完成加载前按全局名调用。
if type(_G.get_hero) ~= 'function' then
  _G.get_hero = function(env)
    local hero = env and env.STATE and env.STATE.hero
    if hero and hero.is_exist and hero:is_exist() then
      return hero
    end
    return nil
  end
end
if type(_G.get_hero_attr) ~= 'function' then
  _G.get_hero_attr = function(env, name)
    local hero = env and env.STATE and env.STATE.hero
    if not hero or not hero.is_exist or not hero:is_exist() then
      return 0
    end
    local hero_attr_system = env and env.hero_attr_system
    if hero_attr_system and hero_attr_system.get_attr then
      return tonumber(hero_attr_system.get_attr(hero, name)) or 0
    end
    return tonumber(hero:get_attr(name)) or 0
  end
end

local BOND_NAME_ALIASES = {
  ['冰法'] = '冰霜法师',
  ['冰法师'] = '冰霜法师',
  ['冰霜法'] = '冰霜法师',
  ['寒冰法师'] = '冰霜法师',
  ['寒冰法'] = '冰霜法师',
  ['寒冰法师 '] = '冰霜法师',
  [' 寒冰法师'] = '冰霜法师',
  ['电法'] = '雷电法王',
  ['雷法'] = '雷电法王',
}

-- 激活后直接生效的静态属性加成（按羁绊名）
M.SET_ATTR_BONUSES = {
  ['刀锋战士'] = { ['攻击增幅'] = 0.50 },
  ['全能骑士'] = {
    ['攻击增幅'] = 0.10,
    ['生命增幅'] = 0.10,
    ['护甲增幅'] = 0.10,
  },
  ['骷髅法师'] = { ['攻击增幅'] = 0.15 },
}

-- 激活后生效的运行时加成（按羁绊名）
M.SET_RUNTIME_BONUSES = {
}

-- 统一视觉层配置：
-- 1) particle_key 鐢ㄤ簬鍛戒腑鐗规晥
-- 2) projectile_key 鐢ㄤ簬寮归亾
-- 若某羁绊未配置，则走默认配置。
local ATTACK_SKILL_VFX = AttackSkillObjects.vfx_by_id or {}

local function to_positive_number(value)
  value = tonumber(value)
  if value and value > 0 then
    return value
  end
  return nil
end

local function pick_particle_from_vfx(vfx)
  if type(vfx) ~= 'table' then
    return nil
  end
  return to_positive_number(vfx.impact_particle)
    or to_positive_number(vfx.explosion_particle)
    or to_positive_number(vfx.cast_particle)
    or to_positive_number(vfx.chain_particle)
    or to_positive_number(vfx.charge_particle)
end

local BASIC_ATTACK_VFX = ATTACK_SKILL_VFX.basic_attack or {}
local BASIC_PARTICLE_KEY = pick_particle_from_vfx(BASIC_ATTACK_VFX)
local BASIC_PROJECTILE_KEY = to_positive_number(BASIC_ATTACK_VFX.projectile_key)
  or RuntimeEditorIds.projectile and RuntimeEditorIds.projectile.basic_attack
  or nil
local DEFAULT_VISUAL = {
  -- 对齐 06-技能：统一采用“投射物 + 命中特效”标准流。
  particle_key = BASIC_PARTICLE_KEY or BondVisualEditorIds.default_particle_key or 101175,
  projectile_key = BASIC_PROJECTILE_KEY or 201392033,
  projectile_speed = 800,
  projectile_time = 1.0,
  projectile_height = 0,
  projectile_target_distance = 0,
}
local VISUAL_FORCE_BY_BOND = {}
for bond_name, visual_entry in pairs(BondVisualEditorIds.visual_by_bond or {}) do
  if type(visual_entry) == 'table' then
    VISUAL_FORCE_BY_BOND[bond_name] = {
      projectile_key = to_positive_number(visual_entry.projectile_key),
      particle_key = to_positive_number(visual_entry.particle_key),
      projectile_speed = tonumber(visual_entry.projectile_speed),
      projectile_time = tonumber(visual_entry.projectile_time),
      projectile_target_distance = tonumber(visual_entry.target_distance),
      projectile_line_distance = tonumber(visual_entry.projectile_line_distance),
      projectile_angle_offset = tonumber(visual_entry.projectile_angle_offset),
      projectile_motion_angle_offset = tonumber(visual_entry.projectile_motion_angle_offset),
      area_fx_base_radius = tonumber(visual_entry.area_fx_base_radius),
      area_fx_scale_bias = tonumber(visual_entry.area_fx_scale_bias),
      particle_scale_bias = tonumber(visual_entry.particle_scale_bias),
      delivery_mode = visual_entry.delivery_mode,
      motion_mode = visual_entry.motion_mode,
    }
  end
end

-- 不再在运行时硬覆盖单个羁绊视觉参数，统一以 bond_visual_editor_ids.lua 为唯一来源，
-- 避免“视觉配置与伤害规则调参不同步”。

local function build_bond_visual(opts)
  opts = opts or {}
  local area_fx_base_radius = math.max(80, tonumber(opts.area_fx_base_radius) or 360)
  local area_fx_scale_bias = (tonumber(opts.area_fx_scale_bias) or 1.0) * GLOBAL_AREA_SCALE_MULTIPLIER
  return {
    particle_key = to_positive_number(opts.particle_key) or DEFAULT_VISUAL.particle_key,
    line_particle_key = to_positive_number(opts.line_particle_key) or nil,
    projectile_key = to_positive_number(opts.projectile_key) or DEFAULT_VISUAL.projectile_key,
    projectile_speed = tonumber(opts.projectile_speed) or DEFAULT_VISUAL.projectile_speed,
    projectile_time = tonumber(opts.projectile_time) or DEFAULT_VISUAL.projectile_time,
    projectile_height = tonumber(opts.projectile_height) or DEFAULT_VISUAL.projectile_height,
    projectile_target_distance = tonumber(opts.projectile_target_distance) or DEFAULT_VISUAL.projectile_target_distance,
    projectile_line_distance = tonumber(opts.projectile_line_distance) or nil,
    projectile_angle_offset = tonumber(opts.projectile_angle_offset) or 0,
    projectile_motion_angle_offset = tonumber(opts.projectile_motion_angle_offset),
    area_fx_base_radius = area_fx_base_radius,
    area_fx_scale_bias = area_fx_scale_bias,
    particle_scale_bias = tonumber(opts.particle_scale_bias) or 1.0,
    delivery_mode = tostring(opts.delivery_mode or 'projectile'),
    motion_mode = tostring(opts.motion_mode or 'target'),
  }
end

-- 按羁绊自动生成视觉配置：避免手写 ID 漂移导致表现不一致。
local function normalize_bond_name(bond_name)
  local key = tostring(bond_name or ''):gsub('^%s+', ''):gsub('%s+$', '')
  key = key:gsub('　', '')
  if key == '' then
    return key
  end
  return BOND_NAME_ALIASES[key] or key
end

local BOND_VISUALS = {}
for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
  local bond_name = normalize_bond_name(effect and effect.bond_name or '')
  if bond_name ~= '' then
    local visual_entry = BondVisualEditorIds.visual_by_bond and BondVisualEditorIds.visual_by_bond[bond_name] or nil
    local dedicated_projectile_key = visual_entry and visual_entry.projectile_key or nil
    local dedicated_particle_key = visual_entry and visual_entry.particle_key or nil
    BOND_VISUALS[bond_name] = build_bond_visual({
      particle_key = dedicated_particle_key or DEFAULT_VISUAL.particle_key,
      line_particle_key = dedicated_particle_key or DEFAULT_VISUAL.particle_key,
      projectile_key = dedicated_projectile_key or DEFAULT_VISUAL.projectile_key,
      projectile_speed = visual_entry and visual_entry.projectile_speed or DEFAULT_VISUAL.projectile_speed,
      projectile_time = visual_entry and visual_entry.projectile_time or DEFAULT_VISUAL.projectile_time,
      projectile_height = DEFAULT_VISUAL.projectile_height,
      projectile_target_distance = visual_entry and visual_entry.target_distance or DEFAULT_VISUAL.projectile_target_distance,
      area_fx_base_radius = visual_entry and visual_entry.area_fx_base_radius or nil,
      area_fx_scale_bias = visual_entry and visual_entry.area_fx_scale_bias or nil,
      particle_scale_bias = visual_entry and visual_entry.particle_scale_bias or nil,
      delivery_mode = visual_entry and visual_entry.delivery_mode or nil,
      motion_mode = visual_entry and visual_entry.motion_mode or nil,
    })
  end
end

local VISUAL_OVERRIDES = {}

-- 历史命名兼容（别名映射到标准名）
for alias, canonical in pairs(BOND_NAME_ALIASES) do
  if BOND_VISUALS[canonical] and not BOND_VISUALS[alias] then
    BOND_VISUALS[alias] = build_bond_visual(BOND_VISUALS[canonical])
  end
end

local PROJECTILE_EDITOR_PATHS = {
  'maps/EntryMap/editor_table/projectileall/%d.json',
  'editor_table/projectileall/%d.json',
  '../editor_table/projectileall/%d.json',
}

local PROJECTILE_EXIST_CACHE = {}

local function projectile_editor_exists(projectile_key)
  projectile_key = to_positive_number(projectile_key)
  if not projectile_key then
    return false
  end
  if PROJECTILE_EXIST_CACHE[projectile_key] ~= nil then
    return PROJECTILE_EXIST_CACHE[projectile_key] == true
  end

  for _, pattern in ipairs(PROJECTILE_EDITOR_PATHS) do
    local path = string.format(pattern, projectile_key)
    local handle = io.open(path, 'r')
    if handle then
      handle:close()
      PROJECTILE_EXIST_CACHE[projectile_key] = true
      return true
    end
  end
  PROJECTILE_EXIST_CACHE[projectile_key] = false
  return false
end

for bond_name, visual in pairs(BOND_VISUALS) do
  if type(visual) == 'table' then
    local projectile_key = to_positive_number(visual.projectile_key)
    if projectile_key and not projectile_editor_exists(projectile_key) then
      visual.projectile_key = projectile_editor_exists(BASIC_PROJECTILE_KEY) and BASIC_PROJECTILE_KEY or nil
    end
    if not to_positive_number(visual.particle_key) then
      visual.particle_key = DEFAULT_VISUAL.particle_key
    end
  end
end

local PARTICLE_SCALE_CFG_BY_KEY = {}
for _, visual in pairs(BOND_VISUALS) do
  if type(visual) == 'table' then
    local particle_key = to_positive_number(visual.particle_key)
    if particle_key then
      PARTICLE_SCALE_CFG_BY_KEY[particle_key] = {
        particle_scale_bias = tonumber(visual.particle_scale_bias) or 1.0,
      }
    end
  end
end

-- 读取羁绊专属投射物物编后的基准尺寸（effect_foes.items[4]）得到的反向归一系数。
-- 第一阶段：先把不同资源拉回统一基准视觉尺寸。
local PARTICLE_BASELINE_NORM_BY_KEY = {
  [106056] = 1 / 1.08,
  [106060] = 1 / 0.98,
  [106065] = 1 / 1.12,
  [106067] = 1 / 1.10,
  [106069] = 1 / 0.96,
  [106074] = 1 / 1.20,
  [106081] = 1 / 1.18,
  [106082] = 1 / 1.00,
  [106088] = 1 / 1.00,
  [106089] = 1 / 1.42,
  [106090] = 1 / 0.98,
  [106092] = 1 / 1.00,
  [106107] = 1 / 1.00,
  [106109] = 1 / 1.00,
  [106112] = 1 / 1.16,
}

local PARTICLE_BASELINE_NORM_BY_PROJECTILE = {
  [201391101] = 1 / 1.00,
  [201391102] = 1 / 1.00,
  [201391103] = 1 / 1.10,
  [201391104] = 1 / 1.00,
  [201391105] = 1 / 1.00,
  [201391106] = 1 / 1.08,
  [201391107] = 1 / 1.18,
  [201391108] = 1 / 1.20,
  [201391109] = 1 / 0.96,
  [201391110] = 1 / 1.42,
  [201391111] = 1 / 1.00,
  [201391112] = 1 / 1.16,
  [201391113] = 1 / 1.00,
  [201391114] = 1 / 0.98,
  [201391115] = 1 / 0.98,
  [201391116] = 1 / 1.12,
}

-- 关闭自动弹道去重：严格使用每个羁绊显式配置，避免运行时“被替换”为其他弹道。

-- 鍘熸枃娉ㄩ噴鍖猴細
-- 1) ACTIVATION_TEXT_BY_BOND锛氱緛缁娾€滄縺娲绘晥鏋溾€濆師鏂囷紙鎸夌緛缁婅仛鍚堬級
-- 2) SPECIAL_TEXT_BY_CARD锛氬崟鍗♀€滅壒娈婃晥鏋溾€濆師鏂囷紙鎸夊崱鍚嶇储寮曪級
local ACTIVATION_TEXT_BY_BOND = {}
local ACTIVATION_TEXT_LIST = {}
local SPECIAL_TEXT_BY_CARD = {}
local SPECIAL_TEXT_LIST = {}
local SUSPECTED_SPECIAL_ROWS = {}
do
  for index, effect in ipairs(BondModifierPool.activation_effects or {}) do
    if effect.bond_name and effect.desc and effect.desc ~= '' then
      ACTIVATION_TEXT_BY_BOND[effect.bond_name] = effect.desc
      ACTIVATION_TEXT_LIST[#ACTIVATION_TEXT_LIST + 1] = {
        index = index,
        bond_name = effect.bond_name,
        activation_text = effect.desc,
      }
    end
  end
  for _, card in ipairs(BondModifierPool.cards or {}) do
    if card and card.name then
      local special_text = card.extra_skill_desc or ''
      local activation_text = card.activation_desc or ACTIVATION_TEXT_BY_BOND[card.bond_name] or ''
      if special_text ~= '' and special_text ~= '无' then
        SPECIAL_TEXT_BY_CARD[card.name] = special_text
        local row = {
          card_id = card.id,
          card_name = card.name,
          bond_name = card.bond_name,
          special_text = special_text,
          activation_text = activation_text,
          suspected_same_as_activation = activation_text ~= '' and special_text == activation_text or false,
        }
        SPECIAL_TEXT_LIST[#SPECIAL_TEXT_LIST + 1] = row
        if row.suspected_same_as_activation then
          SUSPECTED_SPECIAL_ROWS[#SUSPECTED_SPECIAL_ROWS + 1] = row
        end
      end
    end
  end
end

function M.get_original_effect_docs()
  return {
    activation_text_by_bond = ACTIVATION_TEXT_BY_BOND,
    activation_text_list = ACTIVATION_TEXT_LIST,
    special_text_by_card = SPECIAL_TEXT_BY_CARD,
    special_text_list = SPECIAL_TEXT_LIST,
    suspected_special_rows = SUSPECTED_SPECIAL_ROWS,
    runtime_rules = BondEffectRuntimeRules,
  }
end

local function is_visual_hidden(env)
  local state = env and env.STATE
  return state and state.ui_preferences and state.ui_preferences.hide_hit_effects == true or false
end

local function get_visual_config(bond_name)
  local canonical_bond_name = normalize_bond_name(bond_name)
  local base = BOND_VISUALS[canonical_bond_name] or BOND_VISUALS[bond_name] or {}
  local override = VISUAL_OVERRIDES[canonical_bond_name] or VISUAL_OVERRIDES[bond_name]
  local extra = base
  if override then
    extra = {
      particle_key = override.particle_key or base.particle_key,
      line_particle_key = override.line_particle_key or base.line_particle_key,
      projectile_key = override.projectile_key or base.projectile_key,
      projectile_speed = override.projectile_speed or base.projectile_speed,
      projectile_time = override.projectile_time or base.projectile_time,
      projectile_height = override.projectile_height or base.projectile_height,
      projectile_target_distance = override.projectile_target_distance or base.projectile_target_distance,
      projectile_line_distance = override.projectile_line_distance or base.projectile_line_distance,
      projectile_angle_offset = override.projectile_angle_offset or base.projectile_angle_offset,
      projectile_motion_angle_offset = override.projectile_motion_angle_offset or base.projectile_motion_angle_offset,
      area_fx_base_radius = override.area_fx_base_radius or base.area_fx_base_radius,
      area_fx_scale_bias = override.area_fx_scale_bias or base.area_fx_scale_bias,
      particle_scale_bias = override.particle_scale_bias or base.particle_scale_bias,
      delivery_mode = override.delivery_mode or base.delivery_mode,
      motion_mode = override.motion_mode or base.motion_mode,
    }
  end
  local forced = VISUAL_FORCE_BY_BOND[canonical_bond_name] or VISUAL_FORCE_BY_BOND[bond_name]
  if forced then
    extra = {
      particle_key = forced.particle_key or extra.particle_key,
      line_particle_key = forced.particle_key or extra.line_particle_key,
      projectile_key = forced.projectile_key or extra.projectile_key,
      projectile_speed = forced.projectile_speed or extra.projectile_speed,
      projectile_time = forced.projectile_time or extra.projectile_time,
      projectile_height = extra.projectile_height,
      projectile_target_distance = forced.projectile_target_distance or extra.projectile_target_distance,
      projectile_line_distance = forced.projectile_line_distance or extra.projectile_line_distance,
      projectile_angle_offset = forced.projectile_angle_offset or extra.projectile_angle_offset,
      projectile_motion_angle_offset = forced.projectile_motion_angle_offset or extra.projectile_motion_angle_offset,
      area_fx_base_radius = forced.area_fx_base_radius or extra.area_fx_base_radius,
      area_fx_scale_bias = forced.area_fx_scale_bias or extra.area_fx_scale_bias,
      particle_scale_bias = forced.particle_scale_bias or extra.particle_scale_bias,
      delivery_mode = forced.delivery_mode or extra.delivery_mode,
      motion_mode = forced.motion_mode or extra.motion_mode,
    }
  end
  local projectile_key = to_positive_number(extra.projectile_key)
    or DEFAULT_VISUAL.projectile_key
  local particle_key = to_positive_number(extra.particle_key)
    or DEFAULT_VISUAL.particle_key
  return {
    particle_key = particle_key,
    line_particle_key = to_positive_number(extra.line_particle_key) or particle_key,
    projectile_key = projectile_key,
    projectile_speed = extra.projectile_speed or DEFAULT_VISUAL.projectile_speed,
    projectile_time = extra.projectile_time or DEFAULT_VISUAL.projectile_time,
    projectile_height = extra.projectile_height or DEFAULT_VISUAL.projectile_height,
    projectile_target_distance = extra.projectile_target_distance or DEFAULT_VISUAL.projectile_target_distance,
    projectile_line_distance = tonumber(extra.projectile_line_distance) or nil,
    projectile_angle_offset = tonumber(extra.projectile_angle_offset) or 0,
    projectile_motion_angle_offset = tonumber(extra.projectile_motion_angle_offset),
    area_fx_base_radius = math.max(80, tonumber(extra.area_fx_base_radius) or 320),
    area_fx_scale_bias = tonumber(extra.area_fx_scale_bias) or 1.0,
    particle_scale_bias = tonumber(extra.particle_scale_bias) or 1.0,
    delivery_mode = tostring(extra.delivery_mode or 'projectile'),
    motion_mode = tostring(extra.motion_mode or 'target'),
  }
end

local function apply_particle_scale(visual_cfg, effect_key, scale)
  local base_scale = tonumber(scale) or 1.0
  local baseline_norm = 1.0
  -- 第二阶段：按伤害范围（以 area_fx_base_radius 作为范围代理）做轻量二次缩放。
  local radius = math.max(80, tonumber(visual_cfg and visual_cfg.area_fx_base_radius) or 220)
  local range_factor = math.max(0.97, math.min(1.03, (radius / 220) ^ 0.18))
  local final_scale = base_scale * baseline_norm * range_factor
  return final_scale
end

local function resolve_particle_scale_cfg(effect_key, fallback_cfg)
  local key = to_positive_number(effect_key)
  if key and PARTICLE_SCALE_CFG_BY_KEY[key] then
    return PARTICLE_SCALE_CFG_BY_KEY[key]
  end
  return fallback_cfg
end

local function get_fx_time_now(env)
  local y3 = env and env.y3
  if y3 and y3.game and y3.game.current_game_run_time then
    return tonumber(y3.game.current_game_run_time()) or 0
  end
  return 0
end

local function build_unit_fx_anchor_key(unit)
  if not unit then
    return 'unit:nil'
  end
  local uid = nil
  if unit.get_id then
    local ok, id = pcall(unit.get_id, unit)
    if ok then
      uid = id
    end
  end
  if uid == nil and unit.id then
    uid = unit.id
  end
  return 'unit:' .. tostring(uid or unit)
end

local function build_point_fx_anchor_key(point)
  if not point then
    return 'point:nil'
  end
  local x = point.get_x and tonumber(point:get_x()) or 0
  local y = point.get_y and tonumber(point:get_y()) or 0
  -- 量化到 60 网格，避免极小抖动导致去重失效。
  local qx = math.floor(x / 60 + 0.5)
  local qy = math.floor(y / 60 + 0.5)
  return string.format('point:%d:%d', qx, qy)
end

local function should_emit_particle(env, effect_key, anchor_key, life_time)
  local state = env and env.STATE
  if not state then
    return true
  end
  -- 个别技能可通过此标记放行高频特效（用后即焚）。
  if state.__bond_fx_allow_spam_once == true then
    state.__bond_fx_allow_spam_once = nil
    return true
  end
  local now = get_fx_time_now(env)
  state.__bond_fx_emit_cache = state.__bond_fx_emit_cache or {}
  local cache = state.__bond_fx_emit_cache
  local k = string.format('%s|%s', tostring(effect_key), tostring(anchor_key))
  local prev = tonumber(cache[k]) or -999
  local t = tonumber(life_time) or 0.20
  -- 高频短效命中特效才节流，长时/常驻类不拦截。
  local cooldown = t <= 0.35 and math.max(0.08, math.min(0.20, t * 0.75)) or 0.05
  if now - prev < cooldown then
    return false
  end
  cache[k] = now
  return true
end

local function play_particle_on_unit(env, unit, effect_key, scale, time)
  if is_visual_hidden(env) or not effect_key or not unit or not unit.is_exist or not unit:is_exist() then
    return nil
  end
  local y3 = env and env.y3
  if not y3 or not y3.projectile or not y3.projectile.create then
    return nil
  end
  if not should_emit_particle(env, effect_key, build_unit_fx_anchor_key(unit), time) then
    return nil
  end
  local state = env and env.STATE
  local forced = tonumber(state and state.debug_force_projectile_key) or 0
  local key = forced > 0 and math.floor(forced) or 201392033
  local ok, particle = pcall(y3.projectile.create, {
    key = key,
    target = unit,
    socket = 'origin',
    owner = state and state.hero or nil,
    angle = 0,
    time = time or 0.30,
    remove_immediately = true,
  })
  if ok and particle then
    return particle
  end
  return nil
end

local function play_particle_on_point(env, point, effect_key, scale, time, height)
  if is_visual_hidden(env) or not effect_key or not point then
    return nil
  end
  local y3 = env and env.y3
  if not y3 or not y3.projectile or not y3.projectile.create then
    return nil
  end
  if not should_emit_particle(env, effect_key, build_point_fx_anchor_key(point), time) then
    return nil
  end
  local state = env and env.STATE
  local forced = tonumber(state and state.debug_force_projectile_key) or 0
  local key = forced > 0 and math.floor(forced) or 201392033
  local ok, particle = pcall(y3.projectile.create, {
    key = key,
    target = point,
    socket = 'origin',
    owner = state and state.hero or nil,
    angle = 0,
    time = time or 0.30,
    remove_immediately = true,
  })
  if ok and particle then
    return particle
  end
  return nil
end

local function play_bond_sound(env, bond_name, stage, anchor)
  -- 已按需求禁用羁绊音频调用链（audio.lua 相关）。
  local state = env and env.STATE
  if state and state.bond_debug_trace_enabled == true and env and env.message then
    env.message(string.format('[bond_audio_trace] disabled bond=%s stage=%s', tostring(bond_name), tostring(stage)))
  end
  return nil
end

local function resolve_projectile_key(state, projectile_key)
  local forced = tonumber(state and state.debug_force_projectile_key) or 0
  if forced > 0 then
    return forced
  end
  return projectile_key
end

local function launch_projectile_to_target(env, target, visual_cfg)
  local state = env and env.STATE
  local hero = state and state.hero
  local y3 = env and env.y3
  if not hero or not hero.is_exist or not hero:is_exist() then
    return false
  end
  if not target or not target.is_exist or not target:is_exist() then
    return false
  end
  if not y3 or not y3.projectile or not y3.projectile.create then
    return false
  end
  if not visual_cfg.projectile_key then
    return false
  end

  local launch_angle = nil
  local fallback_facing = 0
  pcall(function()
    if hero.get_facing then
      fallback_facing = tonumber(hero:get_facing()) or 0
    end
  end)
  local target_distance_now = nil
  local hero_point = nil
  local target_point = nil
  pcall(function()
    if hero.get_point then
      hero_point = hero:get_point()
    end
  end)
  pcall(function()
    if target.get_point then
      target_point = target:get_point()
    end
  end)
  if hero_point and target_point then
    if hero_point.get_angle_with then
      pcall(function()
        launch_angle = hero_point:get_angle_with(target_point)
      end)
    end
    local hx = hero_point.get_x and hero_point:get_x() or nil
    local hy = hero_point.get_y and hero_point:get_y() or nil
    local tx = target_point.get_x and target_point:get_x() or nil
    local ty = target_point.get_y and target_point:get_y() or nil
    if hx and hy and tx and ty then
      local dx = tx - hx
      local dy = ty - hy
      target_distance_now = math.sqrt(dx * dx + dy * dy)
      if launch_angle == nil and target_distance_now > 0.001 then
        launch_angle = math.atan(dy, dx)
      end
    end
  end
  if launch_angle == nil then
    launch_angle = fallback_facing
  end

  local delivery_mode = tostring(visual_cfg and visual_cfg.delivery_mode or 'projectile')
  local spawn_on_target = delivery_mode == 'spawn_on_target'
  local spawn_anchor = spawn_on_target and target or hero

  local function create_with_key(projectile_key)
    return pcall(y3.projectile.create, {
      key = projectile_key,
      target = spawn_anchor,
      socket = 'origin',
      owner = hero,
      angle = launch_angle,
      time = visual_cfg.projectile_time,
      remove_immediately = true,
    })
  end

  local requested_key = resolve_projectile_key(state, visual_cfg.projectile_key)
  local ok_create, projectile = create_with_key(requested_key)
  if state and state.bond_debug_trace_enabled == true and env and env.message then
    env.message(string.format(
      '[bond_projectile_trace] requested=%s create_ok=%s',
      tostring(requested_key),
      tostring(ok_create and projectile and true or false)
    ))
  end
  if not ok_create or not projectile then
    if env and env.message then
      env.message(string.format('[bond_projectile] create failed key=%s', tostring(requested_key)))
    end
    return false
  end

  pcall(function()
    projectile:set_height(visual_cfg.projectile_height)
  end)
  if launch_angle ~= nil then
    pcall(function()
      projectile:set_facing(launch_angle)
    end)
  end

  local function remove_projectile_safe()
    if projectile and projectile.is_exist and projectile:is_exist() then
      projectile:remove()
    end
  end

  local speed = math.max(200, tonumber(visual_cfg.projectile_speed) or 800)
  local ok_move = false
  local motion_mode = tostring(visual_cfg and visual_cfg.motion_mode or 'target')
  local use_line_fallback = motion_mode == 'line' or (target_distance_now ~= nil and target_distance_now < 80)

  if use_line_fallback then
    local line_motion_angle_offset = tonumber(visual_cfg and visual_cfg.projectile_motion_angle_offset)
    if line_motion_angle_offset == nil then
      line_motion_angle_offset = DEFAULT_LINE_MOTION_ANGLE_OFFSET
    end
    if state and state.bond_debug_trace_enabled == true and env and env.message then
      env.message(string.format(
        '[bond_line_angle] mode=%s launch=%.4f offset=%.4f final=%.4f',
        tostring(motion_mode),
        tonumber(launch_angle or 0) or 0,
        tonumber(line_motion_angle_offset or 0) or 0,
        (tonumber(launch_angle or 0) or 0) + (tonumber(line_motion_angle_offset or 0) or 0)
      ))
    end
    local line_distance = math.max(
      spawn_on_target and 80 or 120,
      tonumber(visual_cfg and visual_cfg.projectile_line_distance)
        or target_distance_now
        or 420
    )
    ok_move = pcall(function()
      projectile:mover_line({
        angle = (launch_angle or 0) + line_motion_angle_offset,
        distance = line_distance,
        speed = speed,
        height = visual_cfg.projectile_height,
        on_finish = remove_projectile_safe,
        on_break = remove_projectile_safe,
      })
    end)
  else
    ok_move = pcall(function()
      projectile:mover_target({
        target = target,
        speed = speed,
        target_distance = visual_cfg.projectile_target_distance,
        height = visual_cfg.projectile_height,
        init_angle = launch_angle,
        rotate_time = 0.0,
        face_angle = true,
        miss_when_target_destroy = false,
        on_finish = remove_projectile_safe,
        on_break = remove_projectile_safe,
        on_miss = remove_projectile_safe,
      })
    end)
  end
  if not ok_move then
    remove_projectile_safe()
    return false
  end
  return true
end

local function wait_seconds(env, delay, callback)
  local y3 = env and env.y3
  if y3 and y3.ltimer and y3.ltimer.wait and delay and delay > 0 then
    y3.ltimer.wait(delay, callback)
    return
  end
  if callback then
    callback()
  end
end

local function is_unit_alive(unit)
  if not unit or type(unit.is_exist) ~= 'function' then
    return false
  end
  local ok, alive = pcall(unit.is_exist, unit)
  return ok and alive == true
end

local function is_active_enemy_safe(env, unit)
  if not is_unit_alive(unit) then
    return false
  end
  if not env or type(env.is_active_enemy) ~= 'function' then
    return true
  end
  local ok, active = pcall(env.is_active_enemy, unit)
  return ok and active == true
end

local function get_enemies_in_range_safe(env, center, radius, except_unit, max_count)
  if not env or type(env.get_enemies_in_range) ~= 'function' then
    return {}
  end
  local ok, result = pcall(env.get_enemies_in_range, center, radius, except_unit, max_count)
  if ok and type(result) == 'table' then
    return result
  end
  return {}
end

local function get_unit_point(unit)
  if not unit or not unit.get_point then
    return nil
  end
  local ok, point = pcall(function()
    return unit:get_point()
  end)
  if ok then
    return point
  end
  return nil
end

local function create_offset_point(env, center_point, angle, distance, z)
  local y3 = env and env.y3
  if not y3 or not y3.point or not y3.point.create or not center_point then
    return nil
  end
  local base_x = center_point.get_x and center_point:get_x() or 0
  local base_y = center_point.get_y and center_point:get_y() or 0
  local base_z = center_point.get_z and center_point:get_z() or 0
  local offset = distance or 0
  local angle_rad = angle_to_radian(angle)
  local point_x = base_x + math.cos(angle_rad) * offset
  local point_y = base_y + math.sin(angle_rad) * offset
  local point_z = base_z + (z or 0)
  local ok, point = pcall(y3.point.create, point_x, point_y, point_z)
  if ok then
    return point
  end
  return nil
end

local function play_ring_burst(env, center_point, effect_key, radius, count, scale, time, height)
  -- 鍏ㄥ眬鏀舵暃锛氱鐢ㄧ幆褰㈠鐐瑰埛鐗规晥锛岄伩鍏嶁€滅獊鐒朵竴鍫嗙伀鐞?鍏夌偣鈥濄€?  return
end

local function play_line_trail(env, start_point, angle, distance, effect_key, step, scale, time, height)
  -- 鍏ㄥ眬鏀舵暃锛氱鐢ㄧ嚎娈甸摵鐐圭壒鏁堬紝鍙繚鐣欐姇灏勭墿鏈綋琛ㄧ幇銆?  return
end

local function play_impact_burst(env, target, effect_key, base_scale)
  if not target then
    return
  end
  play_particle_on_unit(env, target, effect_key, base_scale or 1.0, 0.26)
end

local function play_lightning_strike(env, target, visual_cfg)
  if not target then
    return
  end
  local target_point = get_unit_point(target)
  if play_particle_on_point and target_point then
    play_particle_on_point(env, target_point, visual_cfg and visual_cfg.particle_key, 1.05, 0.22, 140)
  end
  play_impact_burst(env, target, visual_cfg and visual_cfg.particle_key, 0.95)
end

local function play_summon_arrive_fx(env, hero, visual_cfg)
  play_particle_on_unit(env, hero, visual_cfg.particle_key, 1.15, 0.28)
end

local function play_summon_burst_fx(env, hero, visual_cfg)
  play_particle_on_unit(env, hero, visual_cfg.particle_key, 1.25, 0.30)
end

local SUMMON_UNIT_CANDIDATES = {
  magic_deer = { 134229682, 134280097 },
  magic_bear = { 134229682, 134280098 },
  hawk = { 134229682, 134280099 },
  skeleton = { 134280100, 134280101 },
}
local SUMMON_PREFAB_MISS_WARNED = {}
local SUMMON_INHERIT_PROFILES = BondEffectRuntimeRules.summon_inherit_profiles or {
  default = {
    attack_ratio = 0.35,
    hp_ratio = 0.20,
    attack_bonus_ratio = 1.00,
    hp_bonus_ratio = 0.60,
  },
}

local function create_summon_unit(env, hero, summon_kind)
  if not hero or not hero.is_exist or not hero:is_exist() then
    error(string.format('[bond_summon] hero invalid when create summon: kind=%s', tostring(summon_kind)))
  end
  local y3 = env and env.y3
  if not y3 or not y3.unit or not y3.unit.create_unit then
    error(string.format('[bond_summon] y3.unit.create_unit unavailable: kind=%s', tostring(summon_kind)))
  end

  local hero_point = get_unit_point(hero)
  if not hero_point then
    error(string.format('[bond_summon] hero point unavailable: kind=%s', tostring(summon_kind)))
  end
  local spawn_point = create_offset_point(env, hero_point, math.random() * math.pi * 2, 90 + math.random() * 90, 0) or hero_point
  local facing = 0
  if spawn_point.get_angle_with and hero_point then
    facing = spawn_point:get_angle_with(hero_point)
  end

  local candidates = SUMMON_UNIT_CANDIDATES[summon_kind] or {}
  if #candidates == 0 then
    error(string.format('[bond_summon] no unit candidates configured: kind=%s', tostring(summon_kind)))
  end
  local summon_player = env and env.get_player and env.get_player() or nil
  if not summon_player then
    error(string.format('[bond_summon] get_player() returned nil: kind=%s', tostring(summon_kind)))
  end

  local last_err = nil
  for _, candidate in ipairs(candidates) do
    local unit_id = tonumber(candidate) or 0
    if unit_id > 0 then
      local ok, unit_or_err = pcall(y3.unit.create_unit, summon_player, unit_id, spawn_point, facing)
      if ok then
        local unit = unit_or_err
        if unit and unit.is_exist and unit:is_exist() then
          return unit
        end
        last_err = string.format('create_unit returned invalid unit: id=%d', unit_id)
      else
        last_err = tostring(unit_or_err)
      end
    end
  end

  local warn_key = tostring(summon_kind or 'unknown')
  if SUMMON_PREFAB_MISS_WARNED[warn_key] ~= true then
    SUMMON_PREFAB_MISS_WARNED[warn_key] = true
    local message = env and env.message
    if message then
      message(string.format('[bond_summon] 鍙敜鍗曚綅 prefab 涓嶅瓨鍦ㄦ垨涓嶅彲鐢細kind=%s锛屽€欓€?%s锛岄敊璇?%s',
        warn_key,
        table.concat(candidates, ','),
        tostring(last_err or 'unknown')
      ))
    end
  end
  return nil
end

local function apply_summon_inherit_attrs(env, summon, summon_kind)
  if not summon or not summon.is_exist or not summon:is_exist() then
    return
  end
  local kind_key = tostring(summon_kind or 'default')
  local profile = SUMMON_INHERIT_PROFILES[kind_key] or SUMMON_INHERIT_PROFILES.default
  local summon_bonus = math.max(0, get_hero_attr(env, '召唤加成'))
  local attack_value = get_attack_value(env)
  local hp_value = get_max_hp_value(env)
  local armor_value = get_hero_attr(env, '护甲结算值')
  if armor_value <= 0 then
    armor_value = get_hero_attr(env, '护甲')
  end
  local move_speed = get_hero_attr(env, '移动速度')
  local attack_speed = get_hero_attr(env, '攻击速度')

  local inherit_attack = math.max(
    20,
    attack_value * ((profile.attack_ratio or 0.35) + summon_bonus * (profile.attack_bonus_ratio or 1.00))
  )
  local inherit_hp = math.max(
    150,
    hp_value * ((profile.hp_ratio or 0.20) + summon_bonus * (profile.hp_bonus_ratio or 0.60))
  )
  local inherit_armor = math.max(0, armor_value * (0.25 + summon_bonus * 0.35))
  local inherit_move_speed = math.max(260, move_speed * (0.70 + summon_bonus * 0.15))
  local inherit_attack_speed = math.max(0, attack_speed * (0.85 + summon_bonus * 0.20))
  pcall(function()
    summon:set_attr('攻击', inherit_attack)
    summon:set_attr('生命', inherit_hp)
    summon:set_attr('最大生命', inherit_hp)
    summon:set_attr('护甲', inherit_armor)
    summon:set_attr('移动速度', inherit_move_speed)
    summon:set_attr('攻击速度', inherit_attack_speed)
    if summon.set_hp then
      summon:set_hp(inherit_hp)
    end
  end)
end

local function drive_summon_attack(env, summon)
  if not is_unit_alive(summon) then
    return
  end
  local target = get_enemies_in_range_safe(env, summon, 1200, nil, 1)[1]
  if is_unit_alive(target) then
    pcall(function()
      if summon.attack_target then
        summon:attack_target(target, 0)
      elseif summon.move_to_pos and target.get_point then
        summon:move_to_pos(target:get_point())
      end
    end)
  end
end

local function schedule_summon_lifecycle_fx(env, hero, visual_cfg, duration_sec, summon_kind)
  if not hero or not hero.is_exist or not hero:is_exist() then
    return false
  end
  local duration = math.max(1, tonumber(duration_sec) or 8)
  local is_skeleton = tostring(summon_kind or '') == 'skeleton'
  local burst_triggered = false

  local summon = create_summon_unit(env, hero, summon_kind or 'magic_deer')
  local ai_timer = nil

  local function stop_summon_ai()
    if ai_timer and ai_timer.remove then
      pcall(ai_timer.remove, ai_timer)
    end
    ai_timer = nil
  end

  local function start_summon_ai()
    if not summon or not summon.is_exist or not summon:is_exist() then
      return
    end
    drive_summon_attack(env, summon)
    local y3 = env and env.y3
    if not y3 or not y3.ltimer or not y3.ltimer.loop then
      return
    end
    ai_timer = y3.ltimer.loop(0.40, function()
      if not summon or not summon.is_exist or not summon:is_exist() then
        stop_summon_ai()
        return
      end
      drive_summon_attack(env, summon)
    end)
  end

  if summon then
    apply_summon_inherit_attrs(env, summon, summon_kind or 'magic_deer')
    start_summon_ai()
  end

  local function trigger_skeleton_death_burst(anchor)
    if not is_skeleton or burst_triggered then
      return
    end
    burst_triggered = true
    local burst_anchor = anchor
    if not is_unit_alive(burst_anchor) then
      burst_anchor = hero
    end
    if burst_anchor then
      play_summon_burst_fx(env, burst_anchor, visual_cfg)
    end

    if not env or not env.deal_skill_damage or not burst_anchor then
      return
    end
    local attack = get_attack_value and get_attack_value(env) or 0
    local summon_bonus = math.max(0, get_hero_attr and get_hero_attr(env, '召唤加成') or 0)
    local amount = math.max(1, (attack * 3.0) + (attack * summon_bonus))
    local victims = get_enemies_in_range_safe(env, burst_anchor, 320, summon, 64)
    for _, enemy in ipairs(victims) do
      if is_active_enemy_safe(env, enemy) then
        env.deal_skill_damage(
          enemy,
          env.round_number and env.round_number(amount) or math.floor(amount),
          { scope = 'bond', key = '骷髅法师' },
          {
            text_type = 'magic',
            debug_radius = 320,
            metric_scope = 'bond',
            metric_key = '骷髅法师',
            skip_hunter_first_hit = true,
          }
        )
      end
    end
  end

  if is_skeleton and summon and summon.event then
    pcall(function()
      summon:event('单位-死亡', function()
        stop_summon_ai()
        trigger_skeleton_death_burst(summon)
      end)
    end)
  end

  play_summon_arrive_fx(env, hero, visual_cfg)
  wait_seconds(env, duration, function()
    if summon and summon.is_exist and summon:is_exist() then
      stop_summon_ai()
      trigger_skeleton_death_burst(summon)
      pcall(function()
        summon:remove()
      end)
      if not is_skeleton then
        play_summon_burst_fx(env, summon, visual_cfg)
      end
    elseif hero and hero.is_exist and hero:is_exist() then
      stop_summon_ai()
      if is_skeleton then
        trigger_skeleton_death_burst(hero)
      else
        play_summon_burst_fx(env, hero, visual_cfg)
      end
    end
  end)
  return true
end

local function launch_projectile_to_point(env, direction, distance, visual_cfg, life_time_override, mover_opts)
  local state = env and env.STATE
  local hero = state and state.hero
  local y3 = env and env.y3
  if not hero or not hero.is_exist or not hero:is_exist() then
    return false
  end
  if not y3 or not y3.projectile or not y3.projectile.create then
    return false
  end
  if not visual_cfg or not visual_cfg.projectile_key then
    return false
  end
  local raw_angle = tonumber(direction) or 0
  local motion_angle_offset = tonumber(visual_cfg and visual_cfg.projectile_motion_angle_offset)
  if motion_angle_offset == nil then
    motion_angle_offset = DEFAULT_LINE_MOTION_ANGLE_OFFSET
  end
  local move_angle = raw_angle + motion_angle_offset
  local facing_angle = raw_angle + (tonumber(visual_cfg.projectile_angle_offset) or 0)

  local function create_with_key(projectile_key)
    return pcall(y3.projectile.create, {
      key = projectile_key,
      target = hero,
      socket = 'origin',
      owner = hero,
      angle = move_angle,
      time = math.max(0.05, tonumber(life_time_override) or tonumber(visual_cfg.projectile_time) or 1.0),
      remove_immediately = true,
    })
  end

  local ok_create, projectile = create_with_key(resolve_projectile_key(state, visual_cfg.projectile_key))
  if not ok_create or not projectile then
    return false
  end

  pcall(function()
    projectile:set_height(visual_cfg.projectile_height)
  end)
  pcall(function()
    projectile:set_facing(facing_angle)
  end)

  local ok_move = pcall(function()
    projectile:mover_line({
      angle = move_angle,
      distance = math.max(1, tonumber(distance) or 1),
      speed = math.max(200, tonumber(visual_cfg.projectile_speed) or 800),
      height = visual_cfg.projectile_height,
      face_angle = true,
      hit_type = tonumber(mover_opts and mover_opts.hit_type) or 0,
      hit_radius = math.max(0, tonumber(mover_opts and mover_opts.hit_radius) or 0),
      hit_same = mover_opts and mover_opts.hit_same == true or false,
      hit_interval = math.max(0, tonumber(mover_opts and mover_opts.hit_interval) or 0),
      on_hit = mover_opts and mover_opts.on_hit or nil,
      on_finish = function()
        if projectile and projectile.is_exist and projectile:is_exist() then
          projectile:remove()
        end
      end,
      on_break = function()
        if projectile and projectile.is_exist and projectile:is_exist() then
          projectile:remove()
        end
      end,
    })
  end)
  if not ok_move then
    if projectile and projectile.is_exist and projectile:is_exist() then
      projectile:remove()
    end
    return false
  end
  return projectile
end

local function compute_direction_by_points(from_point, to_point, fallback_angle)
  if from_point and from_point.get_angle_with and to_point then
    local ok, angle = pcall(function()
      return from_point:get_angle_with(to_point)
    end)
    if ok and angle ~= nil then
      return angle
    end
  end
  local fx = from_point and from_point.get_x and from_point:get_x() or nil
  local fy = from_point and from_point.get_y and from_point:get_y() or nil
  local tx = to_point and to_point.get_x and to_point:get_x() or nil
  local ty = to_point and to_point.get_y and to_point:get_y() or nil
  if fx and fy and tx and ty then
    local dx = tx - fx
    local dy = ty - fy
    if math.abs(dx) > 0.001 or math.abs(dy) > 0.001 then
      return math.deg(math.atan(dy, dx))
    end
  end
  return fallback_angle or 0
end

local get_hero
local collect_units_in_line

local function resolve_get_hero()
  if type(get_hero) == 'function' then
    return get_hero
  end
  if type(_G.get_hero) == 'function' then
    return _G.get_hero
  end
  return function(_)
    return nil
  end
end

local function safe_collect_units_in_line(env, origin_point, impact_point, max_distance, line_width, max_hits, fallback_target)
  local collect_line = collect_units_in_line
  if type(collect_line) ~= 'function' then
    return {}
  end

  local ok, result = pcall(
    collect_line,
    env,
    origin_point,
    impact_point,
    max_distance,
    line_width,
    max_hits,
    fallback_target
  )
  if ok and type(result) == 'table' then
    return result
  end
  return {}
end

local function execute_projectile_pierce_template(env, target, visual_cfg, opts, on_tick_hit)
  if not env or not target or not visual_cfg then
    return false
  end
  local hero = resolve_get_hero()(env)
  local hero_point = get_unit_point(hero)
  local target_point = get_unit_point(target)
  local forced_direction = tonumber(opts and opts.force_direction)
  if not hero or not hero_point then
    return false
  end
  if not forced_direction and not target_point then
    return false
  end

  local line_distance = math.max(1, tonumber(opts and opts.distance) or tonumber(visual_cfg and visual_cfg.projectile_line_distance) or 0)
  local pierce_width = math.max(40, tonumber(opts and opts.pierce_width) or 120)
  local direction = forced_direction
  if direction == nil then
    direction = compute_direction_by_points(hero_point, target_point, 0)
  end
  local projectile_speed = math.max(200, tonumber(opts and opts.projectile_speed) or tonumber(visual_cfg.projectile_speed) or 800)
  local total_time = math.max(0.08, line_distance / projectile_speed)
  local projectile_life_time = math.max(total_time + 0.05, 0.10)

  play_bond_sound(env, opts and opts.bond_name, 'cast', hero)
  local hit_radius = math.max(20, tonumber(opts and opts.hit_radius) or math.floor(pierce_width * 0.5))
  local hit_interval = math.max(0.02, tonumber(opts and opts.hit_interval) or 0.05)
  local hit_same = opts and opts.hit_same == true or false
  local max_hit_targets = tonumber(opts and opts.max_targets)
  if max_hit_targets then
    max_hit_targets = math.max(1, math.floor(max_hit_targets))
  end
  local hit_count = 0
  local hit_marks = {}
  local projectile = launch_projectile_to_point(env, direction, line_distance, visual_cfg, projectile_life_time, {
    hit_type = 0,
    hit_radius = hit_radius,
    hit_same = hit_same,
    hit_interval = hit_interval,
    on_hit = function(_, unit)
      if not unit or not unit.is_exist or not unit:is_exist() or not is_active_enemy_safe(env, unit) then
        return
      end
      if max_hit_targets and hit_count >= max_hit_targets then
        return
      end
      local uid = tostring(unit)
      if not hit_same and hit_marks[uid] then
        return
      end
      hit_marks[uid] = true
      hit_count = hit_count + 1
      play_bond_sound(env, opts and opts.bond_name, 'impact', unit)
      play_particle_on_unit(env, unit, visual_cfg.particle_key, tonumber(opts and opts.hit_fx_scale) or 0.9, tonumber(opts and opts.hit_fx_time) or 0.18)
      if on_tick_hit then
        on_tick_hit(unit)
      end
    end,
  })
  return projectile ~= false and projectile ~= nil

end

local function blink_hero_tactical_reposition(env, target, visual_cfg)
  local hero = resolve_get_hero()(env)
  local target_point = get_unit_point(target)
  local hero_point = get_unit_point(hero)
  if not hero or not target_point or not hero_point or not hero.blink then
    return false
  end

  local angle = target_point.get_angle_with and target_point:get_angle_with(hero_point) or 0
  local jitter = (math.random() * 0.7) - 0.35
  local blink_point = create_offset_point(env, target_point, angle + jitter, 170, 0) or target_point
  local ok = pcall(hero.blink, hero, blink_point)
  if not ok then
    return false
  end

  play_particle_on_unit(env, hero, visual_cfg and visual_cfg.particle_key or nil, 0.9, 0.18)
  play_particle_on_point(env, blink_point, visual_cfg and visual_cfg.particle_key or nil, 0.8, 0.16, 20)
  return true
end

get_hero_attr = function(env, name)
  local state = env and env.STATE
  local hero = state and state.hero
  if not hero or not hero.is_exist or not hero:is_exist() then
    return 0
  end
  local hero_attr_system = env and env.hero_attr_system
  if hero_attr_system and hero_attr_system.get_attr then
    return tonumber(hero_attr_system.get_attr(hero, name)) or 0
  end
  return tonumber(hero:get_attr(name)) or 0
end
_G.get_hero_attr = get_hero_attr

get_attack_value = function(env)
  local attack = get_hero_attr(env, '攻击结算值')
  if attack > 0 then
    return attack
  end
  return math.max(1, get_hero_attr(env, '攻击'))
end

get_max_hp_value = function(env)
  local hp = get_hero_attr(env, '生命结算值')
  if hp > 0 then
    return hp
  end
  return math.max(1, get_hero_attr(env, '生命'))
end

local function get_three_attr_value(env)
  return get_hero_attr(env, '力量') + get_hero_attr(env, '敏捷') + get_hero_attr(env, '智力')
end

local function get_damage_template_api(env)
  if not env then
    return nil
  end
  env.__bond_damage_template_api = env.__bond_damage_template_api or SkillDamageTemplates.create({
    y3 = env.y3,
    deal_skill_damage = function(target, amount, damage_meta, visual)
      env.deal_skill_damage(target, amount, damage_meta, visual)
    end,
    emit_damage_debug = env.emit_damage_debug,
    get_enemies_in_range = env.get_enemies_in_range,
    is_active_enemy = env.is_active_enemy or function(unit)
      return unit and unit.is_exist and unit:is_exist()
    end,
  })
  return env.__bond_damage_template_api
end

local function damage_target(env, target, amount, damage_type, metric)
  if not env or not env.deal_skill_damage or not target or not target.is_exist or not target:is_exist() then
    return false
  end
  local visual = {
    text_type = damage_type == '法术' and 'magic' or 'physics',
    debug_radius = 70,
  }
  if type(metric) == 'table' then
    visual.metric_scope = metric.scope
    visual.metric_key = metric.key
  elseif type(metric) == 'string' and metric ~= '' then
    visual.metric_scope = 'bond'
    visual.metric_key = metric
  end
  local api = get_damage_template_api(env)
  if not api or not api.single then
    return false
  end
  return api.single(target, math.max(1, env.round_number and env.round_number(amount) or math.floor(amount)), damage_type or '物理', {
    text_type = visual.text_type,
    metric_scope = visual.metric_scope,
    metric_key = visual.metric_key,
    -- 羁绊触发伤害不应再次进入“普攻首击”链路，否则会递归触发 notify_basic_attack
    skip_hunter_first_hit = true,
  })
end

local function damage_area(env, center, radius, amount, damage_type, except_unit, max_count, metric)
  if not env or not center then
    return false
  end
  local visual = {
    text_type = damage_type == '法术' and 'magic' or 'physics',
    debug_radius = math.max(60, tonumber(radius) or 320),
  }
  if type(metric) == 'table' then
    visual.metric_scope = metric.scope
    visual.metric_key = metric.key
  elseif type(metric) == 'string' and metric ~= '' then
    visual.metric_scope = 'bond'
    visual.metric_key = metric
  end
  visual.skip_hunter_first_hit = true

  local api = get_damage_template_api(env)
  if not api or not api.area then
    return false
  end
  local hero = env and env.STATE and env.STATE.hero or nil
  local final_except_unit = except_unit or hero
  local hit_units = api.area(center, radius or 320, math.max(1, env.round_number and env.round_number(amount) or math.floor(amount)), damage_type or '物理', {
    except_unit = final_except_unit,
    max_count = max_count,
    visual = visual,
  })
  return #hit_units > 0
end

collect_units_in_line = function(env, origin_point, impact_point, max_distance, line_width, max_hits, fallback_target)
  local result = {}
  if not env or type(env.get_enemies_in_range) ~= 'function' or not origin_point or not impact_point then
    if is_unit_alive(fallback_target) then
      result[1] = fallback_target
    end
    return result
  end

  local ox = origin_point.get_x and origin_point:get_x() or 0
  local oy = origin_point.get_y and origin_point:get_y() or 0
  local tx = impact_point.get_x and impact_point:get_x() or ox
  local ty = impact_point.get_y and impact_point:get_y() or oy
  local dir_x = tx - ox
  local dir_y = ty - oy
  local length = origin_point.get_distance_with and origin_point:get_distance_with(impact_point)
    or math.sqrt(dir_x * dir_x + dir_y * dir_y)
  if not length or length < 1 then
    if is_unit_alive(fallback_target) then
      result[1] = fallback_target
    end
    return result
  end

  local reach = math.max(length, tonumber(max_distance) or length)
  local width = math.max(40, tonumber(line_width) or 95)
  -- 统一按“完整线段”做判定，避免只命中末端一截导致表现与伤害区域不一致。
  -- 对于分段采样（from->to），length 本身就是该分段长度，此处同样成立。
  local start_projection = 0
  local segment_length = reach - start_projection
  local max_target_count = tonumber(max_hits)
  if max_target_count then
    max_target_count = math.max(1, math.floor(max_target_count))
  end
  if segment_length <= 0 then
    if is_unit_alive(fallback_target) then
      result[1] = fallback_target
    end
    return result
  end

  local direction = origin_point.get_angle_with and origin_point:get_angle_with(impact_point) or 0

  local function push_fallback_target()
    if #result == 0 and is_unit_alive(fallback_target) then
      result[1] = fallback_target
    end
  end

  local player = env.get_player and env.get_player() or nil
  local y3 = env.y3
  if player and y3 and y3.shape and y3.shape.create_rectangle_shape and y3.selector and y3.selector.create
      and y3.point and y3.point.get_point_offset_vector then
    local segment_center = y3.point.get_point_offset_vector(
      origin_point,
      direction,
      start_projection + segment_length / 2
    )
    local shape = y3.shape.create_rectangle_shape(width * 2, segment_length, direction)
    local picked = y3.selector.create()
      :is_enemy(player)
      :in_shape(segment_center, shape)
      :pick()
    local projected = {}
    for _, unit in ipairs(picked or {}) do
      if is_active_enemy_safe(env, unit) then
        local point = get_unit_point(unit)
        if point then
          local ux = point.get_x and point:get_x() or ox
          local uy = point.get_y and point:get_y() or oy
          local projection = ((ux - ox) * dir_x + (uy - oy) * dir_y) / length
          if projection >= start_projection and projection <= reach then
            projected[#projected + 1] = { unit = unit, forward = projection }
          end
        end
      end
    end
    table.sort(projected, function(a, b)
      return a.forward < b.forward
    end)
    local limit = max_target_count and math.min(max_target_count, #projected) or #projected
    for index = 1, limit do
      result[#result + 1] = projected[index].unit
    end
    -- 若主采样路径拿到了目标，直接返回；否则继续走后备采样，避免偶发空伤
    if #result > 0 then
      push_fallback_target()
      return result
    end
  end

  local query_radius = math.max(reach + width + 80, 320)
  local candidates = get_enemies_in_range_safe(env, origin_point, query_radius, nil, 96)
  local projected = {}

  for _, unit in ipairs(candidates) do
    if is_active_enemy_safe(env, unit) then
      local point = get_unit_point(unit)
      if point then
        local ux = point.get_x and point:get_x() or ox
        local uy = point.get_y and point:get_y() or oy
        local rel_x = ux - ox
        local rel_y = uy - oy
        local projection = (rel_x * dir_x + rel_y * dir_y) / length
        if projection >= start_projection and projection <= reach then
          local side = math.abs(rel_x * dir_y - rel_y * dir_x) / length
          if side <= width then
            projected[#projected + 1] = { unit = unit, forward = projection }
          end
        end
      end
    end
  end

  table.sort(projected, function(a, b)
    return a.forward < b.forward
  end)

  local limit = max_target_count and math.min(max_target_count, #projected) or #projected
  for index = 1, limit do
    result[#result + 1] = projected[index].unit
  end
  push_fallback_target()
  return result
end
-- 兼容旧闭包/旧热更环境：有些路径会按全局名解析，兜底注册一次，避免 nil 崩溃。

local function try_chance(chance)
  if FORCE_SPECIAL_EFFECTS_100 then
    return true
  end
  return math.random() <= math.max(0, math.min(1, chance or 0))
end

local function normalize_ratio_chance(value, fallback)
  local chance = tonumber(value)
  if chance == nil then
    return fallback or 0
  end
  if chance > 1 then
    chance = chance / 100
  end
  return math.max(0, math.min(1, chance))
end

function M.set_force_special_effects_100(enabled)
  FORCE_SPECIAL_EFFECTS_100 = enabled == true
end

function M.is_force_special_effects_100()
  return FORCE_SPECIAL_EFFECTS_100 == true
end

local CARD_ID_BY_NAME = {}
do
  for _, card in ipairs(BondModifierPool.cards or {}) do
    if card and card.name then
      CARD_ID_BY_NAME[card.name] = card.id
    end
  end
end

local CARD_NAME_ALIASES = {
  ['嗜剑剑气'] = '赐剑剑气',
  ['赐剑剑气'] = '赐剑剑气',
}

local function normalize_card_name(card_name)
  local key = tostring(card_name or ''):gsub('^%s+', ''):gsub('%s+$', '')
  key = key:gsub('　', '')
  if key == '' then
    return key
  end
  local canonical = CARD_NAME_ALIASES[key] or key
  return canonical
end

do
  for alias, canonical in pairs(CARD_NAME_ALIASES) do
    if CARD_ID_BY_NAME[alias] == nil and CARD_ID_BY_NAME[canonical] ~= nil then
      CARD_ID_BY_NAME[alias] = CARD_ID_BY_NAME[canonical]
    end
  end
end

local function has_card_effect(runtime, card_name)
  card_name = normalize_card_name(card_name)
  local card_id = CARD_ID_BY_NAME[card_name]
  if not runtime or not card_id then
    return false
  end
  return runtime.modifier_card_effect_ids and runtime.modifier_card_effect_ids[card_id] == true or false
end

local function has_any_card_effect(runtime, card_names)
  if type(card_names) ~= 'table' then
    return false
  end
  for _, card_name in ipairs(card_names) do
    if has_card_effect(runtime, card_name) then
      return true
    end
  end
  return false
end

local function ensure_card_effect_state(runtime, card_name)
  card_name = normalize_card_name(card_name)
  local card_id = CARD_ID_BY_NAME[card_name]
  if not runtime or not card_id then
    return nil
  end
  runtime.modifier_card_effect_state = runtime.modifier_card_effect_state or {}
  runtime.modifier_card_effect_state[card_id] = runtime.modifier_card_effect_state[card_id] or {
    card_name = card_name,
    elapsed = 0,
    counter = 0,
    cooldown = 0,
  }
  return runtime.modifier_card_effect_state[card_id]
end

local function ensure_custom_card_effect_state(runtime, state_key)
  if not runtime or not state_key or state_key == '' then
    return nil
  end
  runtime.modifier_card_effect_custom_state = runtime.modifier_card_effect_custom_state or {}
  runtime.modifier_card_effect_custom_state[state_key] = runtime.modifier_card_effect_custom_state[state_key] or {
    card_name = state_key,
    elapsed = 0,
    counter = 0,
    cooldown = 0,
  }
  return runtime.modifier_card_effect_custom_state[state_key]
end

local function add_hero_attr(env, attr_name, value)
  if not env or not env.STATE or not env.STATE.hero or not attr_name or not value or value == 0 then
    return
  end
  local hero = env.STATE.hero
  local hero_attr_system = env.hero_attr_system
  if hero_attr_system and hero_attr_system.add_attr then
    hero_attr_system.add_attr(hero, attr_name, value)
  elseif hero.add_attr then
    hero:add_attr(attr_name, value)
  end
  if hero_attr_system and hero_attr_system.rebuild_derived_attrs then
    hero_attr_system.rebuild_derived_attrs(hero)
  end
end

get_hero = function(env)
  local hero = env and env.STATE and env.STATE.hero
  if not hero or not hero.is_exist or not hero:is_exist() then
    return nil
  end
  return hero
end
-- 兼容旧闭包/旧热更环境：有些路径会按全局名解析，兜底注册一次，避免 nil 崩溃。
_G.get_hero = get_hero

local function update_card_stack_attr(env, state, attack_per_stack, attack_speed_per_stack)
  if not state then
    return
  end
  local hero = get_hero(env)
  if not hero then
    return
  end

  local stacks = math.max(0, state.stacks or 0)
  local target_attack = stacks * (attack_per_stack or 0)
  local target_attack_speed = stacks * (attack_speed_per_stack or 0)
  local applied_attack = state.applied_attack or 0
  local applied_attack_speed = state.applied_attack_speed or 0

  local delta_attack = target_attack - applied_attack
  if delta_attack ~= 0 then
    add_hero_attr(env, '攻击', delta_attack)
    state.applied_attack = target_attack
  end

  local delta_attack_speed = target_attack_speed - applied_attack_speed
  if delta_attack_speed ~= 0 then
    add_hero_attr(env, '攻击速度', delta_attack_speed)
    state.applied_attack_speed = target_attack_speed
  end
end

local function push_stack_expire(state, expire_time)
  state.stack_expire_times = state.stack_expire_times or {}
  state.stack_expire_times[#state.stack_expire_times + 1] = expire_time
end

local function cleanup_stack_expire(state, now, max_stack)
  local list = state and state.stack_expire_times
  if not list then
    state.stacks = 0
    return
  end
  local write = 1
  for i = 1, #list do
    if (list[i] or 0) > now then
      list[write] = list[i]
      write = write + 1
    end
  end
  for i = write, #list do
    list[i] = nil
  end
  state.stacks = math.min(max_stack or #list, #list)
end

local function get_game_time(env)
  local y3 = env and env.y3
  if y3 and y3.game and y3.game.current_game_run_time then
    return tonumber(y3.game.current_game_run_time()) or 0
  end
  return 0
end

local AUTO_ACTIVE_STATUS_KEYS = RuntimeEditorIds.modifier and RuntimeEditorIds.modifier.auto_active_effect or {}
local BOND_STATUS_KEYS = RuntimeEditorIds.modifier and RuntimeEditorIds.modifier.bond_status or {}
local STATUS_RUNTIME_PRESETS = {}
for status_id, preset in pairs(BondEffectRuntimeRules.status_runtime_presets or {}) do
  if type(preset) == 'table' then
    local copied = {}
    for k, v in pairs(preset) do
      copied[k] = v
    end
    if status_id == 'magic_swordsman_demon' then
      copied.buff_key = tonumber(BOND_STATUS_KEYS.magic_swordsman_demon) or tonumber(AUTO_ACTIVE_STATUS_KEYS.charge_breaker_rally) or 0
    elseif status_id == 'berserker_frenzy' then
      copied.buff_key = tonumber(BOND_STATUS_KEYS.berserker_frenzy) or tonumber(AUTO_ACTIVE_STATUS_KEYS.rapid_overdrive) or 0
    end
    STATUS_RUNTIME_PRESETS[status_id] = copied
  end
end

local function is_runtime_obj_alive(obj)
  return obj and obj.is_exist and obj:is_exist() or false
end

local function sync_runtime_status_effect(env, runtime, status_id, active)
  local state = env and env.STATE
  local hero = state and state.hero
  local preset = STATUS_RUNTIME_PRESETS[status_id]
  if not runtime or not preset then
    return
  end
  runtime.modifier_runtime_status = runtime.modifier_runtime_status or {}
  local entry = runtime.modifier_runtime_status[status_id] or {}
  runtime.modifier_runtime_status[status_id] = entry

  local function clear_entry()
    if is_runtime_obj_alive(entry.buff) and entry.buff.remove then
      pcall(entry.buff.remove, entry.buff)
    end
    if is_runtime_obj_alive(entry.particle) and entry.particle.remove then
      pcall(entry.particle.remove, entry.particle)
    end
    entry.buff = nil
    entry.particle = nil
    entry.next_particle_at = nil
  end

  if not active or not hero or not hero.is_exist or not hero:is_exist() then
    clear_entry()
    return
  end

  local buff_refresh = math.max(0.8, tonumber(preset.buff_refresh) or 1.2)
  local buff_key = tonumber(preset.buff_key) or 0
  if buff_key > 0 and hero.add_buff then
    if not is_runtime_obj_alive(entry.buff) then
      entry.buff = hero:add_buff({
        key = buff_key,
        source = hero,
        time = buff_refresh,
      })
      if is_runtime_obj_alive(entry.buff) then
        if preset.name and entry.buff.set_name then
          pcall(entry.buff.set_name, entry.buff, preset.name)
        end
        if preset.description and entry.buff.set_description then
          pcall(entry.buff.set_description, entry.buff, preset.description)
        end
      end
    elseif entry.buff.set_time then
      pcall(entry.buff.set_time, entry.buff, buff_refresh)
    end
  end

  if not is_runtime_obj_alive(entry.particle) then
    local visual_cfg = get_visual_config(preset.particle_bond or '')
    entry.particle = play_particle_on_unit(
      env,
      hero,
      visual_cfg and visual_cfg.particle_key or nil,
      tonumber(preset.particle_scale) or 1.0,
      tonumber(preset.particle_time) or 1.0
    )
  end
end

local function clear_all_runtime_status_effects(runtime)
  if not runtime or type(runtime.modifier_runtime_status) ~= 'table' then
    return
  end
  for _, entry in pairs(runtime.modifier_runtime_status) do
    if type(entry) == 'table' then
      if is_runtime_obj_alive(entry.buff) and entry.buff.remove then
        pcall(entry.buff.remove, entry.buff)
      end
      if is_runtime_obj_alive(entry.particle) and entry.particle.remove then
        pcall(entry.particle.remove, entry.particle)
      end
      entry.buff = nil
      entry.particle = nil
      entry.next_particle_at = nil
    end
  end
  runtime.modifier_runtime_status = {}
end

local function update_magic_swordsman_runtime_bonus(runtime, active)
  if not runtime or not runtime.modifier_pool_active_runtime_bonuses then
    return
  end
  local effect_id = 'initial_bond_set_魔剑士'
  local pack = runtime.modifier_pool_active_runtime_bonuses[effect_id]
  if type(pack) ~= 'table' then
    pack = {}
    runtime.modifier_pool_active_runtime_bonuses[effect_id] = pack
  end
  if active then
    local bonus = 0.20
    -- [嗜剑剑气] 在入魔状态下进一步提高最终伤害
    if has_card_effect(runtime, '嗜剑剑气') then
      bonus = bonus + 0.20
    end
    pack.all_damage_bonus = bonus
  else
    pack.all_damage_bonus = nil
  end
end

function M.ensure_effect_state(runtime, bond_name)
  local canonical_bond_name = normalize_bond_name(bond_name)
  local effect_id = 'initial_bond_set_' .. tostring(canonical_bond_name)
  runtime.modifier_pool_effect_state[effect_id] = runtime.modifier_pool_effect_state[effect_id] or {
    bond_name = canonical_bond_name,
    cooldown = 0,
    counter = 0,
    elapsed = 0,
  }
  return runtime.modifier_pool_effect_state[effect_id]
end

function M.has_active_modifier_bond(runtime, bond_name, get_cards_by_bond)
  local canonical_bond_name = normalize_bond_name(bond_name)
  local effect_id = 'initial_bond_set_' .. tostring(canonical_bond_name)
  if runtime and runtime.modifier_pool_active_effects and runtime.modifier_pool_active_effects[effect_id] == true then
    return true
  end
  local cards = get_cards_by_bond and get_cards_by_bond(canonical_bond_name) or {}
  for _, card in ipairs(cards) do
    if runtime and runtime.modifier_card_effect_ids and runtime.modifier_card_effect_ids[card.id] == true then
      return true
    end
  end
  return false
end

local function execute_linear_bond_template(env, target, visual_cfg, opts, on_hit)
  if not env or not target or not visual_cfg then
    return false
  end
  local hero = resolve_get_hero()(env)
  local hero_point = get_unit_point(hero)
  local target_point = get_unit_point(target)
  if not hero or not hero_point or not target_point then
    return false
  end

  local line_distance = math.max(1, tonumber(opts and opts.distance) or 0)
  local line_width = math.max(40, tonumber(opts and opts.width) or 95)
  local max_hits = tonumber(opts and opts.max_targets)
  if max_hits then
    max_hits = math.max(1, math.floor(max_hits))
  end
  local projectile_speed = math.max(200, tonumber(opts and opts.projectile_speed) or tonumber(visual_cfg.projectile_speed) or 800)

  local direction = compute_direction_by_points(hero_point, target_point, 0)
  local impact_point = create_offset_point(env, hero_point, direction, line_distance, 0) or target_point

  play_bond_sound(env, opts and opts.bond_name, 'cast', hero)
  launch_projectile_to_point(env, direction, line_distance, visual_cfg)
  play_particle_on_point(env, impact_point, visual_cfg.particle_key, tonumber(opts and opts.target_fx_scale) or 1.0, tonumber(opts and opts.target_fx_time) or 0.25, 20)

  local function apply_line_hit()
    local fallback_target = nil
    local line_units = safe_collect_units_in_line(env, hero_point, impact_point, line_distance, line_width, max_hits, fallback_target)
    for _, unit in ipairs(line_units) do
      play_bond_sound(env, opts and opts.bond_name, 'impact', unit)
      play_particle_on_unit(env, unit, visual_cfg.particle_key, tonumber(opts and opts.hit_fx_scale) or 0.9, tonumber(opts and opts.hit_fx_time) or 0.18)
      if on_hit then
        on_hit(unit)
      end
    end
  end

  if opts and opts.instant_hit == true then
    apply_line_hit()
  else
    local travel_delay = math.max(0.10, math.min(0.45, line_distance / projectile_speed))
    wait_seconds(env, travel_delay, apply_line_hit)
  end
  return true
end

local function trigger_dragon_fireball_effect(env, runtime, target, effect_state, trigger_floor, extra_damage_scale, extra_radius_scale)
  if not effect_state then
    return false
  end
  local now = get_game_time(env)
  if (tonumber(effect_state.cast_lock_until) or 0) > now then
    return false
  end
  local visual_cfg = get_visual_config('龙骑士')
  -- 火龙效果强制使用专属火球弹道，避免映射异常时回退到默认普攻弓箭弹道
  visual_cfg.projectile_key = 201391110
  visual_cfg.particle_key = to_positive_number(visual_cfg.particle_key) or 104627
  visual_cfg.line_particle_key = to_positive_number(visual_cfg.line_particle_key) or visual_cfg.particle_key
  visual_cfg.projectile_speed = tonumber(visual_cfg.projectile_speed) or 760
  visual_cfg.projectile_time = tonumber(visual_cfg.projectile_time) or 1.10
  if not visual_cfg.projectile_key then
    error('龙骑士 fireball projectile_key 未配置')
  end
  local attack = get_attack_value(env)
  local max_hp = get_max_hp_value(env)
  local trigger_chance = math.max(
    normalize_ratio_chance(get_hero_attr(env, '物理暴击'), 0),
    normalize_ratio_chance(trigger_floor, 0.08)
  )
  if (effect_state.cooldown or 0) > 0 or not try_chance(trigger_chance) then
    return false
  end

  local has_tail_sweep = has_card_effect(runtime, '神龙摆尾')
  local dragon_rule = BondEffectRuntimeRules.dragon_fireball or {}
  -- 提升火龙覆盖：基础射程与线宽都上调，缓解“范围过近”体感。
  local line_distance = has_tail_sweep
    and (tonumber(dragon_rule.line_distance_with_tail_sweep) or 1720)
    or (tonumber(dragon_rule.line_distance_default) or 1450)
  local line_width = has_tail_sweep
    and (tonumber(dragon_rule.line_width_with_tail_sweep) or 320)
    or (tonumber(dragon_rule.line_width_default) or 220)

  effect_state.cooldown = 1
  play_particle_on_unit(env, get_hero(env), visual_cfg.particle_key, 1.05, 0.22)

  local damage_scale = (extra_damage_scale or 1.0) * (has_card_effect(runtime, '龙族血统') and 1.20 or 1.0)
  local width_scale = (extra_radius_scale or 1.0) * (has_tail_sweep and (tonumber(dragon_rule.width_scale_with_tail_sweep) or 1.20) or 1.0)
  line_width = math.max(tonumber(dragon_rule.min_width) or 140, math.floor(line_width * width_scale + 0.5))
  local amount = (attack + max_hp * 0.05) * damage_scale

  local direction = nil
  local hero = get_hero(env)
  local hero_point = get_unit_point(hero)
  local target_point = get_unit_point(target)
  if hero_point and target_point then
    direction = compute_direction_by_points(hero_point, target_point, 0)
  end
  effect_state.cast_lock_until = now + 0.30

  return execute_projectile_pierce_template(env, target, visual_cfg, {
    bond_name = '龙骑士',
    distance = line_distance,
    pierce_width = math.max(
      tonumber(dragon_rule.min_pierce_width) or 120,
      math.floor(line_width * (tonumber(dragon_rule.pierce_width_ratio) or 0.70))
    ),
    hit_radius = math.max(60, math.floor(line_width * 0.45)),
    hit_interval = 0.04,
    hit_same = false,
    projectile_speed = visual_cfg.projectile_speed,
    tick_interval = tonumber(dragon_rule.tick_interval) or 0.12,
    tick_fx_scale = 1.05,
    tick_fx_time = 0.22,
    hit_fx_scale = 1.05,
    hit_fx_time = 0.24,
    force_direction = direction,
  }, function(unit)
    damage_target(env, unit, amount, '物理', { scope = 'bond', key = '龙骑士' })
    damage_target(env, unit, amount, '法术', { scope = 'bond', key = '龙骑士' })
  end)
end

local BondModifierSpecialEffects = BondModifierSpecialEffectsFactory.create({
  runtime_rules = BondEffectRuntimeRules,
  has_card_effect = has_card_effect,
  has_any_card_effect = has_any_card_effect,
  ensure_card_effect_state = ensure_card_effect_state,
  ensure_custom_card_effect_state = ensure_custom_card_effect_state,
  add_hero_attr = add_hero_attr,
  get_hero = get_hero,
  get_hero_attr = get_hero_attr,
  get_attack_value = get_attack_value,
  get_max_hp_value = get_max_hp_value,
  get_game_time = get_game_time,
  get_visual_config = get_visual_config,
  play_particle_on_unit = play_particle_on_unit,
  play_particle_on_point = play_particle_on_point,
  play_lightning_strike = play_lightning_strike,
  launch_projectile_to_target = launch_projectile_to_target,
  wait_seconds = wait_seconds,
  damage_target = damage_target,
  damage_area = damage_area,
  try_chance = try_chance,
  push_stack_expire = push_stack_expire,
  cleanup_stack_expire = cleanup_stack_expire,
  update_card_stack_attr = update_card_stack_attr,
  schedule_summon_lifecycle_fx = schedule_summon_lifecycle_fx,
  trigger_dragon_fireball_effect = trigger_dragon_fireball_effect,
  update_magic_swordsman_runtime_bonus = update_magic_swordsman_runtime_bonus,
  sync_runtime_status_effect = sync_runtime_status_effect,
  has_active_modifier_bond = M.has_active_modifier_bond,
})

local BondModifierCoreEffects = BondModifierCoreEffectsFactory.create({
  runtime_rules = BondEffectRuntimeRules,
  get_attack_value = get_attack_value,
  get_max_hp_value = get_max_hp_value,
  get_three_attr_value = get_three_attr_value,
  get_hero_attr = get_hero_attr,
  get_visual_config = get_visual_config,
  get_hero = get_hero,
  get_game_time = get_game_time,
  has_card_effect = has_card_effect,
  try_chance = try_chance,
  play_bond_sound = play_bond_sound,
  play_particle_on_unit = play_particle_on_unit,
  play_particle_on_point = play_particle_on_point,
  play_impact_burst = play_impact_burst,
  play_lightning_strike = play_lightning_strike,
  launch_projectile_to_target = launch_projectile_to_target,
  wait_seconds = wait_seconds,
  execute_linear_bond_template = execute_linear_bond_template,
  trigger_dragon_fireball_effect = trigger_dragon_fireball_effect,
  blink_hero_tactical_reposition = blink_hero_tactical_reposition,
  schedule_summon_lifecycle_fx = schedule_summon_lifecycle_fx,
  damage_target = damage_target,
  damage_area = damage_area,
  update_magic_swordsman_runtime_bonus = update_magic_swordsman_runtime_bonus,
  sync_runtime_status_effect = sync_runtime_status_effect,
})

function M.trigger_modifier_basic_attack_effect(env, runtime, bond_name, target)
  if not runtime or not target then
    return false
  end
  local canonical_bond_name = normalize_bond_name(bond_name)
  local effect_state = M.ensure_effect_state(runtime, canonical_bond_name)
  return BondModifierCoreEffects.trigger_modifier_basic_attack_effect(env, runtime, canonical_bond_name, effect_state, target)
end

function M.trigger_modifier_periodic_effect(env, runtime, bond_name, effect_state, dt)
  if not runtime or not bond_name then
    return false
  end
  local canonical_bond_name = normalize_bond_name(bond_name)
  effect_state = effect_state or M.ensure_effect_state(runtime, canonical_bond_name)
  return BondModifierCoreEffects.trigger_modifier_periodic_effect(env, runtime, canonical_bond_name, effect_state, dt)
end

function M.trigger_modifier_card_basic_attack_effects(env, runtime, target)
  return BondModifierSpecialEffects.trigger_modifier_card_basic_attack_effects(env, runtime, target)
end

function M.trigger_modifier_card_periodic_effects(env, runtime, dt)
  return BondModifierSpecialEffects.trigger_modifier_card_periodic_effects(env, runtime, dt)
end

function M.handle_modifier_card_pre_hurt(env, runtime, data)
  return BondModifierSpecialEffects.handle_modifier_card_pre_hurt(env, runtime, data)
end

function M.handle_modifier_enemy_kill(env, runtime, info, get_cards_by_bond)
  return BondModifierSpecialEffects.handle_modifier_enemy_kill(env, runtime, info, get_cards_by_bond)
end

function M.clear_runtime_status_effects(runtime)
  clear_all_runtime_status_effects(runtime)
end

function M.register_visual_override(bond_name, visual_opts)
  local canonical_bond_name = normalize_bond_name(bond_name)
  if canonical_bond_name == '' then
    return false
  end
  VISUAL_OVERRIDES[canonical_bond_name] = build_bond_visual(visual_opts or {})
  return true
end

function M.normalize_bond_name(bond_name)
  return normalize_bond_name(bond_name)
end

function M.get_visual_registry_snapshot()
  return {
    base = BOND_VISUALS,
    overrides = VISUAL_OVERRIDES,
    forced = VISUAL_FORCE_BY_BOND,
  }
end

return M

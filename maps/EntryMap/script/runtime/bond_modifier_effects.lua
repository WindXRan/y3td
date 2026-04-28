local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'
local BondModifierPool = require 'data.object_tables.bond_modifier_pool'
local BondVisualEditorIds = require 'data.object_tables.bond_visual_editor_ids'
local AttackSkillObjects = require 'entry_objects.attack_skills'
local BondModifierSpecialEffectsFactory = require 'runtime.bond_modifier_special_effects'
local BondModifierCoreEffectsFactory = require 'runtime.bond_modifier_core_effects'
local SkillDamageTemplates = require 'runtime.skill_damage_templates'

local M = {}
local FORCE_SPECIAL_EFFECTS_100 = false
local get_hero_attr
local get_attack_value
local get_max_hp_value

-- 热更早期兜底：旧闭包可能在本文件完成加载前按全局名调用。
if type(_G.collect_units_in_line) ~= 'function' then
  _G.collect_units_in_line = function(_, _, _, _, _, _, fallback_target)
    if fallback_target and fallback_target.is_exist and fallback_target:is_exist() then
      return { fallback_target }
    end
    return {}
  end
end
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
  ['战法法师'] = '战斗法师',
}

-- 激活后直接生效的静态属性加成（按羁绊名）
M.SET_ATTR_BONUSES = {
  ['刀锋战士'] = { ['攻击增幅'] = 0.50 },
  ['全能骑士'] = {
    ['攻击增幅'] = 0.10,
    ['生命增幅'] = 0.10,
    ['护甲增幅'] = 0.10,
  },
}

-- 激活后生效的运行时加成（按羁绊名）
M.SET_RUNTIME_BONUSES = {
  ['雷电法王'] = { lightning_target_count = 5 },
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
    }
  end
end

local function build_bond_visual(opts)
  opts = opts or {}
  return {
    particle_key = to_positive_number(opts.particle_key) or DEFAULT_VISUAL.particle_key,
    line_particle_key = to_positive_number(opts.line_particle_key) or nil,
    projectile_key = to_positive_number(opts.projectile_key) or DEFAULT_VISUAL.projectile_key,
    projectile_speed = tonumber(opts.projectile_speed) or DEFAULT_VISUAL.projectile_speed,
    projectile_time = tonumber(opts.projectile_time) or DEFAULT_VISUAL.projectile_time,
    projectile_height = tonumber(opts.projectile_height) or DEFAULT_VISUAL.projectile_height,
    projectile_target_distance = tonumber(opts.projectile_target_distance) or DEFAULT_VISUAL.projectile_target_distance,
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
local UNIQUE_PROJECTILE_POOL = {
  201391101, 201391102, 201391103, 201391104,
  201391105, 201391106, 201391107, 201391108,
  201391109, 201391110, 201391111, 201391112,
  201391113, 201391114, 201391115, 201391116,
  201392001, 201392002, 201392003,
  201392011, 201392012, 201392013,
  201392021, 201392022, 201392023,
  201392031, 201392032, 201392033,
  201392041, 201392042, 201392043,
  201392051, 201392052,
  201392061, 201392062, 201392063,
}

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

-- 强制去重：不同羁绊技能使用不同弹道 key
do
  local used = {}
  local ordered_bonds = {}
  for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
    local bond_name = normalize_bond_name(effect and effect.bond_name or '')
    if bond_name ~= '' and BOND_VISUALS[bond_name] then
      ordered_bonds[#ordered_bonds + 1] = bond_name
    end
  end
  for bond_name, _ in pairs(BOND_VISUALS) do
    local exists = false
    for _, ordered in ipairs(ordered_bonds) do
      if ordered == bond_name then
        exists = true
        break
      end
    end
    if not exists then
      ordered_bonds[#ordered_bonds + 1] = bond_name
    end
  end

  local function pick_unused_projectile()
    for _, key in ipairs(UNIQUE_PROJECTILE_POOL) do
      if not used[key] and projectile_editor_exists(key) then
        return key
      end
    end
    return nil
  end

  for _, bond_name in ipairs(ordered_bonds) do
    local visual = BOND_VISUALS[bond_name]
    if type(visual) == 'table' then
      local key = to_positive_number(visual.projectile_key)
      if not key or used[key] then
        local replacement = pick_unused_projectile()
        if replacement then
          visual.projectile_key = replacement
          used[replacement] = true
        elseif key then
          used[key] = true
        end
      else
        used[key] = true
      end
    end
  end
end

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
  }
end

local function play_particle_on_unit(env, unit, effect_key, scale, time)
  if is_visual_hidden(env) or not effect_key or not unit or not unit.is_exist or not unit:is_exist() then
    return nil
  end
  local y3 = env and env.y3
  if not y3 or not y3.particle or not y3.particle.create then
    return nil
  end
  local ok, particle = pcall(y3.particle.create, {
    type = effect_key,
    target = unit,
    socket = 'origin',
    scale = scale or 1.0,
    time = time or 0.30,
    immediate = true,
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
  if not y3 or not y3.particle or not y3.particle.create then
    return nil
  end
  local ok, particle = pcall(y3.particle.create, {
    type = effect_key,
    target = point,
    scale = scale or 1.0,
    time = time or 0.30,
    height = height or 0,
    immediate = true,
  })
  if ok and particle then
    return particle
  end
  return nil
end

local function play_bond_sound(env, bond_name, stage, anchor)
  if not env or not env.play_bond_sound then
    return nil
  end
  local state = env and env.STATE
  local ok, result = pcall(env.play_bond_sound, bond_name, stage, anchor)
  if ok then
    if state and state.bond_debug_trace_enabled == true and env.message then
      env.message(string.format('[bond_audio_trace] bond=%s stage=%s ok=true', tostring(bond_name), tostring(stage)))
    end
    return result
  end
  if state and state.bond_debug_trace_enabled == true and env.message then
    env.message(string.format('[bond_audio_trace] bond=%s stage=%s ok=false', tostring(bond_name), tostring(stage)))
  end
  return nil
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
  local hero_point = hero.get_point and hero:get_point() or nil
  local target_point = target.get_point and target:get_point() or nil
  if hero_point and target_point and hero_point.get_angle_with then
    launch_angle = hero_point:get_angle_with(target_point)
  end

  local function create_with_key(projectile_key)
    return pcall(y3.projectile.create, {
      key = projectile_key,
      target = hero,
      socket = 'origin',
      owner = hero,
      angle = launch_angle,
      time = visual_cfg.projectile_time,
      remove_immediately = true,
    })
  end

  local fallback_projectile_key = to_positive_number(DEFAULT_VISUAL.projectile_key) or 201392033
  local requested_key = visual_cfg.projectile_key
  local used_fallback = false
  local ok_create, projectile = create_with_key(visual_cfg.projectile_key)
  if (not ok_create or not projectile) and tonumber(visual_cfg.projectile_key) ~= fallback_projectile_key then
    ok_create, projectile = create_with_key(fallback_projectile_key)
    used_fallback = ok_create and projectile and true or false
  end
  if state and state.bond_debug_trace_enabled == true and env and env.message then
    env.message(string.format(
      '[bond_projectile_trace] requested=%s fallback=%s used_fallback=%s create_ok=%s',
      tostring(requested_key),
      tostring(fallback_projectile_key),
      tostring(used_fallback),
      tostring(ok_create and projectile and true or false)
    ))
  end
  if not ok_create or not projectile then
    if env and env.message then
      env.message(string.format('[bond_projectile] create failed key=%s', tostring(visual_cfg.projectile_key)))
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

  local ok_move = pcall(function()
    projectile:mover_target({
      target = target,
      speed = visual_cfg.projectile_speed,
      target_distance = visual_cfg.projectile_target_distance,
      height = visual_cfg.projectile_height,
      init_angle = launch_angle,
      rotate_time = 0.0,
      face_angle = true,
      miss_when_target_destroy = false,
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
      on_miss = function()
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
  local point_x = base_x + math.cos(angle or 0) * offset
  local point_y = base_y + math.sin(angle or 0) * offset
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
  launch_projectile_to_target(env, target, visual_cfg)
  play_impact_burst(env, target, visual_cfg.particle_key, 0.95)
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

local function apply_summon_inherit_attrs(env, summon)
  if not summon or not summon.is_exist or not summon:is_exist() then
    return
  end
  local summon_bonus = math.max(0, get_hero_attr(env, '召唤加成'))
  local attack_value = get_attack_value(env)
  local hp_value = get_max_hp_value(env)
  local inherit_attack = math.max(20, attack_value * (0.35 + summon_bonus))
  local inherit_hp = math.max(150, hp_value * (0.20 + summon_bonus * 0.6))
  pcall(function()
    summon:set_attr('攻击', inherit_attack)
    summon:set_attr('生命', inherit_hp)
    summon:set_attr('最大生命', inherit_hp)
  end)
end

local function drive_summon_attack(env, summon)
  if not summon or not summon.is_exist or not summon:is_exist() then
    return
  end
  local target = env.get_enemies_in_range and env.get_enemies_in_range(summon, 1200, nil, 1)[1] or nil
  if target and target.is_exist and target:is_exist() then
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

  local summon = create_summon_unit(env, hero, summon_kind or 'magic_deer')
  if summon then
    apply_summon_inherit_attrs(env, summon)
    drive_summon_attack(env, summon)
  end
  play_summon_arrive_fx(env, hero, visual_cfg)
  wait_seconds(env, duration, function()
    if summon and summon.is_exist and summon:is_exist() then
      pcall(function()
        summon:remove()
      end)
      play_summon_burst_fx(env, summon, visual_cfg)
    elseif hero and hero.is_exist and hero:is_exist() then
      play_summon_burst_fx(env, hero, visual_cfg)
    end
  end)
  return true
end

local function launch_projectile_to_point(env, direction, distance, visual_cfg)
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

  local function create_with_key(projectile_key)
    return pcall(y3.projectile.create, {
      key = projectile_key,
      target = hero,
      socket = 'origin',
      owner = hero,
      angle = direction,
      time = visual_cfg.projectile_time,
      remove_immediately = true,
    })
  end

  local fallback_projectile_key = to_positive_number(DEFAULT_VISUAL.projectile_key) or 201392033
  local ok_create, projectile = create_with_key(visual_cfg.projectile_key)
  if (not ok_create or not projectile) and tonumber(visual_cfg.projectile_key) ~= fallback_projectile_key then
    ok_create, projectile = create_with_key(fallback_projectile_key)
  end
  if not ok_create or not projectile then
    return false
  end

  pcall(function()
    projectile:set_height(visual_cfg.projectile_height)
  end)
  pcall(function()
    projectile:set_facing(direction)
  end)

  local ok_move = pcall(function()
    projectile:mover_line({
      angle = direction,
      distance = math.max(1, tonumber(distance) or 1),
      speed = math.max(200, tonumber(visual_cfg.projectile_speed) or 800),
      height = visual_cfg.projectile_height,
      face_angle = true,
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
  return true
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

local function resolve_collect_units_in_line()
  if type(collect_units_in_line) == 'function' then
    return collect_units_in_line
  end
  if type(_G.collect_units_in_line) == 'function' then
    return _G.collect_units_in_line
  end
  return function(_, _, _, _, _, _, _)
    return {}
  end
end

local function safe_collect_units_in_line(env, origin_point, impact_point, max_distance, line_width, max_hits, fallback_target)
  local collect_line = resolve_collect_units_in_line()
  if type(collect_line) ~= 'function' then
    if fallback_target and fallback_target.is_exist and fallback_target:is_exist() then
      return { fallback_target }
    end
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
  if fallback_target and fallback_target.is_exist and fallback_target:is_exist() then
    return { fallback_target }
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
  if not hero or not hero_point or not target_point then
    return false
  end

  local y3 = env and env.y3
  if not y3 or not y3.ltimer or not y3.ltimer.loop then
    return false
  end

  local line_distance = math.max(1, tonumber(opts and opts.distance) or 0)
  local pierce_width = math.max(40, tonumber(opts and opts.pierce_width) or 120)
  local projectile_speed = math.max(200, tonumber(opts and opts.projectile_speed) or tonumber(visual_cfg.projectile_speed) or 800)
  local tick_interval = math.max(0.2, tonumber(opts and opts.tick_interval) or 1.0)
  local direction = hero_point.get_angle_with and hero_point:get_angle_with(target_point) or 0
  local total_time = math.max(tick_interval, line_distance / projectile_speed)

  play_bond_sound(env, opts and opts.bond_name, 'cast', hero)
  launch_projectile_to_point(env, direction, line_distance, visual_cfg)

  local elapsed = 0
  local finished = false
  local last_travel_distance = 0
  local function apply_tick(next_elapsed)
    if finished then
      return true
    end
    next_elapsed = math.max(elapsed, math.min(total_time, tonumber(next_elapsed) or elapsed))
    if next_elapsed <= elapsed then
      return finished
    end
    local curr_travel_distance = math.min(line_distance, projectile_speed * next_elapsed)
    local from_point = create_offset_point(env, hero_point, direction, last_travel_distance, 0)
    local to_point = create_offset_point(env, hero_point, direction, curr_travel_distance, 0)
    if not from_point or not to_point then
      elapsed = next_elapsed
      if elapsed >= total_time then
        finished = true
      end
      return finished
    end
    play_particle_on_point(env, to_point, visual_cfg.particle_key, tonumber(opts and opts.tick_fx_scale) or 0.9, tonumber(opts and opts.tick_fx_time) or 0.20, 20)
    local segment_length = from_point.get_distance_with and from_point:get_distance_with(to_point) or math.max(1, curr_travel_distance - last_travel_distance)
    local pierced = safe_collect_units_in_line(env, from_point, to_point, segment_length, pierce_width, nil, nil)
    if opts and opts.guarantee_target_hit == true and target and target.is_exist and target:is_exist() then
      local exists = false
      for _, unit in ipairs(pierced) do
        if unit == target then
          exists = true
          break
        end
      end
      if not exists then
        pierced[#pierced + 1] = target
      end
    end
    for _, unit in ipairs(pierced) do
      if unit and unit.is_exist and unit:is_exist() then
        play_bond_sound(env, opts and opts.bond_name, 'impact', unit)
        play_particle_on_unit(env, unit, visual_cfg.particle_key, tonumber(opts and opts.hit_fx_scale) or 0.9, tonumber(opts and opts.hit_fx_time) or 0.18)
        if on_tick_hit then
          on_tick_hit(unit)
        end
      end
    end
    last_travel_distance = curr_travel_distance
    elapsed = next_elapsed
    if elapsed >= total_time then
      finished = true
    end
    return finished
  end

  if apply_tick(math.min(total_time, tick_interval)) then
    return true
  end
  local timer
  timer = y3.ltimer.loop(tick_interval, function()
    local done = apply_tick(elapsed + tick_interval)
    if done and timer and timer.remove then
      timer:remove()
    end
  end)
  return true
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
  local hit_units = api.area(center, radius or 320, math.max(1, env.round_number and env.round_number(amount) or math.floor(amount)), damage_type or '物理', {
    except_unit = except_unit,
    max_count = max_count,
    visual = visual,
  })
  return #hit_units > 0
end

collect_units_in_line = function(env, origin_point, impact_point, max_distance, line_width, max_hits, fallback_target)
  local result = {}
  if not env or not env.get_enemies_in_range or not origin_point or not impact_point then
    if fallback_target then
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
    if fallback_target then
      result[1] = fallback_target
    end
    return result
  end

  local reach = math.max(length, tonumber(max_distance) or length)
  local width = math.max(40, tonumber(line_width) or 95)
  local start_projection = math.max(0, length - width)
  local segment_length = reach - start_projection
  local max_target_count = tonumber(max_hits)
  if max_target_count then
    max_target_count = math.max(1, math.floor(max_target_count))
  end
  if segment_length <= 0 then
    if fallback_target then
      result[1] = fallback_target
    end
    return result
  end

  local direction = origin_point.get_angle_with and origin_point:get_angle_with(impact_point) or 0

  local function push_fallback_target()
    if #result == 0 and fallback_target and fallback_target.is_exist and fallback_target:is_exist() then
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
      if unit and unit.is_exist and unit:is_exist() and (not env.is_active_enemy or env.is_active_enemy(unit)) then
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
  local candidates = env.get_enemies_in_range(origin_point, query_radius, nil, 96) or {}
  local projected = {}

  for _, unit in ipairs(candidates) do
    if unit and unit.is_exist and unit:is_exist() and (not env.is_active_enemy or env.is_active_enemy(unit)) then
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
_G.collect_units_in_line = collect_units_in_line

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

local function has_card_effect(runtime, card_name)
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

  local direction = hero_point.get_angle_with and hero_point:get_angle_with(target_point) or 0
  local impact_point = create_offset_point(env, hero_point, direction, line_distance, 0) or target_point

  play_bond_sound(env, opts and opts.bond_name, 'cast', hero)
  launch_projectile_to_point(env, direction, line_distance, visual_cfg)
  play_particle_on_point(env, impact_point, visual_cfg.particle_key, tonumber(opts and opts.target_fx_scale) or 1.0, tonumber(opts and opts.target_fx_time) or 0.25, 20)

  local function apply_line_hit()
    local line_units = safe_collect_units_in_line(env, hero_point, impact_point, line_distance, line_width, max_hits, target)
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
    normalize_ratio_chance(trigger_floor, 0.08),
    normalize_ratio_chance(get_hero_attr(env, '物理暴击'), 0),
    0.22
  )
  if (effect_state.cooldown or 0) > 0 or not try_chance(trigger_chance) then
    return false
  end

  local has_tail_sweep = has_card_effect(runtime, '神龙摆尾')
  -- 提升火龙手感：基础射程/宽度上调，尾扫再额外强化覆盖
  local line_distance = has_tail_sweep and 1520 or 1200
  local line_width = has_tail_sweep and 360 or 260

  effect_state.cooldown = 1
  play_particle_on_unit(env, get_hero(env), visual_cfg.particle_key, 1.05, 0.22)

  local damage_scale = (extra_damage_scale or 1.0) * (has_card_effect(runtime, '龙族血统') and 1.20 or 1.0)
  local width_scale = (extra_radius_scale or 1.0) * (has_tail_sweep and 1.20 or 1.0)
  line_width = math.max(180, math.floor(line_width * width_scale + 0.5))
  local amount = (attack + max_hp * 0.05) * damage_scale * 1.18

  return execute_projectile_pierce_template(env, target, visual_cfg, {
    bond_name = '龙骑士',
    distance = line_distance,
    pierce_width = math.max(160, math.floor(line_width * 0.70)),
    projectile_speed = visual_cfg.projectile_speed,
    tick_interval = 0.75,
    guarantee_target_hit = true,
    tick_fx_scale = 1.05,
    tick_fx_time = 0.22,
    hit_fx_scale = 1.05,
    hit_fx_time = 0.24,
  }, function(unit)
    damage_target(env, unit, amount, '物理', { scope = 'bond', key = '龙骑士' })
    damage_target(env, unit, amount, '法术', { scope = 'bond', key = '龙骑士' })
  end)
end

local BondModifierSpecialEffects = BondModifierSpecialEffectsFactory.create({
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
  play_lightning_strike = play_lightning_strike,
  launch_projectile_to_target = launch_projectile_to_target,
  damage_target = damage_target,
  damage_area = damage_area,
  try_chance = try_chance,
  push_stack_expire = push_stack_expire,
  cleanup_stack_expire = cleanup_stack_expire,
  update_card_stack_attr = update_card_stack_attr,
  schedule_summon_lifecycle_fx = schedule_summon_lifecycle_fx,
  trigger_dragon_fireball_effect = trigger_dragon_fireball_effect,
  update_magic_swordsman_runtime_bonus = update_magic_swordsman_runtime_bonus,
  has_active_modifier_bond = M.has_active_modifier_bond,
})

local BondModifierCoreEffects = BondModifierCoreEffectsFactory.create({
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


local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'
local SkillFramework = require 'runtime.skill_framework'
local Skills = require 'runtime.skills'

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

local function build_vfx(kind)
  local projectile = RuntimeEditorIds.projectile or {}
  if kind == 'point_burst' then
    return {
      cast = 106082,
      warning = 106082,
      impact = 106089,
      hit = 106089,
      projectile_key = projectile.meteor or projectile.basic_attack or 201392013,
      projectile_height = 28,
      projectile_time = 0.70,
    }
  end
  return {
    cast = 106060,
    warning = 106060,
    impact = 106069,
    hit = 106069,
    projectile_key = projectile.basic_attack or 201391110,
    projectile_height = 20,
    projectile_time = 0.62,
  }
end

local function make_skill(id, name, desc, family, tier, coeff)
  local is_burst = family == 'point_burst'
  return {
    id = id,
    name = name,
    desc = desc,
    family = family,
    tier = tier,
    coeff = coeff,
    base_id = is_burst and 'sf_area_burst' or 'sf_line_pierce',
    pattern = is_burst and 'area_burst' or 'line_pierce',
    target_mode = is_burst and 'point' or 'unit',
    damage_type = coeff.damage_type,
    visual = build_vfx(family),
  }
end

local SKILLS = {
  make_skill('s_str_1', '裂地重斩', '向前劈出冲击波，对路径敌人造成[物理攻击×220% + 力量×90%]物理伤害。', 'line', 'mid', { attack_ratio = 2.20, stat_ratio = 0.90, stat = '力量', damage_type = '物理', cd = 0.80, range = 1100, width = 240 }),
  make_skill('s_str_2', '战吼震踏', '在目标点践踏爆发，对范围敌人造成[物理攻击×240% + 力量×110%]物理伤害。', 'point_burst', 'mid', { attack_ratio = 2.40, stat_ratio = 1.10, stat = '力量', damage_type = '物理', cd = 1.00, radius = 320 }),
  make_skill('s_str_3', '破阵突刺', '向前突刺贯穿敌阵，对路径敌人造成[物理攻击×260% + 力量×95%]物理伤害。', 'line', 'heavy', { attack_ratio = 2.60, stat_ratio = 0.95, stat = '力量', damage_type = '物理', cd = 1.20, range = 1350, width = 210 }),
  make_skill('s_str_4', '磐石坠击', '在目标点落下重击，对范围敌人造成[物理攻击×280% + 力量×120%]物理伤害。', 'point_burst', 'heavy', { attack_ratio = 2.80, stat_ratio = 1.20, stat = '力量', damage_type = '物理', cd = 1.30, radius = 360 }),
  make_skill('s_str_5', '不屈横扫', '向前横扫压制，对路径敌人造成[物理攻击×210% + 力量×85%]物理伤害。', 'line', 'light', { attack_ratio = 2.10, stat_ratio = 0.85, stat = '力量', damage_type = '物理', cd = 0.70, range = 980, width = 260 }),

  make_skill('s_dex_1', '穿心连射', '射出高速弹道，对首条路径敌人造成[物理攻击×205% + 敏捷×115%]物理伤害。', 'line', 'mid', { attack_ratio = 2.05, stat_ratio = 1.15, stat = '敏捷', damage_type = '物理', cd = 0.72, range = 1400, width = 160 }),
  make_skill('s_dex_2', '回旋刃雨', '在目标点抛出刃雨，对范围敌人造成[物理攻击×225% + 敏捷×125%]物理伤害。', 'point_burst', 'mid', { attack_ratio = 2.25, stat_ratio = 1.25, stat = '敏捷', damage_type = '物理', cd = 0.95, radius = 300 }),
  make_skill('s_dex_3', '疾风穿云', '发射穿云箭，对路径敌人造成[物理攻击×250% + 敏捷×130%]物理伤害。', 'line', 'heavy', { attack_ratio = 2.50, stat_ratio = 1.30, stat = '敏捷', damage_type = '物理', cd = 1.10, range = 1550, width = 140 }),
  make_skill('s_dex_4', '落影伏击', '在目标点引爆落影，对范围敌人造成[物理攻击×235% + 敏捷×140%]物理伤害。', 'point_burst', 'mid', { attack_ratio = 2.35, stat_ratio = 1.40, stat = '敏捷', damage_type = '物理', cd = 1.00, radius = 280 }),
  make_skill('s_dex_5', '三段追猎', '三段弹道追猎，对路径敌人造成[物理攻击×215% + 敏捷×120%]物理伤害。', 'line', 'mid', { attack_ratio = 2.15, stat_ratio = 1.20, stat = '敏捷', damage_type = '物理', cd = 0.82, range = 1200, width = 180 }),

  make_skill('s_int_1', '寒星坠落', '在目标点坠落寒星，对范围敌人造成[法术攻击×240% + 智力×130%]法术伤害。', 'point_burst', 'mid', { attack_ratio = 2.40, stat_ratio = 1.30, stat = '智力', damage_type = '法术', cd = 1.00, radius = 330 }),
  make_skill('s_int_2', '雷枪贯体', '发射雷枪弹道，对路径敌人造成[法术攻击×250% + 智力×120%]法术伤害。', 'line', 'mid', { attack_ratio = 2.50, stat_ratio = 1.20, stat = '智力', damage_type = '法术', cd = 0.90, range = 1450, width = 170 }),
  make_skill('s_int_3', '爆裂陨焰', '在目标点引爆陨焰，对范围敌人造成[法术攻击×285% + 智力×145%]法术伤害。', 'point_burst', 'heavy', { attack_ratio = 2.85, stat_ratio = 1.45, stat = '智力', damage_type = '法术', cd = 1.35, radius = 380 }),
  make_skill('s_int_4', '奥能穿刺', '发射奥能弹道，对路径敌人造成[法术攻击×230% + 智力×135%]法术伤害。', 'line', 'mid', { attack_ratio = 2.30, stat_ratio = 1.35, stat = '智力', damage_type = '法术', cd = 0.86, range = 1320, width = 190 }),
  make_skill('s_int_5', '虚空脉冲', '在目标点压缩后爆发，对范围敌人造成[法术攻击×265% + 智力×150%]法术伤害。', 'point_burst', 'mid', { attack_ratio = 2.65, stat_ratio = 1.50, stat = '智力', damage_type = '法术', cd = 1.15, radius = 340 }),

  make_skill('s_phy_1', '断岳重炮', '重炮弹道命中路径敌人，造成[物理攻击×255% + 力量×80%]物理伤害。', 'line', 'mid', { attack_ratio = 2.55, stat_ratio = 0.80, stat = '力量', damage_type = '物理', cd = 0.92, range = 1380, width = 200 }),
  make_skill('s_phy_2', '碎甲轰落', '在目标点轰落碎甲弹，对范围敌人造成[物理攻击×245% + 力量×100%]物理伤害。', 'point_burst', 'mid', { attack_ratio = 2.45, stat_ratio = 1.00, stat = '力量', damage_type = '物理', cd = 1.05, radius = 320 }),
  make_skill('s_phy_3', '血线切割', '血刃弹道切割路径敌人，造成[物理攻击×235% + 敏捷×105%]物理伤害。', 'line', 'mid', { attack_ratio = 2.35, stat_ratio = 1.05, stat = '敏捷', damage_type = '物理', cd = 0.84, range = 1280, width = 185 }),
  make_skill('s_phy_4', '连环爆矢', '在目标点爆裂连环矢，对范围敌人造成[物理攻击×260% + 敏捷×110%]物理伤害。', 'point_burst', 'heavy', { attack_ratio = 2.60, stat_ratio = 1.10, stat = '敏捷', damage_type = '物理', cd = 1.20, radius = 350 }),
  make_skill('s_phy_5', '猎杀贯穿', '猎杀弹道贯穿路径敌人，造成[物理攻击×270% + 敏捷×95%]物理伤害。', 'line', 'heavy', { attack_ratio = 2.70, stat_ratio = 0.95, stat = '敏捷', damage_type = '物理', cd = 1.10, range = 1500, width = 160 }),

  make_skill('s_spell_1', '霜狱爆点', '在目标点冻结爆点，对范围敌人造成[法术攻击×255% + 智力×125%]法术伤害。', 'point_burst', 'mid', { attack_ratio = 2.55, stat_ratio = 1.25, stat = '智力', damage_type = '法术', cd = 1.00, radius = 330 }),
  make_skill('s_spell_2', '炎脉贯流', '炎脉弹道贯流路径敌人，造成[法术攻击×245% + 智力×120%]法术伤害。', 'line', 'mid', { attack_ratio = 2.45, stat_ratio = 1.20, stat = '智力', damage_type = '法术', cd = 0.88, range = 1420, width = 175 }),
  make_skill('s_spell_3', '天雷定标', '在目标点定标落雷，对范围敌人造成[法术攻击×275% + 智力×135%]法术伤害。', 'point_burst', 'heavy', { attack_ratio = 2.75, stat_ratio = 1.35, stat = '智力', damage_type = '法术', cd = 1.22, radius = 360 }),
  make_skill('s_spell_4', '秘能光矛', '秘能光矛弹道命中路径敌人，造成[法术攻击×235% + 智力×140%]法术伤害。', 'line', 'mid', { attack_ratio = 2.35, stat_ratio = 1.40, stat = '智力', damage_type = '法术', cd = 0.86, range = 1360, width = 180 }),
  make_skill('s_spell_5', '虚焰震爆', '在目标点引爆虚焰，对范围敌人造成[法术攻击×290% + 智力×150%]法术伤害。', 'point_burst', 'heavy', { attack_ratio = 2.90, stat_ratio = 1.50, stat = '智力', damage_type = '法术', cd = 1.30, radius = 390 }),

  make_skill('s_summon_1', '魂枪指令', '召唤指令弹道打击路径敌人，造成[法术攻击×220% + 智力×110%]法术伤害。', 'line', 'mid', { attack_ratio = 2.20, stat_ratio = 1.10, stat = '智力', damage_type = '法术', cd = 0.84, range = 1260, width = 170 }),
  make_skill('s_summon_2', '灵阵坠击', '在目标点召唤灵阵爆发，对范围敌人造成[法术攻击×240% + 智力×120%]法术伤害。', 'point_burst', 'mid', { attack_ratio = 2.40, stat_ratio = 1.20, stat = '智力', damage_type = '法术', cd = 1.02, radius = 320 }),
  make_skill('s_summon_3', '傀儡掷枪', '傀儡投掷弹道穿透路径敌人，造成[物理攻击×230% + 力量×90%]物理伤害。', 'line', 'mid', { attack_ratio = 2.30, stat_ratio = 0.90, stat = '力量', damage_type = '物理', cd = 0.90, range = 1300, width = 200 }),
  make_skill('s_summon_4', '死灵爆心', '在目标点触发死灵爆心，对范围敌人造成[法术攻击×265% + 智力×130%]法术伤害。', 'point_burst', 'heavy', { attack_ratio = 2.65, stat_ratio = 1.30, stat = '智力', damage_type = '法术', cd = 1.20, radius = 360 }),
  make_skill('s_summon_5', '军团齐射', '军团弹道齐射路径敌人，造成[物理攻击×245% + 敏捷×100%]物理伤害。', 'line', 'mid', { attack_ratio = 2.45, stat_ratio = 1.00, stat = '敏捷', damage_type = '物理', cd = 0.88, range = 1400, width = 175 }),
}

function M.create(env)
  env = env or {}
  local skill_framework = SkillFramework.create({
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

  local defs = {}
  local by_id = {}
  local alias_to_id = {
    sf_line_pierce_mid = 's_str_1',
    sf_area_burst_mid = 's_int_1',
    sf_chain_bounce_mid = 's_dex_1',
    ['裂地重斩'] = 's_str_1',
    ['血怒处决'] = 's_str_2',
    ['猛冲践踏'] = 's_str_3',
    ['穿心连射'] = 's_dex_1',
    ['回旋刃阵'] = 's_dex_2',
    ['寒星坠落'] = 's_int_1',
    ['雷枪贯体'] = 's_int_2',
    ['爆裂陨焰'] = 's_int_3',
    ['虚空脉冲'] = 's_int_5',
  }
  local next_index = 1

  local function to_framework_def(row)
    local def = Skills.build_production_skill(row.base_id, row.tier, row.visual, {
      id = row.id,
      name = row.name,
      pattern = row.pattern,
      target_mode = row.target_mode,
      damage_type = row.coeff.damage_type,
      resource = { cooldown = row.coeff.cd },
      hit_model = {
        range = row.coeff.range,
        width = row.coeff.width,
        radius = row.coeff.radius,
        max_hits = 0,
      },
      scale = {
        attack_ratio = row.coeff.attack_ratio,
      },
    })
    return def
  end

  for _, row in ipairs(SKILLS) do
    local def = deepcopy(row)
    defs[#defs + 1] = def
    by_id[def.id] = def
    local framework_def = to_framework_def(def)
    if framework_def then
      skill_framework.register(framework_def)
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
    local query_id = tostring(sample_id or '')
    local resolved_id = alias_to_id[query_id] or query_id
    local def = by_id[resolved_id]
    if not def then
      return false, string.format('未知 sample 技能：%s', tostring(sample_id))
    end
    return skill_framework.cast_by_id(def.id)
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

  function api.reset_framework_telemetry(_)
    return true
  end

  function api.build_framework_tier_report()
    local rows = { '[sample_skills] v2 已重做：仅保留弹道(line_pierce) / 点爆(area_burst) 两种模式。' }
    rows[#rows + 1] = string.format('[sample_skills] 技能总数: %d', #defs)
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

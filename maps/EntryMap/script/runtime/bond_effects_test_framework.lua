local BondModifierEffects = require 'runtime.bond_modifier_effects'
local BondModifierPool = require 'data.tables.bond_modifier_pool'
local SkillVisuals = require 'data.tables.skill_visuals'

local M = {}

local function to_bool(v)
  return v == true
end

function M.run(env)
  local report = {
    total = 0,
    passed = 0,
    failed = 0,
    cases = {},
  }

  local function add_case(name, ok, detail, level)
    report.total = report.total + 1
    if ok then
      report.passed = report.passed + 1
    else
      report.failed = report.failed + 1
    end
    report.cases[#report.cases + 1] = {
      name = name,
      ok = to_bool(ok),
      detail = tostring(detail or ''),
      level = level or 'warn',
    }
  end

  -- 1) 羁绊别名归一化
  add_case(
    'alias: 寒冰法师 -> 冰霜法师',
    BondModifierEffects.normalize_bond_name('寒冰法师') == '冰霜法师',
    'normalize_bond_name("寒冰法师") 应映射为 冰霜法师',
    'critical'
  )
  add_case(
    'alias: 寒冰法 -> 冰霜法师',
    BondModifierEffects.normalize_bond_name('寒冰法') == '冰霜法师',
    'normalize_bond_name("寒冰法") 应映射为 冰霜法师',
    'high'
  )

  -- 2) 关键羁绊存在性
  local has_fire_dragon = false
  local has_ice_mage = false
  for _, effect in ipairs(BondModifierPool.activation_effects or {}) do
    if tostring(effect.bond_name) == '龙骑士' then
      has_fire_dragon = true
    elseif tostring(effect.bond_name) == '冰霜法师' then
      has_ice_mage = true
    end
  end
  add_case('pool: 龙骑士存在', has_fire_dragon, 'activation_effects 应包含 龙骑士', 'critical')
  add_case('pool: 冰霜法师存在', has_ice_mage, 'activation_effects 应包含 冰霜法师', 'critical')

  -- 3) 关键视觉资源配置
  local visual_map = SkillVisuals.visual_by_bond or {}
  local dragon_visual = visual_map['龙骑士']
  local ice_visual = visual_map['冰霜法师']
  add_case(
    'visual: 龙骑士 projectile_key',
    type(dragon_visual) == 'table' and tonumber(dragon_visual.projectile_key) and tonumber(dragon_visual.projectile_key) > 0,
    '龙骑士应配置有效 projectile_key',
    'high'
  )
  add_case(
    'visual: 冰霜法师 projectile_key',
    type(ice_visual) == 'table' and tonumber(ice_visual.projectile_key) and tonumber(ice_visual.projectile_key) > 0,
    '冰霜法师应配置有效 projectile_key',
    'high'
  )

  -- 4) 运行时接口可用性
  add_case(
    'api: trigger_modifier_basic_attack_effect',
    type(BondModifierEffects.trigger_modifier_basic_attack_effect) == 'function',
    'BondModifierEffects.trigger_modifier_basic_attack_effect 必须存在',
    'critical'
  )
  add_case(
    'api: trigger_modifier_periodic_effect',
    type(BondModifierEffects.trigger_modifier_periodic_effect) == 'function',
    'BondModifierEffects.trigger_modifier_periodic_effect 必须存在',
    'critical'
  )

  -- 5) 输出报告
  local message = env and env.message
  if message then
    message(string.format('[bond_test] total=%d pass=%d fail=%d', report.total, report.passed, report.failed))
    for _, case in ipairs(report.cases) do
      message(string.format(
        '[bond_test][%s][%s] %s | %s',
        case.ok and 'PASS' or 'FAIL',
        tostring(case.level),
        tostring(case.name),
        tostring(case.detail)
      ))
    end
  end

  return report
end

return M


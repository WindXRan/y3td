-- 验证"新增技能只靠数据就能生成定义"的目标
local Skills = require 'runtime.skills'

local def = Skills.build_element_skill('fire', 'area_burst', 'mid', {
  id = 'test_fire_burst',
  name = '测试火焰爆裂',
  desc = '只靠数据构建的技能',
  attack_ratio = 2.0,
  cooldown = 1.1,
})

assert(def.id == 'test_fire_burst', 'expected test_fire_burst, got ' .. tostring(def.id))
assert(def.pattern == 'area', 'expected area, got ' .. tostring(def.pattern))
assert(def.sub_behavior == 'burst', 'expected burst, got ' .. tostring(def.sub_behavior))
assert(def.damage_type == '法术', 'expected 法术, got ' .. tostring(def.damage_type))
assert(def.resource.cooldown == 1.1, 'expected cooldown 1.1, got ' .. tostring(def.resource.cooldown))

print('[PASS] test_skill_definition_smoke: 只靠数据构建的技能定义字段全部通过')

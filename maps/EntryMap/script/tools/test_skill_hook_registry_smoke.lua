-- 验证 fireball 的命中后灼烧不是写死在技能定义里，而是从 hook registry 挂上去
local Hooks = require 'runtime.skill_hooks'
local hook = Hooks.get('fireball', 'OnProjectileHit')
assert(type(hook) == 'function', 'expected fireball OnProjectileHit hook to exist')

-- 验证不存在的 hook 返回 nil
assert(Hooks.get('nonexistent', 'OnProjectileHit') == nil, 'expected nil for unknown skill')
assert(Hooks.get('fireball', 'OnSpellStart') == nil, 'expected nil for unregistered hook name')

print('[PASS] test_skill_hook_registry_smoke: hook 注册表独立可用')

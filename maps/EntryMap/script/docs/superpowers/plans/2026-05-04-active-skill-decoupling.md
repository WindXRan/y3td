# Active Skill Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把主动技能这条链路收口成“数据驱动 + 通用执行器 + 独立 hook”，让后续新增技能尽量只加数据，不再手写 boot 注册和技能特例。

**Architecture:** 以 `runtime.skill_framework` 作为唯一执行器，`runtime.skills` / `runtime.generated_skills` 作为技能定义入口，特殊效果单独放进 hook 注册表。`boot.lua` 只负责装配，不再硬编码具体技能。这样火球、区域瞬伤、区域持续伤害这三类技能仍然走同一套模式，但新增技能时只需要补定义和必要 hook。

**Tech Stack:** Lua 5.4, Y3 y3-lualib, 现有 `runtime/` 模块, 轻量 Lua smoke test, 现有 Python static smoke。

---

## File Map

- Modify: `maps/EntryMap/script/runtime/skill_framework.lua`
  - 收敛 pattern 分发、执行模板和默认值归一化。
- Modify: `maps/EntryMap/script/runtime/skills.lua`
  - 统一框架技能定义和元素技能构建规则，减少分散的 pattern 映射。
- Modify: `maps/EntryMap/script/runtime/generated_skills.lua`
  - 只保留 CSV -> 技能定义转换，不再写死特例 hook。
- Create: `maps/EntryMap/script/runtime/skill_hooks.lua`
  - 独立管理火球灼烧、未来新增命中后效果等技能特例。
- Modify: `maps/EntryMap/script/runtime/sample_skills.lua`
  - 复用统一技能定义来源，避免 sample 和生产链路各自维护一套映射。
- Modify: `maps/EntryMap/script/runtime/boot.lua`
  - 用数据驱动注册 `custom_area_dot` / `custom_area_burst`，并接入 hook 注册表。
- Modify: `maps/EntryMap/script/data_csv/element_skills.csv`
  - 必要时补齐技能元数据字段，作为新增技能的主入口。
- Add/Update tests:
  - `maps/EntryMap/script/tools/test_runtime_skill_framework_smoke.py`
  - `maps/EntryMap/script/tools/test_generated_skills_smoke.py`
  - `maps/EntryMap/script/tools/test_skill_hook_registry_smoke.lua`

---

### Task 1: 统一技能定义入口

**Files:**
- Modify: `maps/EntryMap/script/runtime/skills.lua`
- Modify: `maps/EntryMap/script/runtime/generated_skills.lua`
- Modify: `maps/EntryMap/script/runtime/sample_skills.lua`
- Modify: `maps/EntryMap/script/tools/test_generated_skills_smoke.py`
- Create: `maps/EntryMap/script/tools/test_skill_definition_smoke.lua`

- [ ] **Step 1: 先写一个最小失败用例，锁定“新增技能只靠数据就能生成定义”的目标**

在 `maps/EntryMap/script/tools/test_skill_definition_smoke.lua` 里构造一条最小技能定义，验证下面这些字段都能被框架吃进去：

```lua
local Skills = require 'runtime.skills'

local def = Skills.build_element_skill('fire', 'area_burst', 'mid', {
  id = 'test_fire_burst',
  name = '测试火焰爆裂',
  desc = '只靠数据构建的技能',
  attack_ratio = 2.0,
  cooldown = 1.1,
})

assert(def.id == 'test_fire_burst')
assert(def.pattern == 'area')
assert(def.sub_behavior == 'burst')
assert(def.damage_type == '法术')
assert(def.resource.cooldown == 1.1)
```

- [ ] **Step 2: 运行 smoke，确认当前已有结构还不能完全满足“只靠数据构建”**

运行：

```powershell
lua .\tools\test_skill_definition_smoke.lua
```

预期：先失败在缺失字段、重复映射或样式不一致。

- [ ] **Step 3: 把 `runtime.skills` 里的 pattern/base_id/visual 归一成一条链**

目标是让 `build_framework_skill -> build_framework_skill_tier -> build_production_skill -> build_element_skill` 只保留一份权威映射，去掉各处重复定义。重点动作：

```lua
-- 保留一份 pattern -> base_id 的表
-- 保留一份 pattern -> target_mode 的表
-- 保留一份 element -> vfx 的表
-- 旧别名只做兼容，不再参与新技能定义
```

- [ ] **Step 4: 让 `runtime.generated_skills` 只做 CSV 解析，不再夹杂技能特例**

把 `fireball` 的灼烧 hook 从 `generated_skills.lua` 挪走，`generated_skills.lua` 只负责：

```lua
local def = Skills.build_element_skill(...)
defs[#defs + 1] = def
```

不再在这里直接写 `def.hooks.OnProjectileHit = ...`。

- [ ] **Step 5: 运行 smoke，确认技能定义字段稳定**

运行：

```powershell
lua .\tools\test_skill_definition_smoke.lua
py -3 .\tools\test_generated_skills_smoke.py
```

预期：技能定义字段通过，且 CSV 驱动生成流程不再依赖写死特例。

---

### Task 2: 把特例行为抽成独立 hook 注册表

**Files:**
- Create: `maps/EntryMap/script/runtime/skill_hooks.lua`
- Modify: `maps/EntryMap/script/runtime/generated_skills.lua`
- Modify: `maps/EntryMap/script/runtime/boot.lua`
- Create: `maps/EntryMap/script/tools/test_skill_hook_registry_smoke.lua`

- [ ] **Step 1: 先写一个 hook 注册表失败用例**

`maps/EntryMap/script/tools/test_skill_hook_registry_smoke.lua` 只验证一件事：`fireball` 的命中后灼烧不是写死在技能定义里，而是从 hook registry 挂上去。

```lua
local Hooks = require 'runtime.skill_hooks'
local hook = Hooks.get('fireball', 'OnProjectileHit')
assert(type(hook) == 'function', 'expected fireball hook to exist')
```

- [ ] **Step 2: 运行 smoke，确认当前还没有独立 hook 注册表**

运行：

```powershell
lua .\tools\test_skill_hook_registry_smoke.lua
```

预期：失败，因为 `skill_hooks.lua` 还不存在。

- [ ] **Step 3: 新建 `runtime/skill_hooks.lua`，把特例行为集中管理**

把所有“技能定义之外的附加行为”放到同一个表里，先只实现火球这一个真实特例，接口保持统一：

```lua
local M = {}

local HOOKS = {
  fireball = {
    OnProjectileHit = function(ctx)
      -- 命中后灼烧
    end,
  },
}

function M.get(skill_id, hook_name)
  local skill_hooks = HOOKS[tostring(skill_id or '')]
  return skill_hooks and skill_hooks[hook_name] or nil
end

return M
```

- [ ] **Step 4: 在技能注册时自动挂载 hook，而不是在定义文件里手写**

在 `generated_skills.lua` 里注册完 `def` 后，从 `skill_hooks` 查询并挂到 `def.hooks`。这样新增特例时只改 hook 表，不动 CSV 驱动链路。

- [ ] **Step 5: 再跑一次 smoke，确认 hook 仍然可用**

运行：

```powershell
lua .\tools\test_skill_hook_registry_smoke.lua
py -3 .\tools\test_generated_skills_smoke.py
```

预期：hook 可查，技能定义照常生成。

---

### Task 3: 去掉 `boot.lua` 里的手写技能注册

**Files:**
- Modify: `maps/EntryMap/script/runtime/boot.lua`
- Modify: `maps/EntryMap/script/tools/test_runtime_skill_framework_smoke.py`

- [ ] **Step 1: 先写一个失败用例，锁定“boot 不再手写技能”**

在 `maps/EntryMap/script/tools/test_runtime_skill_framework_smoke.py` 里加断言，检查 `boot.lua` 不再出现 `custom_area_dot` / `custom_area_burst` 的直接注册片段。

```python
from pathlib import Path

text = Path(r"maps/EntryMap/script/runtime/boot.lua").read_text(encoding="utf-8")
assert "custom_area_dot" not in text or "skill_framework_system.register({" not in text
assert "custom_area_burst" not in text or "skill_framework_system.register({" not in text
```

- [ ] **Step 2: 运行 smoke，确认当前还会命中手写注册**

运行：

```powershell
py -3 .\tools\test_runtime_skill_framework_smoke.py
```

预期：失败，因为 `boot.lua` 仍直接写了两个技能注册块。

- [ ] **Step 3: 把这两个技能定义下沉到数据入口**

把 `custom_area_dot`、`custom_area_burst` 改成和 `fireball` 同样的数据流：定义字段放进 CSV 或统一定义表，`boot.lua` 只负责调用批量注册。

- [ ] **Step 4: 在 `boot.lua` 里保留一个批量注册入口，不再写单技能块**

目标结构：

```lua
local defs = GeneratedSkills.load_defs()
for _, def in ipairs(defs) do
  skill_framework_system.register(def)
end
```

这样后面新增技能不需要继续往 boot 里加段落。

- [ ] **Step 5: 复跑 smoke，确认 boot 只做装配**

运行：

```powershell
py -3 .\tools\test_runtime_skill_framework_smoke.py
```

预期：通过。

---

### Task 4: 清理旧映射和重复路径

**Files:**
- Modify: `maps/EntryMap/script/runtime/skill_framework.lua`
- Modify: `maps/EntryMap/script/runtime/skills.lua`
- Modify: `maps/EntryMap/script/runtime/sample_skills.lua`

- [ ] **Step 1: 先整理 skill_framework 的 pattern 分发**

把 `execute_pattern`、`VALID_PATTERN`、`VALID_SUB_BEHAVIOR` 以及 `area_burst` / `area_tick` 的兼容逻辑收拢成一组可维护的 dispatcher，不再在多个地方重复同样的模式判断。

```lua
local PATTERN_EXECUTORS = {
  projectile = execute_projectile,
  area = execute_area,
}
```

让 `pattern` 只负责选执行器，`sub_behavior` 只负责细分行为。

- [ ] **Step 2: 收敛 `skills.lua` 和 `sample_skills.lua` 的重复映射**

两处都在做 `pattern -> base_id`、`pattern -> target_mode` 之类的工作。计划里只保留一份共享表，另一份直接复用，不再维护两套枚举。

- [ ] **Step 3: 删除所有已失效的兼容分支**

确认没有旧调用后，清掉这些只为历史遗留准备的路径：

```lua
line_pierce
chain_bounce
area_burst
area_tick
```

保留兼容别名，但不再让新技能走旧别名入口。

- [ ] **Step 4: 验证新增技能仍能在 sample 路径里正常跑通**

运行：

```powershell
py -3 .\tools\test_generated_skills_smoke.py
lua .\tools\test_skill_definition_smoke.lua
```

预期：通过，且 sample 路径仍能从统一定义源读取。

---

## Self-Review

### Spec Coverage

- 主动技能数据驱动入口统一：Task 1
- 特例 hook 解耦：Task 2
- boot 去硬编码注册：Task 3
- 重复映射与旧兼容清理：Task 4

### Placeholder Scan

- 没有 `TODO` / `TBD`
- 每个任务都指向了具体文件
- 每个验证步骤都有明确命令和预期结果

### Type Consistency

- `skill_framework` 仍是唯一执行器
- `skill_hooks.get(skill_id, hook_name)` 作为特例入口
- `GeneratedSkills.load_defs()` 仍是批量技能入口
- `boot.lua` 只保留装配逻辑


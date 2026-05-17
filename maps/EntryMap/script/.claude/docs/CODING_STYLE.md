# Lua 代码命名规范

## 概述

本文档定义项目中 Lua 代码的命名规范，确保代码风格统一，提高可读性和可维护性。

---

## 1. 文件命名

### ✅ 推荐格式
- **全小写 + 下划线分隔**（snake_case）
- 示例：`sample_skills.lua`、`runtime_hud.lua`、`event_bus.lua`

### ❌ 避免格式
- PascalCase：`SampleSkills.lua`
- camelCase：`sampleSkills.lua`

### 📝 说明
- Lua 社区推荐 snake_case 作为标准命名风格
- 避免大小写敏感问题（某些文件系统不区分大小写）
- 保持与现有大多数文件一致

---

## 2. 模块导出表命名

### ✅ 推荐格式
- **PascalCase**（首字母大写）
- 示例：`SkillFramework`、`EventBus`、`BootCore`

### 📝 原因
- 区分模块定义与实例
- 与 Lua 标准库（如 `io`、`table`、`string`）保持一致
- 明确标识这是"类型"或"类"定义

### ❌ 避免格式
- 全小写：`skill_framework`、`event_bus`（与文件名混淆）
- 全大写：`SKILL_FRAMEWORK`（与常量混淆）

---

## 3. 工厂函数命名

### ✅ 推荐格式
- **统一使用 `create()`**
- 示例：`SkillFramework.create()`

### ❌ 避免格式
- PascalCase：`Create()`、`New()`
- 混合：`CreateSkill()`、`makeSkill()`

### 📝 说明
- 工厂函数统一命名，减少记忆负担
- 如果需要多个工厂函数，使用 `create()`、`createWith()` 等变体

---

## 4. 实例变量命名

### ✅ 推荐格式
- **snake_case**（小写 + 下划线）
- 示例：
  ```lua
  local skill_framework = require 'runtime.skill_framework'
  local framework_instance = skill_framework.create()
  ```

### 📝 说明
- 与模块文件命名保持一致
- 避免与模块定义混淆

### ❌ 避免格式
- PascalCase：`FrameworkInstance`（与类型混淆）
- 过度缩写：`fi`、`sf`（可读性差）

---

## 5. 全局变量（_G）命名

### ✅ 推荐格式
- **根据用途选择**：

#### 5.1 常量（只读配置）
- **全大写 + 下划线**
- 示例：
  ```lua
  _G.CONFIG = config_data
  _G.ATTACK_SKILL_DEFS = defs_table
  _G.ATTACK_SKILL_SLOT_COUNT = 5
  ```

#### 5.2 系统实例
- **snake_case + `_system` 后缀**
- 示例：
  ```lua
  _G.skill_framework_system = skill_framework.create()
  _G.event_bus_system = event_bus.create()
  _G.runtime_hud_system = runtime_hud.create()
  ```

#### 5.3 状态对象
- **全大写**
- 示例：
  ```lua
  _G.STATE = {}
  _G.SkillRuntime = SkillRuntime
  _G.SkillState = SkillState
  ```

#### 5.4 工具函数
- **snake_case**
- 示例：
  ```lua
  _G.get_player = function() ... end
  _G.random_point_in_area = function() ... end
  _G.message = function() ... end
  ```

---

## 6. 局部变量命名

### ✅ 推荐格式
- **snake_case**（小写 + 下划线）
- 示例：
  ```lua
  local current_wave_index = 1
  local hero_object = unit:get_hero()
  local damage_ratio = 1.5
  ```

### ❌ 避免格式
- 单字母：`a`、`b`、`x`（除非是循环计数器）
- 匈牙利命名：`strName`、`nCount`（违反 Lua 风格）
- PascalCase 局部变量：`CurrentWaveIndex`

---

## 7. 函数命名

### ✅ 推荐格式
- **snake_case**
- 示例：
  ```lua
  local function get_player_id()
    return player:get_id()
  end

  function M.subscribe(event, handler)
    -- ...
  end
  ```

### 📝 说明
- 公共方法（导出表上）：使用 `M.method_name` 格式
- 私有方法：使用 `local function method_name()` 格式

---

## 8. 类和元表命名

### ✅ 推荐格式
- **PascalCase** + `.__index` 元方法
- 示例：
  ```lua
  local SkillRuntime = {}
  SkillRuntime.__index = SkillRuntime

  function SkillRuntime:create()
    local instance = setmetatable({}, SkillRuntime)
    return instance
  end
  ```

---

## 9. 表格键名

### ✅ 推荐格式
- **根据上下文选择**：
  - **字符串键**：snake_case
    ```lua
    local data = {
      skill_id = 'fireball',
      damage_ratio = 2.0,
      cooldown_seconds = 5,
    }
    ```

  - **枚举/常量键**：snake_case（小写）
    ```lua
    local SKILL_TYPE = {
      attack = 1,
      defense = 2,
      utility = 3,
    }
    ```

  - **面向对象属性**：PascalCase
    ```lua
    local hero = {
      Name = 'Archer',
      Level = 10,
      MaxHP = 1000,
    }
    ```

---

## 10. 注释和文档

### ✅ 推荐格式
- **中文注释**（符合项目要求）
- 示例：
  ```lua
  --- 技能运行时状态管理器
  --- @class SkillRuntime
  local SkillRuntime = {}

  --- 创建技能实例
  --- @param skill_id string 技能ID
  --- @param slot number 槽位索引
  --- @return SkillRuntime 实例
  function SkillRuntime:create_instance(skill_id, slot)
    -- ...
  end
  ```

---

## 11. 现有代码迁移指南

### 优先级

#### 高优先级（立即统一）
1. **boot.lua 中的全局变量导出**
   - `_G.runtime_hud_system` → `_G.runtime_hud_system` ✅（已符合）
   - `_G.result_panel_system` → `_G.result_panel_system` ✅（已符合）
   - `_G.growth_weapon_item_tip_system` → `_G.growth_weapon_item_tip_system` ✅（已符合）

2. **工厂函数命名统一**
   - 统一使用 `create()` 而非 `Create()`

#### 中优先级（逐步迁移）
3. **模块导出表命名**
   - 保持 PascalCase（如 `EventBus`、`SkillFramework`）
   - 避免在 boot.lua 中混用 `event_bus` 和 `EventBus`

4. **局部变量命名**
   - 统一使用 snake_case
   - 避免 PascalCase 局部变量

#### 低优先级（选择性优化）
5. **性能关键代码**
   - 允许使用简短变量名（如循环计数器）
   - 但需添加注释说明

---

## 12. 检查清单

在提交代码前，请确认：

- [ ] 文件名使用 snake_case
- [ ] 模块导出表使用 PascalCase
- [ ] 工厂函数命名为 `create()`
- [ ] 全局常量使用 UPPER_SNAKE_CASE
- [ ] 全局系统实例使用 snake_case + `_system` 后缀
- [ ] 局部变量使用 snake_case
- [ ] 函数名使用 snake_case
- [ ] 注释使用中文

---

## 13. 示例对比

### ❌ 不一致命名（当前问题）
```lua
-- boot.lua
local RuntimeHudSystem = require 'ui.runtime_hud'
local runtime_hud_system = RuntimeHudSystem.create()
_G.runtime_hud_system = runtime_hud_system

local event_bus = require 'runtime.event_bus'
_G.event_bus = event_bus
```

### ✅ 统一命名（建议改进）
```lua
-- boot.lua
local RuntimeHud = require 'ui.runtime_hud'
local hud = RuntimeHud.create()
_G.hud_system = hud

local EventBus = require 'runtime.event_bus'
_G.event_bus_system = EventBus.create()
```

---

## 14. 总结

| 元素 | 推荐命名 | 示例 |
|------|----------|------|
| 文件名 | snake_case | `sample_skills.lua` |
| 模块导出表 | PascalCase | `SkillFramework` |
| 工厂函数 | `create()` | `module.create()` |
| 全局常量 | UPPER_SNAKE_CASE | `_G.CONFIG` |
| 全局系统实例 | snake_case | `_G.hud_system` |
| 局部变量 | snake_case | `local current_index` |
| 函数名 | snake_case | `get_player()` |

---

**维护者**：项目技术团队
**最后更新**：2026-05-17
**版本**：v1.1（移除向后兼容别名）

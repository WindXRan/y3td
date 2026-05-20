# 代码风格对比分析

## 一、风格来源定位

### y3 仓库风格
- **代码位置**: `script/y3/` 目录下所有文件
- **归属**: Y3 引擎官方框架代码

### 业务代码风格
- **代码位置**: `script/runtime/`、`script/ui/`、`script/tools/` 等
- **归属**: 项目业务逻辑代码

---

## 二、核心差异对比

| 维度 | y3 仓库风格 | 业务代码风格 |
|-----|------------|-------------|
| **模块定义** | 使用 `Class 'ClassName'` 宏 | 使用 `local M = {}` |
| **类型注解** | 大量 TypeDoc 注解 | 极少或无类型注解 |
| **类定义** | 基于 `Class` 系统的面向对象 | 基于 table 的模块模式 |
| **方法定义** | `function M:method_name()` | `function M.method_name()` |
| **构造函数** | 使用 `__init` 方法 | 使用 `create_xxx()` 工厂函数 |
| **状态管理** | 封装在类实例内部 | 依赖全局 `_G.STATE` |
| **命名风格** | `get_by_handle`、`add_unit` | `ensure_xxx`、`spawn_xxx` |
| **错误处理** | 使用 `error()` 抛出异常 | 使用 `pcall()` 安全调用 |

---

## 三、代码示例对比

### y3 仓库风格（框架层）

```lua
-- script/y3/object/runtime_object/unit_group.lua
---@class UnitGroup
---@field handle py.UnitGroup
local M = Class 'UnitGroup'

function M:__init(py_unit_group)
    self.handle = py_unit_group
    return self
end

---@param unit Unit 单位
function M:add_unit(unit)
    GameAPI.add_unit_to_group(unit.handle, self.handle)
end
```

### 业务代码风格

```lua
-- script/runtime/effects/buff_system.lua
local M = {}

local STATE = _G.STATE

function M.apply_buff(unit, template_id, duration, stacks, source)
    local template = find_template(template_id)
    if not template then return nil end
    
    local unit_buffs = get_unit_buffs(unit)
    pcall(unit.add_attr, unit, template.attr_name, value, '增益')
end
```

---

## 四、设计理念差异

| 方面 | y3 仓库风格 | 业务代码风格 |
|-----|------------|-------------|
| **封装性** | 高，隐藏实现细节 | 低，直接访问全局状态 |
| **可复用性** | 高，通用组件设计 | 中，业务耦合度较高 |
| **类型安全** | 强，依赖 TypeDoc 注解 | 弱，动态类型为主 |
| **错误处理** | 严格，主动抛出异常 | 宽松，防御性编程 |
| **架构定位** | 基础设施层 | 业务逻辑层 |

---

## 五、采用 y3 仓库风格的优缺点

### 优点
1. **代码结构更清晰**：类定义配合 TypeDoc 注解，意图明确
2. **更好的封装与可维护性**：getter/setter 机制，生命周期管理
3. **类型安全与 IDE 支持**：自动补全、类型检查、跳转定义
4. **与框架层风格一致**：降低跨模块理解成本

### 缺点
1. **学习曲线**：需要熟悉 Class 系统的使用方式
2. **性能开销**：元表机制引入额外开销
3. **灵活性受限**：OO 模式相对更重
4. **迁移成本**：现有代码迁移需要投入时间

---

## 六、适用场景建议

| 场景 | 推荐采用 y3 风格 | 保持现有风格 |
|-----|-----------------|-------------|
| 通用组件 | ✓ | ✗ |
| 频繁复用的逻辑 | ✓ | ✗ |
| 需要类型约束的模块 | ✓ | ✗ |
| 快速原型开发 | ✗ | ✓ |
| 一次性业务逻辑 | ✗ | ✓ |
| 与底层 API 交互层 | ✓ | ✗ |

---

## 七、推荐方案：混合模式

根据模块职责选择合适的风格：

```lua
-- 核心业务对象使用 y3 风格
---@class SkillRuntime
local SkillRuntime = Class 'SkillRuntime'

function SkillRuntime:__init(skill_id)
    self.id = skill_id
    self.level = 1
end

-- 业务流程使用现有风格
local SkillSystem = {}

function SkillSystem.upgrade_skill(hero, skill_id)
    local runtime = New 'SkillRuntime' (skill_id)
    -- ...
end
```

---

## 八、关键识别特征

### y3 仓库代码特征
- 文件头部有 `---@class` 注解
- 使用 `Class 'XXX'` 定义类
- 方法使用冒号语法 `M:method()`
- 包含 `py_converter` 注册逻辑
- 调用 `GameAPI`、`GlobalAPI` 等底层接口

### 业务代码特征
- 文件开头是 `local M = {}`
- 大量访问 `_G.STATE`
- 使用 `pcall()` 包裹外部调用
- 函数名以 `ensure_`、`spawn_`、`update_` 开头

---

## 九、总结

| 维度 | 结论 |
|-----|------|
| 是否推荐全面迁移 | 不建议，成本收益比不高 |
| 新开发模块 | 建议尝试 y3 风格 |
| 核心业务对象 | 推荐使用 y3 风格封装 |
| 工具函数/一次性逻辑 | 保持现有风格 |

**最终建议**：在新建模块时尝试 y3 风格，特别是需要封装复用的核心对象；对于快速迭代的业务逻辑，保持现有风格更高效。

# 代码风格规范

**强制要求**：所有新增业务代码必须采用 **y3 仓库风格** 编写。

## 一、风格选择声明

本项目**强制推荐**使用 **y3 仓库风格**（基于 `Class` 系统的面向对象风格）进行代码编写。现有业务代码风格（基于 `local M = {}` 的模块模式）仅用于维护历史代码，**新开发必须遵循 y3 仓库风格**。

---

## 二、风格来源定位

### y3 仓库风格（推荐/强制）
- **代码位置**: `script/y3/` 目录下所有文件
- **归属**: Y3 引擎官方框架代码
- **状态**: **强制推荐用于新代码**

### 业务代码风格（兼容/维护）
- **代码位置**: `script/runtime/`、`script/ui/`、`script/tools/` 等历史代码
- **归属**: 项目业务逻辑代码
- **状态**: **仅用于维护历史代码，禁止新代码使用**

---

## 三、核心差异对比

| 维度 | y3 仓库风格（推荐） | 业务代码风格（兼容） |
|-----|-------------------|-------------------|
| **模块定义** | 使用 `Class 'ClassName'` 宏 | 使用 `local M = {}` |
| **类型注解** | 强制 TypeDoc 注解 | 极少或无类型注解 |
| **类定义** | 基于 `Class` 系统的面向对象 | 基于 table 的模块模式 |
| **方法定义** | `function M:method_name()` | `function M.method_name()` |
| **构造函数** | 使用 `__init` 方法 | 使用 `create_xxx()` 工厂函数 |
| **状态管理** | 封装在类实例内部 | 依赖全局 `_G.STATE` |
| **命名风格** | `get_by_handle`、`add_unit` | `ensure_xxx`、`spawn_xxx` |
| **错误处理** | 使用 `error()` 抛出异常 | 使用 `pcall()` 安全调用 |
| **新代码** | **强制使用** | **禁止使用** |

---

## 四、代码示例对比

### y3 仓库风格（必须使用）

```lua
-- script/runtime/effects/buff_system.lua
---@class BuffSystem
---@field private buff_instances table<string, table<string, BuffInstance>>
local M = Class 'BuffSystem'

---@class BuffInstance
---@field template table
---@field remain_time number
---@field stacks integer

function M:__init()
    self.buff_instances = {}
end

---@param unit table
---@param template_id string
---@param duration number|nil
---@param stacks integer|nil
---@param source table|nil
---@return BuffInstance|nil
function M:apply_buff(unit, template_id, duration, stacks, source)
    local template = self:_find_template(template_id)
    if not template then
        error("Buff template not found: " .. tostring(template_id))
    end
    
    local unit_key = self:_get_unit_key(unit)
    self.buff_instances[unit_key] = self.buff_instances[unit_key] or {}
    
    local instance = {
        template = template,
        remain_time = duration or template.duration,
        stacks = stacks or 1,
        source = source,
    }
    self.buff_instances[unit_key][template_id] = instance
    
    self:_apply_attr_change(unit, template, instance.stacks)
    return instance
end

---@private
---@param template_id string
---@return table|nil
function M:_find_template(template_id)
    return _G.CONFIG and _G.CONFIG.GameTables 
        and _G.CONFIG.GameTables.buff_templates 
        and _G.CONFIG.GameTables.buff_templates.by_id[template_id]
end
```

### 业务代码风格（禁止新代码使用）

```lua
-- 旧风格示例，仅用于历史代码维护
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

## 五、设计理念差异

| 方面 | y3 仓库风格 | 业务代码风格 |
|-----|------------|-------------|
| **封装性** | 高，隐藏实现细节 | 低，直接访问全局状态 |
| **可复用性** | 高，通用组件设计 | 中，业务耦合度较高 |
| **类型安全** | 强，依赖 TypeDoc 注解 | 弱，动态类型为主 |
| **错误处理** | 严格，主动抛出异常 | 宽松，防御性编程 |
| **架构定位** | 基础设施层 | 业务逻辑层 |
| **新代码** | **强制** | **禁止** |

---

## 六、强制规范

### 6.1 类定义规范

```lua
---@class YourClassName
---@field public field_name type
---@field private _private_field type
local M = Class 'YourClassName'

function M:__init(params)
    -- 初始化逻辑
    return self
end
```

### 6.2 方法定义规范

```lua
---@param param_name type
---@return type
function M:method_name(param_name)
    -- 方法逻辑
end

---private
function M:_private_method()
    -- 私有方法逻辑
end
```

### 6.3 类型注解规范（强制）

```lua
---@class MyClass
---@field public name string
---@field public value number
---@field private _
# 项目架构对比分析报告

## 一、概述

本报告对比分析了两个项目的架构设计：
- **EntryMap**：当前项目，采用模块 require + 上下文注入模式
- **xunhuanquan**：参考项目，采用触发器事件驱动架构

## 二、xunhuanquan 架构分析

### 2.1 核心架构模式

**事件驱动架构（Event-Driven Architecture）**

项目的核心驱动力是**触发器系统**，所有业务逻辑通过事件触发执行：

```lua
-- 事件绑定示例
y3.game:on_custom_event(1652038731, function(event_data)
    -- 事件处理逻辑
end)
```

### 2.2 领域划分结构

按**功能领域**清晰划分模块，每个领域是独立的业务单元：

| 领域 | 职责 | 文件示例 |
|-----|------|---------|
| **回合事件** | 回合流程控制（刷怪、波次管理） | `回合开始事件.lua`、`刷普通敌人.lua` |
| **武将事件** | 武将生命周期（出生、升阶、遣散） | `武将出生动作.lua`、`武将升阶动作.lua` |
| **基础规则** | 核心游戏规则（伤害、胜负结算） | `伤害结算公式.lua`、`游戏胜利结算.lua` |
| **中控台** | 玩家交互界面（备战区管理） | `中控台刷新.lua`、`备战区排序.lua` |
| **军需处** | 装备商店系统 | `南兵北器刷新事件.lua` |
| **求贤处** | 武将招募系统 | `普通求贤.lua`、`高级求贤.lua` |

### 2.3 分层设计

采用**动作层**与**显示层**分离：

| 层级 | 职责 | 示例 |
|-----|------|-----|
| **动作层** | 处理业务逻辑 | `[动作层]购买装备成功.lua` |
| **显示层** | 同步 UI 状态 | `[显示层]南兵北器结果同步.lua` |

### 2.4 架构优势

| 优势 | 说明 |
|-----|------|
| **高内聚低耦合** | 每个领域模块独立，职责单一 |
| **易于扩展** | 新增功能只需添加新触发器文件 |
| **逻辑可视化** | 触发器结构清晰，便于理解业务流程 |
| **热更新友好** | 触发器可单独重载，无需重启游戏 |

## 三、EntryMap 当前架构分析

### 3.1 核心架构模式

**模块 require + 上下文注入模式**

```lua
-- init.lua
local ctx = {
  STATE = STATE, CONFIG = CONFIG, y3 = y3, ...
}
require('runtime.combat.battlefield.utils')(ctx)
require('runtime.combat.battlefield.reactions')(ctx)
```

### 3.2 当前架构问题

| 问题类型 | 表现 | 影响 |
|---------|------|------|
| **全局变量泛滥** | `_G.STATE`, `_G.CONFIG`, `_G.get_player` | 隐式依赖，难以追踪 |
| **跨层依赖** | `boot.lua` 直接 require 各层模块 | 耦合度高 |
| **重复 require** | 多个模块 require 相同依赖 | 冗余加载 |
| **循环依赖风险** | `boot_combat` ↔ `battlefield_system` | 初始化顺序敏感 |

### 3.3 当前模块结构

```
runtime/
├── combat/           # 战斗系统
│   ├── battlefield/  # 战场管理
│   ├── battle_logic.lua
│   └── skill_handlers.lua
├── heroes/           # 英雄系统
├── effects/          # 效果系统
├── progression/      # 成长系统
├── rounds/           # 回合系统
└── core/             # 核心工具
```

## 四、架构对比

### 4.1 核心差异

| 维度 | EntryMap | xunhuanquan |
|-----|---------|-------------|
| **架构模式** | 模块 require + 上下文注入 | 触发器事件驱动 |
| **入口** | `boot.lua` 统一加载 | 触发器系统 |
| **状态管理** | 全局 `_G.STATE` | 触发器内部 + KV存储 |
| **逻辑组织** | 按技术层（runtime/combat/effects） | 按业务领域（回合/武将/资源） |
| **事件机制** | `EventBus` 发布订阅 | `on_custom_event` 触发器 |
| **扩展方式** | 添加新模块 + require | 添加新触发器文件 |

### 4.2 适用场景对比

| 场景 | EntryMap | xunhuanquan |
|-----|---------|-------------|
| **快速迭代** | ⭐⭐ | ⭐⭐⭐ |
| **复杂业务逻辑** | ⭐⭐⭐ | ⭐⭐⭐ |
| **热更新需求** | ⭐⭐ | ⭐⭐⭐ |
| **多人协作** | ⭐⭐ | ⭐⭐⭐ |
| **性能敏感场景** | ⭐⭐⭐ | ⭐⭐ |

## 五、改进建议

### 5.1 架构优化方向

参考 xunhuanquan 的事件驱动模式，建议进行以下优化：

```
┌─────────────────────────────────────────────────────┐
│                   Event Bus                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐            │
│  │ 事件发布 │→│ 事件路由 │→│ 事件处理 │            │
│  └─────────┘  └─────────┘  └─────────┘            │
└─────────────────────────────────────────────────────┘
         │              │              │
         ▼              ▼              ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│   战斗领域    │ │   英雄领域    │ │   资源领域    │
│  battlefield  │ │    heroes     │ │   resources   │
└───────────────┘ └───────────────┘ └───────────────┘
```

### 5.2 具体改进措施

| 措施 | 说明 | 优先级 |
|-----|------|-------|
| **领域划分重组** | 按业务领域重新组织模块 | 高 |
| **事件总线引入** | 建立统一事件总线，解耦模块依赖 | 高 |
| **全局变量清理** | 减少 `_G` 挂载，使用系统定位器 | 中 |
| **依赖注入容器** | 建立 DI 容器管理模块依赖 | 中 |
| **触发器模式引入** | 对于频繁变更的业务逻辑采用触发器模式 | 低 |

### 5.3 代码示例：领域模块重构

```lua
-- 重构后的战斗领域模块
---@class BattlefieldSystem
---@field private eventBus EventBus
---@field private state table
local BattlefieldSystem = Class 'BattlefieldSystem'

function BattlefieldSystem:__init(eventBus, state)
    self.eventBus = eventBus
    self.state = state
    self:_subscribe_events()
end

function BattlefieldSystem:_subscribe_events()
    self.eventBus:on('wave_start', function(data)
        self:_handle_wave_start(data)
    end)
    self.eventBus:on('enemy_death', function(data)
        self:_handle_enemy_death(data)
    end)
end

function BattlefieldSystem:_handle_wave_start(data)
    -- 波次开始处理逻辑
end

function BattlefieldSystem:_handle_enemy_death(data)
    -- 敌人死亡处理逻辑
end

return BattlefieldSystem
```

## 六、总结

### 6.1 架构评估

| 项目 | 优点 | 改进空间 |
|-----|------|---------|
| **EntryMap** | 结构清晰，适合复杂逻辑 | 减少全局依赖，提高可测试性 |
| **xunhuanquan** | 高扩展性，热更新友好 | 性能优化空间 |

### 6.2 推荐方案

建议采用**混合架构**：
1. **核心系统**：保持当前的模块 require 模式，确保性能和稳定性
2. **业务逻辑**：采用触发器事件驱动模式，提高扩展性
3. **事件总线**：引入统一事件总线，解耦模块间通信

### 6.3 实施路径

| 阶段 | 任务 | 时间估计 |
|-----|------|---------|
| **Phase 1** | 引入事件总线，建立领域边界 | 2-3 周 |
| **Phase 2** | 重构战斗系统为领域模块 | 3-4 周 |
| **Phase 3** | 重构英雄和资源系统 | 3-4 周 |
| **Phase 4** | 清理全局变量，建立 DI 容器 | 2-3 周 |

---

**文档版本**: v1.0  
**创建日期**: 2026-05-20  
**适用范围**: EntryMap 项目架构优化参考
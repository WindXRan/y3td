# Runtime 目录重组方案

> 借鉴 xunhuanquan 项目的领域驱动组织方式，将当前扁平的 `runtime/` 目录（66 个 Lua 文件 + 2 个子目录）重组为按游戏领域分组的树状结构。

## 一、xunhuanquan 参考模型解析

### 1.1 组织原则

xunhuanquan 的 `lua_triggers/` 采用**中文领域目录**作为顶层分组，每个目录代表一个独立的游戏子系统：

```
初始化/       — 游戏初始化（加载项、玩家项、UI初始化）
回合事件/     — 波次/回合相关（刷怪、BOSS、回合信息同步）
基础规则/     — 核心规则（伤害公式、胜负结算、掉线处理）
中台/         — 中央事件路由
军需处/       — 装备/物品商店
求贤处/       — 英雄招募
库房/         — 物品仓库
军乐台/       — 悬赏/任务系统
伤害记录器/   — 伤害/击杀统计
资源结算/     — 资源产出结算
选中单位/     — 选中单位处理
悬浮提示/     — Tooltip/提示
武将事件/     — 英雄相关事件
多语言/       — i18n
```

其核心思想：**一个目录 = 一个游戏领域 = 一个玩家可认知的功能模块**。

### 1.2 两大关键约定

**约定一：`[N]描述.lua` — 数字前缀控制加载顺序**

```
初始化/
  [1]游戏加载项_标准定义.lua       ← 最先加载
  [2]游戏加载项_敌人池.lua
  [3]游戏加载项_列传池.lua
  [4]游戏加载项_名品池.lua
  [7]游戏加载项_快捷键.lua         ← 最后加载
```

数字较小的文件先加载。同一数字（如 `[1]玩家加载项`、`[1]游戏加载项`）表示同优先级，可并行。

**约定二：`[显示层]` / `[动作层]` — UI 同步与逻辑执行分离**

```
军需处/
  [动作层]购买装备成功.lua          ← 逻辑：扣资源、生成装备、发事件
  [显示层][1]南兵北器结果同步.lua    ← UI：set_image、set_text、set_visible
  [显示层][2]装备结果同步(sold).lua  ← UI：售罄状态同步
```

回合事件中也有此约定：
```
回合事件/
  [1]刷普通敌人.lua                  ← 动作：刷怪逻辑
  [显示层]回合信息同步(0).lua        ← 显示：基础回合提示
  [显示层]回合信息同步(普通波次).lua  ← 显示：普通波次提示
  [显示层]回合信息同步(BOSS).lua     ← 显示：BOSS 波次提示
```

**判断标准**：
- **显示层**：主要调用 UI API（`set_image`、`set_text`、`set_visible`），从全局变量读取状态同步到界面。不修改游戏状态。
- **动作层**：主要执行游戏逻辑（`change_resource`、`add_item`、`send_custom_event`），修改全局变量和游戏状态。

### 1.3 与本项目的差异

| 维度 | xunhuanquan | 本项目 |
|------|-------------|--------|
| 文件来源 | Y3 编辑器自动生成（每个 trigger → 一个 .lua + .json） | 手写 Lua 模块，多函数聚合 |
| 文件粒度 | 极细（每个文件一个 trigger 函数） | 较粗（每个文件一个子系统，多个公共方法） |
| 加载控制 | 数字前缀隐式排序 + Y3 trigger 系统 | boot.lua 显式 `require` 顺序 |
| 显示/动作分离 | 文件级清晰分离 | 多数模块混合两种职责 |

**结论**：本项目不适合完全照搬文件级 `[显示层]/[动作层]` 约定，但应在**模块职责层面**明确区分，并在命名上标注纯显示模块。

---

## 二、当前项目 runtime/ 领域分析

### 2.1 玩法背景

本项目是**自走棋 + 羁绊（Bond/Faction）**玩法。核心循环：

```
选择英雄 → 配置技能 → 波次战斗(自动) → 结算奖励 → 英雄成长 → 下一轮
                ↑ 羁绊效果加成贯穿始终 ↑
```

### 2.2 现有文件按游戏领域归类

基于对全部 66 个文件和 2 个子目录的分析，按游戏领域归纳如下：

| 领域 | 英文目录名 | 现有文件 | 数量 |
|------|-----------|---------|------|
| **启动协调** | `core/` | boot.lua, boot_core.lua, boot_combat.lua, boot_helpers.lua, boot_utils.lua, boot_camera.lua, boot_runtime_setup.lua, boot_ui_enhancements.lua, boot_ui_phase.lua, compat.lua, event_bus.lua, loops.lua, projectile_name_guard.lua | 13 |
| **英雄系统** | `heroes/` | hero_attr_defs.lua, hero_attr_system.lua, hero_model.lua, hero_selection_range.lua | 4 |
| **战斗系统** | `combat/` | battlefield/ (子目录 5 文件), battle_system.lua, battle_logic.lua, battle_events.lua, battle_finish_handler.lua, battle_auto_acceptance.lua, battle_event_feed.lua, battle_event_prompts.lua | 7 + 子目录 |
| **技能系统** | `skills/` | skill_system/ (子目录 6 文件), skill_framework.lua, skill_framework_registry.lua, attack_skills.lua, skills.lua, generated_skills.lua, skill_damage_templates.lua, skill_system.lua (门面) | 7 + 子目录 |
| **羁绊系统** | `bonds/` | bonds_chain.lua, bond_modifier_effects.lua, bond_bonus_pack.lua | 3 |
| **成长系统** | `progression/` | progression.lua, rewards.lua, reward_manager.lua, gear_upgrades.lua, achievements.lua | 5 |
| **回合系统** | `rounds/` | round_choice.lua, round_choice_logic.lua, round_choice_state_machine.lua, round_manager.lua, choice_panel.lua, challenge_manager.lua | 6 |
| **运行时UI** | `ui/` | runtime_ui_helpers.lua, ui_phase_manager.lua, ui_system.lua, attr_tips_panel.lua, status_display_manager.lua | 5 |
| **效果系统** | `effects/` | buff_system.lua, auto_active_effects.lua, effect_debug.lua | 3 |
| **音频系统** | `audio/` | audio.lua | 1 |
| **资源系统** | `resources/` | resource_system.lua | 1 |
| **调试系统** | `debug/` | debug_system.lua, debug_tools.lua, debug_actions.lua, editor_object_api.lua | 4 |
| **局外系统** | `outgame/` | outgame_system.lua, session_state.lua, message_system.lua, outgame_hero_growth.lua | 4 |

> **总计**：13 个领域目录 + boot.lua（留在 runtime/ 根目录作为入口）

### 2.3 依赖关系图（简化为领域间依赖）

```
                    ┌─────────────┐
                    │  boot.lua   │ (根目录入口，require 所有领域)
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
    ┌──────────┐    ┌──────────┐     ┌──────────┐
    │  core/   │◄───│ heroes/  │     │  audio/   │
    └────┬─────┘    └────┬─────┘     └──────────┘
         │               │
    ┌────┴───────────────┴──────────────────────┐
    │                                            │
    ▼                ▼                ▼          ▼
┌─────────┐   ┌──────────┐   ┌──────────┐  ┌──────────┐
│ bonds/  │   │ skills/  │   │ combat/  │  │resources/│
└────┬────┘   └────┬─────┘   └────┬─────┘  └──────────┘
     │             │              │
     └──────┬──────┘              │
            ▼                     ▼
     ┌────────────┐        ┌──────────┐
     │progression/│        │ rounds/  │
     └──────┬─────┘        └────┬─────┘
            │                   │
            └───────┬───────────┘
                    ▼
             ┌──────────┐     ┌──────────┐
             │   ui/    │     │ effects/ │
             └──────────┘     └──────────┘

 ┌──────────┐  ┌──────────┐
 │  debug/  │  │ outgame/ │  (相对独立，通过 EventBus 松耦合)
 └──────────┘  └──────────┘
```

---

## 三、重组后的目录结构

### 3.1 完整目录树

```
runtime/
├── boot.lua                          # ★ 唯一根文件，总入口
│
├── core/                             # 启动协调与基础设施
│   ├── boot_core.lua                 # [动作层] 核心状态初始化
│   ├── boot_combat.lua               # [动作层] 战斗工具函数工厂
│   ├── boot_helpers.lua              # [动作层] 时间/玩家/回合辅助
│   ├── boot_utils.lua                # [动作层] _G 全局函数注册
│   ├── boot_camera.lua               # [显示层] 相机控制
│   ├── boot_runtime_setup.lua        # [动作层] 运行时事件/loop 注册
│   ├── boot_ui_enhancements.lua      # [显示层] UI 增强包装
│   ├── boot_ui_phase.lua             # [动作层] UI 阶段管理
│   ├── compat.lua                    # [动作层] 兼容层
│   ├── event_bus.lua                 # [动作层] 事件总线
│   ├── loops.lua                     # [动作层] 主循环管理
│   └── projectile_name_guard.lua     # [动作层] 投射物名校验
│
├── heroes/                           # 英雄系统
│   ├── hero_attr_defs.lua            # [动作层] 英雄属性定义与公式
│   ├── hero_attr_system.lua          # [动作层] 英雄属性计算引擎
│   ├── hero_model.lua                # [动作层] 英雄数据模型
│   └── hero_selection_range.lua      # [动作层] 英雄选择范围管理
│
├── combat/                           # 战斗系统（波次、刷怪、结算）
│   ├── battle_system.lua             # [动作层] 战斗系统门面
│   ├── battle_logic.lua              # [动作层] 战斗核心逻辑
│   ├── battle_events.lua             # [动作层] 战斗事件定义
│   ├── battle_finish_handler.lua     # [动作层] 战斗结束处理
│   ├── battle_auto_acceptance.lua    # [动作层] 自动接受战斗
│   ├── battle_event_feed.lua         # [显示层] 战斗事件信息流
│   ├── battle_event_prompts.lua      # [显示层] 战斗事件提示
│   └── battlefield/                  # [动作层] 战场子模块
│       ├── init.lua                  # 战场初始化
│       ├── apis.lua                  # 战场 API
│       ├── reactions.lua             # 战场反应
│       ├── spawning.lua             # 刷怪逻辑
│       └── utils.lua                 # 战场工具
│
├── skills/                           # 技能系统
│   ├── skill_system.lua              # [动作层] 技能系统门面
│   ├── skill_framework.lua           # [动作层] 技能框架核心
│   ├── skill_framework_registry.lua  # [动作层] 技能注册表
│   ├── attack_skills.lua             # [动作层] 攻击技能实现
│   ├── skills.lua                    # [动作层] 技能定义（元素VFX等）
│   ├── generated_skills.lua          # [动作层] 批量生成技能
│   ├── skill_damage_templates.lua    # [动作层] 伤害模板
│   └── skill_system/                 # [动作层] 技能子系统
│       ├── init.lua                  # 子系统入口
│       ├── activation/
│       │   └── init.lua              # 技能激活逻辑
│       └── modifiers/
│           ├── init.lua              # 修改器入口
│           └── effects.lua           # 效果实现
│
├── bonds/                            # 羁绊系统
│   ├── bonds_chain.lua               # [动作层] 羁绊链核心逻辑
│   ├── bond_modifier_effects.lua     # [动作层] 羁绊修改器效果
│   └── bond_bonus_pack.lua           # [动作层] 羁绊加成包
│
├── progression/                      # 成长与奖励
│   ├── progression.lua               # [动作层] 英雄升级/成长
│   ├── rewards.lua                   # [动作层] 奖励发放与选择
│   ├── reward_manager.lua            # [动作层] 奖励队列管理
│   ├── gear_upgrades.lua             # [动作层] 装备升级
│   └── achievements.lua              # [动作层] 成就系统
│
├── rounds/                           # 回合与选择
│   ├── round_choice.lua              # [动作层] 回合选择入口
│   ├── round_choice_logic.lua        # [动作层] 选择逻辑
│   ├── round_choice_state_machine.lua # [动作层] 选择状态机
│   ├── round_manager.lua             # [动作层] 回合管理器
│   ├── choice_panel.lua              # [显示层] 选择面板 UI
│   └── challenge_manager.lua         # [动作层] 挑战管理器
│
├── ui/                               # 运行时 UI
│   ├── ui_system.lua                 # [动作层] UI 系统门面
│   ├── runtime_ui_helpers.lua        # [显示层] HUD 刷新/创建辅助
│   ├── ui_phase_manager.lua          # [动作层] UI 阶段管理
│   ├── attr_tips_panel.lua           # [显示层] 属性提示面板
│   └── status_display_manager.lua    # [显示层] 状态显示管理
│
├── effects/                          # Buff 与自动效果
│   ├── buff_system.lua               # [动作层] Buff 系统
│   ├── auto_active_effects.lua       # [动作层] 自动触发效果
│   └── effect_debug.lua              # [显示层] 效果调试可视化
│
├── audio/                            # 音频系统
│   └── audio.lua                     # [动作层] 音频播放管理
│
├── resources/                        # 资源系统
│   └── resource_system.lua           # [动作层] 资源获取/消耗
│
├── debug/                            # 调试工具
│   ├── debug_system.lua              # [动作层] 调试系统门面
│   ├── debug_tools.lua               # [显示层] GM 命令面板
│   ├── debug_actions.lua             # [动作层] GM 命令执行
│   └── editor_object_api.lua         # [动作层] 编辑器对象 API
│
└── outgame/                          # 局外系统
    ├── outgame_system.lua            # [动作层] 局外系统门面
    ├── session_state.lua             # [动作层] 会话状态管理
    ├── message_system.lua            # [显示层] 消息/提示系统
    └── outgame_hero_growth.lua       # [动作层] 局外英雄成长
```

### 3.2 显示层 / 动作层标注说明

每个文件标注了 `[显示层]` 或 `[动作层]`，判断依据：

| 层次 | 特征 | 典型 API |
|------|------|----------|
| **显示层** | 读取游戏状态，写入 UI 控件；不修改 `_G.STATE` 或游戏数据 | `set_image`, `set_text`, `set_visible`, `create_ui_xxx` |
| **动作层** | 修改游戏状态、触发事件、执行计算逻辑 | `change_resource`, `send_custom_event`, `require`, 修改 `_G.STATE` 字段 |

标注统计：
- 显示层：13 个文件（约占 20%）
- 动作层：53 个文件（约占 80%）

> **注意**：本项目是手写模块（非单 trigger 单文件），多数模块混合两种职责。标注反映的是**主要职责倾向**。对于混合模块（如 `runtime_ui_helpers.lua` 既有 UI 刷新又有逻辑），标注为占主导地位的一侧。

### 3.3 跨领域依赖的实现方式

重组后，跨领域通信使用以下三种机制（按优先级）：

1. **EventBus**（`core/event_bus.lua`）：松耦合事件订阅/发布。战斗结束、技能命中、英雄属性变化等跨领域通知通过此机制。
2. **`_G.SYSTEM` 定位器**：启动时注册，运行时按需获取。如 `_G.SYSTEM.battle`、`_G.SYSTEM.skill`。
3. **直接 require**（仅限领域内和 core→其他）：保持 Lua 模块的显式依赖。领域间不直接 require。

---

## 四、boot.lua 加载顺序保持不变

### 4.1 当前 11 阶段加载顺序

boot.lua 现有的 11 个阶段和对应的 require 路径保持不变，仅需更新路径前缀：

```
阶段1：数据表和配置          → 不变（config/*, data/* 不移动）
阶段2：核心状态初始化         → core/boot_core.lua
阶段3：基础能力               → core/boot_helpers, core/boot_utils, core/projectile_name_guard
阶段4：RuntimeEntry API       → 内联在 boot.lua，不变
阶段5：英雄属性               → heroes/hero_attr_system, heroes/hero_model
阶段6：核心玩法系统           → progression/*, audio/*
阶段7：技能系统               → skills/*
阶段8：战斗系统               → combat/*
阶段9：UI 系统                → ui/*
阶段10：调试系统              → debug/*
阶段11：局外系统              → outgame/*
```

### 4.2 路径变更对照表

boot.lua 中需要修改的 require 路径（共 ~20 处）：

| 当前路径 | 新路径 |
|---------|--------|
| `require 'runtime.boot_core'` | `require 'runtime.core.boot_core'` |
| `require 'runtime.boot_combat'` | `require 'runtime.core.boot_combat'` |
| `require 'runtime.boot_helpers'` | `require 'runtime.core.boot_helpers'` |
| `require 'runtime.boot_utils'` | `require 'runtime.core.boot_utils'` |
| `require 'runtime.boot_ui_enhancements'` | `require 'runtime.core.boot_ui_enhancements'` |
| `require 'runtime.event_bus'` | `require 'runtime.core.event_bus'` |
| `require 'runtime.projectile_name_guard'` | `require 'runtime.core.projectile_name_guard'` |
| `require 'runtime.hero_attr_system'` | `require 'runtime.heroes.hero_attr_system'` |
| `require 'runtime.hero_model'` | `require 'runtime.heroes.hero_model'` |
| `require 'runtime.progression'` | `require 'runtime.progression.progression'` |
| `require 'runtime.rewards'` | `require 'runtime.progression.rewards'` |
| `require 'runtime.audio'` | `require 'runtime.audio.audio'` |
| `require 'runtime.round_choice'` | `require 'runtime.rounds.round_choice'` |
| `require 'runtime.skill_damage_templates'` | `require 'runtime.skills.skill_damage_templates'` |
| `require 'runtime.skill_system'` | `require 'runtime.skills.skill_system'` |
| `require 'runtime.battle_system'` | `require 'runtime.combat.battle_system'` |
| `require 'runtime.ui_system'` | `require 'runtime.ui.ui_system'` |
| `require 'runtime.attr_tips_panel'` | `require 'runtime.ui.attr_tips_panel'` |
| `require 'runtime.debug_system'` | `require 'runtime.debug.debug_system'` |
| `require 'runtime.battle_auto_acceptance'` | `require 'runtime.combat.battle_auto_acceptance'` |
| `require 'runtime.outgame_system'` | `require 'runtime.outgame.outgame_system'` |
| `require 'runtime.boot_runtime_setup'` | `require 'runtime.core.boot_runtime_setup'` |

### 4.3 全局路径批量替换

除了 boot.lua，所有被移动文件的**内部 require** 也需要更新。预估影响：

- **boot.lua**：~20 处路径变更
- **各领域内部文件**：~40 处路径变更（跨领域 require）
- **非 runtime 目录的文件**：需扫描 `maps/EntryMap/script/` 下其他引用 `runtime.xxx` 的文件，预估 ~10 处

总计约 **70 处路径变更**。

---

## 五、迁移步骤

### 总原则

1. **每次移动一个领域，移动后立即验证**
2. **先移低风险孤立模块，后移高耦合核心模块**
3. **每阶段提交一次 git commit，便于回滚**
4. **迁移期间禁止其他功能开发，避免冲突**

### 阶段 1：基础设施准备（风险：低）

**目标**：创建所有目标目录，移动零耦合或极低耦合文件。

**移动文件**：

| 源路径 | 目标路径 | 理由 |
|--------|---------|------|
| `runtime/compat.lua` | `runtime/core/compat.lua` | 纯兼容层，无内部 require |
| `runtime/event_bus.lua` | `runtime/core/event_bus.lua` | 纯事件总线，无内部 require |
| `runtime/projectile_name_guard.lua` | `runtime/core/projectile_name_guard.lua` | 独立工具，仅 boot.lua 引用 |
| `runtime/editor_object_api.lua` | `runtime/debug/editor_object_api.lua` | 独立调试工具 |

**变更范围**：仅 boot.lua 中 4 处路径。

**验证方式**：运行游戏，检查启动日志无 require 错误。

---

### 阶段 2：音频系统（风险：低）

**目标**：移动最独立的功能模块。

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/audio.lua` | `runtime/audio/audio.lua` |

**变更范围**：boot.lua 1 处 + audio.lua 内部 require（引用 `runtime.boot_helpers` → `runtime.core.boot_helpers`）。

**验证方式**：游戏内音效正常播放。

---

### 阶段 3：资源系统（风险：低）

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/resource_system.lua` | `runtime/resources/resource_system.lua` |

**变更范围**：boot.lua 1 处间接引用（通过 `_G.resource_system`）+ 各引用文件的路径更新（debug_actions, battlefield/init.lua, session_state）。

**验证方式**：资源获取/消耗正常。

---

### 阶段 4：效果系统（风险：中低）

**目标**：移动 Buff 与自动效果（相互依赖，需一起移动）。

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/buff_system.lua` | `runtime/effects/buff_system.lua` |
| `runtime/auto_active_effects.lua` | `runtime/effects/auto_active_effects.lua` |
| `runtime/effect_debug.lua` | `runtime/effects/effect_debug.lua` |

**变更范围**：boot.lua 1 处（buff_system） + battle_system.lua 内部引用 + battlefield/apis.lua 内部引用 + session_state.lua 引用。

**验证方式**：Buff 添加/移除/过期正常，自动效果触发正常。

---

### 阶段 5：英雄系统（风险：中）

**目标**：移动英雄属性核心。

**高层风险点**：
- `hero_attr_system` 被 `attr_tips_panel` 和 `hero_attr_defs` require
- `hero_model` 被 boot.lua require 并挂到 `_G`
- 多处通过 `_G.hero_attr_system` 和 `_G.SYSTEM.hero_attr` 访问

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/hero_attr_defs.lua` | `runtime/heroes/hero_attr_defs.lua` |
| `runtime/hero_attr_system.lua` | `runtime/heroes/hero_attr_system.lua` |
| `runtime/hero_model.lua` | `runtime/heroes/hero_model.lua` |
| `runtime/hero_selection_range.lua` | `runtime/heroes/hero_selection_range.lua` |

**变更范围**：boot.lua 2 处 + hero_attr_defs 内部 1 处 + attr_tips_panel 内部 1 处 + outgame_system.lua 内部 1 处。

**验证方式**：英雄属性计算正确，属性提示面板显示正常。

---

### 阶段 6：羁绊系统（风险：中）

**目标**：移动羁绊核心模块。

**高层风险点**：
- `bonds_chain` 是跨系统枢纽（被 `boot_utils` 直接 `_G.BondSystem = require('runtime.bonds_chain')`）
- 内部依赖 `bond_bonus_pack`、`bond_modifier_effects`、`skill_system.activation`
- `round_choice.lua` 也直接引用

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/bonds_chain.lua` | `runtime/bonds/bonds_chain.lua` |
| `runtime/bond_modifier_effects.lua` | `runtime/bonds/bond_modifier_effects.lua` |
| `runtime/bond_bonus_pack.lua` | `runtime/bonds/bond_bonus_pack.lua` |

**变更范围**：boot_utils.lua 1 处 + bonds_chain.lua 内部 3 处 + bond_modifier_effects.lua 内部 1 处 + round_choice.lua 1 处 + skill_system/activation/init.lua 内部 2 处。

**验证方式**：羁绊抽卡/激活/效果加成正常，羁绊面板刷新正常。

---

### 阶段 7：技能系统（风险：中高）

**目标**：移动整个技能体系。

**高层风险点**：
- `skill_system/` 子目录内部结构复杂（6 个文件，多级 require 链）
- `skill_framework` ↔ `skill_framework_registry` 紧密耦合
- `generated_skills` 引用 `skills.lua` 的 `ELEMENT_VFX`
- `skill_system.lua`（门面）+ `skill_system/init.lua`（入口）需要区分

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/skill_system.lua` | `runtime/skills/skill_system.lua` |
| `runtime/skill_system/` (整个子目录) | `runtime/skills/skill_system/` |
| `runtime/skill_framework.lua` | `runtime/skills/skill_framework.lua` |
| `runtime/skill_framework_registry.lua` | `runtime/skills/skill_framework_registry.lua` |
| `runtime/attack_skills.lua` | `runtime/skills/attack_skills.lua` |
| `runtime/skills.lua` | `runtime/skills/defs.lua` （注意：重命名为 defs.lua 避免与目录名 skills 冲突！） |
| `runtime/generated_skills.lua` | `runtime/skills/generated_skills.lua` |
| `runtime/skill_damage_templates.lua` | `runtime/skills/skill_damage_templates.lua` |

> **关键命名冲突**：原 `runtime/skills.lua` 与新建的 `runtime/skills/` 目录在 Lua `require` 机制中会产生路径歧义。必须将 `skills.lua` 重命名为 `defs.lua`（或 `skill_defs.lua`），并更新所有引用它的地方（仅 `generated_skills.lua` 和 `skill_system/init.lua` 两处）。

**变更范围**：boot.lua 3 处 + skills 内部 ~12 处互相引用 + bonds_chain.lua 1 处 + battle_system.lua 1 处。

**验证方式**：技能注册、施放、伤害计算、VFX 播放全部正常。

---

### 阶段 8：战斗系统（风险：高）

**目标**：移动战斗/战场相关模块。

**高层风险点**：
- `battlefield/` 子目录已有 5 个内部文件，内部 require 复杂
- `battle_system.lua` 是门面，被 boot.lua 和多处引用
- `boot_combat` 通过 `_G` 大量导出函数（10+ 个），虽然不是移动目标但引用链长
- `battle_event_feed` 和 `battle_event_prompts` 被 `boot_utils`、`message_system`、`session_state` 多处 require

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/battle_system.lua` | `runtime/combat/battle_system.lua` |
| `runtime/battle_logic.lua` | `runtime/combat/battle_logic.lua` |
| `runtime/battle_events.lua` | `runtime/combat/battle_events.lua` |
| `runtime/battle_finish_handler.lua` | `runtime/combat/battle_finish_handler.lua` |
| `runtime/battle_auto_acceptance.lua` | `runtime/combat/battle_auto_acceptance.lua` |
| `runtime/battle_event_feed.lua` | `runtime/combat/battle_event_feed.lua` |
| `runtime/battle_event_prompts.lua` | `runtime/combat/battle_event_prompts.lua` |
| `runtime/battlefield/` (整个子目录) | `runtime/combat/battlefield/` |

**变更范围**：boot.lua 2 处 + battle_system.lua 内部 1 处 + battlefield/ 内部 2 处 + boot_utils.lua 4 处 + message_system.lua 2 处 + session_state.lua 1 处 + debug_tools.lua 1 处。

**验证方式**：完整战斗流程（刷怪→自动战斗→波次切换→BOSS→结算）正常。

---

### 阶段 9：成长系统（风险：中）

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/progression.lua` | `runtime/progression/progression.lua` |
| `runtime/rewards.lua` | `runtime/progression/rewards.lua` |
| `runtime/reward_manager.lua` | `runtime/progression/reward_manager.lua` |
| `runtime/gear_upgrades.lua` | `runtime/progression/gear_upgrades.lua` |
| `runtime/achievements.lua` | `runtime/progression/achievements.lua` |

**变更范围**：boot.lua 3 处 + progression.lua 1 处 + session_state.lua 1 处 + boot_utils.lua 1 处 + 各处引用 gear_upgrades 的文件（~4 处）。

**验证方式**：英雄升级、奖励选择、装备升级、成就触发正常。

---

### 阶段 10：回合系统（风险：中）

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/round_choice.lua` | `runtime/rounds/round_choice.lua` |
| `runtime/round_choice_logic.lua` | `runtime/rounds/round_choice_logic.lua` |
| `runtime/round_choice_state_machine.lua` | `runtime/rounds/round_choice_state_machine.lua` |
| `runtime/round_manager.lua` | `runtime/rounds/round_manager.lua` |
| `runtime/choice_panel.lua` | `runtime/rounds/choice_panel.lua` |
| `runtime/challenge_manager.lua` | `runtime/rounds/challenge_manager.lua` |

**变更范围**：boot.lua 1 处 + round_choice 内部互相引用 ~3 处。

**验证方式**：回合推进、选择面板弹出/选择/确认、挑战触发正常。

---

### 阶段 11：UI 系统（风险：中）

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/ui_system.lua` | `runtime/ui/ui_system.lua` |
| `runtime/runtime_ui_helpers.lua` | `runtime/ui/runtime_ui_helpers.lua` |
| `runtime/ui_phase_manager.lua` | `runtime/ui/ui_phase_manager.lua` |
| `runtime/attr_tips_panel.lua` | `runtime/ui/attr_tips_panel.lua` |
| `runtime/status_display_manager.lua` | `runtime/ui/status_display_manager.lua` |

**变更范围**：boot.lua 2 处 + ui_system.lua 内部 1 处 + attr_tips_panel 内部 1 处。

**验证方式**：HUD 显示正常、选择面板刷新、属性提示面板正常。

---

### 阶段 12：调试系统（风险：中低）

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/debug_system.lua` | `runtime/debug/debug_system.lua` |
| `runtime/debug_tools.lua` | `runtime/debug/debug_tools.lua` |
| `runtime/debug_actions.lua` | `runtime/debug/debug_actions.lua` |

> `editor_object_api.lua` 已在阶段 1 移动。

**变更范围**：boot.lua 1 处 + debug_system.lua 内部 3 处 + debug_tools.lua 内部 2 处 + debug_actions.lua 内部 1 处。

**验证方式**：GM 面板可用，调试命令正常执行。

---

### 阶段 13：局外系统（风险：中）

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/outgame_system.lua` | `runtime/outgame/outgame_system.lua` |
| `runtime/session_state.lua` | `runtime/outgame/session_state.lua` |
| `runtime/message_system.lua` | `runtime/outgame/message_system.lua` |
| `runtime/outgame_hero_growth.lua` | `runtime/outgame/outgame_hero_growth.lua` |

**变更范围**：boot.lua 1 处 + outgame_system.lua 内部 2 处 + session_state.lua 内部 ~4 处。

**验证方式**：局外选关、存档、会话状态切换正常。

---

### 阶段 14：Core 启动模块（风险：最高）

**目标**：最后移动 boot 系列的核心基础设施文件。

**为什么不先移动**：core/ 中的文件是其他所有领域的依赖基础。在所有下游文件的 require 路径更新完毕前移动 core 会导致大规模连锁改动。因此 core 文件**最后移动**。

**移动文件**：

| 源路径 | 目标路径 |
|--------|---------|
| `runtime/boot_core.lua` | `runtime/core/boot_core.lua` |
| `runtime/boot_combat.lua` | `runtime/core/boot_combat.lua` |
| `runtime/boot_helpers.lua` | `runtime/core/boot_helpers.lua` |
| `runtime/boot_utils.lua` | `runtime/core/boot_utils.lua` |
| `runtime/boot_camera.lua` | `runtime/core/boot_camera.lua` |
| `runtime/boot_runtime_setup.lua` | `runtime/core/boot_runtime_setup.lua` |
| `runtime/boot_ui_enhancements.lua` | `runtime/core/boot_ui_enhancements.lua` |
| `runtime/boot_ui_phase.lua` | `runtime/core/boot_ui_phase.lua` |
| `runtime/loops.lua` | `runtime/core/loops.lua` |

> `compat.lua`, `event_bus.lua`, `projectile_name_guard.lua` 已在阶段 1 移动。

**变更范围**：boot.lua ~8 处 + **所有其他领域的内部引用**（这是最大的改动面，因为几乎每个文件都引用了 boot_helpers 或 boot_combat）。预计 ~25 处跨领域引用需更新。

**关键注意**：`boot_combat.lua` 的 10+ 个函数通过 `_G` 导出（`get_current_hero`、`get_hero_attack`、`deal_skill_damage` 等）。移动文件不影响这些 `_G` 全局，因为它们是在 boot.lua 中显式赋值的。所以文件的物理位置变化不会破坏这些全局引用。

**验证方式**：全链路回归测试。启动 → 局外选关 → 进入战斗 → 5 波推进 → BOSS 战 → 结算 → 返回局外。

---

## 六、风险评估

### 6.1 高耦合文件（移动风险大）

| 文件 | 被引用次数 | 风险描述 | 缓解措施 |
|------|-----------|---------|---------|
| `boot_combat.lua` | 12+ | 10+ 函数导出到 `_G`，被几乎所有战斗相关模块使用 | 最后移动；不改函数签名；仅改 require 路径 |
| `boot_helpers.lua` | 10+ | 时间/玩家/回合辅助，被 audio、battlefield、debug_tools、progression、session_state 等引用 | 最后移动；保持所有公共 API 不变 |
| `boot_utils.lua` | 8+ | 注册了大量 `_G` 全局函数，内部还 require 了 bonds_chain 和 battle_event 等 | 最后移动；验证 _G 全局注册顺序 |
| `bonds_chain.lua` | 6+ | 在 boot_utils、round_choice、skill_system/activation 中被引用；本身又引用 bond_bonus_pack 和 bond_modifier_effects | 与 bond 系列一起移动；分阶段验证 |
| `battlefield/init.lua` | 5+ | 子目录内部复杂依赖（utils、reactions、spawning、apis），引用 resource_system 和 boot_helpers | 作为整体子目录移动（不拆分）；保持内部路径的相对引用 |

### 6.2 命名冲突风险

| 冲突 | 描述 | 解决方案 |
|------|------|---------|
| `runtime/skills.lua` vs `runtime/skills/` | Lua require 系统中，`require 'runtime.skills'` 会优先匹配 `skills.lua` 还是 `skills/init.lua`？ | 将 `skills.lua` 重命名为 `defs.lua`（技能定义），与 `skills/` 目录并存不再冲突 |
| `runtime/battle_system.lua` vs `runtime/combat/` 内的 `battle_system.lua` | 移动后路径变化，核心门面文件的引用需全量更新 | 在阶段 8 一次性批量替换 |
| `runtime/skill_system.lua`（门面） vs `runtime/skill_system/init.lua`（入口） | 这是现有设计：门面文件 vs 子目录入口是两个不同的 require 路径 | 移动后变为 `skills/skill_system.lua`（门面）和 `skills/skill_system/init.lua`（入口），结构不变 |

### 6.3 非 runtime 目录的外部引用

需要扫描并更新以下可能引用 `runtime.xxx` 的外部文件：

- `maps/EntryMap/script/main.lua`
- `maps/EntryMap/script/ui/runtime_hud.lua`
- `maps/EntryMap/script/config/entry_config.lua` 附近文件
- `maps/EntryMap/script/entry_objects/` 下的文件

**建议**：在阶段 0（正式迁移前），先用 `grep` 全面扫描所有 `require.*runtime\.` 引用，建立完整的影响范围清单。

### 6.4 回滚策略

1. **每阶段独立 git commit**，commit message 格式：`refactor: move [domain] modules to runtime/[domain]/`
2. 如果某阶段验证失败，`git revert` 该阶段的 commit 即可
3. `boot.lua` 在迁移期间保持双份路径兼容：先同时支持新旧路径，全部迁移完成后再清理旧路径。但此方案大幅增加复杂度，不推荐——每阶段原子化迁移 + 即时验证更简单可靠

---

## 七、借鉴 xunhuanquan 的其他建议（非本次迁移范围）

### 7.1 引入 `[N]描述.lua` 加载顺序约定

当前项目的加载顺序完全由 boot.lua 中的 `require` 顺序控制，这已经足够。但如果有文件需要**同一领域内按固定顺序加载**（当前用不到，因为模块间依赖通过显式 require 解决），可在文件名加数字前缀作为视觉提示：

```
combat/
  01_battle_events.lua        # 事件定义（最先，无依赖）
  02_battle_logic.lua         # 逻辑层（依赖事件定义）
  03_battle_system.lua        # 门面（依赖逻辑层）
```

**建议**：暂不采用。当前显式 require 已经足够清晰。

### 7.2 文件级 `[显示层]` / `[动作层]` 前缀

xunhuanquan 的文件名前缀可以用在少数职责清晰的文件上：

```
ui/
  [显示层]attr_tips_panel.lua
  [显示层]status_display_manager.lua
rounds/
  [显示层]choice_panel.lua
  [动作层]round_choice_logic.lua
```

**建议**：暂不采用中文前缀。保持英文命名一致性。显示/动作职责在目录级文档和模块注释中说明即可。

### 7.3 领域 README

每个领域目录下添加一个简短的 `README.md`，说明：
- 该领域的游戏功能
- 文件列表及各自职责
- 对外暴露的公共 API（`_G.SYSTEM.xxx`）
- 依赖的其他领域

**建议**：迁移完成后，作为独立任务补充。

---

## 八、执行检查清单

- [ ] 阶段 0：全项目 grep 扫描 `require.*runtime\.`，建立完整影响范围清单
- [ ] 阶段 0：创建所有目标子目录
- [ ] 阶段 1：移动 compat, event_bus, projectile_name_guard, editor_object_api → 验证
- [ ] 阶段 2：移动 audio → 验证
- [ ] 阶段 3：移动 resource_system → 验证
- [ ] 阶段 4：移动 effects (buff, auto_active, effect_debug) → 验证
- [ ] 阶段 5：移动 heroes → 验证
- [ ] 阶段 6：移动 bonds → 验证
- [ ] 阶段 7：移动 skills（含 skills.lua → defs.lua 重命名）→ 验证
- [ ] 阶段 8：移动 combat → 验证
- [ ] 阶段 9：移动 progression → 验证
- [ ] 阶段 10：移动 rounds → 验证
- [ ] 阶段 11：移动 ui → 验证
- [ ] 阶段 12：移动 debug → 验证
- [ ] 阶段 13：移动 outgame → 验证
- [ ] 阶段 14：移动 core → 全链路回归验证
- [ ] 最终：确认 `runtime/` 目录下只剩 `boot.lua` + 14 个子目录，无遗留文件
- [ ] 最终：运行完整一局游戏（局外→战斗→结算→局外），无报错

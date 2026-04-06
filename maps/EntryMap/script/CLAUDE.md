# CLAUDE.md

本文件只保留 agent 执行开发所需的信息。

## 基本要求

- 始终使用中文回复用户。
- 以 `maps/EntryMap/script` 下的实现为准，不以设计稿、旧入口或占位文件为准。
- 功能实现状态优先看 `maps/EntryMap/script/docs/开发进度与计划/开发进度与计划.md`，再回到 `maps/EntryMap/script/*.lua` 核对。

## 项目主线

- 当前玩法主目录：`maps/EntryMap/script`
- 真实启动入口：`maps/EntryMap/script/main.lua`
- 运行时总协调：`maps/EntryMap/script/entry_runtime.lua`
- 奖励运行时拆分：`maps/EntryMap/script/entry_runtime_rewards.lua`
- 配置汇总入口：`maps/EntryMap/script/entry_config.lua`
- 静态对象定义：`maps/EntryMap/script/entry_objects`
- 羁绊主实现：`maps/EntryMap/script/runtime_bonds.lua`

## 不要误判为主入口

- `maps/EntryMap/script/可重载的代码.lua`：热重载示例
- `global_script/global_main.lua`：项目级占位脚本
- 根目录 `global_trigger`：不是当前玩法主入口
- `maps/EntryMap/script/docs/design`：设计文档，不代表已实现事实

## 开发进度文档使用说明

- `maps/EntryMap/script/docs/开发进度与计划` 维护当前 `已实现 / 部分实现 / 未实现` 状态。
- 功能状态判断先看 `maps/EntryMap/script/docs/开发进度与计划/开发进度与计划.md`，再回到 `maps/EntryMap/script/*.lua` 核对。
- `部分实现` 表示已有 runtime 状态、静态对象、入口或预留字段，但还没有形成完整玩家体验；不能直接按已完成处理。
- `maps/EntryMap/script/docs/design` 仍是目标设计文档，不代表已经实现。

## 建议阅读顺序

1. `maps/EntryMap/script/CLAUDE.md`
2. `maps/EntryMap/script/docs/项目模块/00-项目总览/项目概览.md`
3. `maps/EntryMap/script/docs/开发进度与计划/开发进度与计划.md`
4. `maps/EntryMap/script/docs/项目模块/01-启动与入口/启动入口链路.md`
5. `maps/EntryMap/script/docs/项目模块/02-运行时主循环/主循环与状态机.md`
6. 按需求继续看 `maps/EntryMap/script/docs/开发进度与计划/*`
7. 按需求继续看对应模块文档或 `maps/EntryMap/script/entry_objects/README.md`
8. 如需兼容旧入口，再看 `maps/EntryMap/script/docs/项目模块/07-实现状态与路线图/实现状态与路线图.md`

## 模块定位

- 启动与总协调：
  - `maps/EntryMap/script/main.lua`
  - `maps/EntryMap/script/entry_runtime.lua`
  - `maps/EntryMap/script/entry_runtime_outgame.lua`
- 战斗与波次：
  - `maps/EntryMap/script/entry_runtime_battlefield.lua`
- 成长：
  - `maps/EntryMap/script/entry_runtime_progression.lua`
- 攻击技能：
  - `maps/EntryMap/script/entry_runtime_attack_skills.lua`
  - `maps/EntryMap/script/entry_runtime_attack_upgrades.lua`
  - `maps/EntryMap/script/entry_objects/attack_skills`
- 羁绊：
  - `maps/EntryMap/script/runtime_bonds.lua`
  - `maps/EntryMap/script/entry_objects/bonds`
  - `maps/EntryMap/script/entry_objects/bond_cards`
- 宝物 / 烙印 / 奖励队列：
  - `maps/EntryMap/script/entry_runtime.lua`
  - `maps/EntryMap/script/entry_runtime_rewards.lua`
  - `maps/EntryMap/script/entry_objects/treasures`
  - `maps/EntryMap/script/entry_objects/marks`
  - `maps/EntryMap/script/entry_objects/mark_nodes`
- 配置：
  - `maps/EntryMap/script/entry_config.lua`
- HUD / 调试：
  - `maps/EntryMap/script/entry_runtime_hud.lua`
  - `maps/EntryMap/script/entry_runtime_debug_tools.lua`
  - `maps/EntryMap/script/entry_runtime_debug_actions.lua`
  - `maps/EntryMap/ui`
  - `maps/EntryMap/global_trigger`

## 当前已有的核心系统

- 局外选关与基础存档骨架
- 5 波推进、Boss 切波与挑战
- 英雄自动战斗与攻击技能运行时
- `G` 三选一强化
- `F` 羁绊抽卡与羁绊效果
- 宝物、烙印、奖励队列与 HUD / GM 调试链路

## 目录边界

- 优先修改：`maps/EntryMap/script`
- 静态对象优先看：`maps/EntryMap/script/entry_objects`
- `maps/EntryMap/script/y3` 是框架目录，除非明确修框架，否则不要改
- `maps/EntryMap/unit`、`ability`、`item`、`modifier`、`projectile` 是资源依赖，不是玩法主逻辑入口

## 修改原则

- 先判断需求属于哪层：
  - 规则配置：`entry_config.lua`
  - 静态对象：`entry_objects/*`
  - 战场：`entry_runtime_battlefield.lua`
  - 成长：`entry_runtime_progression.lua`
  - 攻击技能：`entry_runtime_attack_skills.lua` / `entry_runtime_attack_upgrades.lua`
  - 羁绊：`runtime_bonds.lua`
  - 总协调：`entry_runtime.lua`
  - 宝物 / 烙印 / 奖励队列：`entry_runtime_rewards.lua`
  - HUD：`entry_runtime_hud.lua`
  - 调试：`entry_runtime_debug_tools.lua` / `entry_runtime_debug_actions.lua`
- 新系统进入实现前，先明确：
  - 状态放哪
  - 是否进入奖励队列 / 待选轮次互斥
  - 如何与 `G/F/烙印/宝物/挑战` 并存
  - UI 读哪个 runtime
- 尽量使用 `y3` 封装，不直接调用 CAPI
- 当前实现已经按模块拆分，不要回退成单文件堆积

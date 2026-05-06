# CLAUDE.md

本文件只保留 agent 执行开发所需的信息。

## 基本要求

- 始终使用中文回复用户。
- 以 `maps/EntryMap/script` 下的实现为准，不以设计稿、旧入口或占位文件为准。
- 功能实现状态优先看 `maps/EntryMap/script/docs/开发进度与计划/开发进度与计划.md`，再回到 `maps/EntryMap/script/*.lua` 核对。

## 开发偏好

- 当用户没有另行要求时，开发以速度优先，优先选择最短路径完成需求。
- 当用户没有明确要求时，默认不主动编写测试用例、回归脚本或额外验证脚本。
- 如果修改风险较高、影响面较大，或用户明确要求测试，再补充最小必要验证。

## 项目主线

- 当前玩法主目录：`maps/EntryMap/script`
- 真实启动入口：`maps/EntryMap/script/main.lua`
- 运行时总协调：`maps/EntryMap/script/runtime/boot.lua`
- 配置汇总入口：`maps/EntryMap/script/config/entry_config.lua`
- 羁绊主实现：`maps/EntryMap/script/runtime/bonds.lua`
- 宝物系统：已下线（`runtime/rewards.lua` 保留兼容桩）
- 英雄进化：运行时由 `runtime/rewards.lua` 实现，数据表 `data/tables/outgame/hero_evolutions.lua` 和 `hero_evolution_nodes.lua`

## 不要误判为主入口

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
  - `maps/EntryMap/script/runtime/boot.lua`
- 战斗与波次：
  - `maps/EntryMap/script/runtime/battlefield.lua`
- 成长：
  - `maps/EntryMap/script/runtime/progression.lua`
- 攻击技能：
  - `maps/EntryMap/script/runtime/attack_skills.lua`
- 羁绊：
  - `maps/EntryMap/script/runtime/bonds.lua`
  - `maps/EntryMap/script/runtime/bonds_chain.lua`
  - `maps/EntryMap/script/runtime/bond_nodes.lua`
- 英雄进化 / 奖励队列：
  - 由 `maps/EntryMap/script/runtime/rewards.lua` 提供实现
  - 宝物系统已下线，保留空桩兼容
- 配置：
  - `maps/EntryMap/script/config/entry_config.lua`
- HUD / 调试：
  - `maps/EntryMap/script/ui/runtime_hud.lua`
  - `maps/EntryMap/script/runtime/debug_tools.lua`
  - `maps/EntryMap/script/runtime/debug_actions.lua`
  - `maps/EntryMap/ui`
  - `maps/EntryMap/global_trigger`

## 当前已有的核心系统

- 局外选关与基础存档骨架
- 5 波推进、Boss 切波与挑战
- 英雄自动战斗与攻击技能运行时
- `F` 羁绊抽卡与羁绊效果
- HUD / GM 调试链路

## 目录边界

- 优先修改：`maps/EntryMap/script`
- 静态对象优先看：`maps/EntryMap/script/entry_objects`
- `maps/EntryMap/script/y3` 是框架目录，除非明确修框架，否则不要改
- `maps/EntryMap/unit`、`ability`、`item`、`modifier`、`projectile` 是资源依赖，不是玩法主逻辑入口

## 修改原则

- 先判断需求属于哪层：，,，
  - 规则配置：`config/entry_config.lua`
  - 战场：`runtime/battlefield.lua`
  - 成长：`runtime/progression.lua`
  - 攻击技能：`runtime/attack_skills.lua`
  - 羁绊：`runtime/bonds.lua` / `runtime/bonds_chain.lua`
  - 总协调：`runtime/boot.lua`

  - HUD：`ui/runtime_hud.lua`
  - 调试：`runtime/debug_tools.lua` / `runtime/debug_actions.lua`
- 新系统进入实现前，先明确：
  - 状态放哪
  - 是否进入奖励队列 / 待选轮次互斥

  - UI 读哪个 runtime
- 尽量使用 `y3` 封装，不直接调用 CAPI
- 当前实现已经按模块拆分，不要回退成单文件堆积

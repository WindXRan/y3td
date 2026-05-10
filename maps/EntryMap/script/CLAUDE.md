# CLAUDE.md

本文件只保留 agent 执行开发所需的信息。

## 基本要求

- 始终使用中文回复用户。
- 以 `maps/EntryMap/script` 下的实现为准，不以设计稿、旧入口或占位文件为准。
- 功能实现状态优先看 `maps/EntryMap/script/docs/总册/08-现状审查与执行案.md`，再回到 `maps/EntryMap/script/*.lua` 核对。
- Loop 自主开发任务队列：`maps/EntryMap/script/docs/总册/LOOP_TASKS.md`
- 设计文档：`maps/EntryMap/script/docs/总册/`

## 开发偏好

### 自主模式
- **全自动执行**：收到需求后直接分析、实现、验证，不需要请示"是否开始"、"是否继续"。
- **选择最短路径**：当用户没有另行要求时，开发以速度优先，优先选择最短路径完成需求。
- **默认不写测试**：当用户没有明确要求时，默认不主动编写测试用例、回归脚本或额外验证脚本。
- **自己判断架构**：对于有明确答案的技术选择（如 bug 修复、单文件改动），直接动手。只在以下情况停下来问用户：
  - 涉及多系统架构变更，有多种合理方案
  - 破坏性操作（删文件、force push、reset --hard）
  - 用户要求本身有歧义，需要澄清
- **做完就汇报**：实现完成后一句话总结改动点，不等用户追问。

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

## .y3maker 辅助体系

项目在 `maps/EntryMap/.y3maker/` 下有完整的辅助体系，开发时必须主动参考：

### 规则文件
- `maps/EntryMap/.y3maker/rules/rules.mdc` — 核心规则索引、技能路由、Lua 强制规则、核心禁令
- `maps/EntryMap/.y3maker/rules/api-safety.mdc` — API 白名单规则、常见 API 错误速查
- `maps/EntryMap/.y3maker/rules/ui-rules.mdc` — Y3 UI 坐标系（原点左下角）、官方组件（type 17/18/20）、字段规范
- `maps/EntryMap/.y3maker/rules/mcp-rules.mdc` — MCP 熔断规则、热更+保存流程（先热更等 3 秒再保存）
- `maps/EntryMap/.y3maker/rules/memory.mdc` — 记忆系统规则

### 错题集（写 Lua 前必读）
- `maps/EntryMap/.y3maker/memory/lua-issues/api_issues.md` — 12 条已验证的 API 错误用法 vs 正确用法
- `maps/EntryMap/.y3maker/memory/lua-issues/trace_issues.md` — 运行期 Trace 问题归档

### 知识库
- `maps/EntryMap/.y3maker/knowledge/` — Y3 引擎知识（UI 系统 / 核心系统 / 物编系统）
- `maps/EntryMap/.y3maker/knowledge/UI系统/03-官方组件.md` — UI 开发前必读

### 自定义技能
- `maps/EntryMap/.y3maker/skills/` — y3-lua-pipeline / y3-ui-pipeline / y3-obj-gen / y3-auto-test 等 9 个技能

### 强制规则
- 写 Lua 代码前必须先读 `api_issues.md` 和 `trace_issues.md`
- 写 UI 路径前必须先查 `ui_tree/*.json` 确认控件层级
- API 使用必须可追溯到 `y3-lua-pipeline/SKILL.md` 或 `references/`，禁止臆造 API

## 代码风格

- `ui/runtime_hud.lua` 中存在两种风格混写：早期的混淆风格（`aJ`, `bL`, `c4`, `dS`, `dr` 等短变量名 + `end;`）和后来的可读风格（`slot_index`, `slot_path`, `entry` 等语义化命名 + `end`）
- 新增代码一律使用可读风格：语义化变量名，不带分号结尾
- 不要批量重命名混淆变量，除非明确在做该段的完整重构

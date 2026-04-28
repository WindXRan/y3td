# Codex Project Bootstrap

本文件是当前仓库给 Codex 的项目级自动读取入口。Codex 从项目根目录或其子目录启动时，必须先按本文件建立上下文，再处理用户请求。

## 启动必读

1. 始终使用中文回复用户。
2. 当前项目是 Y3 游戏编辑器地图工程，使用 y3-lualib。
3. 真实玩法代码根目录是 `maps/EntryMap/script`，该目录下还有更具体的 `AGENTS.md`。
4. 真实启动入口是 `maps/EntryMap/script/main.lua`。
5. 运行时总协调优先看 `maps/EntryMap/script/entry_runtime.lua` 及 `maps/EntryMap/script/runtime/`。
6. 不要把 `global_script/global_main.lua`、根目录 `global_trigger`、设计稿或旧示例文件误判为当前玩法主入口。
7. 每次开启新会话，必须先读取 `.codex/README.md`、`.codex/rules/y3maker/rules.mdc`、`.codex/knowledge/y3maker/README.md`、`.codex/memories/y3maker/Memory.md`，再开始处理用户任务。
8. 处理具体任务前，按任务类型补读对应技能 `SKILL.md`（至少覆盖 `y3-lua-pipeline`、`y3-ui-pipeline`、`y3-obj-gen`、`y3-obj-edit`、`y3-auto-test`、`y3-ability-api`）。
9. 出现 Lua/API 报错或 Trace 时，必须补读 `.codex/memories/y3maker/lua-issues/api_issues.md` 与 `.codex/memories/y3maker/lua-issues/trace_issues.md`。
10. 默认模型使用 `gpt-5.3-codex`；如无明确指示，不切换到其他模型。

## 自动上下文来源

Codex 启动时会自动读取本 `AGENTS.md`。处理具体任务前，按需继续打开以下项目 AI 配置文件：

| 文件 | 什么时候读 | 用途 |
| --- | --- | --- |
| `maps/EntryMap/script/AGENTS.md` | 任何玩法代码开发、排查、审查任务开始前 | 玩法代码根目录规则 |
| `maps/EntryMap/script/CLAUDE.md` | 任何玩法代码开发、排查、审查任务开始前 | 当前玩法入口、模块边界、开发偏好 |
| `.codex/rules/y3maker/rules.mdc` | 任何 Y3 任务开始前 | Y3 核心规则索引、技能路由、禁令 |
| `.codex/rules/y3maker/api-safety.mdc` | 写 Lua 或调用 y3 API 前 | 防止臆造 API、确认参数和返回值 |
| `.codex/rules/y3maker/mcp-rules.mdc` | 使用 Y3 Editor/MCP/自动化工具前 | 热更、保存、熔断规则 |
| `.codex/rules/y3maker/ui-rules.mdc` | UI 相关任务前 | Y3 UI 坐标系、官方组件、字段规则 |
| `.codex/rules/y3maker/auto-test.mdc` | 用户明确要求自动化测试时 | 测试执行纪律 |
| `.codex/rules/y3maker/memory.mdc` | 任务涉及会话记录、Lua 错题本时 | 记忆归档规则 |
| `.codex/memories/y3maker/Memory.md` | 需要历史项目记忆时 | 长期项目记忆 |
| `.codex/memories/y3maker/lua-issues/*.md` | Lua 报错、Trace、API 问题时 | 历史错题本 |

`.y3maker/` 下存在旧迁移副本；同类内容优先以 `.codex/` 为准。

## 技能路由

按任务触发对应技能并先读该技能的 `SKILL.md`：

| 用户需求 | 技能 |
| --- | --- |
| 写 Lua、游戏逻辑、事件、Buff、伤害、UI 交互代码 | `y3-lua-pipeline` |
| 代码审查、Lua 检查、API 检查 | `y3-lua-review` |
| 创建单位、技能、Buff、投射物、物编数据 | `y3-obj-gen` |
| 修改已有单位、技能、Buff、物编属性 | `y3-obj-edit` |
| 创建 UI、UI 面板、HUD、商店、背包、技能栏 | `y3-ui-pipeline` |
| 自动化测试、自动点击、桌面操作、跑测试 | `y3-auto-test` |
| 给单位添加技能、查找技能实例、监听技能施法、运行时修改技能 | `y3-ability-api` |

Lua 代码必须严格参照 `y3-lua-pipeline/SKILL.md` 及其 `references/`。未在参考文档或 y3 源码中确认的 API 视为不可用。

## 项目边界

- 优先修改 `maps/EntryMap/script`。
- 静态对象优先看 `maps/EntryMap/script/entry_objects`。
- `maps/EntryMap/script/y3` 是框架目录，除非明确修框架，否则不要改。
- `maps/EntryMap/unit`、`ability`、`item`、`modifier`、`projectile` 是资源依赖，不是玩法主逻辑入口。
- 功能状态先看 `maps/EntryMap/script/docs/开发进度与计划/开发进度与计划.md`，再回到代码核对。

## 强制规则摘要

- Y3 UI 原点在左下角，Y 轴向上。
- 技能按钮、Buff 列表、物品槽优先使用官方组件，不手写替代逻辑。
- UI JSON 不手写大型文件，优先用 UI 生成流程和脚本。
- 物编或 UI JSON 生成/修改后，编辑器内必须先热更，再等待，再保存。
- MCP 超时不重试；连续失败 2 次即熔断。
- 修改前先用 `rg` 搜索现有实现和 API 定义。
- 不回退用户已有改动，不清理无关变更。

## 常用入口

| 目标 | 路径 |
| --- | --- |
| 玩法入口 | `maps/EntryMap/script/main.lua` |
| 运行时总协调 | `maps/EntryMap/script/entry_runtime.lua` |
| 配置汇总 | `maps/EntryMap/script/entry_config.lua` |
| 奖励运行时 | `maps/EntryMap/script/entry_runtime_rewards.lua` |
| HUD/调试 | `maps/EntryMap/script/entry_runtime_hud.lua`, `maps/EntryMap/script/entry_runtime_debug_tools.lua` |
| 羁绊 | `maps/EntryMap/script/runtime/bonds.lua`, `maps/EntryMap/script/runtime/bonds_chain.lua` |
| 攻击技能 | `maps/EntryMap/script/entry_runtime_attack_skills.lua`, `maps/EntryMap/script/runtime/attack_skills.lua` |
| UI 文件 | `maps/EntryMap/ui`, `maps/EntryMap/ui_tree`, `ui_tree` |

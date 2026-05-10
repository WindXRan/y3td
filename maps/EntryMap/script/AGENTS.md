# Codex Script Root

本目录是当前玩法代码根目录。Codex 在 `maps/EntryMap/script` 或其子目录工作时，必须以本目录下的代码和文档为准。

## 基本规则

- 始终使用中文回复用户。
- 以本目录下的实现为准，不以设计稿、旧入口或占位文件为准。
- 功能实现状态先看 `runtime/` 目录下的实际 Lua 代码和 `data/tables/` 配置。
- 详细项目说明继续读 `CLAUDE.md`。

## 真实入口

- 启动入口：`main.lua`
- 运行时总协调：`runtime/boot.lua`
- 配置汇总：`config/entry_config.lua`
- 运行时模块：`runtime/`
- UI 交互代码：`ui/`

## 不要误判

- `y3/演示/项目配置/可重载的代码.lua` 是热重载示例，不是主入口。
- `../ui` 和 `../ui_tree` 是 UI 资源目录，不是玩法运行时主逻辑。
- `y3/` 是框架目录，除非明确修框架，否则不要改。
- `.y3maker/knowledge/` 是知识库文档，不代表已经实现。

## 修改优先级

1. 先判断需求属于配置、战场、成长、攻击技能、羁绊、HUD、调试中的哪一层。
2. 优先复用已有模块，不要把已拆分的逻辑回退成单文件堆积。
3. 写 Lua 前必须先确认 y3 API 存在，优先查 `.codex/skills/y3-lua-pipeline/references/` 和 `y3/` 源码。
4. UI 需求优先走项目 UI 生成流程，避免手写大型 UI JSON。
5. 修改风险高或用户明确要求时，再补最小必要测试。

## 继续阅读

建议顺序：

1. `CLAUDE.md`
2. `runtime/boot.lua` - 启动入口逻辑
3. `config/entry_config.lua` - 配置汇总
4. `.y3maker/knowledge/项目结构说明.md` - 项目结构说明
5. `data/tables/README.md` - 数据表说明

## 当前状态说明

- 奖励系统在 `runtime/rewards.lua` 中实现，包含英雄进阶功能。

## 辅助技能体系

项目在 `.y3maker/skills/` 下提供了完整的辅助技能体系，开发时可主动调用：

### 开发工具
- **y3-lua-pipeline** - Lua 开发管道，包含 API 参考文档和代码生成
- **y3-lua-review** - Lua 代码审查工具
- **y3-env-setup** - 开发环境设置

### UI 开发
- **y3-ui-pipeline** - UI 开发管道，自动生成 UI 树结构
- **y3-ui-generator** - UI 组件生成器，支持 HTML 转 Y3 UI 格式

### 对象编辑
- **y3-obj-edit** - 对象编辑器，支持单位属性修改
- **y3-obj-gen** - 对象生成器，基于模板批量创建游戏对象

### 测试与规范
- **y3-auto-test** - 自动化测试框架
- **y3-game-spec** - 游戏规格设计文档生成

### 知识库
- `.y3maker/knowledge/` - Y3 引擎知识文档（UI系统、核心系统、物编系统）
- `.y3maker/memory/` - 项目记忆系统，记录历史开发会话和问题

### 使用建议
- 写 Lua 代码前建议查阅 `y3-lua-pipeline/references/` 中的 API 文档
- UI 开发优先使用 `y3-ui-generator` 生成组件
- 代码提交前使用 `y3-lua-review` 进行代码审查


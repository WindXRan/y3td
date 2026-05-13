---
name: sync-y3maker-to-claude
description: 将遗留的 Y3Maker / CodeMaker 项目助手体系迁移到 Claude Code 原生项目结构中，并在 `.y3maker/` 后续更新时把差异安全同步到现有 `.claude/` 副本。用于存在 `.y3maker/`、旧 `.codemaker` 路径、旧 MCP 配置、遗留 rules/memory/skills，且需要：(1) 首次迁移到 Claude Code 的 `.claude/`、`.mcp.json`、`CLAUDE.md` 相关结构，(2) 把旧路径重写为当前项目结构，(3) 显式选择把 `.y3maker/mcp_settings.json` 转换到项目级 `.mcp.json`、用户级 Claude MCP 配置或跳过，(4) 对已迁移项目执行重复同步/差异合并，或 (5) 审核哪些内容应保留为 `.claude` 归档、哪些规则值得浓缩进 `CLAUDE.md` 时务必使用。
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# 将 Y3Maker 迁移到 Claude Code

先迁移遗留内容的副本，再处理兼容性；不要改动原始 `.y3maker/`。默认先跑脚本，再处理脚本无法判断的人工项。

## 目标结构

- 项目级 Claude Code 资源：`.claude/skills/`、`.claude/rules/`、`.claude/knowledge/`、`.claude/memory/`、`.claude/migration/`
- 项目级 MCP：工作区根目录 `.mcp.json`
- 用户级 MCP：`~/.claude.json` 中的 Claude Code MCP 配置
- 项目长期说明：根目录 `CLAUDE.md`，只在人工判断后浓缩迁移，不由脚本自动拼接

## 脚本入口

### 1. 盘点工作区

先确认遗留面、Claude 面、OMC 面，以及已有同步状态：

```bash
node "./scripts/run-migration.js" inventory --workspace "." --pretty
```

`inventory` 会返回：

- `.y3maker` / `.claude` / `.omc` 是否存在
- 遗留 `knowledge` / `memory` / `rules` / `skills` 目录概况
- `.claude/migration/y3maker-manifest.json` 是否存在
- 已跟踪文件数、`blocked` 数、`orphaned` 数

### 2. 执行迁移或重复同步

先用 dry-run 看计划：

```bash
node "./scripts/run-migration.js" apply --workspace "." --dry-run --pretty
```

如果存在 `.y3maker/mcp_settings.json`，`apply` 不允许静默修改 MCP 配置。交互式终端会提示选择：

- `project`：迁移到当前工作区项目级 `.mcp.json`，适合团队共享
- `user`：迁移到用户级 Claude Code MCP 配置 `~/.claude.json`
- `skip`：本次不迁移 MCP 配置

自动化或非交互环境必须显式传入选择，例如：

```bash
node "./scripts/run-migration.js" apply --workspace "." --dry-run --mcp-scope project --pretty
```

确认后执行：

```bash
node "./scripts/run-migration.js" apply --workspace "." --mcp-scope project --pretty
```

脚本会自动完成这些机械步骤：

- 创建 `.claude/knowledge`、`.claude/memory`、`.claude/rules`、`.claude/skills`、`.claude/migration`
- 复制 `.y3maker/knowledge`、`.y3maker/memory`、`.y3maker/rules`、`.y3maker/skills`
- 跳过旧体系冗余文件，例如 `skills/README.md`、`install_skills.bat`、`.queue`、`.claude-plugin`
- 把迁移副本里的 `.codemaker`、`.codex` 路径改写为 `.claude`
- 规范化迁移后 `SKILL.md` frontmatter，保留 `name`、`description`，并保留/补充 Claude Code 可用的 `allowed-tools` 字段（若原始 skill 有 `tools` 会迁移为 `allowed-tools`）
- 在用户显式选择后，把 `.y3maker/mcp_settings.json` 转成项目级 `.mcp.json`、用户级 `~/.claude.json`，或跳过；如果源文件存在但 `mcpServers` 为空，仍按所选 scope 生成/合并目标配置，并在结果中明确提示这是 `.y3maker` 源配置为空
- 补齐 `openspec/docs`、`openspec/reports`
- 清理 `.claude/cmtmp` 等临时目录
- 维护 `.claude/migration/y3maker-manifest.json`，用于后续重复同步

### 3. 做迁移验收

执行完固定步骤后，必须跑验收脚本：

```bash
node "./scripts/verify-migration.js" --workspace "." --mcp-scope project --pretty
```

`--mcp-scope` 应与迁移时选择一致；如果迁移脚本已经把选择写入 manifest，也可以省略。

如果脚本报错，不要先宣称迁移完成；先修正可自动修的明显问题，再重新验证。

## 重复同步规则

`apply` 不只是首次迁移入口，也是后续 `.y3maker/` 更新后的安全同步入口。

manifest 位于：

- `.claude/migration/y3maker-manifest.json`

结果字段含义：

- `created`：目标文件之前不存在，这次新建
- `updated`：`.y3maker` 变了，而 `.claude` 副本没变，自动更新
- `adopted`：目标内容已经等于按当前规则迁移出的结果，只记录基线
- `resolved`：此前是阻塞项，但现在目标已经和迁移结果一致
- `blocked`：源和目标都变了，或者没有安全基线，保留 `.claude` 不覆盖
- `orphaned`：源文件消失了，但目标文件被保留，不做静默删除

## 安全保护

- 默认拒绝把用户主目录、`~/.claude` 目录树、磁盘根目录当作工作区
- 只有明确知道自己在做什么时，才用 `--allow-unsafe-workspace` 覆盖
- 正常项目根目录执行 `--workspace "."` 不受影响

## 硬约束

- 不要改动原始 `.y3maker/`，只迁移或重写副本
- MCP 配置必须由用户显式选择 `project`、`user` 或 `skip`；禁止在没有交互选择或 `--mcp-scope` 参数时写入、合并或清理任何 MCP 配置
- 推荐优先选择项目级 `.mcp.json`，因为它是 Claude Code 项目共享 MCP 的原生入口；用户级配置适合私有 MCP
- 不要把脚本没验证过的结果说成“已完成迁移”
- 如果验收发现某个依赖、脚本或被引用文件在原始 `.y3maker/` 中本来就不存在，只能明确报告缺失
- 对于 `.y3maker/` 中本来不存在的文件，不要伪造内容或补占位文件
- 只有在确认 OMC 已安装且可用时，才把活跃项目事实写入 `.omc`；否则保留在 `.claude/memory/` 作为归档，并在结果中明确写出 `skipped`

## 保留给人工判断的部分

- 哪些遗留规则应该浓缩进根目录 `CLAUDE.md`
- 哪些 memory 只是归档，哪些事实值得写入 `.omc/project-memory.json`、OMC wiki 或 notepad
- 哪些 skill 的 `scripts/`、`references/`、`assets/` 仍然值得保留
- 验收脚本发现但无法自动修复的缺失依赖，应如何向用户汇报
- 对 `blocked` / `orphaned` 项是手工合并、保留现状，还是进一步清理

## 结果汇报要求

最终汇报至少要说明：

- 实际迁移或同步到了 `.claude/` 的目录和文件
- 是否写入 `.mcp.json` 或 `~/.claude.json`，以及用户选择的 MCP scope；如果 `.y3maker/mcp_settings.json` 的 `mcpServers` 为空，必须明确告知用户源 MCP 配置为空，通常代表 Y3 官方导出的遗留配置本身没有写入 server
- 做了哪些路径改写或 frontmatter 规范化
- 哪些内容被保留为归档，哪些被跳过
- 本次是首次迁移还是重复同步
- `created` / `updated` / `adopted` / `blocked` / `orphaned` 的摘要
- 验收是否通过
- 所有未修复问题，尤其是 `.y3maker/` 原始内容里就缺失的依赖或引用目标

## 参考文件

- 自动/人工边界与映射：[references/migration-map.md](references/migration-map.md)
- 自动化入口：[scripts/run-migration.js](scripts/run-migration.js)
- 验收入口：[scripts/verify-migration.js](scripts/verify-migration.js)

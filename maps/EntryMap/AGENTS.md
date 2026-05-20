# AGENTS.md

**代码风格分析文档已迁移到 script 目录下。**

## 核心文档索引

| 文档 | 路径 | 说明 |
|-----|------|------|
| **项目核心指南** | [script/AGENTS.md](script/AGENTS.md) | 项目规则、入口说明、函数清单 |
| **代码风格对比** | [script/CODE_STYLE.md](script/CODE_STYLE.md) | y3 仓库风格 vs 业务代码风格对比 |

## 快速导航

- **项目入口**: `main.lua`
- **运行时协调**: `runtime/boot.lua`
- **配置汇总**: `config/entry_config.lua`

## 开发建议

1. 开发前必读 [script/AGENTS.md](script/AGENTS.md) 了解项目规则
2. 代码风格参考代码风格对比文档
3. 修改前确认需求所属层次（配置/战场/成长/技能/HUD/调试）

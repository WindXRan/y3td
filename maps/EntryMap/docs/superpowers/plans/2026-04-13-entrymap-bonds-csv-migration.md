# EntryMap Bonds CSV Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前运行中的羁绊静态定义迁移为 CSV，并通过 object table 装配回现有 runtime 可消费的 Lua 结构。

**Architecture:** 首轮只迁移静态羁绊内容，不改抽卡、刷新、替换和 UI 主流程。新增 `bond_base.csv`、`bond_cards.csv`、`bond_effects.csv`，由 `data/object_tables/bonds.lua` 统一读取并组装，再让 `entry_objects/bonds/init.lua` 继续作为 runtime 稳定入口。

**Tech Stack:** Lua, CSV, PowerShell, Git

---

### Task 1: 梳理当前羁绊静态结构

**Files:**
- Read: `maps/EntryMap/script/runtime/bonds.lua`
- Read: `maps/EntryMap/script/runtime/bonds_chain.lua`
- Read: `maps/EntryMap/script/runtime/bond_nodes.lua`
- Read: `maps/EntryMap/script/docs/内容设计/04-羁绊/羁绊总表.md`

- [ ] Step 1: 列出 runtime 当前真实访问的羁绊定义字段
- [ ] Step 2: 区分哪些字段属于 bond、哪些属于 card、哪些仍属于节点图
- [ ] Step 3: 确认首轮不迁移的字段和模块边界

### Task 2: 先写 smoke test

**Files:**
- Create: `maps/EntryMap/script/tools/test_bonds_csv_loader_smoke.lua`

- [ ] Step 1: 写一个失败中的 smoke test，要求存在 `data.object_tables.bonds`
- [ ] Step 2: 断言返回 `list/by_id/cards/cards_by_id`
- [ ] Step 3: 断言至少一个关键羁绊和关键羁绊卡存在
- [ ] Step 4: 运行 `lua maps/EntryMap/script/tools/test_bonds_csv_loader_smoke.lua`，确认先失败

### Task 3: 创建羁绊 CSV

**Files:**
- Create: `maps/EntryMap/script/data_csv/bond_base.csv`
- Create: `maps/EntryMap/script/data_csv/bond_cards.csv`
- Create: `maps/EntryMap/script/data_csv/bond_effects.csv`

- [ ] Step 1: 用当前运行中的羁绊定义生成 `bond_base.csv`
- [ ] Step 2: 用当前运行中的羁绊卡定义生成 `bond_cards.csv`
- [ ] Step 3: 将静态效果拆成 `bond_effects.csv`
- [ ] Step 4: 保留模板驱动效果所需的静态参数，不强行删模板

### Task 4: 实现 object table 装配层

**Files:**
- Create: `maps/EntryMap/script/data/object_tables/bonds.lua`

- [ ] Step 1: 读取三张 CSV
- [ ] Step 2: 将 effect rows 按 `owner_type/owner_id` 聚合
- [ ] Step 3: 组装 `list/by_id/cards/cards_by_id`
- [ ] Step 4: 输出尽量兼容当前 runtime 的字段结构

### Task 5: 切换 entry_objects 入口

**Files:**
- Modify: `maps/EntryMap/script/entry_objects/bonds/init.lua`

- [ ] Step 1: 将入口切换到 `return require 'data.object_tables.bonds'`
- [ ] Step 2: 不改 runtime require 路径，保持现有模块使用方式不变

### Task 6: 回归验证

**Files:**
- Test: `maps/EntryMap/script/tools/test_bonds_csv_loader_smoke.lua`

- [ ] Step 1: 重新运行 smoke test，确认通过
- [ ] Step 2: 追加关键数量校验与关键 bond/card 校验
- [ ] Step 3: 若 runtime 依赖字段有缺失，回补 object table 兼容字段

# EntryMap Treasure CSV Standardization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将宝物配置从两张临时 CSV 整理为五张标准化 CSV，兼顾策划可读性与程序可接入性。

**Architecture:** 保留一张宝物主表承载名称、分类、摘要等人读信息；将单件效果、套装成员、套装激活效果拆到独立子表，用行式结构表达。现阶段只整理配置文件，不改动运行时代码。

**Tech Stack:** CSV, PowerShell, Git

---

### Task 1: 重构宝物 CSV

**Files:**
- Modify: `maps/EntryMap/script/data_csv/treasures.csv`
- Create: `maps/EntryMap/script/data_csv/treasure_effects.csv`
- Modify: `maps/EntryMap/script/data_csv/treasure_sets.csv`
- Create: `maps/EntryMap/script/data_csv/treasure_set_members.csv`
- Create: `maps/EntryMap/script/data_csv/treasure_set_effects.csv`

- [ ] Step 1: 按标准结构重写主表字段
- [ ] Step 2: 将单件效果拆入 `treasure_effects.csv`
- [ ] Step 3: 将套装成员拆入 `treasure_set_members.csv`
- [ ] Step 4: 将套装激活效果拆入 `treasure_set_effects.csv`
- [ ] Step 5: 校对条目数量、关键 ID 与排除项

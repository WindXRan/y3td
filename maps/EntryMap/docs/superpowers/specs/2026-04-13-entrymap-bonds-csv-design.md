# EntryMap 羁绊系统 CSV 首轮迁移设计

## 目标

将当前运行中的羁绊静态内容迁移为 CSV 维护，但保持现有 `runtime/bonds.lua`、`runtime/bonds_chain.lua`、`runtime/bond_nodes.lua` 的运行时行为尽量不变。

这次迁移只处理“静态羁绊内容”，不在首轮改动抽卡权重、替换规则和复杂运行时算法。

## 范围

首轮迁移包含：

- 当前运行中的羁绊基础定义
- 当前运行中的羁绊卡定义
- 当前运行中的羁绊效果定义

首轮不迁移：

- 抽卡池规则
- 候选权重修正
- 满槽替换推荐规则
- UI 面板逻辑
- 羁绊抽卡刷新/消耗逻辑

## 设计结论

采用和宝物相同的“CSV -> object table -> entry_objects -> runtime”链路：

- CSV 只承载静态数据
- `data/object_tables/bonds.lua` 负责把 CSV 装配回 Lua table
- `entry_objects/bonds/init.lua` 继续作为 runtime 稳定入口
- runtime 继续消费 Lua table，不直接读取 CSV

## 建议 CSV 结构

### 1. `bond_base.csv`

保存羁绊本体信息。

建议字段：

- `bond_id`
- `bond_name`
- `quality`
- `summary`
- `route_tags`
- `ui_icon`
- `notes`

### 2. `bond_cards.csv`

保存单张羁绊卡信息。

建议字段：

- `card_id`
- `bond_id`
- `display_name`
- `tier`
- `pool_weight`
- `slot_role`
- `notes`

### 3. `bond_effects.csv`

一行一个效果，统一记录羁绊和羁绊卡的静态效果。

建议字段：

- `owner_type`
- `owner_id`
- `effect_type`
- `effect_key`
- `op`
- `value`
- `condition`
- `notes`

说明：

- `owner_type` 允许 `bond` / `card`
- 如果当前 runtime 只认某一层效果，装配层负责把它聚合回原结构

## Lua 侧结构

新增：

- `maps/EntryMap/script/data/object_tables/bonds.lua`

职责：

- 读取 `bond_base.csv`
- 读取 `bond_cards.csv`
- 读取 `bond_effects.csv`
- 组装出兼容当前 runtime 的羁绊对象结构
- 输出：
  - `list`
  - `by_id`
  - `cards`
  - `cards_by_id`

修改：

- `maps/EntryMap/script/entry_objects/bonds/init.lua`

改为：

- `return require 'data.object_tables.bonds'`

## 兼容原则

- runtime 不直接感知 CSV
- 当前羁绊对象的关键字段命名尽量不变
- 如果 CSV 字段名与 runtime 现名不一致，在 object table 层转换
- 如果某些羁绊效果仍依赖模板模块，如 `runtime/bond_templates/*.lua`，则保留模板入口，只把静态参数转到 CSV

## 风险

### 1. 当前 runtime 依赖字段可能比文档更多

处理：

- 以 `runtime/bonds.lua` 与 `runtime/bonds_chain.lua` 的实际访问字段为准
- 不以设计稿字段替代当前实现事实

### 2. 羁绊效果与模板模块可能强耦合

处理：

- 首轮不试图去掉模板模块
- 只把模板需要的静态参数转成 CSV

### 3. 羁绊节点图和羁绊卡池可能不是同一层结构

处理：

- 首轮只迁移“当前运行中的羁绊静态内容”
- `bond_nodes.lua` 如仍然承担图结构与进阶链，则暂不一起迁

## 推荐实施顺序

1. 先梳理当前 runtime 真正依赖的羁绊静态字段
2. 写羁绊 CSV 设计对应的最小 smoke test
3. 创建 `bond_base.csv`、`bond_cards.csv`、`bond_effects.csv`
4. 实现 `data/object_tables/bonds.lua`
5. 切换 `entry_objects/bonds/init.lua`
6. 运行静态 smoke test 验证条目数量和关键羁绊

## 验收标准

- 羁绊静态内容可由 CSV 作为唯一来源
- `entry_objects/bonds` 仍是 runtime 的稳定入口
- 运行时不需要直接读取 CSV
- 不改变当前羁绊系统的抽卡、刷新、替换主流程

# EntryMap AttrEffect Unification Design

**Date:** 2026-04-15

**Goal**

在不重写现有运行时语义入口的前提下，把当前分散在多张 CSV 里的“确定性数值效果”统一收敛到一张 `attreffect.csv`，并通过 `source_type` / `source_id` 标记效果来源。

这次设计要解决两个问题：

- 策划层当前需要在不同系统里记多套“属性/资源/运行时加成”表，结构不统一。
- 程序层当前需要为主线任务、羁绊、烙印、局外奖励分别维护不同的读取和映射逻辑，后续扩展和排查来源都不够顺。

**Scope**

- 新增统一效果子表：`script/data_csv/attreffect.csv`
- 保留现有来源主表，不把所有系统都硬并成一个总表
- 首版统一以下“确定性数值效果”来源：
  - 羁绊节点属性加成
  - 羁绊节点 runtime 加成
  - 羁绊节点解锁资源奖励
  - 烙印属性加成
  - 烙印 runtime / attack_skill 数值加成
  - 主线任务中的属性、资源、可归一为属性或状态的确定性数值奖励
  - 局外模式属性奖励
- 统一 object table 装配层，但尽量保留现有 runtime 消费结构

**Non-Goals**

- 不在这一轮把 `auto_active_effects.csv` 合并进 `attreffect.csv`
- 不在这一轮把 `treasure_effects.csv` 中的概率、触发、时长、机制开关、刷新次数等行为逻辑合并进 `attreffect.csv`
- 不把所有运行时都改成直接解释 `attreffect.csv`
- 不在这一轮统一初始化基线配置，例如 `hero_init_stats.csv`、`battle_base_rules.csv`

## Existing Context

当前 EntryMap 已经存在多套“来源主表 + 效果子表/字段”的实现方式，但每套拆法不一致：

- `script/data_csv/bond_node_attr.csv`
- `script/data_csv/bond_node_runtime.csv`
- `script/data_csv/mark_bonus_attr.csv`
- `script/data_csv/mark_bonus_runtime.csv`
- `script/data_csv/mainline_task_rewards.csv`
- `script/data_csv/outgame_attr_bonuses.csv`

运行时消费方式也分散在不同模块：

- `script/data/object_tables/bond_nodes.lua`
- `script/data/object_tables/marks.lua`
- `script/data/object_tables/mainline_task_rewards.lua`
- `script/data/object_tables/outgame_attr_bonus_config.lua`
- `script/runtime/bonds_chain.lua`
- `script/runtime/mainline_tasks.lua`
- `script/runtime/rewards.lua`

另一方面，宝物兼容层已经证明“来源主表 + 统一 effect line + bucket 装配”是可行方向：

- `script/data_csv/treasure_effects.csv`
- `script/data/object_tables/treasure_catalog_compat.lua`

但宝物表里同时包含概率、机制、时长、刷新次数等行为效果。如果直接把全工程所有效果都塞进同一张万能表，会让解释器同时承担：

- 数值累加
- 行为触发
- 概率分支
- 临时效果实例化
- 状态机切换

这会让统一表迅速退化成“什么都能写，但什么都难维护”的万能垃圾桶。

## Recommended Approach

采用“保留来源主表，只新增一张统一 `attreffect.csv` 效果子表”的方案。

核心原则：

- 统一的是“确定性数值效果”
- 不统一“行为逻辑定义”
- 统一的是“存储层和装配层”
- 暂不强推统一“业务层消费接口”

也就是说：

- 羁绊、烙印、主线任务、局外奖励继续保留各自主表
- 它们原来分散的 `attr/resource/runtime` 数值效果，改为统一存到 `attreffect.csv`
- object table 继续输出各模块现在在用的数据结构，避免 runtime 一次性大改

这是当前工程里改动面最小、收益最稳定的方案。

## Data Model

### New CSV

新增：

- `script/data_csv/attreffect.csv`

推荐表头：

```csv
source_type,source_id,order_index,effect_kind,effect_key,value
```

示例：

```csv
source_type,source_id,order_index,effect_kind,effect_key,value
bond_node,bond_body_core_vitality,1,attr,力量,50
bond_node,bond_body_core_vitality,2,attr,生命,100
bond_node,bond_growth_strength,3,resource,wood,50
mark,war_god_mark,1,attr,伤害加成,12
mark,war_god_mark,2,runtime,boss_damage_bonus,0.20
mark,storm_mark,3,attack_skill,cooldown_reduction,0.10
mainline_task,1-1,1,attr,攻击范围,100
mainline_task,1-1,2,resource,wood,50
outgame_bonus,1-1:standard,1,attr,攻击白字,6
```

### Field Semantics

- `source_type`
  - 来源类型
  - 首版建议只允许：
    - `bond_node`
    - `mark`
    - `mainline_task`
    - `outgame_bonus`

- `source_id`
  - 来源主表主键
  - 例如：
    - `bond_body_core_vitality`
    - `war_god_mark`
    - `1-1`
    - `1-1:standard`

- `order_index`
  - 来源内稳定排序
  - 主要用于策划阅读顺序、导出顺序和静态校验

- `effect_kind`
  - 首版建议只允许：
    - `attr`
    - `resource`
    - `state`
    - `runtime`
    - `attack_skill`

- `effect_key`
  - 效果键
  - 其合法取值由 `effect_kind` 决定

- `value`
  - 数值
  - 首版统一按 `tonumber` 读取

### Effect Kind Rules

#### `attr`

用于英雄属性和成长属性，直接进入英雄属性体系。

示例：

- `力量`
- `生命`
- `攻击范围`
- `攻击白字`
- `每秒力量`
- `伤害加成`

约束：

- `effect_key` 必须属于统一属性白名单
- 白名单由两部分组成：
  - `runtime/hero_attr_defs.lua` 中可识别的 canonical 名称
  - 当前工程已稳定使用、但暂未并入 `hero_attr_defs.lua` 的兼容属性键，例如 `伤害加成`
- 首版不再允许主线任务这类局部缩写键直接进入统一表，例如 `hp`、`attack_range`

#### `resource`

用于立刻发放的会话资源。

首版只允许：

- `gold`
- `wood`
- `exp`

#### `state`

用于局内可累加状态，但不直接进入英雄属性面板。

示例：

- `skill_point`
- `hero_card_count`

说明：

- 这个 bucket 的意义是避免为了少量局内状态再拆一张额外表
- 但首版只迁移确定性数值状态，不迁移需要特殊行为解释的状态

#### `runtime`

用于现有 runtime 中已经存在、但不直接等价于英雄属性或资源的 bonus key。

示例：

- `boss_damage_bonus`
- `elite_damage_bonus`
- `gold_per_sec_bonus`
- `kill_reward_ratio`

约束：

- `effect_key` 必须是现有 runtime 真正消费的稳定 key
- 不允许混入概率、时长、触发器描述

#### `attack_skill`

用于当前直接作用于攻击技能实例或技能定义的确定性数值加成。

示例：

- `cooldown_reduction`
- `range_bonus`

约束：

- `effect_key` 必须在攻击技能加成白名单中
- 只承接确定性数值修改
- 不承接触发器、概率和临时实例行为

## Source Ownership

`attreffect.csv` 只承载“效果行”，不承载来源主体的其他元信息。

来源主表继续负责：

- 名称
- 描述
- 分类
- 展示资源
- 前置关系
- 候选池规则
- UI 文案

首版来源主表与 `attreffect.csv` 的职责拆分如下。

### Bond Node

保留：

- `script/data_csv/bond_nodes.csv`

迁移进 `attreffect.csv`：

- `script/data_csv/bond_node_attr.csv`
- `script/data_csv/bond_node_runtime.csv`
- `bond_nodes.csv` 中的 `unlock_gold`
- `bond_nodes.csv` 中的 `unlock_wood`
- `bond_nodes.csv` 中的 `unlock_exp`

其中：

- 羁绊属性加成写为 `effect_kind=attr`
- 羁绊 runtime 加成写为 `effect_kind=runtime`
- 解锁资源奖励写为 `effect_kind=resource`

### Mark

保留：

- `script/data_csv/marks.csv`
- `script/data_csv/mark_tags.csv`

迁移进 `attreffect.csv`：

- `script/data_csv/mark_bonus_attr.csv`
- `script/data_csv/mark_bonus_runtime.csv`

其中：

- 纯属性加成为 `attr`
- `bucket=runtime` 的行写为 `runtime`
- `bucket=attack_skill` 的行写为 `attack_skill`
- 后续如要接入 `hero_card_count`、`skill_point` 一类确定性状态，可用 `state`

### Mainline Task

保留：

- `script/data_csv/mainline_task_rewards.csv` 中任务基础信息：
  - `id`
  - `chapter_id`
  - `order_index`
  - `title_text`
  - `objective_text`
  - `target_count`

迁移进 `attreffect.csv`：

- 当前 `reward_1_type/key/value`
- 当前 `reward_2_type/key/value`
- 当前 `reward_3_type/key/value`

其中：

- `attr` 奖励转成 `effect_kind=attr`
- `resource` 奖励转成 `effect_kind=resource`
- 当前主线任务 CSV 中名为 `runtime` 的奖励列，迁移时按真实落点归类：
  - 若旧 key 最终映射到英雄属性，例如 `gold_per_sec -> 每秒金币`，则转成 `effect_kind=attr`
  - 若旧 key 最终映射到局内状态，则转成 `effect_kind=state`
  - 只有真实消费路径是 runtime bonus 时，才转成 `effect_kind=runtime`
- `special` 中的确定性数值状态可转成 `effect_kind=state`

首版仍保留在主表中的 `special`：

- `treasure_choice`

原因：

- 它不是简单加值，而是排队一次“宝物 3 选 1”行为
- 若强行写进 `attreffect.csv`，会污染统一效果表的边界

### Outgame Bonus

保留：

- 来源维度仍由 `stage_id + mode_id` 表示

迁移进 `attreffect.csv`：

- `script/data_csv/outgame_attr_bonuses.csv`

编码规则：

- `source_type=outgame_bonus`
- `source_id=<stage_id>:<mode_id>`

例如：

- `1-1:standard`
- `1-1:challenge`

## Out Of Scope For AttrEffect

以下内容首版明确不进入 `attreffect.csv`：

- `script/data_csv/auto_active_effects.csv`
- `script/data_csv/auto_active_effect_attr.csv`
- `script/data_csv/treasure_effects.csv` 中的：
  - `probability`
  - `temporary_buff`
  - `mechanic_toggle`
  - `refresh_count`
  - `trigger_growth`
  - 其他依赖条件、时长、概率或行为解释的效果
- `script/data_csv/hero_init_stats.csv`
- `script/data_csv/battle_base_rules.csv`
- `script/data_csv/wave_main_attr_overrides.csv`

原因不是这些内容“不重要”，而是它们不属于“确定性数值效果行”：

- 有些是行为定义
- 有些是初始化基线
- 有些是临时实例化规则
- 有些需要额外上下文才能正确执行

## Loader Architecture

### New Object Table

新增：

- `script/data/object_tables/attreffect.lua`

职责：

- 读取 `attreffect.csv`
- 校验字段合法性
- 按 `source_type`
- 再按 `source_id`
- 再按 `effect_kind`
  聚合成稳定结构

推荐输出结构：

```lua
{
  by_source = {
    bond_node = {
      bond_body_core_vitality = {
        attr = { ['力量'] = 50, ['生命'] = 100 },
        resource = {},
        state = {},
        runtime = {},
        attack_skill = {},
      },
    },
    mark = {
      war_god_mark = {
        attr = { ['伤害加成'] = 12 },
        resource = {},
        state = {},
        runtime = { boss_damage_bonus = 0.20 },
        attack_skill = {},
      },
    },
  }
}
```

### Existing Object Tables Stay Stable

首版不建议让业务层到处直接查 `attreffect.by_source`。

而是保留以下 object table 作为稳定业务出口：

- `script/data/object_tables/bond_nodes.lua`
- `script/data/object_tables/marks.lua`
- `script/data/object_tables/mainline_task_rewards.lua`
- `script/data/object_tables/outgame_attr_bonus_config.lua`

它们内部改成：

- 保留原本各自的主表读取
- 从 `attreffect.lua` 中读取对应来源的效果
- 再组装回当前运行时在用的结构

这样可以避免：

- `bonds_chain.lua` 一次性重写
- `mainline_tasks.lua` 一次性重写
- `rewards.lua` 一次性重写

## Runtime Compatibility

首版兼容策略如下。

### Bond Runtime

`script/runtime/bonds_chain.lua` 继续消费：

- `node_def.attr`
- `node_def.runtime`
- `node_def.unlock_rewards`

只是这些字段的底层来源改成 `attreffect.csv`。

### Mark Runtime

`script/runtime/rewards.lua` 继续消费：

- `def.bonuses.attr`
- `def.bonuses.runtime`
- `def.bonuses.attack_skill`

如果后续首版确实引入 `state`，则由 `marks.lua` 在装配层决定是否输出对应字段；不强制 runtime 这一轮立即消费。

### Mainline Task Runtime

`script/runtime/mainline_tasks.lua` 继续保留任务运行时语义：

- 任务主体信息从主表读取
- 奖励效果从 `attreffect.csv` 装配

兼容做法有两种：

1. 继续输出 `reward_lines`
2. 直接输出已分桶的 `attr/resource/state/runtime/attack_skill`

首版推荐第 1 种：

- 业务层几乎不用改
- 只是 `mainline_task_rewards.lua` 不再从 3 组固定列构造 `reward_lines`
- 改为从 `attreffect.csv` 生成任意行数的 `reward_lines`

### Outgame Bonus Runtime

`script/data/object_tables/outgame_attr_bonus_config.lua` 继续输出：

- `list`
- `by_stage_mode`

底层来源改成从 `attreffect.csv` 过滤：

- `source_type=outgame_bonus`
- `effect_kind=attr`

## Validation Rules

`attreffect.lua` 或独立 smoke test 至少需要做以下静态校验：

- `source_type` 非空
- `source_id` 非空
- `order_index` 可转为数字
- `effect_kind` 属于白名单
- `value` 可转为数字
- `source_type + source_id + order_index` 唯一

按 bucket 的额外校验：

- `attr`
  - `effect_key` 必须能被统一属性白名单识别
- `resource`
  - `effect_key` 只允许 `gold` / `wood` / `exp`
- `state`
  - `effect_key` 必须在状态白名单中
- `runtime`
  - `effect_key` 必须在现有 runtime bonus 白名单中
- `attack_skill`
  - `effect_key` 必须在攻击技能加成白名单中

## Migration Strategy

建议按以下顺序迁移。

### Phase 1

先迁：

- `bond_node_attr.csv`
- `bond_node_runtime.csv`
- `bond_nodes.csv` 解锁资源字段
- `mark_bonus_attr.csv`
- `mark_bonus_runtime.csv`

原因：

- 这两组当前已经天然接近“来源主表 + 效果子表”
- 迁移后收益直接，风险也最低

### Phase 2

再迁：

- `mainline_task_rewards.csv` 的数值奖励列

原因：

- 主线任务从固定 3 槽结构升级为任意行数，扩展性会立刻提升
- 但它还带 `special` 行为，需要保留边界

### Phase 3

最后迁：

- `outgame_attr_bonuses.csv`

原因：

- 结构简单
- 主要是统一来源查询口径

## File Changes

首版设计预期涉及：

- Add: `script/data_csv/attreffect.csv`
- Add: `script/data/object_tables/attreffect.lua`
- Modify: `script/data/object_tables/bond_nodes.lua`
- Modify: `script/data/object_tables/marks.lua`
- Modify: `script/data/object_tables/mainline_task_rewards.lua`
- Modify: `script/data/object_tables/outgame_attr_bonus_config.lua`
- Modify: 对应 smoke/static tests

预计仍保留但逐步退出主用途的旧 CSV：

- `script/data_csv/bond_node_attr.csv`
- `script/data_csv/bond_node_runtime.csv`
- `script/data_csv/mark_bonus_attr.csv`
- `script/data_csv/mark_bonus_runtime.csv`
- `script/data_csv/outgame_attr_bonuses.csv`

主线任务表会保留，但其数值奖励列可在迁移完成后裁剪为“任务主信息表”。

## Risks

- 如果 `attr`、`resource`、`runtime` 的 key 规范收不紧，`attreffect.csv` 仍会退化成新的映射地狱。
- 如果把 `special`、概率、时长、触发器也继续往里塞，统一表边界会失控。
- 如果 runtime 层直接大规模改成读取 `attreffect.lua`，会把本来可控的存储层重构升级成高风险行为层重构。
- `state` bucket 如果没有明确白名单，后续也容易变成“什么状态都能往里写”的第二个万能桶。

## Success Criteria

- 羁绊、烙印、主线任务、局外奖励的确定性数值效果，能够通过一张 `attreffect.csv` 统一表达。
- 每条效果都能通过 `source_type` / `source_id` 追溯来源。
- 现有 runtime 仍能继续消费稳定结构，不需要整片重写。
- 主线任务不再受限于固定 `reward_1/2/3` 槽位。
- 统一表没有混入概率、触发、时长和机制开关等行为逻辑。

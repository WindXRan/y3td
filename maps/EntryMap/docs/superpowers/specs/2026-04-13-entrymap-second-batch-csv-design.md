# EntryMap 第二批 CSV 转表设计

## 背景

首批 CSV 转表已经验证了当前 EntryMap 的基本路线可行：

- `script/data_csv/` 作为静态数据源
- `script/data/object_tables/*` 负责把 CSV 行装配成 runtime 继续消费的 Lua table
- `script/entry_objects/*/init.lua` 保留为稳定入口

在这个前提下，第二批转表应继续选择“静态对象明显、结构平整、行为逻辑少”的模块，优先扩大可表格维护的范围，而不是过早进入“数据驱动行为脚本”的高风险区域。

## 本次目标

- 把 `marks` 迁到 CSV，并沿用首批 `treasures` 已验证的装配模式
- 把 `stages` 与 `stage_modes` 迁到 CSV，保持关卡与模式装配入口稳定
- 把 `battle_base_config.lua` 与 `hero_attr_config.lua` 中适合表格维护的全局数值迁到 CSV
- 保持 `script/config/entry_config.lua` 与 `runtime/*` 的读取方式尽量不变
- 为后续更多配置迁移建立统一的 CSV 命名、装配与校验规范

## 非目标

- 不在本次迁移 `runtime/attack_upgrades.lua`
- 不把抽取规则、刷新费用、保底逻辑、`apply` 行为定义改成 CSV 驱动
- 不改变关卡流程、奖励逻辑、模式切换规则和英雄成长表现
- 不在本次引入运行时脚本解释器或 DSL

## 范围与优先级

第二批仅包含以下 4 组对象，按收益与风险排序如下：

1. `marks`
2. `stages` + `stage_modes`
3. `battle_base_config` + `hero_attr_config`
4. `attack_upgrades` 仅保留为后续课题，本轮不实施

### 1. marks

`marks` 与已经完成 CSV 化的 `treasures` 最相似：

- 属于标准静态对象
- 主要由基础字段与少量效果描述组成
- 不承担复杂抽取或行为执行逻辑

设计上直接复用“主表 + 子表”的模式：

- 主表承载 `id`、名称、稀有度、说明、展示文案等稳定字段
- 子表承载奖励、加成、标签等可变长内容
- `script/data/object_tables/marks.lua` 统一装配出 `list` 与 `by_id`

### 2. stages + stage_modes

这组数据的字段较少、结构平直，非常适合转成 CSV：

- `stages` 负责章节、解锁、推荐信息与基础流程配置
- `stage_modes` 负责模式标识、名称、说明和少量控制参数

设计目标不是把流程逻辑搬进 CSV，而是把“静态定义”从 Lua 单文件中抽离出来。运行时仍通过既有入口读取：

- `entry_objects.stages`
- `entry_objects.stage_modes`
- `entry_config.lua`

### 3. battle_base_config + hero_attr_config

这两组全局数值配置具备明显的表格维护价值：

- 成长曲线
- 资源规则
- 英雄初始属性模板
- 调试用基础属性

这里不追求把所有嵌套结构强行拍平成一张表，而是按“同类数值一张表”的原则拆分成若干小 CSV，再由装配层还原成现有 Lua 结构。核心原则：

- 对 runtime 暴露的 key 名尽量保持不变
- 不改变 `entry_data.battle_base_config` / `entry_data.hero_attr_config` 的消费方式
- 避免为了转表而引入难以理解的超宽 CSV

### 4. attack_upgrades（延期）

`attack_upgrades` 的收益确实很高，但本轮明确不做，原因如下：

- 数据中混有候选抽取规则
- 混有刷新费用与保底逻辑
- 混有 `apply` 行为定义与运行时约束
- 不是“纯静态对象 + 装配层”就能安全承接的范围

后续若要处理，应该单独立项，把它当成“数据驱动行为配置设计”而不是普通 CSV 转表。

## 架构方案

第二批继续沿用首批已跑通的三层结构：

1. `script/data_csv/*.csv`
   存放唯一静态数据源
2. `script/data/object_tables/*.lua`
   读取 CSV、完成类型转换、分组与对象装配
3. `script/entry_objects/*/init.lua` 与 `script/entry_data/*.lua`
   继续作为对外稳定入口

这个方案的好处是：

- runtime 基本不感知 CSV 细节
- 数据维护入口统一
- 回归验证可以集中在装配层和入口兼容性上

## 数据建模原则

### 主表优先表达“一个对象一行”

适用于：

- `marks`
- `stages`
- `stage_modes`

只把固定字段放进主表，避免把可变长数组硬塞进列。

### 子表承接“一对多”内容

适用于：

- `marks` 的 bonus、tag、附加描述
- 全局数值配置中的分段成长、资源规则、默认键值对

通过 `group_by` 装配，而不是在 CSV 中使用复杂分隔符协议。

### Lua 装配层负责类型恢复

CSV 中所有值初始都按字符串读取，因此装配层统一处理：

- number
- boolean
- 空值转 `nil`
- 排序字段

这样可以保证 runtime 看到的仍是干净 Lua table，而不是字符串字典。

## 错误处理与兼容策略

- 缺失必填列时由静态校验脚本直接失败
- 装配层对关键主键冲突、引用缺失给出明确报错
- 旧入口文件优先改为 `return require 'data.object_tables.xxx'`
- 只有在 CSV 装配层完全替代后，才删除旧的单对象 Lua 文件

## 验证策略

第二批验证仍以“静态装配正确 + 入口兼容不变”为主：

- 为每个新对象表增加 smoke test
- 校验主表与子表文件存在
- 校验装配后的 `list` 数量、主键可查性与关键字段类型
- 校验 `entry_config.lua` / runtime 继续通过既有模块入口读取

对于全局数值表，额外检查：

- 关键数值键存在
- 数值类型正确
- 默认模板字段完整

## 验收标准

满足以下条件即可认为第二批设计完成：

- `marks`、`stages`、`stage_modes`、全局数值表具备 CSV 唯一数据源
- Lua 装配层对 runtime 暴露的结构与既有入口兼容
- smoke test 能覆盖第二批所有新增装配入口
- `attack_upgrades` 未被误纳入本轮实现范围
- 后续若处理 `attack_upgrades`，需要单独 spec，不复用本次范围

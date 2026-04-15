# EntryMap 首批 CSV 转表设计

## 背景

当前 EntryMap 已经形成了较清晰的数据分层：

- `script/config/entry_config.lua` 负责汇总全局配置与对象入口
- `script/entry_objects/*` 负责维护波次、挑战、宝物、烙印等静态对象
- `script/runtime/*` 负责实际玩法运行时与抽取算法

现状的问题不是“没有配置层”，而是大量静态内容仍以单 Lua 文件维护。这样虽然适合开发期快速落地，但会带来以下问题：

- 策划批量调数值时效率低
- 同类对象跨文件对比成本高
- 运行时逻辑和静态内容边界虽已存在，但仍缺少可直接交给表格维护的载体
- 后续扩内容时容易继续堆单文件，维护成本上升

本设计目标是先完成一轮最小风险的 CSV 转表，把最像“配表”的静态对象迁到 CSV，同时保持现有 runtime 主逻辑和玩法行为尽量不变。

## 本次目标

- 把首批静态对象迁移为 CSV 维护
- 保持 `runtime/*` 现有算法和对外行为基本不变
- 让 `entry_config.lua` 和 `entry_objects/*` 继续作为 Lua 侧稳定入口
- 新增一层 CSV 读取与对象组装逻辑，让 runtime 仍消费 Lua table
- 为后续继续迁移 `G 三选一升级定义`、宝物/烙印更多子表打基础

## 非目标

- 不在本次重写抽卡、保底、权重等 runtime 算法
- 不把地图点位、区域、环境参数全面迁成 CSV
- 不在本次改动 UI 表现、HUD 结构、奖励队列交互
- 不追求一次性把所有 `entry_objects/*` 全部转表
- 不改变现有玩法数值与流程节奏

## 首批迁移范围

### 1. 波次

迁移对象：

- `script/entry_objects/waves/*.lua`

迁移原因：

- 当前波次对象几乎完全由静态字段组成
- 已经天然具备“主表 + 子表”的表格结构
- 后续章节、模式、挑战波次扩展都会依赖这一层

保留在 Lua 的内容：

- 运行时生成、切波、Boss 登场、软上限控制
- `runtime/battlefield.lua` 的行为逻辑

### 2. 挑战

迁移对象：

- `script/entry_objects/challenges/*.lua`

迁移原因：

- 结构简单稳定，字段高度统一
- 奖励、消耗、单位 ID、出生区域都属于典型静态配置

保留在 Lua 的内容：

- 挑战开始条件、战场生成、成功失败处理

### 3. 宝物

迁移对象：

- `script/entry_objects/treasures/*.lua`

迁移原因：

- 已经明显是内容池配置
- 后续会频繁加条目、调权重、调描述、调 bonus
- 继续以单 Lua 文件维护会让横向比较越来越困难

保留在 Lua 的内容：

- 保底逻辑
- 权重修正逻辑
- 临时宝物运行时状态
- 宝物效果的真正施加流程

### 4. 烙印节点

迁移对象：

- `script/entry_objects/mark_nodes/*.lua`

迁移原因：

- 节点本身就是纯门槛触发配置
- 字段结构固定，最适合先迁

保留在 Lua 的内容：

- 烙印抽取逻辑
- 已触发节点的运行时记录

## 暂不迁移的内容

### 地图点位与区域

暂不迁移：

- `entry_config.lua` 中的 `points`
- `entry_config.lua` 中的 `areas`

原因：

- 这些配置更偏地图环境与调试校准
- 与普通策划数值表不是同一维护语境
- 当前项目也明确将其作为全局环境配置保留在主配置层

### G 三选一升级算法

暂不迁移：

- `runtime/attack_upgrades.lua` 中的候选抽取逻辑
- 刷新扣费逻辑
- 保底逻辑

原因：

- 这部分既有静态定义，也有较多运行时策略
- 本次先优先打通“CSV -> Lua 对象 -> runtime”链路

补充说明：

- 本次设计会为后续迁移升级定义预留同样的 loader 模式

## 数据目录设计

新增目录：

- `script/data_csv/`

首批建议文件如下：

- `script/data_csv/waves.csv`
- `script/data_csv/wave_spawn_segments.csv`
- `script/data_csv/wave_rewards.csv`
- `script/data_csv/challenges.csv`
- `script/data_csv/treasures.csv`
- `script/data_csv/treasure_bonus_attr.csv`
- `script/data_csv/treasure_bonus_runtime.csv`
- `script/data_csv/treasure_bonus_reward_ratio.csv`
- `script/data_csv/treasure_bonus_passive_income.csv`
- `script/data_csv/mark_nodes.csv`

命名原则：

- 主表保存对象主体字段
- 子表保存一对多字段或结构化 bonus
- 不把复杂结构塞进单元格 JSON，尽量保持列式表格可读性

## 表结构设计

### waves.csv

字段：

- `id`
- `index`
- `name`
- `main_unit_id`
- `boss_unit_id`
- `spawn_area_id`
- `boss_spawn_area_id`
- `boss_spawn_sec`
- `batch_min`
- `batch_max`
- `max_alive`
- `post_boss_interval_sec`
- `main_spawn_hp`
- `boss_special`
- `theme`
- `boss_timeline_profile_id`
- `boss_low_hp_profile_id`

说明：

- 每行对应一个波次主体
- 单值字段全部留在主表

### wave_spawn_segments.csv

字段：

- `wave_id`
- `order`
- `start_sec`
- `interval_sec`

说明：

- 每行表示一个刷新节奏段
- loader 读入后按 `order` 排序并组装回 `spawn_segments`

### wave_rewards.csv

字段：

- `wave_id`
- `main_exp`
- `main_gold`
- `main_wood`
- `boss_exp`
- `boss_gold`
- `boss_wood`

说明：

- 把主怪和 Boss 的击杀奖励拆成显式字段
- loader 负责组回 `main_kill_reward` 与 `boss_kill_reward`

### challenges.csv

字段：

- `id`
- `name`
- `cost_charge`
- `spawn_area_id`
- `unit_id`
- `boss_unit_id`
- `guard_unit_id`
- `reward_gold`
- `reward_wood`
- `reward_exp`
- `reward_special`

说明：

- 兼容单单位挑战与双单位挑战
- 不使用的单位列允许留空

### treasures.csv

字段：

- `id`
- `name`
- `quality`
- `pool_weight`
- `summary`

说明：

- 只保留宝物主体元数据
- bonus 全部拆到子表，避免主表过宽

### treasure_bonus_attr.csv

字段：

- `treasure_id`
- `attr_name`
- `value`

说明：

- 对应 `bonuses.attr`

### treasure_bonus_runtime.csv

字段：

- `treasure_id`
- `key`
- `value`

说明：

- 对应 `bonuses.runtime` 与类似运行时数值修正

### treasure_bonus_reward_ratio.csv

字段：

- `treasure_id`
- `key`
- `value`

说明：

- 对应 `bonuses.reward_ratio`

### treasure_bonus_passive_income.csv

字段：

- `treasure_id`
- `key`
- `value`

说明：

- 对应 `bonuses.passive_income`

### mark_nodes.csv

字段：

- `id`
- `trigger_level`
- `choice_count`
- `queue_priority`
- `ui_title`

说明：

- 一行一个烙印节点

## Lua 侧架构设计

### 1. 新增 CSV 读取工具层

新增模块建议：

- `script/data/csv_loader.lua`
- `script/data/csv_parsers.lua`

职责：

- 读取 CSV 文件
- 做基础类型转换
- 提供按主键分组、按字段聚合、按顺序排序等通用能力

约束：

- 工具层不感知具体玩法对象
- 只负责通用表解析与基础数据组织

### 2. 新增对象装配层

新增模块建议：

- `script/data/object_tables/waves.lua`
- `script/data/object_tables/challenges.lua`
- `script/data/object_tables/treasures.lua`
- `script/data/object_tables/mark_nodes.lua`

职责：

- 读取对应 CSV
- 组装出与现有 `entry_objects/*` 接近的 Lua table
- 统一返回 `list` / `by_id` / `by_level` 等结构

### 3. 让 entry_objects 继续作为 runtime 入口

`entry_objects/*/init.lua` 不直接消失，而是改成转调新的对象装配层。

这样做的好处：

- `entry_config.lua` 无需感知 CSV
- `runtime/*` 不需要大改 require 路径
- 可以逐类迁移，而不是一次性推翻现有入口

### 4. 单对象 Lua 文件的处理策略

首批迁移完成后，原来的单对象 Lua 文件直接移除，不保留并行数据源。

固定策略：

- 删除原单对象文件
- 让 `init.lua` 统一走 CSV loader

这样可以避免以下问题：

- CSV 与 Lua 双源内容不一致
- 后续维护时误改旧文件
- 实现完成后仍需要判断真实数据源

## 数据流

迁移后的数据流如下：

`CSV 文件 -> 通用 CSV loader -> 对象装配层 -> entry_objects 聚合入口 -> entry_config 汇总 -> runtime 消费`

重点是：

- CSV 不直接暴露给 runtime
- runtime 仍只依赖 Lua 对象结构
- 数据形态变化被限制在加载边界，不扩散到玩法逻辑层

## 兼容策略

本次实现需要保证以下兼容性：

- `CONFIG.waves` 的结构保持兼容
- `ChallengeObjects.by_id` 的结构保持兼容
- `TreasureObjects.list` / `by_id` 的结构保持兼容
- `MarkNodeObjects.by_level` 的结构保持兼容

兼容重点：

- 数值字段要正确转成 number
- 空字段需要转成 `nil`，而不是空字符串
- 子表聚合顺序必须稳定
- `spawn_segments` 必须按 `order` 输出

## 错误处理

CSV 迁移最容易出问题的地方不是算法，而是脏数据和类型错误。本次 loader 需要提供最小必要校验：

- 缺少主键时报错
- 重复主键时报错
- 引用不存在的主对象时报错
- 应为数字的字段无法转换时报错
- 必填字段缺失时报错

错误呈现方式：

- 启动时直接 `error`
- 报错信息包含文件名、主键和值

不在本次做的事情：

- 编辑器级自动修复
- 复杂 schema 系统

## 测试与验证

本次不额外建设完整自动化测试体系，但至少需要以下最小验证：

### 静态验证

- CSV 能成功被读取
- 组装出的对象数量与迁移前一致
- 关键样例对象字段与迁移前一致

建议样例：

- `wave_1`
- `gold_trial`
- `coin_casket`
- `mark_node_lv10`

### 运行时回归

- 能正常进入战斗
- 第 1 波正常刷怪
- 可正常开启一个挑战
- 宝物选择轮次能正常展示并生效
- 10 级烙印轮次能正常触发

## 实施顺序

1. 增加通用 CSV loader
2. 迁移 `waves`
3. 迁移 `challenges`
4. 迁移 `mark_nodes`
5. 迁移 `treasures`
6. 调整 `entry_objects/*/init.lua` 接新 loader
7. 做最小静态校验与手动回归

说明：

- `treasures` 最复杂，放到最后迁，避免一开始就被 bonus 结构拖慢节奏

## 风险与取舍

### 风险 1：双源维护

如果 CSV 和旧 Lua 文件同时作为有效源，会很快失控。

结论：

- 迁移完成后必须只有一个真实数据源

### 风险 2：表拆分过细

如果一开始把所有对象都拆成很多小表，会让维护体验变差。

结论：

- 只对确实是一对多或异构 bonus 的部分拆子表

### 风险 3：运行时结构被牵连

如果 runtime 直接改为消费原始 CSV 行数据，会导致改动面过大。

结论：

- 坚持由装配层输出兼容 Lua 对象

## 后续扩展

本次链路跑通后，下一批适合继续迁移的对象为：

- `G 三选一升级定义`
- `marks`
- `stages`
- `stage_modes`
- `battle_base_config.lua` 中的成长与经济数值
- `hero_attr_config.lua` 中的初始属性模板

优先顺序建议：

1. `marks`
2. `stages` / `stage_modes`
3. `G 三选一升级定义`
4. 全局数值表

## 验收标准

满足以下条件即可认为本次设计目标完成：

- 首批 4 类对象可由 CSV 作为唯一数据源
- `entry_config.lua` 与 `runtime/*` 仍通过既有 Lua 入口读取数据
- 战斗、挑战、宝物、烙印节点主链路可正常运行
- 不引入第二套并行维护入口
- 后续对象迁移可复用同一 loader 与装配模式

# EntryMap 进化节点与抽取规则 CSV 化设计

## 背景

当前 EntryMap 的进化系统已经完成了一半 CSV 化：

- 进化本体已经由 `script/data_csv/marks.csv` 与 bonus 子表维护
- 运行时仍通过 `entry_objects.marks` 读取装配后的 Lua table

但还有两块核心配置仍停留在 Lua / runtime 硬编码中：

1. 等级触发节点 `mark_nodes`
2. 进化候选抽取规则 `pick_mark_choices()`

这会带来两个问题：

- 节点与抽取规则无法像进化本体一样统一交给表格维护
- 抽取逻辑虽然简单，但现在与 runtime 强耦合，不利于后续微调品质概率、保底策略和节点规则

因此本次目标不是重做整套进化系统，而是把“节点配置 + 抽取规则”补齐到 CSV 层，让进化链路完整收口到同一套数据装配模式。

## 本次目标

- 把进化节点配置迁到 CSV
- 把进化抽取规则迁到 CSV
- 保持现有 `marks.csv`、bonus 子表与 runtime 效果结构不变
- 保持 `entry_objects.mark_nodes` 作为稳定 Lua 入口
- 让 runtime 从节点对象中读取 `pool_rule_id`，而不是继续依赖硬编码抽取规则

## 非目标

- 不重命名内部 `mark_*` 技术标识
- 不把进化效果定义重做成新的 DSL
- 不重做 `STATE.mark_runtime` 结构
- 不在本次引入复杂路线偏置、构筑推荐、条件标签脚本执行
- 不改 UI 交互流程，只改其数据来源

## 范围

本次仅包含两层数据：

1. 进化节点配置
2. 进化抽取规则

进化本体数据继续沿用现有：

- `script/data_csv/marks.csv`
- `script/data_csv/mark_bonus_attr.csv`
- `script/data_csv/mark_bonus_runtime.csv`
- `script/data_csv/mark_tags.csv`

## 方案对比

### 方案 A：最小完整 CSV 化

内容：

- 把节点定义迁到 `evolution_nodes.csv`
- 把抽取规则迁到 `evolution_pool_rules.csv`
- runtime 只增加“按规则表抽取”的能力
- 效果定义仍复用当前 `marks.csv + bonus 子表`

优点：

- 风险最低
- 能完成“进化系统剩余配置全部进表”的核心目标
- 不需要把效果执行逻辑也推到数据解释器

缺点：

- 规则表达能力只覆盖当前已落地需求

### 方案 B：全量数据驱动

内容：

- 节点、规则、效果组、监听器、路径偏置全部拆表

优点：

- 更接近长期理想形态

缺点：

- 超出当前 runtime 的承接能力
- 会显著扩大范围和验证面

## 推荐方案

采用方案 A。

原因：

- 用户明确要“全部做成 CSV 配表”，但当前真正尚未进表的只有“节点 + 抽取规则”
- 当前 `marks.csv` 体系已经稳定，继续复用最安全
- 这样能把进化系统收口成一套清晰的三层结构，而不会把需求膨胀成“行为脚本数据驱动化”

## 数据结构设计

### 1. `evolution_nodes.csv`

用途：

- 描述哪些等级会触发一次进化选择
- 该轮使用哪套抽取规则
- 该轮标题和队列优先级是什么

字段：

- `id`
- `trigger_level`
- `choice_count`
- `pool_rule_id`
- `queue_priority`
- `ui_title`

首版示例：

- `mark_node_lv10,10,3,mark_pool_global,95,10级进化选择`
- `mark_node_lv20,20,3,mark_pool_global,95,20级进化选择`
- `mark_node_lv30,30,3,mark_pool_global,95,30级进化选择`
- `mark_node_lv40,40,3,mark_pool_global,95,40级进化选择`

### 2. `evolution_pool_rules.csv`

用途：

- 描述单轮进化候选的品质权重与保底逻辑

字段：

- `pool_rule_id`
- `choice_count`
- `common_weight`
- `rare_weight`
- `epic_weight`
- `guarantee_high_quality`
- `same_round_no_repeat`
- `exclude_owned`
- `enabled`

首版规则：

- `mark_pool_global,3,65,25,10,true,true,true,true`

## 装配层设计

新增：

- `script/data/object_tables/evolution_nodes.lua`

职责：

- 读取 `evolution_nodes.csv`
- 读取 `evolution_pool_rules.csv`
- 做 number / boolean 类型恢复
- 输出：
  - `list`
  - `by_id`
  - `by_level`
  - `pool_rules_by_id`

兼容策略：

- `script/entry_objects/mark_nodes/init.lua` 改为 `return require 'data.object_tables.evolution_nodes'`
- 外部仍通过 `entry_objects.mark_nodes` 使用，不感知 CSV 细节

## Runtime 设计

### 当前状态

`pick_mark_choices(choice_count)` 当前只做了：

- 排除已拥有
- 按 `pool_weight` 随机
- 同轮去重

没有品质概率规则，也没有“每轮至少 1 个 rare/epic”的保底逻辑。

### 改造后

`pick_mark_choices(pool_rule, choice_count)` 读取规则表并执行：

1. 先建立可选进化池
2. 若 `exclude_owned = true`，排除已拥有
3. 若 `same_round_no_repeat = true`，同轮不重复
4. 按品质权重先决定抽取品质，再从该品质池内按 `pool_weight` 抽取
5. 若 `guarantee_high_quality = true`，确保本轮至少有 1 个 `rare` 或 `epic`

节点调用路径改为：

- `try_queue_mark_node_for_level(level)`
  - 从 `MARK_NODES_BY_LEVEL[level]` 取得节点
  - 通过 `node.pool_rule_id` 找到规则
  - 按该规则生成 `candidate_mark_ids`

## 兼容与边界

- `mark_choice`、`candidate_mark_ids`、`owned_mark_ids` 等 runtime key 保持不变
- `MARK_NODES_BY_LEVEL` 继续存在
- 进化显示文案继续沿用“进化”
- 内部模块和目录名继续保留 `mark`

## 错误处理

- 节点引用了不存在的 `pool_rule_id` 时，装配层直接报错
- 规则表缺失必填列时，CSV loader smoke 失败
- 某品质池为空时，允许回退到其他可用品质池，但需要保证最终不会死循环
- `enabled = false` 的规则不参与运行时选择

## 验证策略

新增测试应覆盖：

1. `evolution_nodes` loader smoke
   - `by_level[10]` / `by_level[20]` 等存在
   - `pool_rule_id` 正确
2. `evolution_pool_rules` smoke
   - `mark_pool_global` 可读
   - boolean / number 类型正确
3. 抽取规则 smoke
   - 同轮无重复
   - 已拥有项被排除
   - 在可行条件下至少产出 1 个 `rare/epic`
4. 回归 smoke
   - 原有 `marks csv loader smoke` 继续通过

## 验收标准

满足以下条件即可认为设计完成：

- 进化节点配置由 CSV 作为唯一数据源
- 进化抽取规则由 CSV 作为唯一数据源
- `entry_objects.mark_nodes` 继续提供 `list / by_id / by_level`
- runtime 不再写死进化品质权重与保底逻辑
- 现有进化本体和 bonus 结构保持兼容

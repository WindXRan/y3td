# EntryMap 局内战斗目标奖励完整落地设计

## 背景

当前局内战斗目标系统的核心运行时位于 [`script/runtime/mainline_tasks.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/runtime/mainline_tasks.lua)，任务配表入口位于 [`script/data_csv/mainline_task_rewards.csv`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/data_csv/mainline_task_rewards.csv)，并通过 [`script/data/object_tables/mainline_task_rewards.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/data/object_tables/mainline_task_rewards.lua) 叠加来自 `attreffect.csv` 的统一奖励行。

当前任务目标本身已经能推进，但“配表里能表达的奖励”没有全部真正落到运行时：

- `attr`、`resource`、部分 `state` 已有基础执行路径。
- `attreffect.lua` 已允许更多 `runtime` 奖励键进入系统，但主线任务运行时还没有对这些键建立完整执行。
- `attack_skill` 在统一效果表里已是合法类型，但主线任务执行器尚未消费。
- 现有 smoke 更偏向任务推进，对“奖励字段是否真的生效”覆盖不足。

本次目标不是扩展新的任务目标类型，而是把“当前配表内容”完整实现。

## 目标

- 保持当前“击杀计数型”战斗目标流程不变。
- 完整支持当前主线任务配表可表达的奖励类别：
  - `attr`
  - `resource`
  - `state`
  - `runtime`
  - `attack_skill`
- 让加载层和执行层对“允许的奖励键”保持一致，避免出现“表能配、运行时不生效”。
- 补齐静态测试和 smoke，确保奖励不是只被加载，而是会真实落到状态或角色上。

## 非目标

- 不扩展新的任务目标类型，例如到达、交互、护送、累计存活等。
- 不重做全项目统一奖励系统，不把羁绊、局外奖励、主线任务统一迁移到新的总执行器。
- 不重做 HUD 样式或 UI 资源结构。
- 不调整当前任务链顺序和章节配置。

## 当前实现与缺口

### 已有能力

- [`script/runtime/mainline_tasks.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/runtime/mainline_tasks.lua)
  - 能根据当前任务和击杀事件推进进度。
  - 能在完成时发奖励。
  - 能处理 `attr`、`resource`、一部分 `state/runtime`。
- [`script/data/object_tables/mainline_task_rewards.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/data/object_tables/mainline_task_rewards.lua)
  - 能把 `mainline_task_rewards.csv` 与 `attreffect.csv` 合并成 `reward_lines`。

### 明确缺口

- `runtime` 奖励键目前只覆盖了 `RUNTIME_ATTR_KEY_MAP` 中少量旧式映射，和统一表允许的 key 集不一致。
- `attack_skill` 奖励没有执行逻辑。
- `state` 奖励只处理了少量分支，没有统一执行映射。
- 对“统一表允许键”和“主线任务可执行键”没有自动一致性校验。
- 缺少代表性 reward smoke，现有测试更偏推进逻辑。

## 方案

采用“保留现有主线任务运行时，补齐奖励执行适配层”的方案。

### 1. 数据层保持不变，继续输出标准化 `reward_lines`

继续由 [`script/data/object_tables/mainline_task_rewards.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/data/object_tables/mainline_task_rewards.lua) 负责：

- 读取 `mainline_task_rewards.csv`
- 读取 `attreffect.csv` 中 `source_type = mainline_task` 的奖励
- 标准化为统一的 `reward_lines`

这层只负责“配表解释”，不直接操作运行时状态。

### 2. 在主线任务运行时建立统一奖励执行映射

在 [`script/runtime/mainline_tasks.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/runtime/mainline_tasks.lua) 中，将当前零散的奖励分支整理为明确的执行映射：

- `attr`：进入英雄属性包，再调用 `add_hero_attr_pack`
- `resource`：进入 `award_rewards`
- `state`：进入专门的状态执行分派
- `runtime`：进入统一 runtime 奖励执行分派
- `attack_skill`：进入攻击技能修正执行分派

核心原则：

- 每一种 `reward_lines.type` 都要有独立执行入口。
- 每一个允许进入主线任务的 key，都必须能映射到一个真实落点。
- 无法执行的 key 必须在测试或加载阶段明确失败，而不是静默忽略。

### 3. runtime 奖励按“真实落点”分类执行

`runtime` 奖励不要继续混在“英雄属性映射”里一把梭，而是拆成两类：

- 可以安全转成英雄属性语义的，继续汇总进 `attr_pack`
- 需要写入运行时状态或独立系统字段的，直接写入对应 runtime state

这样可以处理当前统一表里已经出现或允许出现的键，例如：

- 击杀成长类
- 每秒成长类
- 伤害增幅类
- 多重射击 / 连锁弹射 / 技能回响类

每个键都需要一个明确的状态落点，例如：

- `STATE` 某个 runtime bucket
- `mainline_task_runtime` 下的增益缓存
- 或现有英雄属性/攻击技能系统已经约定的配置对象

本轮不要求重构这些系统，但要求主线任务奖励能够把值写到它们已经消费的位置。

### 4. attack_skill 奖励接到攻击技能修正状态

对 `attack_skill` 奖励，主线任务运行时需要：

- 识别并累加奖励
- 写入一个稳定的 runtime 容器
- 让后续攻击技能或战斗逻辑能消费该容器

如果项目里已经存在攻击技能修正状态，应直接复用；如果没有，就在主线任务 runtime state 下建立一个小而清晰的容器，只存放配表驱动的攻击技能修正值。

### 5. 一致性测试锁住“表允许 ≈ 运行时可执行”

新增静态测试，验证：

- `attreffect.lua` 中主线任务允许的 effect kind 被 `mainline_task_rewards.lua` 接收
- `mainline_tasks.lua` 对主线任务允许出现的 `type/key` 有明确执行路径
- 不再出现“加载允许，但 apply 时无效”的情况

### 6. smoke 测试锁住真实生效

新增或扩展 smoke，覆盖：

- `resource` 奖励真实进奖励包
- `state` 奖励真实写入 `STATE`
- 一类普通 `runtime` 奖励真实写入 runtime 状态
- 一类当前已暴露问题的 runtime key，例如 `chain_bounces`
- 如主线任务路径允许 `attack_skill`，再加一条 attack skill smoke

## 代码落点

### 需要修改

- [`script/runtime/mainline_tasks.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/runtime/mainline_tasks.lua)
  - 抽出统一奖励执行分派
  - 补齐 `state` / `runtime` / `attack_skill`
- [`script/data/object_tables/mainline_task_rewards.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/data/object_tables/mainline_task_rewards.lua)
  - 补齐必要的 effect kind / key 归一逻辑
  - 明确与执行层一致的映射约束
- [`script/tools/test_mainline_task_runtime_smoke.lua`](c:/Y3TD/Y3GPT/y3td/maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua)
  - 扩展奖励生效断言

### 可能新增

- 针对奖励完整性的静态测试
- 针对 runtime / attack_skill 奖励的 smoke 测试

## 风险与处理

- `runtime` 键的真实落点如果分散在多个系统，容易出现“写了状态但没人消费”。
  - 处理：优先复用现有消费字段；只有在确实没有落点时，才新增最小状态容器。
- `attreffect.lua` 允许的 key 可能比主线任务当前实际使用的还多。
  - 处理：测试按“主线任务允许使用的子集”收口，不无意义地一次性为全项目所有 key 背书。
- 现有 smoke 已经受 `attreffect` 校验影响。
  - 处理：先把主线任务奖励映射补齐，再恢复 smoke。

## 验收标准

- 当前主线任务配表中出现的奖励类型都能真实生效。
- 当前主线任务统一效果表中允许并实际使用的 key 都有稳定执行路径。
- 任务完成后，奖励只发一次，且状态/数值变化可被 smoke 断言。
- 不再出现“表加载成功但奖励运行时无效”的静默情况。

# EntryMap 主线任务面板设计

## 背景

`EntryMap` 当前已经具备主线任务运行时与 `GameHUD.hud_root.right_tracker_panel` 右侧追踪区骨架，但这块面板还没有正式接入局内主线任务展示，也没有完成 `自动任务` 开关的真实联动。

本次目标是把右侧追踪区做成局内可用的主线任务卡，直接接入现有 `mainline_task_rewards.csv` 与 `runtime.mainline_tasks`，并贴近参考图的视觉层级。

## 目标

- 在局内 HUD 右侧展示当前主线任务卡
- 接入当前主线任务标题、目标、真实进度、奖励内容
- 实现 `自动任务` 开关的点击切换、状态保存与运行时联动
- 保持与现有 `GameHUD` 节点骨架兼容，不新开第二套 HUD 结构

## 非目标

- 不扩展成多任务列表
- 不替玩家执行任何自动战斗、自动移动、自动抽卡或自动挑战
- 不在本次重构整个主线任务系统
- 不处理尚未进入当前 `mainline_task_rewards.csv` 的第五章数据制作

## 现状

### 已有数据链路

- 主线任务配表位于 `maps/EntryMap/script/data_csv/mainline_task_rewards.csv`
- 配表加载位于 `maps/EntryMap/script/data/object_tables/mainline_task_rewards.lua`
- 配置接线位于 `maps/EntryMap/script/config/entry_config.lua`
- 运行时摘要由 `maps/EntryMap/script/runtime/mainline_tasks.lua` 的 `get_current_task_summary()` 提供
- 启动接入位于 `maps/EntryMap/script/runtime/boot.lua`

### 已有 UI 骨架

- `maps/EntryMap/ui/GameHUD.json` 已有 `GameHUD.hud_root.right_tracker_panel`
- 当前预留节点包括：
  - `tracker_title`
  - `tracker_objective`
  - `tracker_progress`
  - `tracker_reward`
  - `tracker_hint`
  - `auto_task_checkbox`
  - `auto_task_label`

### 当前缺口

- 右侧追踪区尚未按主线任务正式刷新
- `progress_text` 当前固定为 `(0/target)`，没有真实当前进度
- 奖励文案目前会直接显示原始 key，不适合直接展示给玩家
- `auto_task_checkbox` 只有节点，没有真实状态和交互
- 现有主线配表条目数为 40 条，覆盖 `1-1` 到 `4-10`

## 方案选择

本次采用 `方案 B：保留现有节点结构，重做右侧追踪区样式`。

原因：

- 现有 `GameHUD` 已经预留了右侧任务追踪区，继续沿用可以减少结构性风险
- 保留节点名可以复用 `runtime_hud_nodes.lua` 的解析路径，避免新增并行 UI 体系
- 在此基础上重做样式，能更贴近参考图的视觉表达

## UI 设计

### 挂载方式

任务面板继续使用 `GameHUD.hud_root.right_tracker_panel`，不新增独立弹层，不新增单独 prefab。

### 布局内容

面板固定展示单条当前主线任务，内容顺序如下：

1. 顶部小提示区
2. 主线编号标题，例如 `主线4-6`
3. `任务：` 标签与任务目标，例如 `击杀魁魔`
4. 真实进度，例如 `击杀魁魔(0/3)` 或 `击杀魁魔(2/3)`
5. `奖励：` 标签
6. 最多 3 行奖励文本
7. 底部 `自动任务` 勾选框与标签

### 视觉风格

面板视觉贴近用户提供的参考图，但遵守当前项目 HUD 的整体语言：

- 使用深灰黑半透明底板
- 使用细描边与弱内阴影强化卡片边界
- 主标题采用高对比白字
- `任务` 与 `奖励` 标签使用偏黄绿色强调
- 进度数字中的当前值使用强调色
- 在标题下方增加细青色分隔线
- 面板整体保持轻装饰，避免压过战斗主视野

### 文案规则

- 标题来自 `summary.title_text`
- 任务目标优先显示 `任务：` + `summary.objective_text`
- 进度行显示 `summary.objective_text` 加真实 `(current/target)`
- 奖励区逐行显示转义后的玩家文案，不显示底层 key
- 提示区显示当前自动任务状态或任务完成状态

## 数据设计

### 主线任务来源

任务面板唯一数据源为 `mainline_task_system.get_current_task_summary()`，不额外维护第二套任务模型。

摘要结构继续以当前运行时为基础，补充真实进度与可展示文案：

- `id`
- `title_text`
- `objective_text`
- `target_count`
- `current_count`
- `progress_text`
- `reward_lines`
- `reward_line_texts`
- `is_completed`

### 真实进度

当前 `mainline_tasks.lua` 中的进度文本固定为 `(0/target)`，本次需要补上真实计数。

设计如下：

- 在 `STATE.mainline_task_runtime` 下新增当前任务进度桶
- 进度按任务 id 记录，不和奖励发放状态混用
- 主线任务清理判定仍以当前任务完成事件为准
- 面板展示读取当前任务 id 对应的实时值

当前版本仅要求支持与现有主线清理逻辑一致的进度展示，不额外扩展复杂条件任务。

### 奖励文案映射

需要把配表中的原始 key 转成玩家可读文本。

属性奖励继续复用 `ATTR_KEY_MAP` 与 `RUNTIME_ATTR_KEY_MAP` 思路，但要同时满足两类需求：

- 奖励应用时可正确落地
- 面板展示时有稳定中文名称

本次需要补齐当前配表里出现但展示/应用映射不完整的 key，包括：

- `kill_count`
- `kill_per_sec`
- `kill_material_pct`

所有奖励展示文案统一输出为 `名称 +数值` 或 `名称 +百分比` 形式。

### 自动任务状态

`自动任务` 只控制右侧任务追踪区的自动跟随行为，不代替玩家执行操作。

状态保存位置放入 `STATE.mainline_task_runtime`，与主线章节和楼层共存，避免新增分散状态：

- `auto_track_enabled`
- `pinned_task_id`
- `last_snapshot`

规则如下：

- 默认开启
- 开启时，面板始终跟随当前主线任务刷新
- 关闭时，面板保留最近一次已展示的任务快照，不随着当前波次推进自动切换
- 玩家再次开启后，立即回到当前真实任务

## 运行时交互

### 面板刷新

HUD 刷新时执行以下流程：

1. 获取当前主线任务摘要
2. 依据自动任务状态决定使用当前摘要还是冻结快照
3. 刷新标题、目标、进度、奖励与提示文本
4. 刷新勾选框显示状态
5. 如果当前无主线任务，则显示占位文案

### 勾选框交互

`auto_task_checkbox` 需要绑定点击事件。

点击后：

- 切换 `auto_track_enabled`
- 更新勾选框选中状态
- 更新 `tracker_hint`
- 立即触发一次面板刷新

### 任务完成反馈

当前任务完成后：

- 若自动任务开启，面板切换到下一条当前任务
- 若自动任务关闭，面板保留完成前快照，直到玩家重新开启自动任务
- 提示区可短暂显示 `当前主线已完成`

## 文件职责

### 需要修改的文件

- `maps/EntryMap/ui/GameHUD.json`
  - 调整右侧追踪区的布局与样式
- `maps/EntryMap/ui_tree/GameHUD_Tree.json`
  - 由 UI 树生成流程更新，确保节点树与 UI 一致
- `maps/EntryMap/script/ui/runtime_hud_nodes.lua`
  - 如有必要，补充右侧任务区新增或重命名节点解析
- `maps/EntryMap/script/ui/runtime_hud_panel1_top.lua`
  - 接入右侧任务区的刷新逻辑与勾选框交互
- `maps/EntryMap/script/runtime/mainline_tasks.lua`
  - 补真实进度、奖励展示文案与自动任务状态访问接口
- `maps/EntryMap/script/runtime/boot.lua`
  - 把主线任务摘要与任务面板需要的行为注入 HUD

### 需要新增或补充的测试

- 主线任务摘要测试：验证真实进度、奖励文本与自动任务状态默认值
- HUD 静态测试：验证右侧任务区节点仍存在
- UI/HUD 逻辑测试：验证右侧任务区刷新链路引用了主线任务摘要

## 测试方案

### 静态验证

- 验证 `mainline_task_rewards.csv` 仍然可以加载 40 条数据
- 验证 `GameHUD` 节点树仍然包含右侧任务区关键节点
- 验证 HUD 刷新逻辑继续引用 `get_mainline_task_summary`

### 运行时验证

- 进入局内后右侧出现任务卡
- `1-1` 开始时显示当前主线编号、目标、进度和奖励
- 波次推进后面板随当前主线变化
- 点击 `自动任务` 后面板状态可切换
- 关闭自动任务后，当前展示不自动跳转
- 再次开启自动任务后，面板恢复跟随当前任务

## 风险与约束

### 第五章数据未接入

当前主线任务 CSV 仅覆盖 `1-1` 到 `4-10`。因此本次 UI 实现以当前配表范围为准，不虚构第五章内容。

如果后续补入 `5-1 ~ 5-10`，当前任务面板设计无需改结构，只需要增加配表与运行时支持。

### 配表 key 与运行时映射不齐

当前少量 `runtime` 奖励 key 未完全进入展示/应用映射。如果不补齐，会出现玩家文案穿帮或奖励应用缺失。

本次实现必须顺手补齐这些 key，避免 UI 做好后仍然展示原始字段。

### 旧 HUD 逻辑仍可能隐藏右侧区

现有 `runtime_hud_panel1_top.lua` 有隐藏右侧追踪区的旧逻辑痕迹。本次实现需要确认不会在刷新链路里被误隐藏。

## 验收标准

- 局内 HUD 右侧出现主线任务卡，视觉接近参考图
- 面板展示当前主线编号、任务目标、真实进度与奖励
- 奖励文本全部为玩家可读中文，不出现原始 key
- `自动任务` 勾选框可以点击切换，并在运行时生效
- 状态在当前局内会话内保持一致
- 不破坏现有顶部 HUD、挑战条、底部操作条的功能

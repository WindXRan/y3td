# EntryMap 主 HUD 借鉴方案落地设计

## 1. 背景

本次目标不是机械复刻参考图，而是提取它的核心优点并落地到当前 `EntryMap` 的真实工程结构里：

- 顶部中轴聚焦战斗节奏
- 左侧承担教学与系统入口
- 右侧承担任务追踪与当前目标
- 底部采用 MOBA 式角色操作区

当前项目已经存在两类 HUD 资产：

- 编辑器侧静态面板：`maps/EntryMap/ui/GameHUD.json`
- Lua 侧动态 HUD：`maps/EntryMap/script/ui/runtime_hud.lua`

其中，`runtime_hud.lua` 已经接好了波次、Boss、资源、技能点、挑战按钮、宝物继续选择等真实运行时字段。因此，本次最合适的方案不是纯编辑器重建，也不是继续只靠 Lua 动态创建，而是采用混合式改造：

- 用编辑器重建常驻主 HUD 骨架
- 用 Lua 复用现有数据源和交互逻辑
- 把当前动态块逐步挂接到新的编辑器节点

## 2. 目标与范围

### 2.1 本次目标

在不打散现有可玩逻辑的前提下，完成一版可进入编辑器、可直接预览、可继续绑定真实数据的主 HUD 重构。

### 2.2 本次纳入范围

- 顶部战斗栏
- 左侧快捷键与系统按钮区
- 右侧任务追踪区
- 底部角色操作区
- 挑战入口与经验条的重新收纳
- 现有运行时字段接线

### 2.3 本次不纳入范围

- 中央三选一决策弹窗
- 正式背包面板与属性面板
- 胜利 / 失败 / Loading 全流程重做
- 多人玩家统计板的完整视觉升级
- 复杂新美术资源定制

这些内容继续保留现有逻辑或延后到后续专题。

## 3. 推荐方案

### 3.1 方案结论

采用“编辑器骨架 + Lua 运行时绑定”的混合式改造方案。

### 3.2 选择理由

和纯编辑器重建相比：

- 能最大化复用 `runtime_hud.lua` 里的已实现逻辑
- 不需要在本轮重写波次、Boss、资源、挑战、技能按钮状态机
- 出问题时可以按区域回退，不会整块失效

和继续纯 Lua 动态绘制相比：

- 满足“落地到编辑器内”的核心诉求
- 后续节点路径稳定，方便 UI 逻辑、动画、显隐控制继续追加
- 设计、程序、编辑器协作成本更低

## 4. 对参考图的提炼

本次借鉴的是信息架构和视觉权重，不是像素级还原。

### 4.1 保留的优点

- 顶部中心区域只承载当前局最重要的节奏信息
- 左侧快捷提示天然适合做教学和低频操作说明
- 右侧追踪框适合持续显示“当前该做什么”
- 底部主操作区采用“英雄信息在左、技能在中、功能入口在右”的成熟布局

### 4.2 不直接照搬的部分

- 参考图底部信息量极大，首版不整块照抄，避免在当前数据结构下过度堆叠
- 右下角开关簇不在本轮完整复刻，仅保留必要挂点
- 聊天、玩家榜、复杂装备格子等内容不在本轮一次性接入

### 4.3 首版视觉方向

- 深色底板
- 金属边框或半机械感框体
- 金色用于重点资源或关键入口
- 绿色用于增益、恢复、可行动状态
- 红 / 橙用于 Boss 预警和危险状态

首版优先信息清晰和层级稳定，不优先追求花纹、纹理密度和强装饰。

## 5. 目标布局

主 HUD 固定分为四个常驻区域，加一个过渡区：

1. 顶部战斗中轴
2. 左侧快捷提示区
3. 右侧任务追踪区
4. 底部角色操作区
5. 底部左侧挑战入口带

### 5.1 顶部战斗中轴

位置：

- 居中贴顶，使用安全区布局

承载内容：

- 当前计时
- 当前波次 `第 X / 5 波`
- 波次状态说明
- Boss 名称 / 倒计时 / 生命信息
- 当前关卡节点
- 资源条目

视觉原则：

- 以“中轴”而非“通栏”为核心
- 波次与 Boss 是第一阅读层
- 资源是第二阅读层

### 5.2 左侧快捷提示区

位置：

- 左上到左中纵向排布

承载内容：

- `退出游戏`
- `设置`
- 快捷键标题与说明列表

视觉原则：

- 更轻、更窄，避免压过战斗主区
- 文案型组件优先可读性，不做复杂按钮矩阵

### 5.3 右侧任务追踪区

位置：

- 右侧中上部悬挂

承载内容：

- 主线标题
- 当前目标
- 进度 / 阶段说明
- 奖励提示
- 自动任务开关

首版数据策略：

- 当前项目没有完整“任务系统 runtime”
- 首版右侧追踪区使用“主线阶段 + 当前波次目标 + 奖励提示”的轻任务化映射

也就是说，这个面板在第一版更像“战斗目标追踪器”，而不是完整 MMORPG 式任务系统。

### 5.4 底部角色操作区

位置：

- 底部居中

承载内容：

- 英雄头像 / 名称 / 血量
- 4 个攻击技能槽
- `技能 G`
- `羁绊 F`
- 宝物入口
- 次级功能位
- 底部经验条

视觉原则：

- MOBA 式熟悉布局
- 技能槽是视觉中心
- `G / F` 是右侧主入口
- 次级按钮下沉，不和技能区争中心

### 5.5 底部左侧挑战入口带

位置：

- 英雄面板上方或左前侧

承载内容：

- 金币挑战
- 木材挑战
- 经验挑战
- 宝物挑战

处理原则：

- 保留现有四个挑战入口
- 不再散落在底栏内部，改为成组展示
- 与底部角色操作区形成“挑战入口”和“构筑入口”的功能分层

## 6. 编辑器节点结构

本轮需要把 `GameHUD` 重构成稳定的容器树，后续 Lua 只针对命名节点填数据或绑定事件。

建议结构如下：

```text
GameHUD
└─ hud_root
   ├─ top_battle_cluster
   │  ├─ stage_chip
   │  │  └─ stage_text
   │  ├─ timer_block
   │  │  ├─ timer_text
   │  │  └─ wave_status_text
   │  ├─ wave_medallion
   │  │  └─ wave_title
   │  ├─ boss_capsule
   │  │  ├─ boss_name
   │  │  └─ boss_state
   │  └─ resource_cluster
   │     ├─ gold_card
   │     │  └─ gold_value
   │     ├─ wood_card
   │     │  └─ wood_value
   │     ├─ skill_card
   │     │  └─ skill_value
   │     └─ challenge_card
   │        └─ challenge_value
   ├─ left_shortcut_panel
   │  ├─ exit_button
   │  ├─ settings_button
   │  ├─ shortcut_title
   │  └─ shortcut_list
   ├─ right_tracker_panel
   │  ├─ tracker_title
   │  ├─ tracker_objective
   │  ├─ tracker_progress
   │  ├─ tracker_reward
   │  ├─ tracker_hint
   │  └─ auto_task_checkbox
   ├─ challenge_strip
   │  ├─ gold_trial_button
   │  ├─ wood_trial_button
   │  ├─ exp_trial_button
   │  └─ treasure_trial_button
   ├─ bottom_action_bar
   │  ├─ hero_core_panel
   │  │  ├─ hero_portrait
   │  │  ├─ hero_name
   │  │  ├─ hero_hp_bar
   │  │  └─ hero_hp_text
   │  ├─ skill_hotbar
   │  │  ├─ skill_slot_1
   │  │  ├─ skill_slot_2
   │  │  ├─ skill_slot_3
   │  │  └─ skill_slot_4
   │  ├─ primary_action_cluster
   │  │  ├─ skill_button
   │  │  └─ bond_button
   │  ├─ secondary_action_cluster
   │  │  ├─ treasure_button
   │  │  ├─ focus_clear_button
   │  │  └─ swallowed_list_button
   │  └─ exp_rail
   └─ overlay_reserved
```

### 6.1 命名原则

- 节点名直接体现业务语义
- 不使用 `panel_1`、`node_a` 之类的临时命名
- 所有需要 Lua 查找的叶子节点都给稳定名称

### 6.2 容器原则

- 编辑器只负责摆出稳定骨架
- 文本、数值、状态色、显隐切换由 Lua 驱动
- 选择面板等覆盖层仍可继续挂在 `overlay_reserved` 或独立动态层

## 7. 数据映射

本轮不重写状态源，只重做显示层。

### 7.1 顶部战斗栏映射

- `stage_text`
  - 来源：`get_stage_text()`
  - 依赖：`env.get_current_stage_text()` 或 `STATE.current_wave_index`

- `wave_title`
  - 来源：`get_wave_title_text()`
  - 依赖：`STATE.current_wave_index`、`CONFIG.waves`

- `wave_status_text`
  - 来源：`get_wave_status_text()`
  - 依赖：`STATE.active_wave`、`STATE.total_enemy_alive`

- `boss_name` / `boss_state`
  - 来源：`get_boss_display()`
  - 依赖：`STATE.active_wave`、`active_wave.boss_spawned`、`active_wave.boss_info`

- `gold_value`
  - 来源：`STATE.resources.gold`

- `wood_value`
  - 来源：`STATE.resources.wood`

- `skill_value`
  - 来源：`STATE.skill_points`

- `challenge_value`
  - 来源：`STATE.challenge_charges` 与 `CONFIG.challenge_rules.max_charges`

### 7.2 底部角色区映射

- `hero_hp_text`
  - 来源：`get_hero_hp_text()`
  - 依赖：`STATE.hero`

- `skill_button`
  - 来源：现有 `skill_button` 逻辑
  - 依赖：`STATE.skill_points`、`STATE.awaiting_upgrade`、`STATE.game_finished`

- `bond_button`
  - 来源：现有 `bond_button` 逻辑
  - 依赖：`STATE.bond_runtime.awaiting_choice`、`STATE.resources.wood`

- `treasure_button`
  - 首版明确作为“继续处理待选宝物”的恢复入口
  - 仅在存在待选宝物时高亮或可点击
  - 不承担“进入宝物挑战”的职责；宝物挑战仍由 `treasure_trial_button` 负责
  - 依赖：`env.has_pending_treasure_choice()` 与现有待选恢复逻辑

- `skill_slot_1..4`
  - 首版至少显示已装配状态、技能名缩写、是否解锁
  - 数据来自 `STATE.attack_skill_state.slots`
  - 详细样式和点击后打开技能详情面板可作为本轮的预留挂点

- `exp_rail`
  - 直接绑定 `STATE.hero_progress.exp` 与 `STATE.hero_progress.exp_to_next`
  - 同步显示当前等级，可复用 `get_hero_progress_text()` 的文案能力
  - 若极少数初始化阶段 `STATE.hero_progress` 尚未建立，则经验条显示为 `0%` 并在完成初始化后刷新

### 7.3 挑战入口带映射

四个挑战按钮直接复用现有逻辑：

- `gold_trial_button`
- `wood_trial_button`
- `exp_trial_button`
- `treasure_trial_button`

数据与状态仍来自：

- `get_challenge_button_state()`
- `decorate_challenge_status()`
- `STATE.active_challenges`
- `STATE.challenge_charges`
- `env.try_start_challenge()`
- `env.try_treasure_entry()`

### 7.4 右侧任务追踪区映射

首版不引入新任务 runtime，而是做轻映射：

- `tracker_title`
  - 固定显示主线章节，例如 `主线 1-1`

- `tracker_objective`
  - 显示当前波目标，例如“击杀本波敌人 / 等待 Boss 来临 / 击败 Boss”

- `tracker_progress`
  - 显示剩余时间、剩余敌人或波次阶段状态

- `tracker_reward`
  - 显示当前阶段的核心收益说明，例如挑战充能、待领奖励或波次奖励提示

- `tracker_hint`
  - 显示简要行动建议，例如“按 G 消耗技能点”或“按 F 抽取羁绊”

## 8. 交互边界

### 8.1 本轮保留并复用的交互

- `技能 G`
- `羁绊 F`
- 四个挑战按钮
- 宝物继续选择入口

这些交互继续走现有 runtime 函数，不重写业务逻辑。

### 8.2 本轮只提供挂点、不完整展开的交互

- 点击技能槽打开技能详情
- 点击头像打开属性面板
- 点击右侧任务追踪打开完整任务详情
- 点击已吞噬列表打开羁绊历史

这些入口会留稳定节点和按钮命名，但允许首版先不接完整展开层。

### 8.3 本轮不做的交互

- 新增任务系统状态机
- 背包全功能页签
- 正式属性树与装备页

## 9. 实施分层

### 9.1 编辑器层

目标：

- 改造 `ui/GameHUD.json`
- 补齐主 HUD 的容器树和命名节点
- 形成可在编辑器直接预览的骨架布局

### 9.2 Lua 显示层

目标：

- 调整 `script/ui/runtime_hud.lua`
- 从“动态创建大块容器”转为“查找编辑器节点并填充内容”
- 仅对暂时不适合静态化的块保留少量动态创建逻辑

### 9.3 样式层

目标：

- 优先复用 `ui/res.lua`、`ui/skin.lua` 的语义皮肤槽
- 若缺少合适资源，则用现有底板和按钮素材先完成一版
- 不在本轮引入大量新贴图依赖

## 10. 实施顺序

1. 备份并重构 `GameHUD.json` 的主容器命名和布局骨架
2. 运行 UI 节点树脚本，得到新的节点树供 Lua 查询
3. 修改 `runtime_hud.lua`，先接顶部战斗栏
4. 接左侧快捷提示区
5. 接底部角色操作区和挑战入口带
6. 接右侧任务追踪区
7. 清理旧的动态布局残留，保留必要兼容层
8. 进入游戏验证布局、文本、按钮点击和待选恢复逻辑

## 11. 风险与应对

### 11.1 风险：`GameHUD.json` 体量很大

应对：

- 不尝试全文件语义化重排
- 只围绕新主 HUD 相关节点做局部增改
- 每一轮改完都生成节点树检查路径

### 11.2 风险：运行时当前依赖动态创建坐标

应对：

- 先做“编辑器节点存在 + Lua 查找兼容”
- 按区域迁移，不一次性删除全部动态布局代码

### 11.3 风险：右侧任务区没有真实任务 runtime

应对：

- 首版明确定位为“战斗目标追踪器”
- 使用现有波次 / Boss / 挑战状态做映射
- 后续若补完整任务系统，再替换数据源

### 11.4 风险：技能槽详细交互未完全定稿

应对：

- 本轮先把技能槽做成可显示和可点的稳定挂点
- 详细技能详情层后续专题再补

## 12. 验证要求

完成实现后至少验证：

- `GameHUD` 在编辑器内可直接看到四区骨架
- 顶部波次、Boss、资源字段正常刷新
- `技能 G`、`羁绊 F`、四个挑战按钮点击后仍按旧逻辑工作
- 宝物待选状态存在时入口文案和高亮正确
- 右侧追踪区能跟随当前波次状态变化
- 分辨率变化时顶部和底部区域不明显错位

## 13. 定案

本次定案为：

- 范围：核心可玩版 HUD
- 方案：混合式改造
- 落点：编辑器主骨架 + Lua 数据绑定
- 原则：先稳定常驻主 HUD，再逐步吸纳更多面板和信息层

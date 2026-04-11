# UI资源与HUD结构

## 文档职责

汇总当前 `maps/EntryMap/script` 下真实生效的 HUD、三选一面板、资源槽和后续美术接入位，避免继续把设计稿或旧 merge 分支误判成主链路。

## Source Of Truth

- 总协调：`maps/EntryMap/script/entry_runtime.lua`
- HUD 入口：`maps/EntryMap/script/entry_runtime_hud.lua`
- 三选一入口：`maps/EntryMap/script/entry_runtime_choice_panel.lua`
- HUD 包装层：`maps/EntryMap/script/ui/runtime_hud_panel1_top.lua`
- HUD 主实现：`maps/EntryMap/script/ui/runtime_hud_v2.lua`
- 三选一实现：`maps/EntryMap/script/ui/choice_panel.lua`
- 三选一布局：`maps/EntryMap/script/ui/choice_panel_layout.lua`
- 资源索引：`maps/EntryMap/script/ui/res.lua`
- 样式索引：`maps/EntryMap/script/ui/skin.lua`
- 局外 UI：`maps/EntryMap/script/entry_runtime_outgame.lua`

## 当前结构

- 常驻 HUD：
  - 当前由 `ui/runtime_hud_panel1_top.lua` 调度，底层真实实现为 `ui/runtime_hud_v2.lua`
  - `runtime_hud_v2.lua` 依赖 `GameHUD.json` 中的 `hud_root` 骨架节点，并在运行时额外挂载 `bottom_bg` prefab
  - `runtime_hud_panel1_top.lua` 当前主要负责兼容旧入口，并强制隐藏 `GameHUD` 内残留的模板状态栏
- 三选一奖励面板：
  - 由 `ui/choice_panel.lua` 动态挂到 `GameHUD`
  - 只接管 `G 技能强化`、`F 羁绊抽卡`、`宝物候选 / 替换`
  - 采用全屏遮罩 + 中央三张竖卡 + 底部两个按钮
- 局内总览：
  - 由 `ui/runtime_overview.lua` 负责 `B / TAB` 查看型界面
- 局外选关：
  - 由 `ui/outgame.lua` 动态挂载

## 责任边界

- `ui/runtime_hud_v2.lua`：
  - 负责常驻信息和入口按钮
  - 负责挂载 `bottom_bg` prefab，并把英雄信息、属性、按钮状态刷新到 prefab 节点
- `ui/runtime_hud_panel1_top.lua`：
  - 当前不再承担旧 `panel_1` 顶栏映射
  - 主要负责隐藏 `panel_1` 与 `GameHUD` 自带模板栏，避免和新 HUD 叠层
- `ui/choice_panel.lua`：
  - 只读当前 runtime 的待选状态
  - 负责显隐、按钮交互、三张卡内容渲染
- `entry_runtime.lua`：
  - 负责把 `G / F / 宝物` 转成统一 `choice_panel model`
  - 负责隐藏、刷新、恢复和轮次互斥

## 图片绑定规则

### 固定 UI 壳子图

固定面板图都走 `maps/EntryMap/script/ui/res.lua`：

- `skin.images.choice_panel.panel_bg`
- `skin.images.choice_panel.card_bg`
- `skin.images.choice_panel.card_frame_common`
- `skin.images.choice_panel.card_frame_rare`
- `skin.images.choice_panel.card_frame_epic`
- `skin.images.choice_panel.badge_bg_common`
- `skin.images.choice_panel.badge_bg_rare`
- `skin.images.choice_panel.badge_bg_epic`
- `skin.images.choice_panel.icon_frame`
- `skin.images.choice_panel.action_button_bg`
- `skin.images.choice_panel.action_button_shadow`

按钮样式由 `maps/EntryMap/script/ui/skin.lua` 的 `choice_panel_action` 消费这些槽位。

### 业务图标

跟候选本体绑定的图标不写在 UI 文件里，而是走业务对象上的 `ui_icon` 字段：

- 攻击技能：`maps/EntryMap/script/entry_objects/attack_skills/*.lua`
- 羁绊节点：`maps/EntryMap/script/runtime/bond_nodes.lua`
- 宝物：`maps/EntryMap/script/entry_objects/treasures/*.lua`

如果对象上暂时没有 `ui_icon`，当前 runtime 会退回到 `entry_runtime.lua` 里的默认图标，不会卡死流程。

## 未来美术接入位

后续如果美术开始接资源，优先按下面顺序补：

1. 在 `ui/res.lua` 替换三选一壳子图槽位
2. 在业务对象上补 `ui_icon`
3. 如需改按钮皮肤，只改 `ui/skin.lua` 对应样式，不要回写业务逻辑

这样可以保证：

- 换皮不动 runtime 逻辑
- 业务图标和 UI 壳子分层明确
- `G / F / 宝物` 共用一套面板，不会重复接线

## 当前注意事项

- `GameHUD.json` 里仍保留一套模板自带的旧状态栏节点，例如主血蓝条、英雄头像列、背包按钮与旧技能/背包区。
- 当前版本不依赖这些旧节点提供功能，而是在运行时直接隐藏，避免与 `bottom_bg` 新底栏重叠。
- `bottom_bg` prefab 原始内容尺寸和原点都偏向大屏原稿；当前运行时已改为按屏幕中心挂载，并追加缩放适配。

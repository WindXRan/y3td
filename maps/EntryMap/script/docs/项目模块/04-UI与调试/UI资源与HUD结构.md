# UI资源与HUD结构

## 文档职责

汇总当前 `maps/EntryMap/script` 下真实生效的 HUD、三选一面板、资源槽和后续美术接入位，避免继续把设计稿或旧 merge 分支误判成主链路。

## Source Of Truth

- 总协调：`maps/EntryMap/script/entry_runtime.lua`
- HUD 入口：`maps/EntryMap/script/entry_runtime_hud.lua`
- 三选一入口：`maps/EntryMap/script/entry_runtime_choice_panel.lua`
- HUD 实现：`maps/EntryMap/script/ui/runtime_hud.lua`
- 三选一实现：`maps/EntryMap/script/ui/choice_panel.lua`
- 三选一布局：`maps/EntryMap/script/ui/choice_panel_layout.lua`
- 资源索引：`maps/EntryMap/script/ui/res.lua`
- 样式索引：`maps/EntryMap/script/ui/skin.lua`
- 局外 UI：`maps/EntryMap/script/entry_runtime_outgame.lua`

## 当前结构

- 常驻 HUD：
  - 由 `ui/runtime_hud.lua` 动态挂到 `GameHUD`
  - 负责顶部战斗信息、底部入口按钮、挑战入口和资源显示
- 三选一奖励面板：
  - 由 `ui/choice_panel.lua` 动态挂到 `GameHUD`
  - 只接管 `G 技能强化`、`F 羁绊抽卡`、`宝物候选 / 替换`
  - 采用全屏遮罩 + 中央三张竖卡 + 底部两个按钮
- 局内总览：
  - 由 `ui/runtime_overview.lua` 负责 `B / TAB` 查看型界面
- 局外选关：
  - 由 `ui/outgame.lua` 动态挂载

## 责任边界

- `ui/runtime_hud.lua`：
  - 只负责常驻信息和入口按钮
  - 旧 decision 分支已隐藏，不再承担三选一正文展示
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
- 羁绊卡：`maps/EntryMap/script/entry_objects/bond_cards/*.lua`
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

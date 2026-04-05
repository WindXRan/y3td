# UI资源与HUD结构

## 模块职责

说明当前项目有哪些地图 UI 资产、Lua 如何引用它们，以及 UI 与运行时的边界。

## Source Of Truth

- 地图 UI 资产：`maps/EntryMap/ui`
- 运行时 HUD：`maps/EntryMap/script/entry_runtime_hud.lua`
- UI 资源 ID 索引：`maps/EntryMap/script/ui_res.lua`
- HUD 挂载点：`maps/EntryMap/ui/GameHUD.json`

## 关键状态与数据流

- 静态面板：`GameHUD.json`、`LogoPanel.json`、`LoadingPanel.json`、`win.json`、`loss.json`、`CommonTip.json`
- 预制体：`maps/EntryMap/ui/prefab/hero.json`
- 运行时挂载：`y3.ui.get_ui(get_player(), 'GameHUD')`
- 资源 ID 映射：`ui_res.lua`
- 运行时 HUD 状态：`STATE.runtime_hud`
- 运行时 HUD 结构：`center_root`、`left_root`、`right_root`

## 当前已实现行为

- `GameHUD` 已作为运行时 HUD 和 GM 面板的挂载父节点
- `ui_res.lua` 已维护常用 UI 资源和按钮样式 ID
- `entry_runtime_hud.lua` 会在 Lua 侧动态创建顶部和底部 HUD：
  - 顶部显示波次、Boss、战斗计时、金币、木材、技能点、挑战次数
  - 中部状态条显示英雄等级进度、生命、挑战摘要、待领奖励数量
  - 底部按钮提供 `技能 G`、`羁绊 F`、`金币 Q`、`木材 W`、`经验 E`、`宝物 R`
- 按钮状态会根据技能点、木材、挑战次数、解锁条件和待选轮次实时刷新
- 地图级触发器目录中已有一套原生 UI 绑定资产

## 当前实现边界

- 运行时 HUD 已经落地，但正式中央决策面板、背包、奖励记录页还没有落地
- 当前高价值决策仍主要靠文本消息配合 HUD 按钮，不是完整卡面 UI
- `docs/design/初步设计/27-BananaPro-UI整合直发稿.md` 与 17-26 号文档仍是未来 UI 工程化参考，不是当前 UI 现实

## 部分实现与未实现

- 已有运行时 HUD，但设计稿中的中央决策面板和背包页还未真正接线
- 结算面板、强化候选面板、羁绊候选面板、宝物候选面板、烙印选择面板仍未正式做成独立 UI

## Agent 修改建议与风险点

- 改 UI 先区分“资产存在”与“Lua 已接线”这两件事
- 任何新增 UI 文档都要注明挂载位置、状态来源和更新责任
- 想做正式战斗 UI 时，先定义运行时只读接口，再补资产与触发器

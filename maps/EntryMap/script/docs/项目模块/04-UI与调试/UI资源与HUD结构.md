# UI资源与HUD结构

## 模块职责

说明当前项目有哪些地图 UI 资产、Lua 如何引用它们，以及 UI 与运行时的边界。

## Source Of Truth

- 地图 UI 资产：`maps/EntryMap/ui`
- UI 资源 ID 索引：`maps/EntryMap/script/ui_res.lua`
- HUD 挂载点：`maps/EntryMap/ui/GameHUD.json`

## 关键状态与数据流

- 静态面板：`GameHUD.json`、`LogoPanel.json`、`LoadingPanel.json`、`win.json`、`loss.json`、`CommonTip.json`
- 预制体：`maps/EntryMap/ui/prefab/hero.json`
- 运行时挂载：`y3.ui.get_ui(get_player(), 'GameHUD')`
- 资源 ID 映射：`ui_res.lua`

## 当前已实现行为

- `GameHUD` 已作为 GM 面板的挂载父节点
- `ui_res.lua` 已维护常用 UI 资源和按钮样式 ID
- 地图级触发器目录中已有一套原生 UI 绑定资产

## 当前实现边界

- 正式战斗 HUD、底部操作区、中央决策面板还没有在 Lua 侧完整落地
- 现阶段业务展示主要靠文本消息和 GM 面板
- `docs/design/初步设计/27-BananaPro-UI整合直发稿.md` 与 17-26 号文档仍是未来 UI 工程化参考，不是当前 UI 现实

## 部分实现与未实现

- 已有 HUD 资产壳，但未形成策划案中的三大核心区
- 结算面板、强化候选面板、羁绊候选面板仍未正式接上

## Agent 修改建议与风险点

- 改 UI 先区分“资产存在”与“Lua 已接线”这两件事
- 任何新增 UI 文档都要注明挂载位置、状态来源和更新责任
- 想做正式战斗 UI 时，先定义运行时只读接口，再补资产与触发器

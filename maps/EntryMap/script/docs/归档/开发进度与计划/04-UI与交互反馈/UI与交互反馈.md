# UI与交互反馈

## 文档职责

说明当前运行时 HUD、候选交互、调试 UI 和正式界面缺口的完成度。

## Source Of Truth

- `maps/EntryMap/script/entry_runtime_hud.lua`
- `maps/EntryMap/script/ui/runtime_hud_panel1_top.lua`
- `maps/EntryMap/script/ui/runtime_hud_v2.lua`
- `maps/EntryMap/script/entry_runtime_debug_tools.lua`
- `maps/EntryMap/script/entry_runtime_debug_actions.lua`
- `maps/EntryMap/script/entry_runtime_outgame.lua`
- `maps/EntryMap/script/ui_res.lua`
- `maps/EntryMap/ui`

## 已实现

- `GameHUD.json` 已补齐 `hud_root` 常驻骨架，顶部战斗轴、左侧快捷区、右侧追踪区、挑战条、底部操作条都已落到编辑器节点；当前运行链路为 `runtime_hud_panel1_top.lua -> runtime_hud_v2.lua`。
- `bottom_bg` prefab 已接入运行时主链路，接管战斗内底部角色状态栏与已有功能按钮入口。
- `技能抽卡`、`羁绊抽卡`、`金币/木材/杀敌/宝物挑战` 已映射到现有 runtime 行为。
- `backpack` 区域当前仍未接正式查看页，本轮保持隐藏。
- `bottom_bg` 当前按屏幕中心基准挂载，并做了一层运行时缩放适配，避免 prefab 原始尺寸过大、位置过低而只露出顶部边缘。
- `GameHUD` 自带的模板状态栏、英雄头像列、背包按钮与旧属性条仍存在于资源文件中，但当前已通过运行时显隐逻辑强制隐藏。
- 局外选关页也已通过 Lua 动态挂载到 `GameHUD`，能完成章节和模式选择。
- GM 面板、调试热键和调试命令已经接线，可用于快速验证波次、挑战、升级、羁绊和宝物链路。
- `G`、`F`、宝物等待选轮次已经接入统一三选一面板；支持三张卡展示、点击 / 数字键选择、暂时隐藏、恢复和刷新。
- `G`、`F`、宝物三类轮次已经统一到“免费次数 + 木材阶梯刷新”规则：
  - `G` 免费 `3` 次
  - `F` 免费 `0` 次
  - 宝物免费 `3` 次
  - 付费阶梯统一为 `40 / 80 / 100 / 100...`
- 旧 `runtime_hud` 的 decision 卡分支已退回隐藏状态，HUD 只保留常驻信息与入口按钮。
- 烙印等待选轮次已有恢复和互斥逻辑；数字键 `1/2/3` 仍可直接选择当前候选。
- 战斗内可按 `I` 查看“已吞噬羁绊”列表，首版仍以文字提示形式展示。

## 部分实现

- 默认模板 UI 仍在 `GameHUD.json` 资源内保留，现阶段依赖 Lua 运行时强制隐藏；若后续要彻底清理，还需要回收这些旧资源节点。
- 烙印轮次目前仍是旧的文字提示 / 热键选择链路，还没接入新三选一面板。
- `win.json`、`loss.json`、`LoadingPanel.json` 等资产已经存在，但当前主链路没有把它们接成正式结算、Loading 或完整反馈流程。
- 设计稿里要求的候选卡详情、替换预览、构筑摘要、奖励记录等信息目前只做了最小可用提示，没有完整 UI 信息架构。
- 设计稿中的部分查看型界面入口，例如 `B` 背包、`TAB` 属性页，当前还没有真正接线。

## 未实现

- 烙印独立选择面板。
- 背包面板、成长武器页签、宝物页签、奖励记录页。
- 正式胜利 / 失败结算页、正式 Loading 与更完整的战斗反馈界面。

## 设计映射

- [UI 与信息表现](../../design/初步设计/07-UI与信息表现.md)
- [UI美术需求文档](../../design/初步设计/14-UI美术需求文档.md)
- [中央决策面板资源清单示例](../../design/初步设计/24-中央决策面板资源清单示例.md)
- [中央决策面板结构标注示例](../../design/初步设计/25-中央决策面板结构标注示例.md)
- [中央决策面板单文件YAML示例](../../design/初步设计/26-中央决策面板单文件YAML示例.md)

## 后续开发建议

1. 正式 UI 接线前，先把 runtime 只读接口固定下来，避免 UI 资产反过来驱动状态。
2. 把现有 pending round 恢复逻辑直接复用到中央决策面板，不要重写一套新的轮次状态机。
3. 背包、奖励记录和正式结算页应优先读取现有 runtime，而不是再做一层独立缓存。

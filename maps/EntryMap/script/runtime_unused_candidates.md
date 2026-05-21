# 运行时 Lua 源冗余候选

## 分析范围
- 目录：`maps/EntryMap/script/runtime`
- 方法：对每个 Lua 文件计算其模块名称（如 `runtime.ui.ui_phase_manager`），然后在仓库内搜索 `require` / `pcall(require, ...)` / 文件路径引用。
- 结论基于静态搜索，可能无法覆盖“动态字符串拼接加载模块”或外部工具直接读取脚本文件的情况。

## 发现结果
以下 10 个 runtime 目录下的 Lua 文件在仓库中未发现直接引用：

- `runtime/combat/battle_events.lua`
- `runtime/combat/battle_logic.lua`
- `runtime/debug/editor_object_api.lua`
- `runtime/heroes/hero_attr_defs.lua`
- `runtime/outgame/message_system.lua`
- `runtime/progression/achievements.lua`
- `runtime/progression/reward_manager.lua`
- `runtime/rounds/challenge_manager.lua`
- `runtime/ui/status_display_manager.lua`
- `runtime/ui/ui_phase_manager.lua`

## 说明
- `runtime/debug/editor_object_api.lua` 仅在文档/说明文件中出现（如 `AREA_SETUP_GUIDE.md`），没有运行时引用证据。
- `runtime/heroes/hero_attr_defs.lua` 仅在 smoke 测试脚本中出现，有可能是测试专用数据，而不是游戏运行时模块。
- 其余文件也未在静态搜索中找到 `require` 或路径引用。

## 建议
- 这些文件是优先检查的冗余候选。建议先将它们移动到临时存档目录或重命名后运行游戏/测试，以观察是否有缺失错误。
- 如果确认无影响，可最终删除。
- 同时，`maps/EntryMap/script/tools/` 下还有一批测试/调试脚本（例如 `tools/test_*_smoke.lua`、`tools/debug_template.lua`、`tools/diag_hud.lua` 等），它们属于工具/验证代码，不应计入运行时加载路径。

# GM面板与开发命令

## 模块职责

说明当前开发调试能力由哪些代码提供，以及这些能力服务哪些运行时模块。

## Source Of Truth

- 调试工具与 GM UI：`maps/EntryMap/script/entry_runtime_debug_tools.lua`
- 调试动作：`maps/EntryMap/script/entry_runtime_debug_actions.lua`
- 调试接线：`maps/EntryMap/script/entry_runtime.lua`
- 开发命令依赖：`maps/EntryMap/script/y3/develop`、`maps/EntryMap/script/y3-helper`

## 关键状态与数据流

- 命令注册：`register_dev_commands()`
- GM UI 挂载：`ensure_gm_panel()`、`create_gm_panel()`
- GM UI 刷新/折叠：`refresh_gm_panel()`、`toggle_gm_panel()`
- GM 状态：`STATE.gm_ui`
- 调试快捷键：`register_runtime_events()` 内注册 `Ctrl+F1` 到 `Ctrl+F10`

## 当前已实现行为

- 调试模式下右上角会挂 GM 面板，父节点来自 `GameHUD`
- 当前 GM 面板支持：
  - 帮助
  - 加资源
  - 升 3 级
  - 解锁全部攻击技能
  - 触发 F 抽卡
  - 补满挑战次数
  - 强制刷 Boss
  - 清场
  - 打印当前状态
- 已有开发命令用于坐标校准与区域 dump：
  - `.epos`
  - `.eset`
  - `.earea`
  - `.eblink`
  - `.edump`
  - `.ehotkey`
- 调试动作已经拆到 `entry_runtime_debug_actions.lua`，不再全部堆在总 runtime 文件里

## 当前实现边界

- GM 面板是开发 UI，不是正式玩家 UI
- 许多功能直接操作 `STATE`，目的是快速验证主循环
- 调试能力仍与运行时强耦合，但已经拆成独立 debug module

## 未实现或占位项

- 没有正式可视化挑战追踪面板
- 没有正式的 `G/F/宝物/烙印` 中央决策面板
- 没有局外调试入口和存档调试工具

## Agent 修改建议与风险点

- 改调试工具时，优先保证“不污染正式玩法状态机”
- 如果新增局内系统，最好同时补一个 GM 快捷验证入口
- 不要把 GM 面板当正式 UI 模块继续扩展业务展示

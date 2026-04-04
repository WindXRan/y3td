# UI资源与HUD结构

## 1. UI 资产放在哪里

当前与 UI 直接相关的主要内容分布在两处：

- `maps/EntryMap/ui`
- `maps/EntryMap/script/ui_res.lua`

此外，`custom/UIScript` 与 `custom/CustomImportRepo.local/resource.repository` 提供了底层 UI 贴图与资源仓库支持。

## 2. `maps/EntryMap/ui` 中有哪些面板

当前地图 UI 目录中能看到的主要面板包括：

- `GameHUD.json`
- `LoadingPanel.json`
- `LogoPanel.json`
- `CommonTip.json`
- `SceneUI.json`
- `win.json`
- `loss.json`
- `panel_1.json`
- `ui_config.json`

这些文件是编辑器导出的 UI 定义，属于“静态 UI 资产层”。

## 3. `ui_res.lua` 的作用

`ui_res.lua` 是一个资源 ID 映射表，按模块组织了 UI 资源编号，例如：

- 通用空白图
- 胜利/失败界面资源
- 加载界面资源
- 通用按钮皮肤
- HUD 相关资源
- 英雄面板预制资源

它更像“代码访问 UI 资源时的资源索引表”，而不是复杂的 UI 行为脚本。

## 4. `GameHUD` 的特殊地位

当前 `entry_runtime.lua` 会尝试：

- `y3.ui.get_ui(get_player(), 'GameHUD')`

随后在 `GameHUD` 下动态创建：

- GM 面板开关按钮
- GM 主面板
- 文本
- 按钮

这说明 `GameHUD` 是当前运行时动态 UI 的挂载根节点之一。

## 5. 当前 UI 分层理解

可以把 UI 结构拆成三层：

### 静态面板层

由 `maps/EntryMap/ui/*.json` 提供，属于编辑器里搭好的 UI 预制。

### 资源索引层

由 `ui_res.lua` 与资源仓库文件提供，负责告诉代码“该用哪张图、哪个资源 ID”。

### 动态创建层

由 `entry_runtime.lua` 在运行时调用 UI API 动态生成，当前最明确的是 GM 面板。

## 6. 当前 Lua 对 UI 的依赖特点

当前核心战斗逻辑并没有大量手写复杂 UI 控制，更多表现为：

- 用 `display_message()` 输出文本提示
- 通过 `GameHUD` 动态挂调试面板
- 借助地图内 `global_trigger` 资产承载一套更完整的 UI 触发器流程

因此，这个项目的 UI 逻辑呈现出“Lua 与可视化触发器并存”的特点。

## 7. 当前需要特别注意的边界

不要把以下内容混为一谈：

- `maps/EntryMap/ui`：静态 UI 资产
- `ui_res.lua`：资源 ID 表
- `entry_runtime.lua`：当前动态 UI 创建代码
- `maps/EntryMap/global_trigger`：地图内 UI 触发器资产

它们都和 UI 有关，但层级不同，职责也不同。

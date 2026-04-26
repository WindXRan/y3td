# Lua Trace 问题归档

> 记录运行期 Trace / stack traceback 类问题，便于后续复用修复经验。

## 记录规范

- 问题现象：简述报错内容或触发场景
- 根因：说明为什么会出现该 Trace
- 解决方案：记录最终有效的修复方式
- 预防建议：总结后续如何避免重复出现

---

## 模板

### 问题标题

- 时间：
- 场景：
- Trace：
- 根因：
- 解决方案：
- 预防建议：

---

### 获取鼠标 UI 坐标前未开启鼠标位置同步

- 时间：2026-04-25
- 场景：战斗 UI 初始化后刷新 hover tip 位置，调用 `player:get_mouse_ui_x_percent()` / `player:get_mouse_ui_y_percent()`
- Trace：`script/y3/object/runtime_object/player.lua:615: 必须先设置 y3.config.sync.mouse = true`
- 根因：框架的鼠标位置接口依赖 `y3.config.sync.mouse`，启动入口未在 runtime/UI 初始化前启用鼠标位置同步
- 解决方案：在 `maps/EntryMap/script/main.lua` 顶部设置 `y3.config.sync.mouse = true`
- 预防建议：新增任何鼠标位置相关 UI 逻辑前，先确认启动阶段已启用 `Config.Sync.mouse`

---

*最后更新: 2026-04-07*

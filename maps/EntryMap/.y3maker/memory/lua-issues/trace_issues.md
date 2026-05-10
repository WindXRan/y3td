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

## 实际案例

### utf8.codes 处理非 UTF-8 文本导致 tooltip 崩溃

- 时间：2026-05-10
- 场景：悬停成长武器/羁绊/技能 tips，详情框根据描述长度自适应高度
- Trace：`runtime_hud.lua:899: invalid UTF-8 code`
- 根因：Y3 运行时传入的部分中文文本可能不是合法 UTF-8 字节序列，`utf8.codes(text)` 遍历时会直接抛错，导致 hover 事件中断。
- 解决方案：自适应尺寸估算不要使用 `utf8.codes`；改为按字节保守估算文本宽度，保证 GBK/混合编码/非法字节都不会触发异常。
- 预防建议：运行时 UI 文案如果来源不完全可控，不要在热路径使用会校验 UTF-8 合法性的迭代器；需要宽度估算时优先使用无异常的保守算法。

### 控件路径不匹配导致 register_events 报"控件不存在"

- 时间：2026-05-09
- 场景：`growth_weapon_item_tip.lua` 为装备栏绑定 hover 事件，显示成长武器 tip
- Trace：`控件不存在！item.equip_slot_bg_1`（同理 bg_2 ~ bg_6）
- 根因：代码使用路径 `item.equip_slot_bg_%d`，但 GameHUD_Tree.json 中 `equip_slot_bg_*` 位于 `inventory` 节点下，而非 `item` 节点下。`item` 节点只有 `img` 和 `des` 子控件（是工具提示区域），`inventory` 才是装备栏容器。两者都是 `main` 的直接子节点。
- 解决方案：路径改为 `main.inventory.equip_slot_bg_%d`，对照 `ui_tree/GameHUD_Tree.json` 确认实际层级
- 预防建议：写 UI 控件路径前，先到 `ui_tree/*.json` 中确认目标控件的父节点链，不要凭命名猜测

---

*最后更新: 2026-05-09*

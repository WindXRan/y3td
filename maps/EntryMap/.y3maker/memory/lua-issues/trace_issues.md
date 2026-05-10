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

### 控件路径不匹配导致 register_events 报"控件不存在"

- 时间：2026-05-09
- 场景：`growth_weapon_item_tip.lua` 为装备栏绑定 hover 事件，显示成长武器 tip
- Trace：`控件不存在！item.equip_slot_bg_1`（同理 bg_2 ~ bg_6）
- 根因：代码使用路径 `item.equip_slot_bg_%d`，但 GameHUD_Tree.json 中 `equip_slot_bg_*` 位于 `inventory` 节点下，而非 `item` 节点下。`item` 节点只有 `img` 和 `des` 子控件（是工具提示区域），`inventory` 才是装备栏容器。两者都是 `main` 的直接子节点。
- 解决方案：路径改为 `main.inventory.equip_slot_bg_%d`，对照 `ui_tree/GameHUD_Tree.json` 确认实际层级
- 预防建议：写 UI 控件路径前，先到 `ui_tree/*.json` 中确认目标控件的父节点链，不要凭命名猜测

---

*最后更新: 2026-05-09*

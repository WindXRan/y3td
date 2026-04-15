# UI 技能自动路由规范

## 1. 目标

本规范用于统一 `y3-ui-pipeline`、`y3-ui-generator`、`y3-ui-official` 三个技能的触发边界，避免同类 UI 需求被路由到不同入口，或在生成 UI 资源与编写 UI Lua 逻辑之间误切换。

## 2. 核心结论

- 所有 `UI/界面/面板/HUD` 相关用户需求，默认先进入 `y3-ui-pipeline`
- `y3-ui-pipeline` 是 UI 统一入口，负责判断后续应调用哪个子技能
- 只有当用户已经明确表达这是一个 `子任务` 时，才允许直接进入 `y3-ui-generator` 或 `y3-ui-official`

## 3. 路由规则

### 3.1 默认规则

以下表述默认触发 `y3-ui-pipeline`：

- 做个 UI
- 生成一个界面
- 做个 HUD
- 做个背包/商店/弹窗/提示框
- 做一个商城商品详情页
- 做一套装备 tips 面板

这类请求的共同点是：用户在描述一个 `完整 UI 需求`，而不是明确限定某一个子阶段。

### 3.2 子技能路由规则

进入 `y3-ui-pipeline` 后，按需求内容继续分流：

| 需求类型 | 子技能 | 产物 |
|------|------|------|
| 新建或重做 UI 资源 | `y3-ui-generator` | `maps/EntryMap/ui/*.json` |
| 为现有 UI 编写交互代码 | `y3-ui-official` | UI Lua 逻辑 |
| 同时包含资源与交互 | `y3-ui-generator` → `y3-ui-official` | UI JSON + UI Lua |

### 3.3 允许直达子技能的场景

仅当用户明确把任务限定为某个子阶段时，允许跳过 `y3-ui-pipeline`：

#### 直达 `y3-ui-generator`

适用表述：

- 用 `y3-ui-generator` 生成一个面板
- 只帮我出 UI JSON
- 创建画板，不用接 Lua
- 从这张图生成 Y3 UI

判定条件：

- 目标明确是 `UI 资源生成`
- 不要求绑定事件、显示隐藏、刷新文本、切状态

#### 直达 `y3-ui-official`

适用表述：

- 给这个面板接点击事件
- 用官方 UI API 写显示隐藏逻辑
- 更新这个 tips 面板的文本和图标
- 给现有 UI 接悬停/移出/按钮事件

判定条件：

- UI 资源已经存在，或用户明确说“只写 UI Lua 逻辑”
- 目标是 `操作 UI`，不是 `新建 UI JSON`

## 4. 冲突处理

当一句话同时命中多个方向时，按以下优先级处理：

1. 如果任务描述的是 `完整界面需求`，优先走 `y3-ui-pipeline`
2. 如果任务显式写出 `只生成 JSON`、`只做画板`，走 `y3-ui-generator`
3. 如果任务显式写出 `只写 UI Lua`、`只接事件`，走 `y3-ui-official`
4. 如果既要新建 UI，又要交互逻辑，仍然走 `y3-ui-pipeline`

## 5. 禁止事项

- 不要把完整 UI 需求直接路由到 `y3-ui-official`
- 不要在需要新建 UI 资源时手写大型 UI JSON
- 不要在用户未限定为子任务时绕过 `y3-ui-pipeline`
- 不要把 `y3-ui-official` 当成 UI 资源生成器使用

## 6. 推荐口径

对外统一口径如下：

- `y3-ui-pipeline`：UI 统一入口
- `y3-ui-generator`：生成 UI JSON / 画板资源
- `y3-ui-official`：编写 UI Lua 交互逻辑

## 7. 典型示例

| 用户请求 | 正确路由 |
|------|------|
| 做个商城商品详情页 UI | `y3-ui-pipeline` |
| 用 `y3-ui-generator` 帮我生成商城详情页 | `y3-ui-generator` |
| 给商城详情页的购买按钮接点击事件 | `y3-ui-official` |
| 做个宝物 tips 面板并接悬停显示 | `y3-ui-pipeline` |
| 只生成一份 tips 面板 JSON | `y3-ui-generator` |
| 现有 tips 面板补显示隐藏逻辑 | `y3-ui-official` |

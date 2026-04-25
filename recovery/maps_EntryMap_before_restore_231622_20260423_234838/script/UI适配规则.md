# Y3 编辑器 UI 适配规则

## 坐标系统

- 原点位置位于画布左下角
- 坐标单位支持像素和百分比

## 锚点和对齐方式

- 默认锚点为控件中心 (0.5, 0.5)

## 不同分辨率下的适配策略

适配在 cocos 屏幕适配 `cc.RESOLUTIONPOLICY_EXACT_FIT`（以下用 REF 指代）方案的基础上进行。

**变量定义：**
- 设计分辨率：`(dw, dh)`
- 实际屏幕分辨率（窗口大小）：`(rw, rh)`
- 横向缩放系数：`sx`
- 纵向缩放系数：`sy`

**适配规则：**
- UI 编辑器内的画布尺寸，高度固定为 1080，即 `dh = 1080`
- REF 方案下：`sx = rw/dw`，`sy = rh/dh`
- 控件不能变形，必须 `sx = sy`
- 当分辨率改变时，默认缩放控件尺寸与坐标：`sy = rh/1080`
- 推导：`dw = 1080/rh * rw`

**设计分辨率公式：**
```
(dw, dh) = (1080/rh * rw, 1080)
```

游戏内画布大小（ECA 输出值）为 `(1080/rh * rw, 1080)`，所有子控件的尺寸坐标都基于此。

**坐标计算流程：**
1. 设计像素坐标 + 设计分辨率 → 坐标百分比
2. 坐标百分比 + 游戏窗口分辨率 → 实际绝对坐标

例如子控件坐标百分比为 `(xp, yp)`，绝对坐标为 `(1080/rh * rw * xp, 1080 * yp)`

## 父子 UI 的坐标关系

子控件的坐标是相对于父控件的**左下角**，而非父控件的锚点位置。控件自身的锚点默认在中心 (0.5, 0.5)。

**重要：** `set_pos(x, y)` 设置的是子控件锚点相对于父控件左下角的位置。

```lua
-- 示例：在父控件内放置一个 100x50 的子控件，使其左下角与父控件左下角对齐
local child = parent:create_child('图片')
child:set_ui_size(100, 50)
-- 锚点在中心，所以 x = 宽度/2, y = 高度/2
child:set_pos(50, 25)

-- 示例：让子控件水平居中于宽度为 200 的父控件底部
local child = parent:create_child('图片')
child:set_ui_size(100, 50)
-- x = 父控件宽度/2 = 100（水平居中）
-- y = 子控件高度/2 = 25（底部对齐）
child:set_pos(100, 25)
```

## 核心原则

**总是优先使用百分比坐标。** 百分比坐标能够自动适配不同分辨率，避免因画布宽度动态变化导致的布局问题。

**当需要使用空节点时，优先考虑使用图片控件并设置为空图片（id:999）。** 这样可以方便后续调试查看控件节点的尺寸。

```lua
-- 推荐：使用图片控件 + 空图片作为容器
local container = root:create_child('图片')
container:set_image(999)

-- 不推荐：使用空节点（调试时无法直观看到尺寸）
local container = root:create_child('空节点')
```

## Lua API

### 坐标设置

| 方法 | 参照系 | 说明 |
|------|--------|------|
| `ui:set_pos(x, y)` | 相对父控件 | 设置设计像素坐标（不推荐用于需要居中的场景） |
| `ui:set_absolute_pos(x, y)` | 相对游戏窗口 | 设置绝对坐标 |
| `GameAPI.set_ui_comp_pos_percent(player.handle, ui.handle, x, y)` | 相对父控件 | 设置百分比坐标（0-100），推荐用于居中布局 |
| `ui:set_relative_parent_pos(direction, offset)` | 相对父控件边缘 | 设置当前控件边缘距离父控件对应边缘的距离 |

### 相对父控件边缘定位

`set_relative_parent_pos` 用于让控件边缘贴合父控件边缘：

```lua
---@param direction y3.Const.UIRelativeParentPosType  -- '顶部' | '底部' | '左侧' | '右侧'
---@param offset number  -- 当前控件边缘距离父控件对应边缘的像素值
ui:set_relative_parent_pos(direction, offset)
```

**边缘对应关系：**

| direction | 含义 |
|-----------|------|
| `'顶部'` | 当前控件**顶边**距离父控件**顶边**的距离 |
| `'底部'` | 当前控件**底边**距离父控件**底边**的距离 |
| `'左侧'` | 当前控件**左边**距离父控件**左边**的距离 |
| `'右侧'` | 当前控件**右边**距离父控件**右边**的距离 |

**全屏铺满示例：**
```lua
local panel = root:create_child('空节点')
panel:set_relative_parent_pos('顶部', 0)
panel:set_relative_parent_pos('底部', 0)
panel:set_relative_parent_pos('左侧', 0)
panel:set_relative_parent_pos('右侧', 0)
```

### 百分比坐标定位

`GameAPI.set_ui_comp_pos_percent` 用于设置控件相对于父控件的百分比位置：

```lua
-- x, y 范围为 0-100，50 表示居中
GameAPI.set_ui_comp_pos_percent(player.handle, ui.handle, x, y)
```

**居中示例：**
```lua
local btn = root:create_child('按钮')
GameAPI.set_ui_comp_pos_percent(player.handle, btn.handle, 50, 50)  -- 水平垂直居中
```

### 画布尺寸获取

```lua
local width = y3.ui.get_screen_width()   -- 当前画布宽度（动态，不推荐用于 set_pos）
local height = y3.ui.get_screen_height() -- 当前画布高度（固定 1080）
```

**注意：** `set_pos` 设置的是设计分辨率下的坐标，不应该根据 `get_screen_width()` 来计算位置。需要居中时应使用百分比坐标。

### 文本对齐方式

```lua
---@param h y3.Const.UIHAlignmentType  -- '左' | '中' | '右'
---@param v y3.Const.UIVAlignmentType  -- '上' | '中' | '下'
ui:set_text_alignment(h, v)
```

**示例：**
```lua
local title = root:create_child('文本')
title:set_ui_size(400, 60)  -- 设置文本控件尺寸
title:set_text_alignment('中', '中')  -- 文本在控件内居中
```

### 可用控件类型

```lua
-- y3.Const.UIComponentType
'空节点'    -- Layout (7)，容器/面板
'图片'      -- Image (4)，背景、图标
'文本'      -- TextLabel (3)，文字显示
'按钮'      -- Button (1)，可点击按钮
'进度条'    -- Progress (5)，进度条
'输入框'    -- InputField (15)，文本输入
'列表'      -- ScrollView (10)，滚动列表
'模型'      -- Model (6)，3D 模型显示
'滑动条'    -- Slider (11)，滑动选择
'技能按钮'  -- SkillBtn (17)，技能按钮
```

## 常见问题与解决方案

### 问题 1：控件无法水平居中

**错误做法：**
```lua
local screen_width = y3.ui.get_screen_width()
ui:set_pos(screen_width / 2, 540)  -- 错误！set_pos 不应该用 screen_width 计算
```

**正确做法：** 使用百分比坐标
```lua
GameAPI.set_ui_comp_pos_percent(player.handle, ui.handle, 50, 50)
```

### 问题 2：全屏背景图片不铺满

**解决方案：** 使用 `set_relative_parent_pos` 四边设为 0
```lua
local bg = root:create_child('图片')
bg:set_relative_parent_pos('顶部', 0)
bg:set_relative_parent_pos('底部', 0)
bg:set_relative_parent_pos('左侧', 0)
bg:set_relative_parent_pos('右侧', 0)
bg:set_image(图片资源ID)
```

### 问题 3：文本控件内容显示不全

**原因：** 文本控件默认宽度可能不够

**解决方案：** 设置足够的控件尺寸，并设置文本对齐方式
```lua
local title = root:create_child('文本')
title:set_text('碰碰车大作战')
title:set_font_size(48)
title:set_ui_size(400, 60)  -- 设置足够宽度
title:set_text_alignment('中', '中')  -- 文本居中对齐
```

### 问题 4：图片控件显示默认图片

**原因：** 创建图片控件后只设置了颜色，没有设置图片资源

**错误做法：**
```lua
local overlay = root:create_child('图片')
overlay:set_image_color(0, 0, 0, 150)  -- 没有图片资源，会显示默认图片
```

**正确做法：** `set_image_color` 是叠加在图片资源上的，应直接在有图片的控件上设置
```lua
local bg = root:create_child('图片')
bg:set_image(图片资源ID)
bg:set_image_color(180, 180, 180, 255)  -- 叠加颜色让图片变暗
```

### 问题 5：按钮文字看不清

**原因：** 按钮背景色和文字颜色对比度不够

**解决方案：** 分别设置按钮背景色和文字颜色
```lua
local btn = root:create_child('按钮')
btn:set_image_color(50, 150, 50, 255)  -- 深绿色背景
btn:set_text_color(255, 255, 255, 255)  -- 白色文字
```

## 推荐布局模式

### 全屏居中布局（推荐）

适用于菜单、弹窗等需要居中的界面：

```lua
-- 1. 创建全屏容器
local root_panel = canvas:create_child('空节点')
root_panel:set_relative_parent_pos('顶部', 0)
root_panel:set_relative_parent_pos('底部', 0)
root_panel:set_relative_parent_pos('左侧', 0)
root_panel:set_relative_parent_pos('右侧', 0)

-- 2. 全屏背景
local bg = root_panel:create_child('图片')
bg:set_relative_parent_pos('顶部', 0)
bg:set_relative_parent_pos('底部', 0)
bg:set_relative_parent_pos('左侧', 0)
bg:set_relative_parent_pos('右侧', 0)
bg:set_image(背景图片ID)

-- 3. 居中元素使用百分比坐标
local title = root_panel:create_child('文本')
GameAPI.set_ui_comp_pos_percent(player.handle, title.handle, 50, 70)  -- 水平居中，垂直 70%

local btn = root_panel:create_child('按钮')
GameAPI.set_ui_comp_pos_percent(player.handle, btn.handle, 50, 50)  -- 居中
```

### 边缘固定布局

适用于 HUD 等需要固定在屏幕边缘的元素：

```lua
-- 左上角元素
local top_left = root:create_child('文本')
top_left:set_relative_parent_pos('顶部', 30)
top_left:set_relative_parent_pos('左侧', 30)

-- 右上角元素
local top_right = root:create_child('文本')
top_right:set_relative_parent_pos('顶部', 30)
top_right:set_relative_parent_pos('右侧', 30)

-- 左下角元素
local bottom_left = root:create_child('空节点')
bottom_left:set_relative_parent_pos('底部', 30)
bottom_left:set_relative_parent_pos('左侧', 30)

-- 右下角元素
local bottom_right = root:create_child('空节点')
bottom_right:set_relative_parent_pos('底部', 30)
bottom_right:set_relative_parent_pos('右侧', 30)
```

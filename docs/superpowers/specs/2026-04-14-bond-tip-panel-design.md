# 羁绊 Tips 面板设计

## 目标

新增一个独立的羁绊详情提示面板 `CardSetEffectTipPanel`，用于展示单个羁绊卡或羁绊节点的关键信息。该面板不复用 `CommonTip`，也不沿用 `ShopItemDetailPanel` 的商品详情结构，而是针对羁绊信息做专门布局。

核心目标：

- 展示品质、羁绊名、激活进度、图标、节点名
- 展示最多 3 行基础加成
- 展示羁绊效果标题与正文
- 根据基础加成实际行数自动调整下半区排版
- 保持后续 Lua 动态填充时的节点职责清晰

## 适用范围

该面板用于羁绊系统：

- 羁绊抽卡候选详情
- 羁绊图鉴或羁绊节点悬浮提示
- 羁绊已拥有节点详情展示

不用于：

- 商城商品详情
- 宝物详情
- 通用确认弹窗

## 方案选择

### 方案 A：独立羁绊提示面板

新增 `CardSetEffectTipPanel.json`，按羁绊信息结构独立建模，所有文本节点按语义拆分。

优点：

- 结构与用途一致，便于后续动态填充
- 基础加成区可做 1 至 3 行自适应
- 不污染旧 Tips 结构

缺点：

- 新增节点较多

### 方案 B：改造 `CommonTip`

继续沿用旧通用 Tips，把羁绊信息硬塞入原结构。

优点：

- 复用现有资源

缺点：

- 结构不匹配
- 后续维护成本高
- 很难自然支持基础加成区伸缩

### 结论

采用方案 A。

## 面板结构

面板名：`CardSetEffectTipPanel`

设计分辨率：`1920×1080`

推荐尺寸：`300×445`

UI 树：

```text
└── layout: panel_card_set_tip (300×445)
    ├── image: image_panel_bg (300×445)
    ├── image: image_top_divider (286×2)
    ├── label: label_quality_badge (54×30)
    ├── label: label_set_name (150×34)
    ├── label: label_set_progress (70×30)
    ├── image: image_item_frame (74×74)
    ├── image: image_item_icon (64×64)
    ├── label: label_item_name (120×30)
    ├── layout: layout_bonus_area (180×84)
    │   ├── label: label_bonus_1 (180×24)
    │   ├── label: label_bonus_2 (180×24)
    │   └── label: label_bonus_3 (180×24)
    ├── layout: layout_effect_area (250×150)
    │   ├── label: label_effect_title (220×28)
    │   ├── label: label_effect_rule (235×52)
    │   ├── label: label_effect_index (70×24)
    │   ├── label: label_effect_name (170×24)
    │   ├── label: label_effect_body (235×56)
    │   ├── label: label_set_title (220×28)
    │   └── label: label_set_body (235×56)
    └── image: image_bottom_shade (280×120)
```

## 视觉规则

- 整体为深色竖向提示板
- 顶部保留细分隔线
- 品质徽记位于顶端，使用单独节点展示 `N`、`R` 等
- 羁绊名与进度分开，便于分别着色
- 图标区居中偏上，图标框与图标分离
- 节点名位于图标下方，使用品质色或主题色
- 基础加成区使用亮绿色文本
- 效果标题使用橙黄或金黄强调色
- 技能名或关键词允许使用独立节点实现强调色，不依赖富文本

## 自适应排版规则

基础加成区最多显示 3 行，使用 `label_bonus_1` 到 `label_bonus_3` 三个独立节点承载。

### 行数规则

- 1 行时，仅显示 `label_bonus_1`
- 2 行时，显示 `label_bonus_1` 和 `label_bonus_2`
- 3 行时，显示全部三行
- 超过 3 行时，面板只展示前 3 行

### 下半区联动规则

`layout_effect_area` 的垂直位置不写死，而是根据基础加成实际显示行数切换：

- 1 行：效果区上移，腾出更多正文空间
- 2 行：效果区居中
- 3 行：效果区下移，避免与基础加成重叠

推荐通过三个离散档位处理，而不是运行时逐像素计算，避免 Y3 UI 调整复杂化：

- `bonus_line_count = 1` -> `effect_area_offset_y = small`
- `bonus_line_count = 2` -> `effect_area_offset_y = medium`
- `bonus_line_count = 3` -> `effect_area_offset_y = large`

实现层面上，UI 资源先按 3 行最大容量设计；运行时只需隐藏未使用 bonus 节点，并根据行数切换 `layout_effect_area` 的 Y 坐标。

## 数据绑定约定

建议后续 Lua 绑定字段如下：

- `quality_text` -> `label_quality_badge`
- `set_name_text` -> `label_set_name`
- `set_progress_text` -> `label_set_progress`
- `icon_res` -> `image_item_icon`
- `item_name_text` -> `label_item_name`
- `bonus_lines[1..3]` -> `label_bonus_1..3`
- `effect_title_text` -> `label_effect_title`
- `effect_rule_text` -> `label_effect_rule`
- `effect_index_text` -> `label_effect_index`
- `effect_name_text` -> `label_effect_name`
- `effect_body_text` -> `label_effect_body`
- `set_title_text` -> `label_set_title`
- `set_body_text` -> `label_set_body`

## 运行时行为建议

- 面板作为单独 tips 资源存在
- 由悬浮、选中或预览事件驱动显示
- 文本为空时，对应节点可隐藏
- 如果仅使用“基础加成 + 套装效果”两段，可隐藏未使用的效果标题节点
- 图标缺失时保留图标框，图标节点可回退到默认资源

## 错误处理

- 基础加成为空：隐藏 `layout_bonus_area` 内所有加成节点，并将效果区视为 0 或 1 行布局中的最上档位
- 效果正文为空：保留标题，正文使用空串并允许隐藏
- 品质缺失：回退为默认品质色与默认文本
- 进度缺失：回退显示 `(0/0)` 或隐藏进度节点，具体由后续 Lua 层决定

## 测试关注点

- 1 行基础加成时，效果区是否自然上移
- 2 行基础加成时，间距是否均衡
- 3 行基础加成时，底部正文是否仍在面板范围内
- 长羁绊名称是否会压缩或越界
- 长效果正文是否需要截断或缩小字号
- 空文本隐藏后是否出现断层

## 后续实现范围

本设计阶段只覆盖 UI 资源结构与数据绑定约定。

后续实现阶段将包含：

- 生成 HTML 预览
- 转换为 `maps/EntryMap/ui/CardSetEffectTipPanel.json`
- 热更并保存 Y3 UI
- 生成 `ui_tree/CardSetEffectTipPanel_Tree.json`
- 如有需要，再补对应 Lua 绑定与排版逻辑

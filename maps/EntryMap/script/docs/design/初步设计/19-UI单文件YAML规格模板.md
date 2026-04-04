# UI单文件YAML规格模板（AI快速版）

> 这是给 `AI / 程序 / 美术` 共用的单文件规格。适合高自动化流程：一份 YAML 同时描述目标、布局、资源、文本和程序接法。

## 1. 适用场景
- 你想让 AI 直接根据规格出：
  `低保真结构图`
  `资源拆分建议`
  `界面出图 prompt`
  `程序骨架`
- 你不想维护多份表格和多份标注图。
- 你希望策划、AI、程序都围绕同一个文件工作。

## 2. 最小字段
- `meta`
- `style`
- `layout`
- `assets`
- `text`
- `runtime`

## 3. 模板

```yaml
meta:
  id: page_id
  title: 页面标题
  goal: 一句话目标
  priority: P0
  mode: ai_fast

style:
  habit_ref: moba_pc
  keywords: [风格词1, 风格词2, 风格词3]
  mood: 氛围描述
  layout_theme: 布局主题

layout:
  canvas: dynamic_width x 1080
  composition: 构图一句话
  blocks:
    - id: block_id
      role: 模块作用
      anchor: top-center
      size: 900x120
      note: 说明

assets:
  - name: asset_name
    use: 所属模块
    type: 底板
    stretch: true
    state: [default]

text:
  - use: 文本用途
    sample: 示例文案
    align: center
    lines: 1

runtime:
  - 程序接法说明1
  - 程序接法说明2

ux_rules:
  - 交互和信息层级规则1
  - 交互和信息层级规则2
```

## 4. 写法建议
- `meta`
  只解决“这页是什么、干什么”。
- `style`
  只写能影响 AI 出图方向的词，不写长段解释。
  若你希望明显贴近某类成熟产品习惯，建议补：
  `habit_ref: moba_pc`
- `layout`
  只写主模块，不在第一版里穷举所有小控件。
- `assets`
  先写逻辑资源，不强求第一版就有最终资源名。
- `text`
  只写动态文本和关键文本。
- `runtime`
  只写程序必须知道的布局和适配规则。
- `ux_rules`
  用来补“更像 MOBA / 更像 ARPG / 更像卡牌游戏”的习惯规则。

## 5. 给 AI 的常用喂法
- `把这份 YAML 转成低保真 UI 结构图`
- `根据这份 YAML 拆一版资源清单`
- `根据这份 YAML 输出美术出图 prompt`
- `根据这份 YAML 生成 UI builder 骨架`

## 6. 最小检查
- 看完 YAML，AI 能不能出第一版图
- 看完 YAML，程序能不能搭第一版骨架
- 布局重点是否清楚
- 动态文本是否独立
- 拉伸底板是否明确

## 7. 相关文档
- [UI资源清单表模板](./15-UI资源清单表模板.md)
- [UI结构标注图模板](./16-UI结构标注图模板.md)
- [顶部战斗HUD单文件YAML示例](./20-顶部战斗HUD单文件YAML示例.md)

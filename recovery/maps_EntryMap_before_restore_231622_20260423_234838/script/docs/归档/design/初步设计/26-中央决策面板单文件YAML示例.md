# 中央决策面板单文件YAML示例

> 这是 `中央决策面板通用框架` 的单文件规格示例，方向明确对齐 `MOBA / PC 端游用户习惯`：`上标题、左摘要、中候选、下操作`。

```yaml
meta:
  id: central_decision_panel
  title: 中央决策面板通用框架
  goal: 在战斗中稳定承载 G/F/宝物/烙印/词缀 等关键决策，不让玩家丢失当前构筑上下文
  priority: P0
  mode: ai_fast

style:
  habit_ref: moba_pc
  keywords: [moba_pc, 战术桌面, 稳重金属, 聚焦决策]
  mood: 战斗中暂停式思考，但不完全切断战场感知
  layout_theme: 上标题 + 左摘要 + 中候选 + 下操作

layout:
  canvas: dynamic_width x 1080
  composition: 中央大弹窗，左侧构筑摘要，中间三列候选，下方固定操作栏
  blocks:
    - id: decision_mask
      role: 聚焦遮罩
      anchor: full
      size: dynamic_widthx1080
      note: 轻度压暗战场，不完全盖死背景
    - id: decision_panel
      role: 中央面板外框
      anchor: percent(50,52)
      size: 1180x720
      note: 共用 G/F/宝物/烙印/词缀
    - id: header_bar
      role: 标题栏
      anchor: top-inner
      size: 1080x68
      note: 主标题、副标题、关闭/返回
    - id: summary_rail
      role: 左侧构筑摘要栏
      anchor: left-inner
      size: 228x520
      note: 当前技能、羁绊、宝物、词缀摘要
    - id: candidate_stage
      role: 候选舞台
      anchor: center-inner
      size: 760x520
      note: 三列候选卡稳定对比
    - id: candidate_slot_1
      role: 候选卡槽1
      anchor: stage-left
      size: 220x420
      note: 固定列宽
    - id: candidate_slot_2
      role: 候选卡槽2
      anchor: stage-center
      size: 220x420
      note: 固定列宽
    - id: candidate_slot_3
      role: 候选卡槽3
      anchor: stage-right
      size: 220x420
      note: 固定列宽
    - id: footer_bar
      role: 底部操作栏
      anchor: bottom-inner
      size: 1080x72
      note: 刷新、稍后、提示文本

assets:
  - name: decision_mask_bg
    use: decision_mask
    type: 遮罩
    stretch: true
  - name: decision_panel_bg
    use: decision_panel
    type: 底板
    stretch: true
    nine_slice: 72/72/32/32
  - name: decision_panel_inner
    use: decision_panel
    type: 内框
    stretch: true
    nine_slice: 36/36/24/24
  - name: decision_header_bg
    use: header_bar
    type: 顶栏底
    stretch: true
    nine_slice: 28/28/18/18
  - name: close_btn_bg
    use: header_bar
    type: 按钮底
    stretch: false
    state: [default, hover]
  - name: summary_rail_bg
    use: summary_rail
    type: 底板
    stretch: true
    nine_slice: 24/24/20/20
  - name: summary_slot_bg
    use: summary_rail
    type: 条目底
    stretch: true
  - name: candidate_stage_bg
    use: candidate_stage
    type: 底板
    stretch: true
    nine_slice: 32/32/24/24
  - name: candidate_slot_bg
    use: candidate_stage
    type: 卡槽底
    stretch: true
    nine_slice: 22/22/18/18
  - name: candidate_slot_glow
    use: candidate_stage
    type: 描边
    stretch: false
    state: [highlight]
  - name: panel_footer_bg
    use: footer_bar
    type: 底板
    stretch: true
    nine_slice: 24/24/18/18
  - name: primary_footer_btn_bg
    use: footer_bar
    type: 主按钮底
    stretch: true
    state: [default, ready, disabled]
    nine_slice: 18/18/14/14
  - name: secondary_footer_btn_bg
    use: footer_bar
    type: 次按钮底
    stretch: true
    state: [default, active]
    nine_slice: 18/18/14/14
  - name: cost_chip_bg
    use: footer_bar
    type: 消耗角标
    stretch: true
  - name: state_hint_chip
    use: candidate_stage
    type: 状态条
    stretch: true

text:
  - use: panel_title
    sample: 攻击技能强化
    align: left
    lines: 1
  - use: panel_subtitle
    sample: 选择 1 项强化当前构筑
    align: left
    lines: 1
  - use: summary_title
    sample: 当前构筑
    align: left
    lines: 1
  - use: summary_item
    sample: 普攻流 / 连射 2/3 / 宝物 2/3
    align: left
    lines: 1
  - use: card_title
    sample: 箭矢齐射
    align: center
    lines: 1
  - use: card_tag
    sample: 路线强化 / 关键强化
    align: center
    lines: 2
  - use: footer_hint
    sample: 当前刷新免费 1 次
    align: left
    lines: 1
  - use: primary_btn_text
    sample: 刷新
    align: center
    lines: 1
  - use: secondary_btn_text
    sample: 稍后选择
    align: center
    lines: 1

runtime:
  - decision_mask 铺满全屏
  - decision_panel 用 percent 居中
  - decision_panel 内部固定分为 header / body / footer 三层
  - body 固定分为 summary_rail + candidate_stage 两列
  - candidate_stage 固定 3 列槽位，不因文本长度变化结构
  - footer_bar 固定承载刷新、稍后和提示文本
  - 所有文本独立，不烘进背景图
  - 所有 stretch=true 的底板启用九宫

beauty_rules:
  - 整体更像端游强化/商店/天赋弹窗，而不是移动端整屏卡牌页
  - 标题栏和底栏稳定存在，建立固定阅读路径
  - 左摘要栏弱于候选卡，但必须持续可见
  - 候选卡工整排列，强调横向比较
  - 高价值信息靠边框、标签、局部高亮表达，不靠满屏粒子

ux_rules:
  - 读图顺序默认从标题到左摘要，再到中间三张候选，最后到底部按钮
  - 玩家做选择时必须看得到当前构筑摘要
  - 刷新/稍后/返回的位置不能在不同系统里跳来跳去
  - 主要状态变化优先靠颜色和局部提示，不频繁改结构
```

## 1. 使用方式
- 把上面整段 YAML 发给 AI，让它先出一版 `中央决策面板低保真结构图`。
- 再让 AI 基于同一份 YAML 输出：
  `资源拆分建议`
  `G/F/宝物/烙印 四类候选的统一出图 prompt`
  `central_panel spec / builder 草案`

## 2. 相关文档
- [UI单文件YAML规格模板](./19-UI单文件YAML规格模板.md)
- [中央决策面板资源清单示例](./24-中央决策面板资源清单示例.md)
- [中央决策面板结构标注示例](./25-中央决策面板结构标注示例.md)

# 顶部战斗HUD单文件YAML示例

> 这是 `顶部战斗HUD` 的单文件规格示例，同时体现了更美观的布局方案：`中轴仪表盘 + 右侧浮动资源簇`。

```yaml
meta:
  id: top_battle_hud
  title: 顶部战斗HUD
  goal: 战斗中快速读取波次、Boss、资源和玩家统计
  priority: P0
  mode: ai_fast

style:
  habit_ref: moba_pc
  keywords: [奇幻金属, 中轴仪表盘, 轻悬浮, 清晰高对比]
  mood: 稳定战场中带高压Boss预警
  layout_theme: 上方扁平状态带 + 右侧浮动资源簇

layout:
  canvas: dynamic_width x 1080
  composition: 左标签 + 中徽章 + 右Boss胶囊 + 下方细时间轨，右上挂资源簇与统计卡
  blocks:
    - id: hud_cluster
      role: 中轴主构图
      anchor: percent(50,43)
      size: 1040x136
      note: 主视觉中心，不做一整条厚横板
    - id: stage_chip
      role: 关卡标签
      anchor: left-wing
      size: 140x44
      note: 小而精，弱于波次徽章
    - id: wave_medallion
      role: 波次主焦点
      anchor: center-crown
      size: 220x92
      note: 略微上浮 12px，形成中心层级
    - id: boss_capsule
      role: Boss信息主模块
      anchor: right-wing
      size: 420x88
      note: 比关卡标签更厚重，承担危险信息
    - id: timer_rail
      role: 细时间轨
      anchor: bottom-center
      size: 560x20
      note: 细而长，不抢主标题
    - id: resource_cluster
      role: 右上资源浮动簇
      anchor: top-right
      size: 392x144
      note: 三张窄卡，像战场仪表而不是后台表格
    - id: player_stats_card
      role: 玩家统计卡
      anchor: under(resource_cluster)
      size: 392x108
      note: 轻于资源簇，作为辅助信息

assets:
  - name: cluster_backplate
    use: hud_cluster
    type: 底板
    stretch: true
    nine_slice: 84/84/30/30
  - name: stage_chip_bg
    use: stage_chip
    type: 标签底
    stretch: false
  - name: wave_medallion_bg
    use: wave_medallion
    type: 徽章底
    stretch: false
  - name: wave_medallion_ring
    use: wave_medallion
    type: 徽章环
    stretch: false
  - name: boss_capsule_bg
    use: boss_capsule
    type: 底板
    stretch: true
    state: [prepare, fight]
    nine_slice: 28/28/18/18
  - name: timer_rail_bg
    use: timer_rail
    type: 底板
    stretch: true
    state: [normal, warning]
    nine_slice: 18/18/8/8
  - name: timer_rail_fill
    use: timer_rail
    type: 填充
    stretch: true
  - name: resource_cluster_plate
    use: resource_cluster
    type: 底板
    stretch: true
    nine_slice: 28/28/24/24
  - name: resource_pillar_bg
    use: resource_cluster
    type: 资源窄卡
    stretch: true
    nine_slice: 18/18/18/18
  - name: player_stats_card_bg
    use: player_stats_card
    type: 底板
    stretch: true
    nine_slice: 24/24/18/18

text:
  - use: stage_text
    sample: 主线 1-1
    align: center
    lines: 1
  - use: wave_title
    sample: 第 1 / 5 波
    align: center
    lines: 1
  - use: boss_name
    sample: 深渊吞噬者
    align: left
    lines: 1
  - use: boss_state
    sample: 来临 8s / 生命 999999
    align: right
    lines: 1
  - use: timer_text
    sample: 剩余 30s
    align: center
    lines: 1
  - use: resource_value
    sample: 999999
    align: center
    lines: 1
  - use: player_name
    sample: 玩家一
    align: left
    lines: 1
  - use: damage_value
    sample: 99999999
    align: right
    lines: 1

runtime:
  - hud_cluster 用 GameAPI.set_ui_comp_pos_percent(...) 居中
  - resource_cluster 用 top/right 吸附
  - player_stats_card 跟随 resource_cluster 下挂
  - hud_cluster 内部用 local_box + set_pos 排版
  - 所有文本独立，不烘进背景图
  - 所有 stretch=true 的底板启用九宫
  - 波次徽章允许上浮，不与左右模块齐平

beauty_rules:
  - 主信息带保持扁平横向，符合 MOBA 端游顶部阅读习惯
  - 波次模块是第一视觉焦点，但不要过度上浮成夸张徽章
  - Boss胶囊比关卡标签更重，形成阅读层级
  - 时间轨细而长，作为第二阅读层
  - 右上资源区做紧凑横向窄卡，不做笨重矩形大面板

ux_rules:
  - 战斗节奏信息优先于资源信息
  - 资源信息优先于玩家统计
  - 读图顺序默认从中上到右上，再到右侧下方
  - 主要状态变化优先用颜色和描边，不频繁改结构
```

## 1. 使用方式
- 把上面整段 YAML 发给 AI，让它先出一版 `低保真结构图`。
- 再让 AI 基于同一份 YAML 输出：
  `资源拆分建议`
  `美术 prompt`
  `程序骨架建议`

## 2. 相关文档
- [UI单文件YAML规格模板](./19-UI单文件YAML规格模板.md)
- [顶部战斗HUD资源清单示例](./17-顶部战斗HUD资源清单示例.md)
- [顶部战斗HUD结构标注示例](./18-顶部战斗HUD结构标注示例.md)

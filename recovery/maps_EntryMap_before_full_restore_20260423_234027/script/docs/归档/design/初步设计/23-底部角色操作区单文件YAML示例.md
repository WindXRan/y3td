# 底部角色操作区单文件YAML示例

> 这是 `底部角色操作区` 的单文件规格示例，方向明确对齐 `MOBA 端游用户习惯`：`左英雄核心 / 中技能热区 / 右功能簇 / 底部经验轨`。

```yaml
meta:
  id: bottom_action_bar
  title: 底部角色操作区
  goal: 战斗中快速完成英雄读取、技能确认、构筑入口点击和功能判断
  priority: P0
  mode: ai_fast

style:
  habit_ref: moba_pc
  keywords: [moba_pc, 功能热键栏, 稳重金属, 清晰高对比]
  mood: 稳定、熟悉、重功能、少花哨
  layout_theme: 左英雄核心 + 中技能热区 + 右功能簇 + 底边经验轨

layout:
  canvas: dynamic_width x 1080
  composition: 左头像等级，中间技能热键，右侧主次功能分层，底边经验轨贯穿
  blocks:
    - id: bottom_shell
      role: 底部主条
      anchor: bottom-center
      size: 1420x168
      note: 统一承载全部底栏模块
    - id: hero_core
      role: 英雄核心区
      anchor: left-wing
      size: 320x108
      note: 头像、等级、英雄名、属性摘要
    - id: growth_weapon_slot
      role: 成长武器格
      anchor: center-left-bridge
      size: 76x76
      note: 连接英雄区和技能区，像特殊装备槽
    - id: skill_hotbar
      role: 技能热键区
      anchor: center
      size: 500x92
      note: 4 个攻击技能位，底栏视觉中心
    - id: primary_actions
      role: 主功能簇
      anchor: center-right
      size: 272x84
      note: 技能(G)、羁绊(F) 两个主按钮
    - id: secondary_actions
      role: 次功能簇
      anchor: right-lower
      size: 312x64
      note: 宝物、集火、已吞噬 三个次级按钮
    - id: exp_rail
      role: 经验轨
      anchor: bottom-inner
      size: 1220x12
      note: 细贴底边，统一成长进度感

assets:
  - name: bottom_shell_bg
    use: bottom_shell
    type: 底板
    stretch: true
    nine_slice: 96/96/28/28
  - name: hero_panel_bg
    use: hero_core
    type: 底板
    stretch: true
    nine_slice: 28/28/22/22
  - name: portrait_frame
    use: hero_core
    type: 边框
    stretch: false
  - name: level_badge
    use: hero_core
    type: 徽标
    stretch: false
  - name: attr_chip_bg
    use: hero_core
    type: 标签底
    stretch: true
  - name: growth_weapon_slot_bg
    use: growth_weapon_slot
    type: 槽位底
    stretch: false
    state: [normal, pending]
  - name: skill_hotbar_bg
    use: skill_hotbar
    type: 底板
    stretch: true
    nine_slice: 42/42/20/20
  - name: skill_slot_bg
    use: skill_hotbar
    type: 技能槽位
    stretch: false
    state: [normal, ready, locked]
  - name: slot_index_chip
    use: skill_hotbar
    type: 角标
    stretch: false
  - name: action_cluster_bg
    use: primary_actions
    type: 底板
    stretch: true
    nine_slice: 26/26/18/18
  - name: primary_action_btn_bg
    use: primary_actions
    type: 按钮底
    stretch: true
    state: [default, ready, disabled]
    nine_slice: 22/22/18/18
  - name: secondary_action_btn_bg
    use: secondary_actions
    type: 按钮底
    stretch: true
    state: [default, active]
    nine_slice: 18/18/14/14
  - name: skill_point_badge
    use: primary_actions
    type: 徽标
    stretch: false
  - name: wood_cost_chip
    use: primary_actions
    type: 消耗角标
    stretch: true
  - name: exp_rail_bg
    use: exp_rail
    type: 底条
    stretch: true
    nine_slice: 18/18/6/6
  - name: exp_rail_fill
    use: exp_rail
    type: 填充
    stretch: true

text:
  - use: hero_name
    sample: 游侠
    align: left
    lines: 1
  - use: level_text
    sample: 12
    align: center
    lines: 1
  - use: attr_summary
    sample: 攻击 120 / 暴击 18%
    align: left
    lines: 1
  - use: weapon_level
    sample: 武器 Lv.8
    align: center
    lines: 1
  - use: primary_action_text
    sample: 技能 / 羁绊
    align: center
    lines: 1
  - use: secondary_action_text
    sample: 宝物 / 集火 / 已吞噬
    align: center
    lines: 1
  - use: skill_point
    sample: 3
    align: center
    lines: 1
  - use: wood_cost
    sample: 100 木材
    align: center
    lines: 1

runtime:
  - bottom_shell 用 bottom-center 吸附
  - hero_core 固定在左侧，skill_hotbar 保持底栏几何中心
  - growth_weapon_slot 位于 hero_core 和 skill_hotbar 之间
  - primary_actions 比 secondary_actions 更大、更靠中
  - 所有文本独立，不烘进背景图
  - 所有 stretch=true 的底板启用九宫
  - exp_rail 贴底栏下沿，不单独占大高度

beauty_rules:
  - 底栏整体要像 MOBA 热键栏，不像横向菜单条
  - 技能热键区是视觉中心
  - G/F 主按钮保持强权重，但不要压过技能位
  - 次级按钮收在右下，不与技能区争中心
  - 头像区稳定厚重，给玩家熟悉的英雄归属感

ux_rules:
  - 读图顺序默认从左侧英雄核心到中间技能热区，再到右侧功能簇
  - 战斗常用区优先居中
  - 功能入口分主次两层，不做同权重平铺
  - 状态变化优先用徽标、描边和局部高亮，不频繁改布局
```

## 1. 使用方式
- 把上面整段 YAML 发给 AI，让它先出一版 `低保真底栏结构图`。
- 再让 AI 基于同一份 YAML 输出：
  `资源拆分建议`
  `MOBA 风格底栏出图 prompt`
  `程序 spec / builder 草案`

## 2. 相关文档
- [UI单文件YAML规格模板](./19-UI单文件YAML规格模板.md)
- [底部角色操作区资源清单示例](./21-底部角色操作区资源清单示例.md)
- [底部角色操作区结构标注示例](./22-底部角色操作区结构标注示例.md)

# 羁绊 CSV 字段稿（参考图展示版）

说明：
- 这份稿子是给 `bond_group_labels.csv`、`bond_group_choices.csv`、`bond_group_choice_paths.csv`、`bond_root_sets.csv` 用的。
- 文案风格和展示信息字段全部按参考图的版式走，不再用概念化说明语。
- 现有代码默认只有 6 个顶层分组；要落地 30 套羁绊，分组表需要从 6 扩到 30。
- 这里先给出可落表的字段方向，节点卡牌本体后续再接 `bond_nodes.csv`。

## 0. 参考图展示模板

### 页面级字段

| 字段名 | 参考图版本 |
|---|---|
| page_title | 卡牌图鉴 |
| top_counter_label | 本局已吞 |
| basic_group_label | 职业卡组 |
| special_group_label | 特殊卡组 |
| card_grid_title | 右侧槽位区不额外加标题，直接展示槽位 |

### 按钮字段

| 字段名 | 参考图版本 |
|---|---|
| group_button_text | `名称(0/5)` 或 `名称(0/3)` |
| group_button_state_active | 高亮黄底 |
| group_button_state_normal | 蓝底 |
| group_button_state_locked | 蓝底但作为特殊卡组显示 |

### 右侧详情字段

| 字段名 | 参考图版本 |
|---|---|
| detail_title_format | `羁绊名·特效>（未激活）` |
| detail_subtitle_format | `（吞噬所有本羁绊卡牌，可激活此特效）` |
| detail_body_format | 首行写触发条件，中间写效果，末尾写限制或补充 |
| detail_color_rule | 关键词按效果语义上色，数值用绿色，伤害类型或风险词可用红色/蓝色/紫色 |

### 文案风格

- 标题短、硬、直给，不写说明性长句。
- 状态词统一为 `未激活`、`已激活`、`已吞噬`、`可激活`。
- 右侧正文采用“触发条件 + 触发效果 + 结果描述”的三段式，不写大段策划解释。
- 如果某套没有单卡功能，也保持同样的 `·特效>` 标题格式，只把正文写成对应的凑齐效果。

## 1. 顶层分组与图鉴入口

| group_id | display_name | quality | 备注 |
|---|---|---|---|
| element | 元素师 | rare | 参考图文本使用“元素师(0/5)” |
| necro | 死灵法师 | epic | 参考图文本使用“死灵法师(0/5)” |
| paladin | 圣骑士 | rare | 参考图文本使用“圣骑士(0/5)” |
| assassin | 刺客 | rare | 参考图文本使用“刺客(0/5)” |
| warlock | 术士 | epic | 参考图文本使用“术士(0/5)” |
| summoner | 召唤师 | epic | 参考图文本使用“召唤师(0/5)” |
| warrior | 战士 | rare | 参考图文本使用“战士(0/5)” |
| guardian | 守护者 | rare | 参考图文本使用“守护者(0/5)” |
| berserker | 狂战士 | epic | 参考图文本使用“狂战士(0/5)” |
| hunter | 猎手 | rare | 参考图文本使用“猎手(0/5)” |
| machinist | 机械师 | epic | 参考图文本使用“机械师(0/5)” |
| alchemist | 炼金师 | rare | 参考图文本使用“炼金师(0/5)” |
| witchdoctor | 巫医 | epic | 参考图文本使用“巫医(0/5)” |
| shadowwalker | 暗影行者 | epic | 参考图文本使用“暗影行者(0/5)” |
| inquisitor | 审判官 | rare | 参考图文本使用“审判官(0/5)” |
| priest | 祭司 | rare | 参考图文本使用“祭司(0/5)” |
| curseblade | 咒刃 | epic | 参考图文本使用“咒刃(0/5)” |
| dragonborn | 龙裔 | epic | 参考图文本使用“龙裔(0/5)” |
| astrologer | 星术师 | epic | 参考图文本使用“星术师(0/5)” |
| illusionist | 幻术师 | epic | 参考图文本使用“幻术师(0/5)” |
| inferno | 炼狱行者 | epic | 参考图文本使用“炼狱行者(0/5)” |
| frost | 冰霜使 | epic | 参考图文本使用“冰霜使(0/5)” |
| thunder | 雷鸣使 | epic | 参考图文本使用“雷鸣使(0/5)” |
| windspeaker | 风语者 | rare | 参考图文本使用“风语者(0/5)” |
| runesmith | 符文师 | rare | 参考图文本使用“符文师(0/5)” |
| oracle | 先知 | epic | 参考图文本使用“先知(0/5)” |
| shadowmage | 影法师 | epic | 参考图文本使用“影法师(0/5)” |
| boneknight | 骸骨骑士 | epic | 参考图文本使用“骸骨骑士(0/5)” |
| forge | 炎铸匠 | epic | 参考图文本使用“炎铸匠(0/5)” |
| executor | 天罚者 | epic | 参考图文本使用“天罚者(0/5)” |

## 2. 分组展示文案

| group_id | choice_id | display_name | quality | order_index | notes |
|---|---|---|---|---|---|
| element | __group_element | 元素师 | rare | 1 | 卡面显示“元素师(0/5)” |
| necro | __group_necro | 死灵法师 | epic | 2 | 卡面显示“死灵法师(0/5)” |
| paladin | __group_paladin | 圣骑士 | rare | 3 | 卡面显示“圣骑士(0/5)” |
| assassin | __group_assassin | 刺客 | rare | 4 | 卡面显示“刺客(0/5)” |
| warlock | __group_warlock | 术士 | epic | 5 | 卡面显示“术士(0/5)” |
| summoner | __group_summoner | 召唤师 | epic | 6 | 卡面显示“召唤师(0/5)” |
| warrior | __group_warrior | 战士 | rare | 7 | 卡面显示“战士(0/5)” |
| guardian | __group_guardian | 守护者 | rare | 8 | 卡面显示“守护者(0/5)” |
| berserker | __group_berserker | 狂战士 | epic | 9 | 卡面显示“狂战士(0/5)” |
| hunter | __group_hunter | 猎手 | rare | 10 | 卡面显示“猎手(0/5)” |
| machinist | __group_machinist | 机械师 | epic | 11 | 卡面显示“机械师(0/5)” |
| alchemist | __group_alchemist | 炼金师 | rare | 12 | 卡面显示“炼金师(0/5)” |
| witchdoctor | __group_witchdoctor | 巫医 | epic | 13 | 卡面显示“巫医(0/5)” |
| shadowwalker | __group_shadowwalker | 暗影行者 | epic | 14 | 卡面显示“暗影行者(0/5)” |
| inquisitor | __group_inquisitor | 审判官 | rare | 15 | 卡面显示“审判官(0/5)” |
| priest | __group_priest | 祭司 | rare | 16 | 卡面显示“祭司(0/5)” |
| curseblade | __group_curseblade | 咒刃 | epic | 17 | 卡面显示“咒刃(0/5)” |
| dragonborn | __group_dragonborn | 龙裔 | epic | 18 | 卡面显示“龙裔(0/5)” |
| astrologer | __group_astrologer | 星术师 | epic | 19 | 卡面显示“星术师(0/5)” |
| illusionist | __group_illusionist | 幻术师 | epic | 20 | 卡面显示“幻术师(0/5)” |
| inferno | __group_inferno | 炼狱行者 | epic | 21 | 卡面显示“炼狱行者(0/5)” |
| frost | __group_frost | 冰霜使 | epic | 22 | 卡面显示“冰霜使(0/5)” |
| thunder | __group_thunder | 雷鸣使 | epic | 23 | 卡面显示“雷鸣使(0/5)” |
| windspeaker | __group_windspeaker | 风语者 | rare | 24 | 卡面显示“风语者(0/5)” |
| runesmith | __group_runesmith | 符文师 | rare | 25 | 卡面显示“符文师(0/5)” |
| oracle | __group_oracle | 先知 | epic | 26 | 卡面显示“先知(0/5)” |
| shadowmage | __group_shadowmage | 影法师 | epic | 27 | 卡面显示“影法师(0/5)” |
| boneknight | __group_boneknight | 骸骨骑士 | epic | 28 | 卡面显示“骸骨骑士(0/5)” |
| forge | __group_forge | 炎铸匠 | epic | 29 | 卡面显示“炎铸匠(0/5)” |
| executor | __group_executor | 天罚者 | epic | 30 | 卡面显示“天罚者(0/5)” |

## 3. 根套装字段建议

| root_id | required_count | completion_mode | base_text | effect_text | pool |
|---|---|---|---|---|---|
| bond_element_core | 4 | consume_all | 元素纹章：火、冰、雷、风各自提供基础伤害 | 元素伤害命中后有概率触发余波，印记可引爆一次额外元素伤害。 | 普通池 |
| bond_necro_core | 4 | consume_all | 骨契：召唤物继承部分属性 | 亡灵与召唤物数量、持续时间提升，击杀后短时增幅。 | 高级池 |
| bond_paladin_core | 4 | consume_all | 圣盾：生命值+100 | 护盾、减伤、生命恢复、护甲同步提高。 | 普通池 |
| bond_assassin_core | 4 | consume_all | 潜影：下一次攻击获得首击加成 | 对低血目标伤害提高，脱战后首击更强。 | 普通池 |
| bond_warlock_core | 4 | consume_all | 诅印：轻微削弱目标 | 代价换强度，生命/资源损耗转为高收益增幅。 | 高级池 |
| bond_summoner_core | 4 | consume_all | 唤灵：召唤物存在时间提高 | 召唤物数量、协战频率、继承比例提升。 | 高级池 |
| bond_warrior_core | 4 | consume_all | 重击：攻击更稳定 | 攻击、生命、护甲同步提高。 | 普通池 |
| bond_guardian_core | 4 | consume_all | 壁垒：承伤更稳 | 减伤、护盾强度、承伤能力提高。 | 普通池 |
| bond_berserker_core | 4 | consume_all | 血怒：低血时获得攻击加成 | 低血时攻击、攻速、回复联动增强，带少量风险换爆发。 | 普通池 |
| bond_hunter_core | 4 | consume_all | 标记：目标被暴露 | 对被标记目标伤害提高，追击和收割更稳定。 | 普通池 |
| bond_machinist_core | 4 | consume_all | 炮塔：自动校准 | 自动火力、持续输出、装填效率提高。 | 高级池 |
| bond_alchemist_core | 4 | consume_all | 药液：增益更持久 | 资源获取、恢复、增益持续时间提高。 | 普通池 |
| bond_witchdoctor_core | 4 | consume_all | 蛊毒：持续削弱 | 持续伤害、减疗、减速和削弱效果增强。 | 高级池 |
| bond_shadowwalker_core | 4 | consume_all | 匿影：脱战后下一击更强 | 脱战、位移、首击增伤联动。 | 高级池 |
| bond_inquisitor_core | 4 | consume_all | 裁定：对高血目标附加压制 | 对高血和残血目标都更容易打出终结收益。 | 普通池 |
| bond_priest_core | 4 | consume_all | 祷言：恢复稳定 | 恢复、护持、持续作战能力提高。 | 普通池 |
| bond_curseblade_core | 4 | consume_all | 附咒：近战攻击附带术式伤害 | 近战与法伤联动，攻击附带额外咒术效果。 | 高级池 |
| bond_dragonborn_core | 4 | consume_all | 龙脉：少量属性转化 | 生命、攻击、爆发同步提高，带觉醒感的终局成长。 | 高级池 |
| bond_astrologer_core | 4 | consume_all | 预兆：提高下一次刷新稳定性 | 重掷、命运修正、随机收益更稳定。 | 高级池 |
| bond_illusionist_core | 4 | consume_all | 替身：吸收一次轻微伤害 | 复制、错位、虚实转换，收益被复制一次。 | 高级池 |
| bond_inferno_core | 4 | consume_all | 焚痕：附带灼烧标记 | 灼烧、持续压制、爆发收尾增强。 | 高级池 |
| bond_frost_core | 4 | consume_all | 霜缚：附带减速 | 减速、冻结、迟滞增强。 | 高级池 |
| bond_thunder_core | 4 | consume_all | 电弧：连锁附近目标 | 连锁、麻痹、短爆发提高。 | 高级池 |
| bond_windspeaker_core | 4 | consume_all | 轻身：行动更轻盈 | 机动、攻速、闪避提高。 | 普通池 |
| bond_runesmith_core | 4 | consume_all | 铭刻：可叠加标记 | 标记叠层、触发收益提高。 | 普通池 |
| bond_oracle_core | 4 | consume_all | 卜算：小幅提高重掷收益 | 刷新、替换、锁定结果更稳定。 | 高级池 |
| bond_shadowmage_core | 4 | consume_all | 暗蚀：附带轻微削弱 | 削弱、吸取、暗爆发提高。 | 高级池 |
| bond_boneknight_core | 4 | consume_all | 骨甲：更耐打 | 护甲、生命、复苏能力提高。 | 高级池 |
| bond_forge_core | 4 | consume_all | 熔炉：强化更顺手 | 强化、灌注、装备收益提高。 | 高级池 |
| bond_executor_core | 4 | consume_all | 雷裁：对残血单位附带处决判定 | 终结、斩杀、清场能力提高。 | 高级池 |

## 4. 落表顺序建议

1. 先扩 `bond_group_labels.csv`、`bond_group_choices.csv`、`bond_group_choice_paths.csv` 到 30 组。
2. 再补 `bond_root_sets.csv`，保证每套 4 张卡的根套装完成阈值统一。
3. 最后再写 `bond_nodes.csv`，把每套 3-5 张卡的属性和功能拆开。

## 5. 当前实现需要注意的地方

- 现有 `runtime/bonds_chain.lua` 仍按旧的 6 个大类思路组织调试文案和部分展示口径，扩成 30 组后要同步检查 UI 和 tip 文案。
- 现有 `bond_pick_config.lua`、`bond_draw_config.lua`、`bond_misc_config.lua` 都会直接读取 CSV，分组扩表后无需改 loader 结构，但要保证 `group_id` 一致。
- 如果保留“普通池 / 高级池”区分，建议先把高级池组在 UI 上单独标记，避免玩家误解。

# 羁绊参考图 CSV 草稿

说明：
- 这份草稿只处理“参考图展示口径”的字段，不展开节点本体数值。
- 展示文本统一使用参考图风格：短标题、状态词、固定副标题、正文分行。
- 现有运行时默认只有 6 个大类；如果要落到这 30 套职业包装版，需要先扩分组，再写节点。
- 旧六大类的 `F` 分组选项已按当前策略屏蔽，不再作为第一层入口展示。

## 页面展示字段

| 字段 | 值 |
|---|---|
| page_title | 卡牌图鉴 |
| top_counter_label | 本局已吞 |
| left_basic_label | 职业卡组 |
| left_special_label | 特殊卡组 |
| detail_title_suffix | ·特效> |
| detail_status_locked | 未激活 |
| detail_hint | （吞噬所有本羁绊卡牌，可激活此特效） |

## group_labels.csv

| group_id | display_name |
|---|---|
| element | 元素师 |
| necro | 死灵法师 |
| paladin | 圣骑士 |
| assassin | 刺客 |
| warlock | 术士 |
| summoner | 召唤师 |
| warrior | 战士 |
| guardian | 守护者 |
| berserker | 狂战士 |
| hunter | 猎手 |
| machinist | 机械师 |
| alchemist | 炼金师 |
| witchdoctor | 巫医 |
| shadowwalker | 暗影行者 |
| inquisitor | 审判官 |
| priest | 祭司 |
| curseblade | 咒刃 |
| dragonborn | 龙裔 |
| astrologer | 星术师 |
| illusionist | 幻术师 |
| inferno | 炼狱行者 |
| frost | 冰霜使 |
| thunder | 雷鸣使 |
| windspeaker | 风语者 |
| runesmith | 符文师 |
| oracle | 先知 |
| shadowmage | 影法师 |
| boneknight | 骸骨骑士 |
| forge | 炎铸匠 |
| executor | 天罚者 |

## group_choices.csv

| group_id | choice_id | display_name | quality | order_index | notes |
|---|---|---|---|---|---|
| element | __group_element | 元素师 | rare | 1 |  |
| necro | __group_necro | 死灵法师 | epic | 2 |  |
| paladin | __group_paladin | 圣骑士 | rare | 3 |  |
| assassin | __group_assassin | 刺客 | rare | 4 |  |
| warlock | __group_warlock | 术士 | epic | 5 |  |
| summoner | __group_summoner | 召唤师 | epic | 6 |  |
| warrior | __group_warrior | 战士 | rare | 7 |  |
| guardian | __group_guardian | 守护者 | rare | 8 |  |
| berserker | __group_berserker | 狂战士 | epic | 9 |  |
| hunter | __group_hunter | 猎手 | rare | 10 |  |
| machinist | __group_machinist | 机械师 | epic | 11 |  |
| alchemist | __group_alchemist | 炼金师 | rare | 12 |  |
| witchdoctor | __group_witchdoctor | 巫医 | epic | 13 |  |
| shadowwalker | __group_shadowwalker | 暗影行者 | epic | 14 |  |
| inquisitor | __group_inquisitor | 审判官 | rare | 15 |  |
| priest | __group_priest | 祭司 | rare | 16 |  |
| curseblade | __group_curseblade | 咒刃 | epic | 17 |  |
| dragonborn | __group_dragonborn | 龙裔 | epic | 18 |  |
| astrologer | __group_astrologer | 星术师 | epic | 19 |  |
| illusionist | __group_illusionist | 幻术师 | epic | 20 |  |
| inferno | __group_inferno | 炼狱行者 | epic | 21 |  |
| frost | __group_frost | 冰霜使 | epic | 22 |  |
| thunder | __group_thunder | 雷鸣使 | epic | 23 |  |
| windspeaker | __group_windspeaker | 风语者 | rare | 24 |  |
| runesmith | __group_runesmith | 符文师 | rare | 25 |  |
| oracle | __group_oracle | 先知 | epic | 26 |  |
| shadowmage | __group_shadowmage | 影法师 | epic | 27 |  |
| boneknight | __group_boneknight | 骸骨骑士 | epic | 28 |  |
| forge | __group_forge | 炎铸匠 | epic | 29 |  |
| executor | __group_executor | 天罚者 | epic | 30 |  |

## group_choice_paths.csv

| group_id | seq | path_text |
|---|---|---|
| element | 1 | 元素师 |
| necro | 1 | 死灵法师 |
| paladin | 1 | 圣骑士 |
| assassin | 1 | 刺客 |
| warlock | 1 | 术士 |
| summoner | 1 | 召唤师 |
| warrior | 1 | 战士 |
| guardian | 1 | 守护者 |
| berserker | 1 | 狂战士 |
| hunter | 1 | 猎手 |
| machinist | 1 | 机械师 |
| alchemist | 1 | 炼金师 |
| witchdoctor | 1 | 巫医 |
| shadowwalker | 1 | 暗影行者 |
| inquisitor | 1 | 审判官 |
| priest | 1 | 祭司 |
| curseblade | 1 | 咒刃 |
| dragonborn | 1 | 龙裔 |
| astrologer | 1 | 星术师 |
| illusionist | 1 | 幻术师 |
| inferno | 1 | 炼狱行者 |
| frost | 1 | 冰霜使 |
| thunder | 1 | 雷鸣使 |
| windspeaker | 1 | 风语者 |
| runesmith | 1 | 符文师 |
| oracle | 1 | 先知 |
| shadowmage | 1 | 影法师 |
| boneknight | 1 | 骸骨骑士 |
| forge | 1 | 炎铸匠 |
| executor | 1 | 天罚者 |

## bond_root_sets.csv

| root_id | required_count | completion_mode | base_text | effect_text |
|---|---|---|---|---|
| bond_element_core | 4 | consume_all | 元素师·特效>（未激活） | 元素伤害命中后有概率触发余波，印记可引爆一次额外元素伤害。 |
| bond_necro_core | 4 | consume_all | 死灵法师·特效>（未激活） | 亡灵与召唤物数量、持续时间提升，击杀后短时增幅。 |
| bond_paladin_core | 4 | consume_all | 圣骑士·特效>（未激活） | 护盾、减伤、生命恢复、护甲同步提高。 |
| bond_assassin_core | 4 | consume_all | 刺客·特效>（未激活） | 对低血目标伤害提高，脱战后首击更强。 |
| bond_warlock_core | 4 | consume_all | 术士·特效>（未激活） | 代价换强度，生命/资源损耗转为高收益增幅。 |
| bond_summoner_core | 4 | consume_all | 召唤师·特效>（未激活） | 召唤物数量、协战频率、继承比例提升。 |
| bond_warrior_core | 4 | consume_all | 战士·特效>（未激活） | 攻击、生命、护甲同步提高。 |
| bond_guardian_core | 4 | consume_all | 守护者·特效>（未激活） | 减伤、护盾强度、承伤能力提高。 |
| bond_berserker_core | 4 | consume_all | 狂战士·特效>（未激活） | 低血时攻击、攻速、回复联动增强，带少量风险换爆发。 |
| bond_hunter_core | 4 | consume_all | 猎手·特效>（未激活） | 对被标记目标伤害提高，追击和收割更稳定。 |
| bond_machinist_core | 4 | consume_all | 机械师·特效>（未激活） | 自动火力、持续输出、装填效率提高。 |
| bond_alchemist_core | 4 | consume_all | 炼金师·特效>（未激活） | 资源获取、恢复、增益持续时间提高。 |
| bond_witchdoctor_core | 4 | consume_all | 巫医·特效>（未激活） | 持续伤害、减疗、减速和削弱效果增强。 |
| bond_shadowwalker_core | 4 | consume_all | 暗影行者·特效>（未激活） | 脱战、位移、首击增伤联动。 |
| bond_inquisitor_core | 4 | consume_all | 审判官·特效>（未激活） | 对高血和残血目标都更容易打出终结收益。 |
| bond_priest_core | 4 | consume_all | 祭司·特效>（未激活） | 恢复、护持、持续作战能力提高。 |
| bond_curseblade_core | 4 | consume_all | 咒刃·特效>（未激活） | 近战与法伤联动，攻击附带额外咒术效果。 |
| bond_dragonborn_core | 4 | consume_all | 龙裔·特效>（未激活） | 生命、攻击、爆发同步提高，带觉醒感的终局成长。 |
| bond_astrologer_core | 4 | consume_all | 星术师·特效>（未激活） | 重掷、命运修正、随机收益更稳定。 |
| bond_illusionist_core | 4 | consume_all | 幻术师·特效>（未激活） | 复制、错位、虚实转换，收益被复制一次。 |
| bond_inferno_core | 4 | consume_all | 炼狱行者·特效>（未激活） | 灼烧、持续压制、爆发收尾增强。 |
| bond_frost_core | 4 | consume_all | 冰霜使·特效>（未激活） | 减速、冻结、迟滞增强。 |
| bond_thunder_core | 4 | consume_all | 雷鸣使·特效>（未激活） | 连锁、麻痹、短爆发提高。 |
| bond_windspeaker_core | 4 | consume_all | 风语者·特效>（未激活） | 机动、攻速、闪避提高。 |
| bond_runesmith_core | 4 | consume_all | 符文师·特效>（未激活） | 标记叠层、触发收益提高。 |
| bond_oracle_core | 4 | consume_all | 先知·特效>（未激活） | 刷新、替换、锁定结果更稳定。 |
| bond_shadowmage_core | 4 | consume_all | 影法师·特效>（未激活） | 削弱、吸取、暗爆发提高。 |
| bond_boneknight_core | 4 | consume_all | 骸骨骑士·特效>（未激活） | 护甲、生命、复苏能力提高。 |
| bond_forge_core | 4 | consume_all | 炎铸匠·特效>（未激活） | 强化、灌注、装备收益提高。 |
| bond_executor_core | 4 | consume_all | 天罚者·特效>（未激活） | 终结、斩杀、清场能力提高。 |

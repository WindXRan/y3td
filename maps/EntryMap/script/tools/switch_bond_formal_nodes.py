#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import csv
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "script" / "data_csv"
DOC = ROOT / "script" / "docs" / "bond_reference_csv"


PERCENT_ATTRS = {
    "物理暴击",
    "魔法暴击",
    "物理暴伤",
    "魔法暴伤",
    "攻击速度",
    "技能急速",
    "物理伤害",
    "魔法伤害",
    "技能伤害",
    "所有伤害",
    "命中",
}


PATTERNS = {
    "magic": {
        "template": "per_second_growth",
        "route_tags": ["skill", "spell_cycle", "arcane"],
        "root_rows": [("attr", "魔法伤害", 5), ("runtime", "skill_damage_bonus", 0.05)],
        "support_rows": [
            ("attr", "技能伤害", 5),
            ("attr", "智力", 50),
            ("attr", "攻击", 50),
        ],
        "root_set_attrs": [("魔法伤害", 5), ("技能伤害", 5)],
        "root_set_runtime": [("skill_damage_bonus", 0.05)],
    },
    "burst": {
        "template": "basic_attack_modifier",
        "route_tags": ["burst", "clear"],
        "root_rows": [("attr", "攻击", 50), ("runtime", "all_damage_bonus", 0.04)],
        "support_rows": [
            ("attr", "物理暴击", 3),
            ("attr", "物理暴伤", 10),
            ("attr", "攻击速度", 30),
        ],
        "root_set_attrs": [("攻击", 50), ("物理暴击", 3)],
        "root_set_runtime": [("all_damage_bonus", 0.04)],
    },
    "defense": {
        "template": "static_attr",
        "route_tags": ["survival", "guardian"],
        "root_rows": [("attr", "生命", 100), ("attr", "护甲", 5)],
        "support_rows": [
            ("attr", "格挡", 5),
            ("attr", "生命恢复", 2),
            ("attr", "生命", 200),
        ],
        "root_set_attrs": [("生命", 100), ("护甲", 5)],
        "root_set_runtime": [],
    },
    "resource": {
        "template": "kill_stack",
        "route_tags": ["economy", "growth"],
        "root_rows": [("resource", "gold", 6000), ("runtime", "gold_per_sec_bonus", 15)],
        "support_rows": [
            ("resource", "wood", 150),
            ("runtime", "wood_per_sec_bonus", 0.5),
            ("runtime", "kill_gold_ratio", 0.1),
        ],
        "root_set_attrs": [],
        "root_set_runtime": [("gold_per_sec_bonus", 15), ("wood_per_sec_bonus", 0.5)],
    },
    "control": {
        "template": "basic_attack_modifier",
        "route_tags": ["tempo", "clear"],
        "root_rows": [("attr", "攻击范围", 150), ("runtime", "chain_bounces", 1)],
        "support_rows": [
            ("attr", "技能急速", 5),
            ("attr", "敏捷", 50),
            ("attr", "命中", 20),
        ],
        "root_set_attrs": [("攻击范围", 100), ("技能急速", 5)],
        "root_set_runtime": [("chain_bounces", 1)],
    },
    "survival": {
        "template": "static_attr",
        "route_tags": ["survival", "blessing"],
        "root_rows": [("attr", "生命", 200), ("attr", "生命恢复", 2)],
        "support_rows": [
            ("attr", "护甲", 5),
            ("attr", "格挡", 5),
            ("attr", "生命", 100),
        ],
        "root_set_attrs": [("生命", 200), ("生命恢复", 2)],
        "root_set_runtime": [],
    },
    "fate": {
        "template": "kill_stack",
        "route_tags": ["economy", "boss"],
        "root_rows": [("attr", "命中", 20), ("runtime", "kill_gold_ratio", 0.1)],
        "support_rows": [
            ("attr", "技能急速", 5),
            ("attr", "攻击范围", 50),
            ("runtime", "gold_per_sec_bonus", 15),
        ],
        "root_set_attrs": [("命中", 20), ("技能急速", 5)],
        "root_set_runtime": [("kill_gold_ratio", 0.1)],
    },
    "summon": {
        "template": "per_second_growth",
        "route_tags": ["skill", "arcane"],
        "root_rows": [("attr", "攻击", 50), ("attr", "生命", 100)],
        "support_rows": [
            ("attr", "技能伤害", 5),
            ("attr", "攻击速度", 30),
            ("attr", "命中", 20),
        ],
        "root_set_attrs": [("攻击", 50), ("生命", 100)],
        "root_set_runtime": [("skill_damage_bonus", 0.05)],
    },
}


GROUPS = [
    ("element", "元素师", "rare", "__group_element", 1, 106858, 201385557, "magic", ("元素师", "火纹", "霜印", "雷脉")),
    ("necro", "死灵法师", "epic", "__group_necro", 2, 106720, 201385562, "summon", ("死灵法师", "骨契", "亡语", "冥火")),
    ("paladin", "圣骑士", "rare", "__group_paladin", 3, 106869, 201385564, "defense", ("圣骑士", "圣盾", "祝祷", "誓约")),
    ("assassin", "刺客", "rare", "__group_assassin", 4, 106810, 201385546, "burst", ("刺客", "潜影", "裂喉", "收割")),
    ("warlock", "术士", "epic", "__group_warlock", 5, 107051, 201385555, "burst", ("术士", "诅印", "献祭", "蚀心")),
    ("summoner", "召唤师", "epic", "__group_summoner", 6, 107049, 201385554, "summon", ("召唤师", "唤灵", "图腾", "协战")),
    ("warrior", "战士", "rare", "__group_warrior", 7, 107026, 201385542, "defense", ("战士", "重击", "格挡", "冲阵")),
    ("guardian", "守护者", "rare", "__group_guardian", 8, 106869, 201385564, "defense", ("守护者", "壁垒", "护持", "替伤")),
    ("berserker", "狂战士", "epic", "__group_berserker", 9, 106720, 201385562, "burst", ("狂战士", "血怒", "破限", "残暴")),
    ("hunter", "猎手", "rare", "__group_hunter", 10, 108140, 201385538, "control", ("猎手", "标记", "追踪", "锁喉")),
    ("machinist", "机械师", "epic", "__group_machinist", 11, 106686, 201385547, "summon", ("机械师", "机括", "连装", "炮塔")),
    ("alchemist", "炼金师", "rare", "__group_alchemist", 12, 106694, 201385558, "resource", ("炼金师", "药液", "灌注", "调和")),
    ("witchdoctor", "巫医", "epic", "__group_witchdoctor", 13, 106720, 201385562, "magic", ("巫医", "蛊毒", "瘴气", "咒针")),
    ("shadowwalker", "暗影行者", "epic", "__group_shadowwalker", 14, 106810, 201385546, "burst", ("暗影行者", "匿影", "滑步", "背刺")),
    ("inquisitor", "审判官", "rare", "__group_inquisitor", 15, 106686, 201385547, "burst", ("审判官", "裁定", "圣罚", "净罪")),
    ("priest", "祭司", "rare", "__group_priest", 16, 107362, 201385560, "survival", ("祭司", "祷言", "赐福", "安魂")),
    ("curseblade", "咒刃", "epic", "__group_curseblade", 17, 107049, 201385554, "burst", ("咒刃", "附咒", "裂锋", "铭痕")),
    ("dragonborn", "龙裔", "epic", "__group_dragonborn", 18, 107026, 201385542, "summon", ("龙裔", "龙鳞", "龙息", "龙脉")),
    ("astrologer", "星术师", "epic", "__group_astrologer", 19, 106857, 201385556, "fate", ("星术师", "星轨", "预兆", "天衡")),
    ("illusionist", "幻术师", "epic", "__group_illusionist", 20, 107051, 201385555, "summon", ("幻术师", "镜影", "替身", "复写")),
    ("inferno", "炼狱行者", "epic", "__group_inferno", 21, 106686, 201385547, "magic", ("炼狱行者", "焚痕", "炽羽", "烬潮")),
    ("frost", "冰霜使", "epic", "__group_frost", 22, 107016, 201385553, "control", ("冰霜使", "寒潮", "霜缚", "冻裂")),
    ("thunder", "雷鸣使", "epic", "__group_thunder", 23, 106858, 201385557, "burst", ("雷鸣使", "电弧", "轰击", "麻痹")),
    ("windspeaker", "风语者", "rare", "__group_windspeaker", 24, 106700, 201385550, "control", ("风语者", "轻身", "回风", "迅步")),
    ("runesmith", "符文师", "rare", "__group_runesmith", 25, 107049, 201385554, "fate", ("符文师", "铭刻", "印阵", "叠痕")),
    ("oracle", "先知", "epic", "__group_oracle", 26, 106857, 201385556, "fate", ("先知", "卜算", "回溯", "定数")),
    ("shadowmage", "影法师", "epic", "__group_shadowmage", 27, 107051, 201385555, "magic", ("影法师", "暗蚀", "夺影", "惧纹")),
    ("boneknight", "骸骨骑士", "epic", "__group_boneknight", 28, 106869, 201385564, "defense", ("骸骨骑士", "骨甲", "亡冲", "复躯")),
    ("forge", "炎铸匠", "epic", "__group_forge", 29, 106694, 201385558, "resource", ("炎铸匠", "熔炉", "锻痕", "重铸")),
    ("executor", "天罚者", "epic", "__group_executor", 30, 106686, 201385547, "burst", ("天罚者", "雷裁", "圣断", "终律")),
]


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, headers: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def fmt_attr(name: str, value: object) -> str:
    if name in PERCENT_ATTRS:
        if isinstance(value, (int, float)) and float(value).is_integer():
            return f"{name}+{int(value)}%"
        return f"{name}+{value}%"
    return f"{name}+{value}"


def fmt_runtime(key: str, value: object) -> str:
    if key == "skill_damage_bonus":
        return f"技能伤害+{int(round(float(value) * 100))}%"
    if key == "all_damage_bonus":
        return f"所有伤害+{int(round(float(value) * 100))}%"
    if key == "kill_gold_ratio":
        return f"杀敌金币+{int(round(float(value) * 100))}%"
    if key == "gold_per_sec_bonus":
        return f"每秒金币+{value}"
    if key == "wood_per_sec_bonus":
        return f"每秒木材+{value}"
    if key == "chain_bounces":
        return f"连锁次数+{int(value)}"
    return f"{key}+{value}"


def effect_to_text(effect_kind: str, effect_key: str, value: object) -> str:
    if effect_kind == "attr":
        return fmt_attr(effect_key, value)
    if effect_kind == "runtime":
        return fmt_runtime(effect_key, value)
    if effect_kind == "resource":
        return f"{effect_key}+{value}"
    return f"{effect_key}+{value}"


def main() -> None:
    # Copy the reference CSVs into the live data folder first.
    for name in [
        "bond_group_labels.csv",
        "bond_group_choices.csv",
        "bond_group_choice_paths.csv",
        "bond_root_sets.csv",
    ]:
        shutil.copyfile(DOC / name, DATA / name)

    # Keep the F-candidate group entry enabled for the new 30-group set.
    pick_rules_path = DATA / "bond_pick_rules.csv"
    pick_rows = read_csv(pick_rules_path)
    for row in pick_rows:
        if row.get("key") == "include_group_choices":
            row["value"] = "1"
    write_csv(pick_rules_path, ["key", "value", "notes"], pick_rows)

    root_set_rows = read_csv(DATA / "bond_root_sets.csv")
    root_meta = {row["root_id"]: row for row in root_set_rows}

    node_rows: list[dict[str, object]] = []
    effect_rows: list[dict[str, object]] = []
    root_attr_rows: list[dict[str, object]] = []
    root_runtime_rows: list[dict[str, object]] = []

    for group_id, display_name, quality, choice_id, order_index, icon, editor_skill_id, pattern_name, cards in GROUPS:
        pattern = PATTERNS[pattern_name]
        root_id = f"bond_{group_id}_core"
        line_id = f"line_{group_id}_core"
        root_row = root_meta[root_id]
        root_base_text = root_row["base_text"]
        root_effect_text = root_row["effect_text"]

        root_attr_rows.extend(
            {
                "root_id": root_id,
                "phase": "base",
                "attr_name": attr_name,
                "value": value,
            }
            for attr_name, value in pattern["root_set_attrs"]
        )
        root_runtime_rows.extend(
            {
                "root_id": root_id,
                "phase": "base",
                "runtime_key": runtime_key,
                "value": value,
            }
            for runtime_key, value in pattern["root_set_runtime"]
        )

        rows_for_node = []
        for idx, card_name in enumerate(cards):
            node_id = root_id if idx == 0 else f"{root_id}_{idx}"
            parent_id = "" if idx == 0 else (root_id if idx == 1 else f"{root_id}_{idx - 1}")
            next_ids = "" if idx == len(cards) - 1 else f"{root_id}_{idx + 1}"
            if idx == 0:
                effect_parts = pattern["root_rows"]
                desc_single = root_base_text
            else:
                effect_parts = [pattern["support_rows"][idx - 1]]
                effect_kind, effect_key, value = effect_parts[0]
                desc_single = f"{card_name}：{effect_to_text(effect_kind, effect_key, value)}"
            rows_for_node.append(
                {
                    "id": node_id,
                    "display_name": card_name,
                    "group_id": group_id,
                    "line_id": line_id,
                    "tier": 1,
                    "parent_id": parent_id,
                    "next_ids": next_ids,
                    "route_tags": "|".join(pattern["route_tags"]),
                    "template": pattern["template"],
                    "quality": quality,
                    "icon": icon,
                    "editor_skill_id": editor_skill_id,
                    "unlock_gold": "",
                    "unlock_wood": "",
                    "unlock_exp": "",
                    "desc_single": desc_single,
                    "desc_advanced": root_effect_text,
                }
            )

            for order, (effect_kind, effect_key, value) in enumerate(effect_parts, start=1):
                effect_rows.append(
                    {
                        "source_type": "bond_node",
                        "source_id": node_id,
                        "order_index": order,
                        "effect_kind": effect_kind,
                        "effect_key": effect_key,
                        "value": value,
                    }
                )

        node_rows.extend(rows_for_node)

    write_csv(
        DATA / "bond_nodes.csv",
        [
            "id",
            "display_name",
            "group_id",
            "line_id",
            "tier",
            "parent_id",
            "next_ids",
            "route_tags",
            "template",
            "quality",
            "icon",
            "editor_skill_id",
            "unlock_gold",
            "unlock_wood",
            "unlock_exp",
            "desc_single",
            "desc_advanced",
        ],
        node_rows,
    )

    attreffect_path = DATA / "attreffect.csv"
    merged_effect_rows = []
    if attreffect_path.exists():
        merged_effect_rows.extend(
            row for row in read_csv(attreffect_path) if row.get("source_type") != "bond_node"
        )
    merged_effect_rows.extend(effect_rows)

    write_csv(
        attreffect_path,
        ["source_type", "source_id", "order_index", "effect_kind", "effect_key", "value"],
        merged_effect_rows,
    )

    write_csv(
        DATA / "bond_root_set_attr.csv",
        ["root_id", "phase", "attr_name", "value"],
        root_attr_rows,
    )
    write_csv(
        DATA / "bond_root_set_runtime.csv",
        ["root_id", "phase", "runtime_key", "value"],
        root_runtime_rows,
    )

    print(f"wrote {DATA / 'bond_nodes.csv'}")
    print(f"wrote {attreffect_path}")
    print(f"wrote {DATA / 'bond_root_set_attr.csv'}")
    print(f"wrote {DATA / 'bond_root_set_runtime.csv'}")


if __name__ == "__main__":
    main()

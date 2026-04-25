#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
MAP_PATH = ROOT / "maps" / "EntryMap"
UNIT_DIR = MAP_PATH / "editor_table" / "editorunit"
TEMPLATE_DIR = MAP_PATH / "script" / "y3" / ".codemaker" / "skills" / "y3-obj-gen" / "data_template"

MINION_TEMPLATE = {
    "melee": "近程小怪模板.json",
    "ranged": "远程小怪模板.json",
}

BOSS_TEMPLATE = {
    "melee": "近战boss模板.json",
    "ranged": "远程boss模板.json",
}

MONSTERS = [
    {"id": 200001, "name": "小鬼", "kind": "minion", "combat": "melee", "reward_exp": 10, "reward_gold": 5},
    {"id": 200002, "name": "虚空行者", "kind": "minion", "combat": "melee", "reward_exp": 10, "reward_gold": 5},
    {"id": 200003, "name": "地狱犬", "kind": "minion", "combat": "melee", "reward_exp": 10, "reward_gold": 5},
    {"id": 200004, "name": "眼魔", "kind": "minion", "combat": "ranged", "reward_exp": 10, "reward_gold": 5},
    {"id": 200005, "name": "魁魔", "kind": "minion", "combat": "melee", "reward_exp": 10, "reward_gold": 5},
    {"id": 200006, "name": "恶魔守卫", "kind": "minion", "combat": "melee", "reward_exp": 10, "reward_gold": 5},
    {"id": 200007, "name": "痛苦女王", "kind": "minion", "combat": "ranged", "reward_exp": 10, "reward_gold": 5},
    {"id": 200008, "name": "恶魔术士", "kind": "minion", "combat": "ranged", "reward_exp": 10, "reward_gold": 5},
    {"id": 400001, "name": "地狱火", "kind": "boss", "combat": "melee", "reward_exp": 200, "reward_gold": 100},
    {"id": 400002, "name": "末日守卫", "kind": "boss", "combat": "melee", "reward_exp": 200, "reward_gold": 100},
    {"id": 400003, "name": "魔犬", "kind": "boss", "combat": "melee", "reward_exp": 200, "reward_gold": 100},
    {"id": 400004, "name": "古尔丹", "kind": "boss", "combat": "ranged", "reward_exp": 200, "reward_gold": 100},
    {"id": 400005, "name": "辛辛诺斯", "kind": "boss", "combat": "melee", "reward_exp": 200, "reward_gold": 100},
    {"id": 400006, "name": "卡扎克", "kind": "boss", "combat": "ranged", "reward_exp": 200, "reward_gold": 100},
    {"id": 400007, "name": "提克迪奥斯", "kind": "boss", "combat": "melee", "reward_exp": 200, "reward_gold": 100},
    {"id": 400008, "name": "玛诺洛斯", "kind": "boss", "combat": "melee", "reward_exp": 200, "reward_gold": 100},
]


def murmur3_hash(text, seed=0):
    key = bytearray(text.encode("utf-8"))

    def fmix(value):
        value ^= value >> 16
        value = (value * 0x85EBCA6B) & 0xFFFFFFFF
        value ^= value >> 13
        value = (value * 0xC2B2AE35) & 0xFFFFFFFF
        value ^= value >> 16
        return value

    length = len(key)
    h1 = seed
    c1 = 0xCC9E2D51
    c2 = 0x1B873593
    nblocks = length // 4

    for index in range(0, nblocks * 4, 4):
        k1 = (
            (key[index + 3] << 24)
            | (key[index + 2] << 16)
            | (key[index + 1] << 8)
            | key[index]
        )
        k1 = (k1 * c1) & 0xFFFFFFFF
        k1 = ((k1 << 15) | (k1 >> 17)) & 0xFFFFFFFF
        k1 = (k1 * c2) & 0xFFFFFFFF

        h1 ^= k1
        h1 = ((h1 << 13) | (h1 >> 19)) & 0xFFFFFFFF
        h1 = (h1 * 5 + 0xE6546B64) & 0xFFFFFFFF

    tail_index = nblocks * 4
    k1 = 0
    tail_size = length & 3
    if tail_size >= 3:
        k1 ^= key[tail_index + 2] << 16
    if tail_size >= 2:
        k1 ^= key[tail_index + 1] << 8
    if tail_size >= 1:
        k1 ^= key[tail_index]
        k1 = (k1 * c1) & 0xFFFFFFFF
        k1 = ((k1 << 15) | (k1 >> 17)) & 0xFFFFFFFF
        k1 = (k1 * c2) & 0xFFFFFFFF
        h1 ^= k1

    h1 ^= length
    h1 = fmix(h1)
    if h1 >= 0x80000000:
        h1 -= 0x100000000
    return h1


def load_json(path):
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_json(path, data):
    with path.open("w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=4)
        file.write("\n")


def template_name(defn):
    if defn["kind"] == "boss":
        return BOSS_TEMPLATE[defn["combat"]]
    return MINION_TEMPLATE[defn["combat"]]


def rebuild_one(defn):
    unit_path = UNIT_DIR / f"{defn['id']}.json"
    existing = load_json(unit_path)
    template = load_json(TEMPLATE_DIR / template_name(defn))
    data = deepcopy(template)

    name_tid = murmur3_hash(defn["name"])

    data["key"] = defn["id"]
    data["uid"] = str(defn["id"])
    data["name"] = name_tid
    data["description"] = name_tid

    for field in [
        "_ref_",
        "model",
        "icon",
        "mini_map_icon",
        "attack_range",
        "attack_phy",
        "hp_max",
        "ori_speed",
        "dead_exp",
        "dead_money",
        "level",
        "content",
        "main_attr",
        "common_atk",
        "common_atk_type",
        "simple_common_atk",
    ]:
        if field in existing:
            data[field] = deepcopy(existing[field])

    data["reward_exp"] = defn["reward_exp"]
    data["reward_official_res_1"] = defn["reward_gold"]

    save_json(unit_path, data)
    return name_tid


def main():
    results = []
    for monster in MONSTERS:
        tid = rebuild_one(monster)
        results.append((monster["id"], monster["name"], tid))

    for unit_id, name, tid in results:
        print(f"{unit_id}: {name} -> {tid}")


if __name__ == "__main__":
    main()

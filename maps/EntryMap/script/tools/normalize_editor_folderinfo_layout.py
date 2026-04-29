#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOLDERINFO_PROJECTILE = ROOT / "editor" / "folderinfo" / "folderinfo_projectile_all.json"
FOLDERINFO_ITEM = ROOT / "editor" / "folderinfo" / "folderinfo_editor_item.json"

PROJECTILE_ROOT_UID = "AtkProjRoot20260418"
PROJECTILE_ROOT_NAME = "技能投射物"
PROJECTILE_SKILL_FOLDERS = [
    (134267104, "AtkProjBasic20260418", "普攻投射物"),
    (201364743, "AtkProjSwordWave20260418", "剑气投射物"),
    (134255909, "AtkProjArcaneLaser20260418", "奥术光束"),
    (134264830, "AtkProjArcaneRay20260418", "奥术射线"),
    (134254402, "AtkProjFrostNova20260418", "寒霜爆裂"),
    (134278613, "AtkProjChainLightning20260418", "连锁闪电"),
    (201364744, "AtkProjEarthquake20260418", "大地震击"),
    (201364745, "AtkProjTornado20260418", "风暴龙卷"),
    (201364746, "AtkProjElectroNet20260418", "雷网禁锢"),
    (201364747, "AtkProjMeteor20260418", "陨星坠落"),
    (201364748, "AtkProjHurricane20260418", "飓风穿刺"),
    (201364749, "AtkProjFireball20260418", "火球爆裂"),
    (201364750, "AtkProjMoonBlade20260418", "月刃回旋"),
    (201364751, "AtkProjLotusFlame20260418", "莲火绽放"),
    (201364752, "AtkProjDemonSeal20260418", "镇魔封印"),
    (201364753, "AtkProjFlyingSwords20260418", "飞剑穿梭"),
]

ITEM_ROOT_UID = "entry_runtime_item_root"
TREASURE_ITEM_IDS = [201390200 + index for index in range(1, 23)]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def tuple_entry(items: list) -> dict:
    return {"__tuple__": True, "items": items}


def ensure_projectile_layout() -> None:
    data = load_json(FOLDERINFO_PROJECTILE)
    folders = data.setdefault("f", [])
    mappings = data.setdefault("d", {})

    folder_by_uid = {}
    for entry in folders:
        if isinstance(entry, dict) and entry.get("__tuple__") is True:
            items = entry.get("items", [])
            if isinstance(items, list) and len(items) >= 3:
                folder_by_uid[items[2]] = entry

    root_folder = folder_by_uid.get(PROJECTILE_ROOT_UID)
    if root_folder is None:
        root_folder = tuple_entry(["/2147483647", 0, PROJECTILE_ROOT_UID, PROJECTILE_ROOT_NAME])
        folders.append(root_folder)
    else:
        root_folder["items"][0] = "/2147483647"
        root_folder["items"][1] = 0
        root_folder["items"][2] = PROJECTILE_ROOT_UID
        root_folder["items"][3] = PROJECTILE_ROOT_NAME

    for order, (projectile_id, folder_uid, folder_name) in enumerate(PROJECTILE_SKILL_FOLDERS):
        folder_entry = folder_by_uid.get(folder_uid)
        if folder_entry is None:
            folder_entry = tuple_entry([f"/2147483647/{PROJECTILE_ROOT_UID}", order, folder_uid, folder_name])
            folders.append(folder_entry)
            folder_by_uid[folder_uid] = folder_entry
        else:
            folder_entry["items"][0] = f"/2147483647/{PROJECTILE_ROOT_UID}"
            folder_entry["items"][1] = order
            folder_entry["items"][2] = folder_uid
            folder_entry["items"][3] = folder_name

        mappings[str(projectile_id)] = tuple_entry([folder_uid, 0])

    dump_json(FOLDERINFO_PROJECTILE, data)


def ensure_item_layout() -> None:
    data = load_json(FOLDERINFO_ITEM)
    folders = data.setdefault("f", [])
    mappings = data.setdefault("d", {})

    folder_by_uid = {}
    for entry in folders:
        if isinstance(entry, dict) and entry.get("__tuple__") is True:
            items = entry.get("items", [])
            if isinstance(items, list) and len(items) >= 3:
                folder_by_uid[items[2]] = entry

    root_folder = folder_by_uid.get(ITEM_ROOT_UID)
    if root_folder is None:
        root_folder = tuple_entry(["/2147483647", 3, ITEM_ROOT_UID, "EntryRuntime道具"])
        folders.append(root_folder)
    else:
        root_folder["items"][0] = "/2147483647"
        root_folder["items"][1] = 3
        root_folder["items"][2] = ITEM_ROOT_UID
        root_folder["items"][3] = "EntryRuntime道具"

    for order, item_id in enumerate(TREASURE_ITEM_IDS):
        mappings[str(item_id)] = tuple_entry([ITEM_ROOT_UID, order])

    dump_json(FOLDERINFO_ITEM, data)


def main() -> None:
    ensure_projectile_layout()
    ensure_item_layout()
    print("folderinfo layout normalized")


if __name__ == "__main__":
    main()

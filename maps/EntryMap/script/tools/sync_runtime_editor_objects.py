#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import csv
import json
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EDITOR_TABLE = ROOT / "editor_table"
ABILITY_DIR = EDITOR_TABLE / "abilityall"
MODIFIER_DIR = EDITOR_TABLE / "modifierall"
LANGUAGE_PATH = ROOT / "zhlanguage.json"
ABILITY_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_ability_all.json"
MODIFIER_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_modifier_all.json"
REGISTRY_PATH = ROOT / "script" / "data" / "object_tables" / "runtime_editor_ids.lua"

ATTACK_SKILLS_CSV = ROOT / "script" / "data_csv" / "attack_skills.csv"
SECOND_BATCH_SKILLS_CSV = ROOT / "script" / "data_csv" / "attack_skill_second_batch_skills.csv"

ABILITY_TEMPLATE_PATH = ABILITY_DIR / "201385537.json"
BUFF_TEMPLATE_PATH = MODIFIER_DIR / "201365013.json"
DEBUFF_TEMPLATE_PATH = MODIFIER_DIR / "201362637.json"
FIGHTING_SPIRIT_TEMPLATE_PATH = MODIFIER_DIR / "201365014.json"

DEFAULT_ABILITY_ICON = 100127

ATTACK_SKILL_ID_ORDER = [
    "basic_attack",
    "sword_wave",
    "arcane_laser",
    "arcane_ray",
    "frost_nova",
    "chain_lightning",
    "earthquake",
    "tornado",
    "electro_net",
    "meteor",
    "hurricane",
    "fireball",
    "moon_blade",
    "lotus_flame",
    "demon_seal",
    "flying_swords",
]

ATTACK_SKILL_EDITOR_IDS = {
    "basic_attack": 201390001,
    "sword_wave": 201390002,
    "arcane_laser": 201390003,
    "arcane_ray": 201390004,
    "frost_nova": 201390005,
    "chain_lightning": 201390006,
    "earthquake": 201390007,
    "tornado": 201390008,
    "electro_net": 201390009,
    "meteor": 201390010,
    "hurricane": 201390011,
    "fireball": 201390012,
    "moon_blade": 201390013,
    "lotus_flame": 201390014,
    "demon_seal": 201390015,
    "flying_swords": 201390016,
}

MODIFIER_EDITOR_IDS = {
    "ignite": 201390101,
    "armor_break": 201390102,
    "shock": 201390103,
    "rapid_overdrive": 201390104,
    "charge_breaker_rally": 201390105,
    "fighting_spirit_field": 201365014,
}

ABILITY_FOLDER_UIDS = {
    "root": "entry_runtime_skill_root",
    "basic": "entry_runtime_skill_basic",
    "attack": "entry_runtime_skill_attack",
}

MODIFIER_FOLDER_UIDS = {
    "root": "entry_runtime_modifier_root",
    "attack_status": "entry_runtime_modifier_attack_status",
    "auto_buff": "entry_runtime_modifier_auto_buff",
    "auto_debuff": "entry_runtime_modifier_auto_debuff",
}

MODIFIER_DEFINITIONS = [
    {
        "id": "ignite",
        "name": "灼烧",
        "description": "持续灼烧目标，每秒造成基于攻击力的额外伤害。",
        "icon": 106978,
        "folder": "attack_status",
        "template": "debuff",
    },
    {
        "id": "armor_break",
        "name": "破甲",
        "description": "护甲被削弱，受到的伤害提高，并可叠加层数。",
        "icon": 106990,
        "folder": "attack_status",
        "template": "debuff",
    },
    {
        "id": "shock",
        "name": "感电",
        "description": "目标处于感电状态时，会承受更高的后续伤害。",
        "icon": 106859,
        "folder": "attack_status",
        "template": "debuff",
    },
    {
        "id": "rapid_overdrive",
        "name": "高速超载",
        "description": "短时间内大幅提升攻击速度。",
        "icon": 107004,
        "folder": "auto_buff",
        "template": "buff",
    },
    {
        "id": "charge_breaker_rally",
        "name": "破阵集结",
        "description": "击杀后获得短时间的全属性、攻速与技能急速增益。",
        "icon": 107026,
        "folder": "auto_buff",
        "template": "buff",
    },
    {
        "id": "fighting_spirit_field",
        "name": "斗气场域",
        "description": "持续削弱周围敌人的护甲与攻击力。",
        "icon": 100859,
        "folder": "auto_debuff",
        "template": "fighting_spirit",
    },
]


def xencode(text):
    if isinstance(text, bytes):
        return text
    return text.encode("utf-8")


def murmur3_hash(key, seed=0):
    key = bytearray(xencode(key))

    def fmix(value):
        value ^= value >> 16
        value = (value * 0x85EBCA6B) & 0xFFFFFFFF
        value ^= value >> 13
        value = (value * 0xC2B2AE35) & 0xFFFFFFFF
        value ^= value >> 16
        return value

    length = len(key)
    nblocks = length // 4
    h1 = seed
    c1 = 0xCC9E2D51
    c2 = 0x1B873593

    for block_start in range(0, nblocks * 4, 4):
        k1 = (
            (key[block_start + 3] << 24)
            | (key[block_start + 2] << 16)
            | (key[block_start + 1] << 8)
            | key[block_start + 0]
        )
        k1 = (c1 * k1) & 0xFFFFFFFF
        k1 = ((k1 << 15) | (k1 >> 17)) & 0xFFFFFFFF
        k1 = (c2 * k1) & 0xFFFFFFFF

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
        k1 ^= key[tail_index + 0]
    if tail_size > 0:
        k1 = (k1 * c1) & 0xFFFFFFFF
        k1 = ((k1 << 15) | (k1 >> 17)) & 0xFFFFFFFF
        k1 = (k1 * c2) & 0xFFFFFFFF
        h1 ^= k1

    unsigned_val = fmix(h1 ^ length)
    if unsigned_val & 0x80000000 == 0:
        return unsigned_val
    return -((unsigned_val ^ 0xFFFFFFFF) + 1)


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, payload):
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=4) + "\n",
        encoding="utf-8",
    )


def make_tuple(items):
    return {"__tuple__": True, "items": items}


def scalar_text(value):
    number = float(value)
    if number.is_integer():
        return str(int(number))
    return f"{number:.2f}".rstrip("0").rstrip(".")


def optional_number(raw, fallback=0):
    if raw in (None, ""):
        return fallback
    try:
        return float(raw)
    except ValueError:
        return fallback


def read_csv_rows(path):
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def build_attack_skill_defs():
    by_id = {}

    for row in read_csv_rows(ATTACK_SKILLS_CSV):
        skill_id = row["id"]
        by_id[skill_id] = {
            "id": skill_id,
            "name": row["name"],
            "summary": row["summary"],
            "damage_ratio": optional_number(row.get("base_damage_ratio")),
            "cooldown": optional_number(row.get("base_cooldown")),
            "range": optional_number(row.get("base_range")),
            "pierce": optional_number(row.get("base_pierce")),
            "duration": optional_number(row.get("base_control_lock_time")),
            "radius": optional_number(row.get("base_explosion_radius")),
            "bounce": optional_number(row.get("base_extra_targets")),
            "icon": DEFAULT_ABILITY_ICON,
        }

    for row in read_csv_rows(SECOND_BATCH_SKILLS_CSV):
        skill_id = row["id"]
        by_id[skill_id] = {
            "id": skill_id,
            "name": row["name"],
            "summary": row["summary"],
            "damage_ratio": optional_number(row.get("damage_ratio")),
            "cooldown": optional_number(row.get("cooldown")),
            "range": optional_number(row.get("range")),
            "pierce": optional_number(row.get("pierce")),
            "duration": optional_number(row.get("duration")),
            "radius": optional_number(row.get("radius")),
            "bounce": optional_number(row.get("bounce")),
            "icon": int(optional_number(row.get("ui_icon"), DEFAULT_ABILITY_ICON)),
        }

    result = []
    for skill_id in ATTACK_SKILL_ID_ORDER:
        if skill_id not in by_id:
            raise KeyError(f"missing attack skill config: {skill_id}")
        result.append(by_id[skill_id])
    return result


def build_attack_skill_description(skill):
    lines = [skill["summary"]]
    lines.append(f"伤害倍率：{int(round(skill['damage_ratio'] * 100))}%")
    if skill["cooldown"] > 0:
        lines.append(f"冷却：{scalar_text(skill['cooldown'])}秒")
    if skill["range"] > 0:
        lines.append(f"射程：{int(round(skill['range']))}")
    if skill["radius"] > 0:
        lines.append(f"作用半径：{int(round(skill['radius']))}")
    if skill["duration"] > 0:
        lines.append(f"持续时间：{scalar_text(skill['duration'])}秒")
    if skill["pierce"] > 0:
        lines.append(f"穿透：{int(round(skill['pierce']))}")
    if skill["bounce"] > 0:
        lines.append(f"额外目标：{int(round(skill['bounce']))}")
    return "\n".join(lines)


def build_language_entry_key(namespace, obj_id, suffix):
    return murmur3_hash(f"{namespace}::{obj_id}::{suffix}")


def generate_ability_files(skills):
    template = load_json(ABILITY_TEMPLATE_PATH)
    pending_language = {}
    assignments = []
    attack_order = 0

    for skill in skills:
        ability_id = ATTACK_SKILL_EDITOR_IDS[skill["id"]]
        data = deepcopy(template)
        data["key"] = ability_id
        data["uid"] = str(ability_id)
        data["ability_icon"] = skill["icon"] or DEFAULT_ABILITY_ICON
        data["cold_down_time"] = make_tuple([scalar_text(skill["cooldown"])])
        data["ability_cost"] = make_tuple(["0"])
        data["ability_damage"] = make_tuple(["0"])
        data["kv"] = {}

        name_tid = build_language_entry_key("EntryRuntimeAbility", ability_id, "name")
        desc_tid = build_language_entry_key("EntryRuntimeAbility", ability_id, "desc")
        data["name"] = name_tid
        data["description"] = desc_tid
        pending_language[str(name_tid)] = skill["name"]
        pending_language[str(desc_tid)] = build_attack_skill_description(skill)

        ability_path = ABILITY_DIR / f"{ability_id}.json"
        write_json(ability_path, data)

        if skill["id"] == "basic_attack":
            assignments.append((ability_id, ABILITY_FOLDER_UIDS["basic"], 0))
        else:
            assignments.append((ability_id, ABILITY_FOLDER_UIDS["attack"], attack_order))
            attack_order += 1

    return pending_language, assignments


def apply_modifier_common(data, modifier_id, name, description, icon):
    name_tid = build_language_entry_key("EntryRuntimeModifier", modifier_id, "name")
    desc_tid = build_language_entry_key("EntryRuntimeModifier", modifier_id, "desc")
    data["key"] = modifier_id
    data["uid"] = str(modifier_id)
    data["name"] = name_tid
    data["description"] = desc_tid
    data["modifier_icon"] = icon
    data["kv"] = {}
    return {
        str(name_tid): name,
        str(desc_tid): description,
    }


def generate_modifier_files():
    buff_template = load_json(BUFF_TEMPLATE_PATH)
    debuff_template = load_json(DEBUFF_TEMPLATE_PATH)
    fighting_spirit_template = load_json(FIGHTING_SPIRIT_TEMPLATE_PATH)

    pending_language = {}
    assignments = []
    folder_order = {
        "attack_status": 0,
        "auto_buff": 0,
        "auto_debuff": 0,
    }

    for definition in MODIFIER_DEFINITIONS:
        modifier_id = MODIFIER_EDITOR_IDS[definition["id"]]

        if definition["template"] == "buff":
            data = deepcopy(buff_template)
            data["show_on_ui"] = True
            data["attach_model_list"] = ""
        elif definition["template"] == "fighting_spirit":
            data = deepcopy(fighting_spirit_template)
        else:
            data = deepcopy(debuff_template)

        pending_language.update(
            apply_modifier_common(
                data,
                modifier_id,
                definition["name"],
                definition["description"],
                definition["icon"],
            )
        )

        modifier_path = MODIFIER_DIR / f"{modifier_id}.json"
        write_json(modifier_path, data)

        folder_key = definition["folder"]
        assignments.append((modifier_id, MODIFIER_FOLDER_UIDS[folder_key], folder_order[folder_key]))
        folder_order[folder_key] += 1

    return pending_language, assignments


def append_language_entries(path, original_text, pending_entries):
    if not pending_entries:
        return

    text = original_text.rstrip("\r\n")
    body, _ = text.rsplit("\n", 1)
    last_line_index = body.rfind("\n")
    if last_line_index >= 0:
        prefix = body[: last_line_index + 1]
        last_line = body[last_line_index + 1 :]
    else:
        prefix = ""
        last_line = body

    if not last_line.rstrip().endswith(","):
        last_line = f"{last_line}, "

    appended_lines = []
    items = list(pending_entries.items())
    for index, (key, value) in enumerate(items):
        line = f"    {json.dumps(key, ensure_ascii=True)}: {json.dumps(value, ensure_ascii=True)}"
        if index < len(items) - 1:
            line += ", "
        appended_lines.append(line)

    new_text = prefix + last_line + "\n" + "\n".join(appended_lines) + "\n}\n"
    path.write_text(new_text, encoding="utf-8")


def sync_language(pending_entries):
    original_text = LANGUAGE_PATH.read_text(encoding="utf-8")
    language = json.loads(original_text)
    pending_append = {}
    needs_full_dump = False

    for key, value in pending_entries.items():
        current = language.get(key)
        if current == value:
            continue
        if current is not None and current != value:
            needs_full_dump = True
        language[key] = value
        pending_append[key] = value

    if not pending_append:
        return 0

    if needs_full_dump:
        LANGUAGE_PATH.write_text(
            json.dumps(language, ensure_ascii=False, indent=4) + "\n",
            encoding="utf-8",
        )
    else:
        append_language_entries(LANGUAGE_PATH, original_text, pending_append)
    return len(pending_append)


def make_folder_tuple(parent_path, order, uid, name):
    return {"__tuple__": True, "items": [parent_path, order, uid, name]}


def current_max_order(folderinfo, parent_path):
    max_order = -1
    for item in folderinfo.get("f", []):
        items = item.get("items", [])
        if len(items) >= 4 and items[0] == parent_path:
            max_order = max(max_order, int(items[1]))
    return max_order


def upsert_folder(folderinfo, parent_path, uid, name, default_order):
    for entry in folderinfo.get("f", []):
        items = entry.get("items", [])
        if len(items) >= 4 and items[2] == uid:
            items[0] = parent_path
            items[3] = name
            return

    folderinfo.setdefault("f", []).append(make_folder_tuple(parent_path, default_order, uid, name))


def sync_folderinfo(path, folder_specs, assignments):
    folderinfo = load_json(path)

    for spec in folder_specs:
        if spec["parent_path"] == "/2147483647":
            order = current_max_order(folderinfo, "/2147483647") + 1
        else:
            order = spec["order"]
        upsert_folder(folderinfo, spec["parent_path"], spec["uid"], spec["name"], order)

    folder_map = folderinfo.setdefault("d", {})
    for object_id, folder_uid, order in assignments:
        folder_map[str(object_id)] = {"__tuple__": True, "items": [folder_uid, order]}

    write_json(path, folderinfo)


def write_registry():
    lines = [
        "return {",
        "  ability = {",
    ]

    for skill_id in ATTACK_SKILL_ID_ORDER:
        lines.append(f"    {skill_id} = {ATTACK_SKILL_EDITOR_IDS[skill_id]},")

    lines.extend(
        [
            "  },",
            "  modifier = {",
            "    attack_status = {",
            f"      ignite = {MODIFIER_EDITOR_IDS['ignite']},",
            f"      armor_break = {MODIFIER_EDITOR_IDS['armor_break']},",
            f"      shock = {MODIFIER_EDITOR_IDS['shock']},",
            "    },",
            "    auto_active_effect = {",
            f"      rapid_overdrive = {MODIFIER_EDITOR_IDS['rapid_overdrive']},",
            f"      charge_breaker_rally = {MODIFIER_EDITOR_IDS['charge_breaker_rally']},",
            f"      fighting_spirit_field = {MODIFIER_EDITOR_IDS['fighting_spirit_field']},",
            "    },",
            "  },",
            "}",
            "",
        ]
    )

    REGISTRY_PATH.write_text("\n".join(lines), encoding="utf-8")


def main():
    skills = build_attack_skill_defs()

    ability_language, ability_assignments = generate_ability_files(skills)
    modifier_language, modifier_assignments = generate_modifier_files()

    language_count = sync_language({**ability_language, **modifier_language})

    sync_folderinfo(
        ABILITY_FOLDERINFO_PATH,
        [
            {
                "uid": ABILITY_FOLDER_UIDS["root"],
                "parent_path": "/2147483647",
                "name": "EntryRuntime技能",
                "order": 0,
            },
            {
                "uid": ABILITY_FOLDER_UIDS["basic"],
                "parent_path": f"/2147483647/{ABILITY_FOLDER_UIDS['root']}",
                "name": "基础攻击",
                "order": 0,
            },
            {
                "uid": ABILITY_FOLDER_UIDS["attack"],
                "parent_path": f"/2147483647/{ABILITY_FOLDER_UIDS['root']}",
                "name": "攻击技能",
                "order": 1,
            },
        ],
        ability_assignments,
    )

    sync_folderinfo(
        MODIFIER_FOLDERINFO_PATH,
        [
            {
                "uid": MODIFIER_FOLDER_UIDS["root"],
                "parent_path": "/2147483647",
                "name": "EntryRuntime魔法效果",
                "order": 0,
            },
            {
                "uid": MODIFIER_FOLDER_UIDS["attack_status"],
                "parent_path": f"/2147483647/{MODIFIER_FOLDER_UIDS['root']}",
                "name": "攻击状态",
                "order": 0,
            },
            {
                "uid": MODIFIER_FOLDER_UIDS["auto_buff"],
                "parent_path": f"/2147483647/{MODIFIER_FOLDER_UIDS['root']}",
                "name": "自动效果-增益",
                "order": 1,
            },
            {
                "uid": MODIFIER_FOLDER_UIDS["auto_debuff"],
                "parent_path": f"/2147483647/{MODIFIER_FOLDER_UIDS['root']}",
                "name": "自动效果-减益",
                "order": 2,
            },
        ],
        modifier_assignments,
    )

    write_registry()

    print(
        "synced runtime editor objects: "
        f"{len(skills)} abilities, "
        f"{len(MODIFIER_DEFINITIONS)} modifiers, "
        f"{language_count} language entries"
    )


if __name__ == "__main__":
    main()

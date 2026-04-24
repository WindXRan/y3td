#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import csv
import html
import json
import re
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EDITOR_TABLE = ROOT / "editor_table"
ABILITY_DIR = EDITOR_TABLE / "abilityall"
ITEM_DIR = EDITOR_TABLE / "editoritem"
MODIFIER_DIR = EDITOR_TABLE / "modifierall"
PROJECTILE_DIR = EDITOR_TABLE / "projectileall"
LANGUAGE_PATH = ROOT / "zhlanguage.json"
ABILITY_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_ability_all.json"
ITEM_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_editor_item.json"
MODIFIER_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_modifier_all.json"
PROJECTILE_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_projectile_all.json"
REGISTRY_PATH = ROOT / "script" / "data" / "object_tables" / "runtime_editor_ids.lua"
EQUIPMENT_CATALOG_PATH = ROOT / "script" / "data" / "object_tables" / "equipment_catalog.lua"

ATTACK_SKILLS_CSV = ROOT / "script" / "data_csv" / "attack_skills.csv"
ATTACK_SKILL_VFX_CSV = ROOT / "script" / "data_csv" / "attack_skill_vfx.csv"
SECOND_BATCH_SKILLS_CSV = ROOT / "script" / "data_csv" / "attack_skill_second_batch_skills.csv"
SECOND_BATCH_EVOLUTIONS_CSV = ROOT / "script" / "data_csv" / "attack_skill_second_batch_evolutions.csv"
TREASURES_CSV = ROOT / "script" / "data_csv" / "treasures.csv"
TREASURE_EFFECTS_CSV = ROOT / "script" / "data_csv" / "treasure_effects.csv"
TREASURE_SETS_CSV = ROOT / "script" / "data_csv" / "treasure_sets.csv"
TREASURE_SET_MEMBERS_CSV = ROOT / "script" / "data_csv" / "treasure_set_members.csv"
TREASURE_SET_EFFECTS_CSV = ROOT / "script" / "data_csv" / "treasure_set_effects.csv"
TREASURE_COMPAT_RARITY_MAP_CSV = ROOT / "script" / "data_csv" / "treasure_compat_rarity_map.csv"
TREASURE_COMPAT_RUNTIME_KEY_MAP_CSV = ROOT / "script" / "data_csv" / "treasure_compat_runtime_key_map.csv"
TREASURE_COMPAT_TAG_RULES_CSV = ROOT / "script" / "data_csv" / "treasure_compat_tag_rules.csv"
TREASURE_COMPAT_DURATION_RULES_CSV = ROOT / "script" / "data_csv" / "treasure_compat_duration_rules.csv"

ABILITY_TEMPLATE_PATH = ABILITY_DIR / "201385537.json"
ITEM_TEMPLATE_PATH = ITEM_DIR / "201390001.json"
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

ABILITY_FOLDER_UIDS = {"root": "entry_runtime_skill_root"}
ITEM_FOLDER_UIDS = {"root": "entry_runtime_item_root"}

PROJECTILE_EDITOR_IDS = {
    "basic_attack": 134267104,
    "sword_wave": 201364743,
    "arcane_laser": 134255909,
    "arcane_ray": 134264830,
    "frost_nova": 134254402,
    "chain_lightning": 134278613,
    "earthquake": 201364744,
    "tornado": 201364745,
    "electro_net": 201364746,
    "meteor": 201364747,
    "hurricane": 201364748,
    "fireball": 201364749,
    "moon_blade": 201364750,
    "lotus_flame": 201364751,
    "demon_seal": 201364752,
    "flying_swords": 201364753,
}

PROJECTILE_FOLDER_UIDS = {
    "root": "AtkProjRoot20260418",
    "basic_attack": "AtkProjBasic20260418",
    "sword_wave": "AtkProjSwordWave20260418",
    "arcane_laser": "AtkProjArcaneLaser20260418",
    "arcane_ray": "AtkProjArcaneRay20260418",
    "frost_nova": "AtkProjFrostNova20260418",
    "chain_lightning": "AtkProjChainLightning20260418",
    "earthquake": "AtkProjEarthquake20260418",
    "tornado": "AtkProjTornado20260418",
    "electro_net": "AtkProjElectroNet20260418",
    "meteor": "AtkProjMeteor20260418",
    "hurricane": "AtkProjHurricane20260418",
    "fireball": "AtkProjFireball20260418",
    "moon_blade": "AtkProjMoonBlade20260418",
    "lotus_flame": "AtkProjLotusFlame20260418",
    "demon_seal": "AtkProjDemonSeal20260418",
    "flying_swords": "AtkProjFlyingSwords20260418",
}

MODIFIER_FOLDER_UIDS = {
    "root": "entry_runtime_modifier_root",
    "attack_status": "entry_runtime_modifier_attack_status",
    "auto_buff": "entry_runtime_modifier_auto_buff",
    "auto_debuff": "entry_runtime_modifier_auto_debuff",
}

TREASURE_EDITOR_ID_BASE = 201390200
TREASURE_QUALITY_BY_RARITY = {
    "normal": "common",
    "rare": "rare",
    "epic": "epic",
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

VISUAL_STAGES = ("cast", "impact", "explosion", "charge", "chain")
VISUAL_STAGE_LABELS = {
    "cast": "起手",
    "impact": "命中",
    "explosion": "爆炸",
    "charge": "蓄力",
    "chain": "连锁",
}
ABILITY_VISIBLE_STAGE_FIELD_MAP = {
    "cast": ("cst_sfx_list", "origin"),
    "impact": ("hit_sfx_list", "origin"),
    "explosion": ("end_sfx_list", "origin"),
    "charge": ("sp_sfx_list", "origin"),
    "chain": ("bs_sfx_list", "origin"),
}
ABILITY_VISUAL_KV_KEYS = tuple(
    key
    for stage in VISUAL_STAGES
    for key in (
        f"entry_{stage}_effect_id",
        f"entry_{stage}_scale",
        f"entry_{stage}_time",
    )
)
PROJECTILE_VISUAL_KV_KEYS = (
    "entry_projectile_speed",
    "entry_projectile_time",
    "entry_target_distance",
    "entry_strike_delay",
)

ATTACK_SKILL_TAXONOMY = {
    "basic_attack": {
        "category": "弓箭普攻",
        "cast_family": "basic_projectile",
        "presentation_family": "eca_projectile_hit",
        "eca_reference": "弓箭普攻/箭矢命中",
        "tactical_tags": ["single", "projectile", "basic_attack", "archery", "arrow"],
    },
    "sword_wave": {
        "category": "直线贯穿",
        "cast_family": "line_pierce",
        "presentation_family": "eca_line_pierce",
        "eca_reference": "直线穿透型技能",
        "tactical_tags": ["line", "pierce", "clear"],
    },
    "arcane_laser": {
        "category": "持续照射",
        "cast_family": "beam",
        "presentation_family": "eca_beam_tick",
        "eca_reference": "持续照射型技能",
        "tactical_tags": ["beam", "sustain", "aoe"],
    },
    "arcane_ray": {
        "category": "长线爆发",
        "cast_family": "line_pierce",
        "presentation_family": "eca_line_pierce",
        "eca_reference": "长线穿透爆发",
        "tactical_tags": ["line", "burst", "pierce"],
    },
    "frost_nova": {
        "category": "近身爆发",
        "cast_family": "nova",
        "presentation_family": "eca_nova_burst",
        "eca_reference": "以自身为心范围爆发",
        "tactical_tags": ["nova", "aoe", "control"],
    },
    "chain_lightning": {
        "category": "连锁弹射",
        "cast_family": "chain",
        "presentation_family": "eca_chain_hit",
        "eca_reference": "命中后链式扩散",
        "tactical_tags": ["chain", "bounce", "clear"],
    },
    "earthquake": {
        "category": "区域爆发",
        "cast_family": "area_burst",
        "presentation_family": "eca_ground_burst",
        "eca_reference": "区域落点爆发",
        "tactical_tags": ["aoe", "burst", "ground"],
    },
    "tornado": {
        "category": "移动场域",
        "cast_family": "moving_field",
        "presentation_family": "eca_moving_field",
        "eca_reference": "持续移动切割场",
        "tactical_tags": ["field", "moving", "pull"],
    },
    "electro_net": {
        "category": "控制场域",
        "cast_family": "control_field",
        "presentation_family": "eca_control_field",
        "eca_reference": "区域束缚控制场",
        "tactical_tags": ["field", "control", "aoe"],
    },
    "meteor": {
        "category": "延迟终结",
        "cast_family": "delayed_area_burst",
        "presentation_family": "eca_charge_burst",
        "eca_reference": "蓄力后高爆发落点",
        "tactical_tags": ["delayed", "burst", "aoe"],
    },
    "hurricane": {
        "category": "聚怪场域",
        "cast_family": "persistent_field",
        "presentation_family": "eca_persistent_field",
        "eca_reference": "持续聚怪切割场",
        "tactical_tags": ["field", "pull", "sustain"],
    },
    "fireball": {
        "category": "点爆炸裂",
        "cast_family": "area_burst",
        "presentation_family": "eca_ground_burst",
        "eca_reference": "点面兼顾爆炸",
        "tactical_tags": ["burst", "aoe", "fire"],
    },
    "moon_blade": {
        "category": "往返轮斩",
        "cast_family": "line_return",
        "presentation_family": "eca_return_blade",
        "eca_reference": "往返飞刃收割",
        "tactical_tags": ["line", "return", "bounce"],
    },
    "lotus_flame": {
        "category": "火域持续",
        "cast_family": "ignite_field",
        "presentation_family": "eca_persistent_field",
        "eca_reference": "持续火域焚烧",
        "tactical_tags": ["field", "ignite", "aoe"],
    },
    "demon_seal": {
        "category": "封镇爆发",
        "cast_family": "seal_burst",
        "presentation_family": "eca_seal_burst",
        "eca_reference": "先封后爆控制",
        "tactical_tags": ["seal", "control", "burst"],
    },
    "flying_swords": {
        "category": "追击飞剑",
        "cast_family": "seeking_swords",
        "presentation_family": "eca_seeking_projectile",
        "eca_reference": "追踪飞剑攒射",
        "tactical_tags": ["projectile", "seek", "bounce"],
    },
}


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


def unwrap_tuple_items(raw):
    if isinstance(raw, dict) and isinstance(raw.get("items"), list):
        return raw["items"]
    if isinstance(raw, list):
        return raw
    return None


def unwrap_editor_kv_value(raw):
    if isinstance(raw, dict) and "value" in raw:
        return raw["value"]
    return raw


def scalar_text(value):
    number = float(value)
    if number.is_integer():
        return str(int(number))
    return f"{number:.2f}".rstrip("0").rstrip(".")


def optional_number(raw, fallback=0):
    raw = unwrap_editor_kv_value(raw)
    if raw in (None, ""):
        return fallback
    try:
        return float(raw)
    except (TypeError, ValueError):
        return fallback


def optional_int(raw, fallback=0):
    raw = unwrap_editor_kv_value(raw)
    if raw in (None, ""):
        return fallback
    try:
        return int(float(raw))
    except (TypeError, ValueError):
        return fallback


def build_editor_kv_entry(key, value):
    value = unwrap_editor_kv_value(value)
    entry = {
        "annotation": "",
        "desc": "",
        "key": key,
        "remark": "",
    }
    if isinstance(value, bool):
        value = int(value)
    if isinstance(value, int):
        entry.update({
            "etype": 1,
            "prop_cls": "PInt",
            "type": 2,
            "value": value,
        })
        return entry
    if isinstance(value, float):
        entry.update({
            "etype": 2,
            "prop_cls": "PFloat",
            "type": 1,
            "value": value,
        })
        return entry
    if value is None:
        value = ""
    if isinstance(value, str):
        entry.update({
            "etype": 0,
            "prop_cls": "PText",
            "type": 0,
            "value": value,
        })
        return entry
    raise TypeError(f"unsupported editor kv value for {key}: {type(value).__name__}")


def build_editor_kv_manifest(manifest):
    return {
        key: build_editor_kv_entry(key, value)
        for key, value in manifest.items()
    }


def is_meaningful_visual_value(value):
    value = unwrap_editor_kv_value(value)
    if value in (None, ""):
        return False
    if isinstance(value, (int, float)):
        return value > 0
    return True


def build_compact_editor_kv_manifest(manifest, allowed_keys):
    compact = {
        key: manifest[key]
        for key in allowed_keys
        if key in manifest and is_meaningful_visual_value(manifest[key])
    }
    return build_editor_kv_manifest(compact)


def strip_generated_entry_kv(existing_kv):
    return {
        key: value
        for key, value in existing_kv.items()
        if not str(key).startswith("entry_")
    }


def extract_first_visible_stage_entry(ability_data, stage):
    field_name, _ = ABILITY_VISIBLE_STAGE_FIELD_MAP[stage]
    effect_list = unwrap_tuple_items((ability_data or {}).get(field_name))
    if not isinstance(effect_list, list):
        return None
    for entry in effect_list:
        entry_items = unwrap_tuple_items(entry)
        if isinstance(entry_items, list) and optional_int(entry_items[0] if entry_items else 0) > 0:
            return entry_items
    return effect_list[0] if effect_list else None


def extract_visible_stage_vfx(ability_data, stage):
    entry = extract_first_visible_stage_entry(ability_data, stage)
    if not isinstance(entry, list):
        return 0, 0.0, 0.0

    effect_id = optional_int(entry[0])
    scale_items = unwrap_tuple_items(entry[3] if len(entry) > 3 else None)
    scale = (
        optional_number(scale_items[0]) if isinstance(scale_items, list) and len(scale_items) > 0 else 0.0
    )
    if scale <= 0 and isinstance(scale_items, list):
        scale = next(
            (optional_number(value) for value in scale_items if optional_number(value) > 0),
            0.0,
        )
    time = optional_number(entry[4] if len(entry) > 4 else None, 0.0)
    return effect_id, scale, time


def build_visible_stage_sfx_entry(existing_entry, effect_id, scale, time, default_socket):
    entry = deepcopy(existing_entry) if isinstance(existing_entry, list) else []
    if len(entry) < 10:
        entry.extend([None] * (10 - len(entry)))

    offset = unwrap_tuple_items(entry[1]) if len(entry) > 1 else None
    rotate = unwrap_tuple_items(entry[2]) if len(entry) > 2 else None
    scale_items = unwrap_tuple_items(entry[3]) if len(entry) > 3 else None
    resolved_scale = scale if scale > 0 else optional_number(scale_items[0] if isinstance(scale_items, list) and scale_items else None, 1.0)
    resolved_time = time if time > 0 else optional_number(entry[4], 0.3)

    entry[0] = int(effect_id)
    entry[1] = offset if isinstance(offset, list) else [0.0, 0.0, 0.0]
    entry[2] = rotate if isinstance(rotate, list) else [0.0, 0.0, 0.0]
    entry[3] = [resolved_scale, resolved_scale, resolved_scale]
    entry[4] = resolved_time
    entry[5] = entry[5] if isinstance(entry[5], str) and entry[5] else default_socket
    if entry[6] is None:
        entry[6] = True
    if entry[7] is None:
        entry[7] = True
    if entry[8] is None:
        entry[8] = 1
    if entry[9] is None:
        entry[9] = False
    return entry


def apply_visible_stage_sfx_fields(ability_data, visual_manifest):
    for stage, (field_name, default_socket) in ABILITY_VISIBLE_STAGE_FIELD_MAP.items():
        effect_id = optional_int(visual_manifest.get(f"entry_{stage}_effect_id"))
        effect_list = unwrap_tuple_items(ability_data.get(field_name)) or []
        existing_first = effect_list[0] if effect_list else None
        if effect_id > 0:
            updated_items = [
                build_visible_stage_sfx_entry(
                    existing_first,
                    effect_id,
                    optional_number(visual_manifest.get(f"entry_{stage}_scale"), 0.0),
                    optional_number(visual_manifest.get(f"entry_{stage}_time"), 0.0),
                    default_socket,
                )
            ]
            if len(effect_list) > 1:
                updated_items.extend(deepcopy(effect_list[1:]))
            ability_data[field_name] = make_tuple(updated_items)
        else:
            ability_data[field_name] = make_tuple([])


def read_csv_rows(path):
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def build_scalar_map(rows, key_field, value_field):
    mapping = {}
    for row in rows:
        key = row.get(key_field)
        if key not in (None, ""):
            mapping[key] = row.get(value_field, "")
    return mapping


def group_rows(rows, key_field):
    grouped = {}
    for row in rows:
        grouped.setdefault(row.get(key_field), []).append(row)
    return grouped


def to_number_if_possible(raw):
    if raw in (None, ""):
        return raw
    try:
        value = float(raw)
    except ValueError:
        return raw
    if value.is_integer():
        return int(value)
    return value


def html_to_text(raw):
    if raw in (None, ""):
        return ""
    text = str(raw).replace("</p>", "\n").replace("<br>", "\n").replace("<br/>", "\n")
    text = re.sub(r"<[^>]+>", "", text)
    lines = [line.strip() for line in text.splitlines()]
    return "\n".join(line for line in lines if line)


def value_to_compact_text(value):
    if isinstance(value, list):
        parts = []
        for entry in value:
            if isinstance(entry, list):
                parts.append(json.dumps(entry, ensure_ascii=False))
            elif isinstance(entry, float) and entry.is_integer():
                parts.append(str(int(entry)))
            else:
                parts.append(str(entry))
        return ", ".join(parts)
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def tuple_items(value):
    if isinstance(value, dict) and value.get("__tuple__") is True and isinstance(value.get("items"), list):
        return value.get("items")
    if isinstance(value, list):
        return value
    return None


def has_nonzero_payload(value):
    items = tuple_items(value)
    if items is not None:
        for entry in items:
            if isinstance(entry, list):
                if entry:
                    return True
            elif isinstance(entry, (int, float)):
                if entry != 0:
                    return True
            elif entry not in (None, "", "0", "0.0"):
                return True
        return False
    if isinstance(value, (int, float)):
        return value != 0
    return value not in (None, "", "0", "0.0")


def extract_attached_fields(item_data):
    fields = []
    for key in sorted(item_data):
        if not key.startswith("attached_"):
            continue
        value = item_data.get(key)
        if has_nonzero_payload(value):
            items = tuple_items(value)
            fields.append((key, items if items is not None else value))
    return fields


def extract_single_ability(value):
    items = tuple_items(value)
    if items and len(items) >= 2:
        ability_key = optional_int(items[0])
        if ability_key > 0:
            return ability_key, optional_int(items[1], 1)
    if isinstance(value, (int, float)) and value:
        return optional_int(value), 1
    return 0, 0


def extract_passive_abilities(value):
    abilities = []
    for entry in tuple_items(value) or []:
        if not isinstance(entry, list) or not entry:
            continue
        ability_key = optional_int(entry[0])
        if ability_key <= 0:
            continue
        level = optional_int(entry[1], 1) if len(entry) > 1 else 1
        abilities.append((ability_key, level))
    return abilities


def extract_lua_table_blocks(text):
    blocks = []
    start = None
    depth = 0
    for index, char in enumerate(text):
        if char == "{":
            if depth == 0:
                start = index
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0 and start is not None:
                blocks.append(text[start : index + 1])
                start = None
    return blocks


def extract_lua_number(block, field_name):
    match = re.search(rf"\b{re.escape(field_name)}\s*=\s*([0-9]+)", block)
    if not match:
        raise ValueError(f"missing number field {field_name}")
    return int(match.group(1))


def extract_lua_string(block, field_name, default=""):
    match = re.search(rf"\b{re.escape(field_name)}\s*=\s*'([^']*)'", block)
    if not match:
        return default
    return match.group(1)


def parse_equipment_catalog():
    text = EQUIPMENT_CATALOG_PATH.read_text(encoding="utf-8")
    start = text.index("local list = {") + len("local list = {")
    end = text.index("\n}\n\ntable.sort", start)
    blocks = extract_lua_table_blocks(text[start:end])
    entries = []
    for block in blocks:
        tags_match = re.search(r"tags\s*=\s*\{([^}]*)\}", block, re.S)
        tags = re.findall(r"'([^']+)'", tags_match.group(1)) if tags_match else []
        entries.append(
            {
                "order_index": extract_lua_number(block, "order_index"),
                "id": extract_lua_number(block, "id"),
                "name": extract_lua_string(block, "name"),
                "rarity": extract_lua_string(block, "rarity"),
                "archetype": extract_lua_string(block, "archetype"),
                "tags": tags,
                "summary": extract_lua_string(block, "summary"),
            }
        )
    entries.sort(key=lambda entry: (entry["order_index"], entry["id"]))
    return entries


def build_equipment_item_manifest(item_def, item_data, language):
    name_text = language.get(str(item_data.get("name"))) or item_def["name"]
    description_text = html_to_text(language.get(str(item_data.get("description")), ""))
    attached_fields = extract_attached_fields(item_data)
    active_ability_key, active_ability_level = extract_single_ability(item_data.get("attached_ability"))
    passive_abilities = extract_passive_abilities(item_data.get("attached_passive_abilities"))
    attr_pack = " | ".join(
        f"{field_name}={value_to_compact_text(field_value)}"
        for field_name, field_value in attached_fields
    )
    active_ability = ""
    if active_ability_key > 0:
        active_ability = f"{active_ability_key}@{active_ability_level}"

    return {
        "entry_item_kind": "equipment",
        "entry_archetype": item_def.get("archetype", ""),
        "entry_tags": encode_tags(item_def.get("tags", [])),
        "entry_summary": item_def.get("summary", "") or name_text,
        "entry_attr_pack": attr_pack or description_text,
        "entry_active_ability": active_ability,
        "entry_passive_abilities": ", ".join(
            f"{ability_key}@{level}" for ability_key, level in passive_abilities
        ),
        "entry_handler": "editor_item_builtin",
    }


def sync_equipment_item_manifests():
    language = load_json(LANGUAGE_PATH)
    synced = 0
    for item_def in parse_equipment_catalog():
        item_path = ITEM_DIR / f"{item_def['id']}.json"
        if not item_path.exists():
            raise FileNotFoundError(f"missing equipment editor item: {item_path}")
        data = load_json(item_path)
        data["kv"] = build_editor_kv_manifest(build_equipment_item_manifest(item_def, data, language))
        write_json(item_path, data)
        synced += 1
    return synced


def build_attack_skill_defs():
    by_id = {}
    evolution_by_id = {
        row["skill_id"]: row for row in read_csv_rows(SECOND_BATCH_EVOLUTIONS_CSV)
    }

    for row in read_csv_rows(ATTACK_SKILLS_CSV):
        skill_id = row["id"]
        taxonomy = ATTACK_SKILL_TAXONOMY.get(skill_id, {})
        base_damage_ratio = optional_number(row.get("base_damage_ratio"))
        base_cooldown = optional_number(row.get("base_cooldown"))
        base_range = optional_number(row.get("base_range"))
        base_pierce = optional_number(row.get("base_pierce"))
        base_duration = optional_number(row.get("base_control_lock_time"))
        base_radius = optional_number(row.get("base_explosion_radius"))
        base_bounce = optional_number(row.get("base_extra_targets"))
        by_id[skill_id] = {
            "id": skill_id,
            "name": row["name"],
            "summary": row["summary"],
            "damage_type": row.get("damage_type", ""),
            "damage_form": row.get("damage_form", ""),
            "element": row.get("element", ""),
            "damage_label": row.get("damage_label", ""),
            "default_slot": optional_int(row.get("default_slot")),
            "damage_ratio": base_damage_ratio,
            "cooldown": base_cooldown,
            "range": base_range,
            "pierce": base_pierce,
            "duration": base_duration,
            "radius": base_radius,
            "bounce": base_bounce,
            "base_damage_ratio": base_damage_ratio,
            "base_cooldown": base_cooldown,
            "base_range": base_range,
            "base_pierce": base_pierce,
            "base_pierce_width": optional_number(row.get("base_pierce_width")),
            "base_duration": base_duration,
            "base_knockback_distance": optional_number(row.get("base_knockback_distance")),
            "base_knockback_speed": optional_number(row.get("base_knockback_speed")),
            "base_explosion_ratio": optional_number(row.get("base_explosion_ratio")),
            "base_radius": base_radius,
            "base_bounce": base_bounce,
            "base_repeat_count": optional_number(row.get("base_repeat_count")),
            "archetype": "",
            "category": taxonomy.get("category", ""),
            "cast_family": taxonomy.get("cast_family", ""),
            "presentation_family": taxonomy.get("presentation_family", ""),
            "eca_reference": taxonomy.get("eca_reference", ""),
            "tactical_tags": taxonomy.get("tactical_tags", []),
            "evolution_id": "",
            "evolution_name": "",
            "evolution_summary": "",
            "icon": DEFAULT_ABILITY_ICON,
        }

    for row in read_csv_rows(SECOND_BATCH_SKILLS_CSV):
        skill_id = row["id"]
        taxonomy = ATTACK_SKILL_TAXONOMY.get(skill_id, {})
        evolution = evolution_by_id.get(skill_id, {})
        base_damage_ratio = optional_number(row.get("damage_ratio"))
        base_cooldown = optional_number(row.get("cooldown"))
        base_range = optional_number(row.get("range"))
        base_pierce = optional_number(row.get("pierce"))
        base_duration = optional_number(row.get("duration"))
        base_radius = optional_number(row.get("radius"))
        base_bounce = optional_number(row.get("bounce"))
        by_id[skill_id] = {
            "id": skill_id,
            "name": row["name"],
            "summary": row["summary"],
            "damage_type": row.get("damage_type", ""),
            "damage_form": row.get("damage_form", ""),
            "element": row.get("element", ""),
            "damage_label": row.get("damage_label", ""),
            "default_slot": 0,
            "damage_ratio": base_damage_ratio,
            "cooldown": base_cooldown,
            "range": base_range,
            "pierce": base_pierce,
            "duration": base_duration,
            "radius": base_radius,
            "bounce": base_bounce,
            "base_damage_ratio": base_damage_ratio,
            "base_cooldown": base_cooldown,
            "base_range": base_range,
            "base_pierce": base_pierce,
            "base_pierce_width": 0.0,
            "base_duration": base_duration,
            "base_knockback_distance": 0.0,
            "base_knockback_speed": 0.0,
            "base_explosion_ratio": 0.0,
            "base_radius": base_radius,
            "base_bounce": base_bounce,
            "base_repeat_count": 0.0,
            "archetype": row.get("archetype", ""),
            "category": taxonomy.get("category", ""),
            "cast_family": taxonomy.get("cast_family", ""),
            "presentation_family": taxonomy.get("presentation_family", ""),
            "eca_reference": taxonomy.get("eca_reference", ""),
            "tactical_tags": taxonomy.get("tactical_tags", []),
            "evolution_id": evolution.get("evolution_id", ""),
            "evolution_name": evolution.get("evolution_name", ""),
            "evolution_summary": evolution.get("evolution_summary", ""),
            "icon": int(optional_number(row.get("ui_icon"), DEFAULT_ABILITY_ICON)),
        }

    result = []
    for skill_id in ATTACK_SKILL_ID_ORDER:
        if skill_id not in by_id:
            raise KeyError(f"missing attack skill config: {skill_id}")
        result.append(by_id[skill_id])
    return result


def build_attack_skill_vfx_by_id():
    by_id = {}
    for row in read_csv_rows(ATTACK_SKILL_VFX_CSV):
        skill_id = row["skill_id"]
        by_id[skill_id] = {
            "projectile_key": optional_int(row.get("projectile_key")),
            "projectile_speed": optional_number(row.get("projectile_speed")),
            "projectile_time": optional_number(row.get("projectile_time")),
            "target_distance": optional_number(row.get("target_distance")),
            "cast_particle": optional_int(row.get("cast_particle")),
            "cast_scale": optional_number(row.get("cast_scale")),
            "cast_time": optional_number(row.get("cast_time")),
            "impact_particle": optional_int(row.get("impact_particle")),
            "impact_scale": optional_number(row.get("impact_scale")),
            "impact_time": optional_number(row.get("impact_time")),
            "explosion_particle": optional_int(row.get("explosion_particle")),
            "explosion_scale": optional_number(row.get("explosion_scale")),
            "explosion_time": optional_number(row.get("explosion_time")),
            "charge_particle": optional_int(row.get("charge_particle")),
            "charge_scale": optional_number(row.get("charge_scale")),
            "charge_time": optional_number(row.get("charge_time")),
            "chain_particle": optional_int(row.get("chain_particle")),
            "chain_scale": optional_number(row.get("chain_scale")),
            "chain_time": optional_number(row.get("chain_time")),
            "strike_delay": optional_number(row.get("strike_delay")),
        }

    for skill_id in ATTACK_SKILL_ID_ORDER:
        by_id.setdefault(skill_id, {})

    return by_id


def build_attack_skill_base_description(skill):
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


def extract_projectile_effect_id(effect_field):
    if isinstance(effect_field, list) and effect_field:
        return optional_int(effect_field[0])
    if isinstance(effect_field, dict):
        items = effect_field.get("items")
        if isinstance(items, list) and items:
            return optional_int(items[0])
    return 0


def format_effect_id(effect_id):
    return "无" if not effect_id or effect_id <= 0 else str(int(effect_id))


def load_existing_or_template(path, template_path=None):
    if path.exists():
        return load_json(path)
    if template_path is None:
        raise FileNotFoundError(path)
    return deepcopy(load_json(template_path))


def coalesce_optional_number(*values, fallback=0.0):
    for value in values:
        if value in (None, ""):
            continue
        return optional_number(value, fallback)
    return fallback


def coalesce_optional_int(*values, fallback=0):
    for value in values:
        if value in (None, ""):
            continue
        return optional_int(value, fallback)
    return fallback


def build_visual_manifest(
    skill,
    ability_id,
    projectile_id,
    ability_data,
    projectile_data,
    existing_ability_kv,
    existing_projectile_kv,
    legacy_vfx,
):
    foe_effect_id = extract_projectile_effect_id(projectile_data.get("effect_foes"))
    friend_effect_id = extract_projectile_effect_id(projectile_data.get("effect_friend"))
    manifest = {
        "entry_skill_id": skill["id"],
        "entry_skill_name": skill["name"],
        "entry_ability_id": ability_id,
        "entry_projectile_id": projectile_id,
        "entry_projectile_effect_id": foe_effect_id,
        "entry_projectile_friend_effect_id": friend_effect_id,
    }
    manifest["entry_projectile_speed"] = coalesce_optional_number(
        legacy_vfx.get("projectile_speed"),
        existing_ability_kv.get("entry_projectile_speed"),
        existing_projectile_kv.get("entry_projectile_speed"),
    )
    manifest["entry_projectile_time"] = coalesce_optional_number(
        legacy_vfx.get("projectile_time"),
        existing_ability_kv.get("entry_projectile_time"),
        existing_projectile_kv.get("entry_projectile_time"),
    )
    manifest["entry_target_distance"] = coalesce_optional_number(
        legacy_vfx.get("target_distance"),
        existing_ability_kv.get("entry_target_distance"),
        existing_projectile_kv.get("entry_target_distance"),
    )
    manifest["entry_strike_delay"] = coalesce_optional_number(
        legacy_vfx.get("strike_delay"),
        existing_ability_kv.get("entry_strike_delay"),
        existing_projectile_kv.get("entry_strike_delay"),
    )

    for stage in VISUAL_STAGES:
        visible_effect_id, visible_scale, visible_time = extract_visible_stage_vfx(ability_data, stage)
        manifest[f"entry_{stage}_effect_id"] = coalesce_optional_int(
            legacy_vfx.get(f"{stage}_particle"),
            existing_ability_kv.get(f"entry_{stage}_effect_id"),
            existing_projectile_kv.get(f"entry_{stage}_effect_id"),
            visible_effect_id,
        )
        manifest[f"entry_{stage}_scale"] = coalesce_optional_number(
            legacy_vfx.get(f"{stage}_scale"),
            existing_ability_kv.get(f"entry_{stage}_scale"),
            existing_projectile_kv.get(f"entry_{stage}_scale"),
            visible_scale,
        )
        manifest[f"entry_{stage}_time"] = coalesce_optional_number(
            legacy_vfx.get(f"{stage}_time"),
            existing_ability_kv.get(f"entry_{stage}_time"),
            existing_projectile_kv.get(f"entry_{stage}_time"),
            visible_time,
        )

    return manifest


def encode_tags(tags):
    if not isinstance(tags, list) or not tags:
        return ""
    return ", ".join(str(tag) for tag in tags if tag)


def build_ability_visual_manifest_kv(visual_manifest):
    return build_compact_editor_kv_manifest(visual_manifest, ABILITY_VISUAL_KV_KEYS)


def build_attack_skill_description(skill, ability_id, visual_manifest):
    lines = [build_attack_skill_base_description(skill), "", f"技能物编ID：{ability_id}"]
    lines.append(f"投射物物编ID：{visual_manifest['entry_projectile_id']}")
    lines.append(f"飞行特效ID：{format_effect_id(visual_manifest['entry_projectile_effect_id'])}")
    if visual_manifest["entry_projectile_friend_effect_id"] not in (
        0,
        visual_manifest["entry_projectile_effect_id"],
    ):
        lines.append(
            f"友方飞行特效ID：{format_effect_id(visual_manifest['entry_projectile_friend_effect_id'])}"
        )
    if visual_manifest["entry_projectile_speed"] > 0:
        lines.append(f"飞行速度：{scalar_text(visual_manifest['entry_projectile_speed'])}")
    if visual_manifest["entry_projectile_time"] > 0:
        lines.append(f"飞行时长：{scalar_text(visual_manifest['entry_projectile_time'])}秒")
    if visual_manifest["entry_target_distance"] > 0:
        lines.append(f"命中收束：{scalar_text(visual_manifest['entry_target_distance'])}")
    if visual_manifest["entry_strike_delay"] > 0:
        lines.append(f"延迟落点：{scalar_text(visual_manifest['entry_strike_delay'])}秒")

    for stage in VISUAL_STAGES:
        effect_id = visual_manifest[f"entry_{stage}_effect_id"]
        scale = visual_manifest[f"entry_{stage}_scale"]
        duration = visual_manifest[f"entry_{stage}_time"]
        if effect_id <= 0 and scale <= 0 and duration <= 0:
            continue
        lines.append(
            f"{VISUAL_STAGE_LABELS[stage]}特效：ID {format_effect_id(effect_id)} / 缩放 {scalar_text(scale)} / 时长 {scalar_text(duration)}秒"
        )
    return "\n".join(lines)


def build_projectile_description(skill, projectile_id, projectile_manifest):
    lines = [
        f"攻击技能投射物：{skill['name']}",
        f"技能ID：{skill['id']}",
        f"技能物编ID：{projectile_manifest['entry_ability_id']}",
        f"投射物物编ID：{projectile_id}",
        f"飞行特效ID：{format_effect_id(projectile_manifest['entry_projectile_effect_id'])}",
    ]

    if projectile_manifest["entry_projectile_friend_effect_id"] not in (
        0,
        projectile_manifest["entry_projectile_effect_id"],
    ):
        lines.append(
            f"友方飞行特效ID：{format_effect_id(projectile_manifest['entry_projectile_friend_effect_id'])}"
        )

    for stage in VISUAL_STAGES:
        effect_id = projectile_manifest[f"entry_{stage}_effect_id"]
        scale = projectile_manifest[f"entry_{stage}_scale"]
        duration = projectile_manifest[f"entry_{stage}_time"]
        if effect_id <= 0 and scale <= 0 and duration <= 0:
            continue
        lines.append(
            f"{VISUAL_STAGE_LABELS[stage]}特效：ID {format_effect_id(effect_id)} / 缩放 {scalar_text(scale)} / 时长 {scalar_text(duration)}秒"
        )

    if projectile_manifest["entry_projectile_speed"] > 0:
        lines.append(f"飞行速度：{scalar_text(projectile_manifest['entry_projectile_speed'])}")
    if projectile_manifest["entry_projectile_time"] > 0:
        lines.append(f"飞行时长：{scalar_text(projectile_manifest['entry_projectile_time'])}秒")
    if projectile_manifest["entry_target_distance"] > 0:
        lines.append(f"命中收束：{scalar_text(projectile_manifest['entry_target_distance'])}")
    if projectile_manifest["entry_strike_delay"] > 0:
        lines.append(f"延迟落点：{scalar_text(projectile_manifest['entry_strike_delay'])}秒")

    return "\n".join(lines)


def build_projectile_manifest_kv(visual_manifest):
    return build_compact_editor_kv_manifest(visual_manifest, PROJECTILE_VISUAL_KV_KEYS)


def build_language_entry_key(namespace, obj_id, suffix):
    return murmur3_hash(f"{namespace}::{obj_id}::{suffix}")


def infer_treasure_tags(row, tag_rule_rows):
    tags = []
    seen = set()
    for rule in tag_rule_rows:
        raw_value = str(row.get(rule.get("match_field", ""), ""))
        matched = False
        if rule.get("match_type") == "contains":
            matched = str(rule.get("match_value", "")) in raw_value
        elif rule.get("match_type") == "equals":
            matched = raw_value == str(rule.get("match_value", ""))
        if matched:
            tag = rule.get("output_tag", "")
            if tag and tag not in seen:
                tags.append(tag)
                seen.add(tag)
    return tags


def infer_treasure_duration_meta(effects, duration_rule_rows):
    for rule in duration_rule_rows:
        for effect in effects:
            raw_value = str(effect.get(rule.get("match_field", ""), ""))
            matched = False
            if rule.get("match_type") == "equals":
                matched = raw_value == str(rule.get("match_value", ""))
            elif rule.get("match_type") == "contains":
                matched = str(rule.get("match_value", "")) in raw_value
            elif rule.get("match_type") == "default":
                matched = True
            if matched:
                duration_sec = optional_number(rule.get("output_duration_sec"), 0.0)
                if duration_sec <= 0 and raw_value.endswith("s"):
                    duration_sec = optional_number(raw_value[:-1], 0.0)
                return {
                    "duration_type": rule.get("output_duration_type") or "permanent",
                    "treasure_type": rule.get("output_treasure_type") or "general",
                    "trigger": rule.get("output_trigger") or "",
                    "duration_sec": duration_sec,
                }
    return {
        "duration_type": "permanent",
        "treasure_type": "general",
        "trigger": "",
        "duration_sec": 0.0,
    }


def treasure_editor_id_for_runtime_id(runtime_id):
    match = re.search(r"ITEM_(\d+)$", runtime_id or "")
    if not match:
        raise ValueError(f"invalid treasure runtime id: {runtime_id}")
    return TREASURE_EDITOR_ID_BASE + int(match.group(1))


def normalize_treasure_effect(row, runtime_key_map):
    return {
        "order_index": optional_int(row.get("order_index")),
        "effect_type": row.get("effect_type", ""),
        "effect_key": row.get("effect_key", ""),
        "runtime_key": runtime_key_map.get(row.get("effect_key", ""), row.get("effect_key", "")),
        "op": row.get("op", ""),
        "value": to_number_if_possible(row.get("value")),
        "scope": row.get("scope", ""),
        "condition": row.get("condition", ""),
        "notes": row.get("notes", ""),
    }


def infer_treasure_apply_mode(effects, set_effects):
    effect_types = {effect.get("effect_type") for effect in list(effects) + list(set_effects)}
    attr_like_types = {"ratio_bonus", "flat_bonus", "temporary_buff", "passive_growth", "passive_income"}
    runtime_types = {"resource_gain", "refresh_count", "mechanic_toggle"}
    trigger_types = {"trigger_growth", "conditional_damage", "probability"}
    has_attr = any(effect_type in attr_like_types for effect_type in effect_types)
    has_runtime = any(effect_type in runtime_types for effect_type in effect_types)
    has_trigger = any(effect_type in trigger_types for effect_type in effect_types)
    if has_attr and (has_runtime or has_trigger):
        return "hybrid_trigger_runtime"
    if has_attr or has_trigger:
        return "trigger_attr_bonus"
    return "runtime_dispatch"


def build_treasure_trigger_hint(duration_meta, effects, set_effects):
    hints = []
    apply_mode = infer_treasure_apply_mode(effects, set_effects)
    if apply_mode in ("trigger_attr_bonus", "hybrid_trigger_runtime"):
        hints.append("属性增减可走 hero_attr_system.add_attr / unit:add_attr")
    if apply_mode in ("runtime_dispatch", "hybrid_trigger_runtime"):
        hints.append("复杂行为继续走 runtime.rewards 分发表")
    if duration_meta.get("duration_type") == "timed" and duration_meta.get("duration_sec", 0) > 0:
        hints.append(f"持续 {scalar_text(duration_meta['duration_sec'])} 秒")
    if duration_meta.get("trigger"):
        hints.append(f"触发方式 {duration_meta['trigger']}")
    return "；".join(hints)


def build_treasure_defs():
    treasure_rows = read_csv_rows(TREASURES_CSV)
    effect_groups = group_rows(read_csv_rows(TREASURE_EFFECTS_CSV), "treasure_id")
    set_rows = read_csv_rows(TREASURE_SETS_CSV)
    set_member_groups = group_rows(read_csv_rows(TREASURE_SET_MEMBERS_CSV), "set_id")
    set_effect_groups = group_rows(read_csv_rows(TREASURE_SET_EFFECTS_CSV), "set_id")
    rarity_map = build_scalar_map(read_csv_rows(TREASURE_COMPAT_RARITY_MAP_CSV), "source_rarity", "output_quality")
    runtime_key_map = build_scalar_map(
        read_csv_rows(TREASURE_COMPAT_RUNTIME_KEY_MAP_CSV),
        "source_key",
        "output_runtime_key",
    )
    tag_rule_rows = read_csv_rows(TREASURE_COMPAT_TAG_RULES_CSV)
    tag_rule_rows.sort(key=lambda row: optional_int(row.get("order_index")))
    duration_rule_rows = read_csv_rows(TREASURE_COMPAT_DURATION_RULES_CSV)
    duration_rule_rows.sort(key=lambda row: optional_int(row.get("order_index")))

    sets_by_id = {}
    for row in set_rows:
        set_id = row.get("set_id")
        set_effects = [
            normalize_treasure_effect(effect_row, runtime_key_map)
            for effect_row in set_effect_groups.get(set_id, [])
        ]
        set_effects.sort(key=lambda effect: effect["order_index"])
        set_members = sorted(
            (member_row.get("treasure_id", "") for member_row in set_member_groups.get(set_id, [])),
            key=lambda treasure_id: treasure_id,
        )
        sets_by_id[set_id] = {
            "set_id": set_id,
            "name": row.get("set_name", ""),
            "piece_count": optional_int(row.get("piece_count")),
            "bonus_desc": row.get("bonus_desc", ""),
            "notes": row.get("notes", ""),
            "members": set_members,
            "effects": set_effects,
        }

    treasures = []
    for row in treasure_rows:
        effects = [
            normalize_treasure_effect(effect_row, runtime_key_map)
            for effect_row in effect_groups.get(row.get("id"), [])
        ]
        effects.sort(key=lambda effect: effect["order_index"])
        duration_meta = infer_treasure_duration_meta(effects, duration_rule_rows)
        set_data = sets_by_id.get(row.get("set_id"))
        set_effects = list(set_data.get("effects", [])) if set_data else []
        treasures.append(
            {
                "order_index": optional_int(row.get("order_index")),
                "id": row.get("id", ""),
                "editor_item_id": treasure_editor_id_for_runtime_id(row.get("id", "")),
                "name": row.get("name", ""),
                "category": row.get("category", ""),
                "rarity": row.get("rarity", ""),
                "quality": rarity_map.get(row.get("rarity", ""), TREASURE_QUALITY_BY_RARITY.get(row.get("rarity", ""), "common")),
                "is_set_item": row.get("is_set_item") in ("true", "1"),
                "set_id": row.get("set_id") or "",
                "summary": row.get("summary", ""),
                "notes": row.get("notes", ""),
                "effects": effects,
                "set_name": set_data.get("name", "") if set_data else "",
                "set_piece_count": set_data.get("piece_count", 0) if set_data else 0,
                "set_bonus_desc": set_data.get("bonus_desc", "") if set_data else "",
                "set_notes": set_data.get("notes", "") if set_data else "",
                "set_members": set_data.get("members", []) if set_data else [],
                "set_effects": set_effects,
                "tags": infer_treasure_tags(row, tag_rule_rows),
                "duration_type": duration_meta["duration_type"],
                "treasure_type": duration_meta["treasure_type"],
                "duration_sec": duration_meta["duration_sec"],
                "duration_trigger": duration_meta["trigger"],
            }
        )

    treasures.sort(key=lambda entry: (entry["order_index"], entry["id"]))
    for treasure in treasures:
        treasure["apply_mode"] = infer_treasure_apply_mode(treasure["effects"], treasure["set_effects"])
        treasure["trigger_hint"] = build_treasure_trigger_hint(
            {
                "duration_type": treasure["duration_type"],
                "duration_sec": treasure["duration_sec"],
                "trigger": treasure["duration_trigger"],
            },
            treasure["effects"],
            treasure["set_effects"],
        )
    return treasures


def build_treasure_effect_manifest(effects):
    if not effects:
        return ""
    return " | ".join(
        (
            f"{effect['effect_type']}:{effect['effect_key']}:{effect['op']}:{effect['value']}"
            f":{effect['scope'] or 'permanent'}"
            + (f":{effect['condition']}" if effect.get("condition") else "")
        )
        for effect in effects
    )


def build_treasure_item_manifest(treasure, item_data):
    duration_text = treasure["duration_type"]
    if treasure["duration_sec"] > 0:
        duration_text = f"{duration_text}:{scalar_text(treasure['duration_sec'])}s"
    if treasure["duration_trigger"]:
        duration_text = f"{duration_text}:{treasure['duration_trigger']}"

    set_text = ""
    if treasure["set_name"]:
        set_text = f"{treasure['set_name']}({treasure['set_piece_count']}件)"
        if treasure["set_bonus_desc"]:
            set_text = f"{set_text} {treasure['set_bonus_desc']}"
        if treasure["set_effects"]:
            set_text = f"{set_text} | {build_treasure_effect_manifest(treasure['set_effects'])}"

    return {
        "entry_item_kind": "treasure",
        "entry_runtime_treasure_id": treasure["id"],
        "entry_quality": treasure["quality"],
        "entry_category": treasure["category"],
        "entry_summary": treasure["summary"],
        "entry_duration": duration_text,
        "entry_effects": build_treasure_effect_manifest(treasure["effects"]),
        "entry_set": set_text,
        "entry_handler": "runtime.rewards",
    }


def build_treasure_item_description(treasure):
    lines = [
        f"运行时宝物ID：{treasure['id']}",
        f"宝物物编ID：{treasure['editor_item_id']}",
        f"分类：{treasure['category']}",
        f"稀有度：{treasure['quality']}",
        f"持续类型：{treasure['duration_type']}",
        f"生效方式：{treasure['apply_mode']}",
    ]
    if treasure["summary"]:
        lines.append(f"摘要：{treasure['summary']}")
    if treasure["trigger_hint"]:
        lines.append(f"触发提示：{treasure['trigger_hint']}")
    for index, effect in enumerate(treasure["effects"], start=1):
        effect_line = (
            f"效果{index}：{effect['effect_type']} / {effect['effect_key']} / {effect['op']} / {effect['value']} / "
            f"{effect['scope'] or 'permanent'}"
        )
        if effect["condition"]:
            effect_line += f" / {effect['condition']}"
        lines.append(effect_line)
    if treasure["set_name"]:
        lines.append(f"套装：{treasure['set_name']}（{treasure['set_piece_count']}件）")
        if treasure["set_bonus_desc"]:
            lines.append(f"套装说明：{treasure['set_bonus_desc']}")
    for index, effect in enumerate(treasure["set_effects"], start=1):
        effect_line = (
            f"套装效果{index}：{effect['effect_type']} / {effect['effect_key']} / {effect['op']} / {effect['value']}"
        )
        if effect["condition"]:
            effect_line += f" / {effect['condition']}"
        lines.append(effect_line)
    return "<html><body>" + "".join(f"<p>{html.escape(line)}</p>" for line in lines) + "</body></html>"


def generate_treasure_item_files():
    pending_language = {}
    assignments = []
    treasure_defs = build_treasure_defs()

    for order, treasure in enumerate(treasure_defs):
        item_id = treasure["editor_item_id"]
        item_path = ITEM_DIR / f"{item_id}.json"
        data = load_existing_or_template(item_path, ITEM_TEMPLATE_PATH)
        data["key"] = item_id
        data["uid"] = str(item_id)
        data["kv"] = build_editor_kv_manifest(build_treasure_item_manifest(treasure, data))

        name_tid = build_language_entry_key("EntryRuntimeTreasure", item_id, "name")
        desc_tid = build_language_entry_key("EntryRuntimeTreasure", item_id, "desc")
        data["name"] = name_tid
        data["description"] = desc_tid
        pending_language[str(name_tid)] = treasure["name"]
        pending_language[str(desc_tid)] = build_treasure_item_description(treasure)

        write_json(item_path, data)
        assignments.append((item_id, ITEM_FOLDER_UIDS["root"], order))

    return pending_language, assignments, treasure_defs


def generate_ability_files(skills, legacy_vfx_by_id):
    pending_language = {}
    assignments = []
    visual_manifests = {}

    for order, skill in enumerate(skills):
        ability_id = ATTACK_SKILL_EDITOR_IDS[skill["id"]]
        ability_path = ABILITY_DIR / f"{ability_id}.json"
        projectile_id = PROJECTILE_EDITOR_IDS[skill["id"]]
        projectile_path = PROJECTILE_DIR / f"{projectile_id}.json"
        projectile_data = load_existing_or_template(projectile_path)
        data = load_existing_or_template(ability_path, ABILITY_TEMPLATE_PATH)
        data["key"] = ability_id
        data["uid"] = str(ability_id)
        data["ability_icon"] = skill["icon"] or DEFAULT_ABILITY_ICON
        data["cold_down_time"] = make_tuple([scalar_text(skill["cooldown"])])
        data["ability_cost"] = make_tuple(["0"])
        data["ability_damage"] = make_tuple(["0"])
        existing_ability_kv = data.get("kv") if isinstance(data.get("kv"), dict) else {}
        existing_projectile_kv = projectile_data.get("kv") if isinstance(projectile_data.get("kv"), dict) else {}
        visual_manifest = build_visual_manifest(
            skill,
            ability_id,
            projectile_id,
            data,
            projectile_data,
            existing_ability_kv,
            existing_projectile_kv,
            legacy_vfx_by_id.get(skill["id"], {}),
        )
        data["kv"] = strip_generated_entry_kv(existing_ability_kv)
        data["kv"].update(build_ability_visual_manifest_kv(visual_manifest))
        apply_visible_stage_sfx_fields(data, visual_manifest)
        visual_manifests[skill["id"]] = visual_manifest

        name_tid = build_language_entry_key("EntryRuntimeAbility", ability_id, "name")
        desc_tid = build_language_entry_key("EntryRuntimeAbility", ability_id, "desc")
        data["name"] = name_tid
        data["description"] = desc_tid
        pending_language[str(name_tid)] = skill["name"]
        pending_language[str(desc_tid)] = build_attack_skill_description(skill, ability_id, visual_manifest)

        write_json(ability_path, data)

        assignments.append((ability_id, ABILITY_FOLDER_UIDS["root"], order))

    return pending_language, assignments, visual_manifests


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


def generate_projectile_files(skills, visual_manifests):
    pending_language = {}

    for skill in skills:
        projectile_id = PROJECTILE_EDITOR_IDS[skill["id"]]
        projectile_path = PROJECTILE_DIR / f"{projectile_id}.json"
        if not projectile_path.exists():
            raise FileNotFoundError(f"missing projectile editor file: {projectile_path}")

        data = load_json(projectile_path)
        existing_projectile_kv = data.get("kv") if isinstance(data.get("kv"), dict) else {}
        visual_manifest = visual_manifests[skill["id"]]
        projectile_manifest = build_projectile_manifest_kv(visual_manifest)

        data["key"] = projectile_id
        data["uid"] = str(projectile_id)
        data["kv"] = strip_generated_entry_kv(existing_projectile_kv)
        data["kv"].update(projectile_manifest)

        desc_tid = data.get("description") or build_language_entry_key("EntryRuntimeProjectile", projectile_id, "desc")
        data["description"] = desc_tid
        pending_language[str(desc_tid)] = build_projectile_description(skill, projectile_id, visual_manifest)

        write_json(projectile_path, data)

    return pending_language


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


def prune_folderinfo_entries(folderinfo, remove_uid_prefixes=None, remove_uids=None):
    remove_uid_prefixes = tuple(remove_uid_prefixes or ())
    remove_uids = set(remove_uids or [])

    kept = []
    for entry in folderinfo.get("f", []):
        items = entry.get("items", [])
        uid = items[2] if len(items) >= 3 else None
        uid_text = str(uid) if uid is not None else ""
        if uid in remove_uids or any(uid_text.startswith(prefix) for prefix in remove_uid_prefixes):
            continue
        kept.append(entry)
    folderinfo["f"] = kept


def sync_folderinfo(path, folder_specs, assignments, remove_uid_prefixes=None, remove_uids=None):
    folderinfo = load_json(path)
    if remove_uid_prefixes or remove_uids:
        prune_folderinfo_entries(
            folderinfo,
            remove_uid_prefixes=remove_uid_prefixes,
            remove_uids=remove_uids,
        )

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


def build_ability_folder_specs(skills):
    return [
        {
            "uid": ABILITY_FOLDER_UIDS["root"],
            "parent_path": "/2147483647",
            "name": "EntryRuntime技能",
            "order": 0,
        }
    ]


def build_projectile_folder_specs(skills):
    specs = [
        {
            "uid": PROJECTILE_FOLDER_UIDS["root"],
            "parent_path": "/2147483647",
            "name": "技能投射物",
            "order": 0,
        }
    ]

    for order, skill in enumerate(skills):
        specs.append(
            {
                "uid": PROJECTILE_FOLDER_UIDS[skill["id"]],
                "parent_path": f"/2147483647/{PROJECTILE_FOLDER_UIDS['root']}",
                "name": skill["name"],
                "order": order,
            }
        )

    return specs


def build_projectile_assignments(skills):
    assignments = []
    for skill in skills:
        projectile_id = PROJECTILE_EDITOR_IDS[skill["id"]]
        projectile_path = PROJECTILE_DIR / f"{projectile_id}.json"
        if not projectile_path.exists():
            raise FileNotFoundError(f"missing projectile editor file: {projectile_path}")
        assignments.append((projectile_id, PROJECTILE_FOLDER_UIDS[skill["id"]], 0))
    return assignments


def write_registry(treasure_defs):
    lines = [
        "return {",
        "  ability = {",
    ]

    for skill_id in ATTACK_SKILL_ID_ORDER:
        lines.append(f"    {skill_id} = {ATTACK_SKILL_EDITOR_IDS[skill_id]},")

    lines.extend(
        [
            "  },",
            "  projectile = {",
        ]
    )

    for skill_id in ATTACK_SKILL_ID_ORDER:
        lines.append(f"    {skill_id} = {PROJECTILE_EDITOR_IDS[skill_id]},")

    lines.extend(
        [
            "  },",
            "  treasure = {",
        ]
    )

    for treasure in treasure_defs:
        lines.append(f"    {treasure['id']} = {treasure['editor_item_id']},")

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
    legacy_vfx_by_id = build_attack_skill_vfx_by_id()

    equipment_count = sync_equipment_item_manifests()
    ability_language, ability_assignments, visual_manifests = generate_ability_files(skills, legacy_vfx_by_id)
    modifier_language, modifier_assignments = generate_modifier_files()
    projectile_language = generate_projectile_files(skills, visual_manifests)
    treasure_language, treasure_assignments, treasure_defs = generate_treasure_item_files()

    language_count = sync_language(
        {
            **ability_language,
            **modifier_language,
            **projectile_language,
            **treasure_language,
        }
    )

    sync_folderinfo(
        ABILITY_FOLDERINFO_PATH,
        build_ability_folder_specs(skills),
        ability_assignments,
        remove_uid_prefixes=["entry_runtime_skill_"],
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

    sync_folderinfo(
        ITEM_FOLDERINFO_PATH,
        [
            {
                "uid": ITEM_FOLDER_UIDS["root"],
                "parent_path": "/2147483647",
                "name": "EntryRuntime道具",
                "order": 0,
            }
        ],
        treasure_assignments,
        remove_uid_prefixes=["entry_runtime_item_"],
    )

    sync_folderinfo(
        PROJECTILE_FOLDERINFO_PATH,
        build_projectile_folder_specs(skills),
        build_projectile_assignments(skills),
    )

    write_registry(treasure_defs)

    print(
        "synced runtime editor objects: "
        f"{len(skills)} abilities, "
        f"{len(skills)} projectiles, "
        f"{len(MODIFIER_DEFINITIONS)} modifiers, "
        f"{equipment_count} equipment manifests, "
        f"{len(treasure_defs)} treasure items, "
        f"{language_count} language entries"
    )


if __name__ == "__main__":
    main()

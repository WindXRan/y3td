#!/usr/bin/env python3
# -*- coding: utf-8 -*-


from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LANGUAGE_PATH = ROOT / "zhlanguage.json"
ABILITY_DIR = ROOT / "editor_table" / "abilityall"
ITEM_DIR = ROOT / "editor_table" / "editoritem"
MODIFIER_DIR = ROOT / "editor_table" / "modifierall"
PROJECTILE_DIR = ROOT / "editor_table" / "projectileall"
ABILITY_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_ability_all.json"
ITEM_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_editor_item.json"
MODIFIER_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_modifier_all.json"
PROJECTILE_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_projectile_all.json"
REGISTRY_PATH = ROOT / "script" / "data" / "object_tables" / "runtime_editor_ids.lua"
ATTACK_SKILLS_LUA = ROOT / "script" / "data" / "object_tables" / "attack_skills.lua"
RUNTIME_ATTACK_SKILLS = ROOT / "script" / "runtime" / "attack_skills.lua"
RUNTIME_AUTO_EFFECTS = ROOT / "script" / "runtime" / "auto_active_effects.lua"
TREASURE_COMPAT = ROOT / "script" / "data" / "object_tables" / "treasure_catalog_compat.lua"
SYNC_RUNTIME_EDITOR_OBJECTS = ROOT / "script" / "tools" / "sync_runtime_editor_objects.py"

ABILITY_IDS = [
    201390001,
    201390002,
    201390003,
    201390004,
    201390005,
    201390006,
    201390007,
    201390008,
    201390009,
    201390010,
    201390011,
    201390012,
    201390013,
    201390014,
    201390015,
    201390016,
]

ABILITY_ALLOWED_KV_KEYS = [
    "entry_cast_effect_id",
    "entry_cast_scale",
    "entry_cast_time",
    "entry_impact_effect_id",
    "entry_impact_scale",
    "entry_impact_time",
    "entry_explosion_effect_id",
    "entry_explosion_scale",
    "entry_explosion_time",
    "entry_charge_effect_id",
    "entry_charge_scale",
    "entry_charge_time",
    "entry_chain_effect_id",
    "entry_chain_scale",
    "entry_chain_time",
]

MODIFIER_IDS = [
    201365014,
    201390101,
    201390102,
    201390103,
    201390104,
    201390105,
]

PROJECTILE_IDS = [
    134267104,
    134255909,
    134264830,
    134254402,
    134278613,
    201364743,
    201364744,
    201364745,
    201364746,
    201364747,
    201364748,
    201364749,
    201364750,
    201364751,
    201364752,
    201364753,
]

PROJECTILE_ALLOWED_KV_KEYS = [
    "entry_projectile_speed",
    "entry_projectile_time",
    "entry_target_distance",
    "entry_strike_delay",
]
ABILITY_VISIBLE_STAGE_FIELD_MAP = {
    "entry_cast_effect_id": "cst_sfx_list",
    "entry_impact_effect_id": "hit_sfx_list",
    "entry_explosion_effect_id": "end_sfx_list",
    "entry_charge_effect_id": "sp_sfx_list",
    "entry_chain_effect_id": "bs_sfx_list",
}

EQUIPMENT_ITEM_IDS = [
    201390081,
    201390082,
    201390083,
    201390084,
    201390085,
    201390086,
    201390087,
    201390088,
    201390089,
    201390090,
]

EQUIPMENT_REQUIRED_KV_KEYS = [
    "entry_item_kind",
    "entry_archetype",
    "entry_tags",
    "entry_summary",
    "entry_attr_pack",
    "entry_active_ability",
    "entry_passive_abilities",
    "entry_handler",
]

TREASURE_ITEM_IDS = [201390200 + index for index in range(1, 23)]

TREASURE_REQUIRED_KV_KEYS = [
    "entry_item_kind",
    "entry_runtime_treasure_id",
    "entry_quality",
    "entry_category",
    "entry_summary",
    "entry_duration",
    "entry_effects",
    "entry_set",
    "entry_handler",
]

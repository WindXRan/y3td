#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LANGUAGE_PATH = ROOT / "zhlanguage.json"
ABILITY_DIR = ROOT / "editor_table" / "abilityall"
MODIFIER_DIR = ROOT / "editor_table" / "modifierall"
ABILITY_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_ability_all.json"
MODIFIER_FOLDERINFO_PATH = ROOT / "editor" / "folderinfo" / "folderinfo_modifier_all.json"
REGISTRY_PATH = ROOT / "script" / "data" / "object_tables" / "runtime_editor_ids.lua"
ATTACK_SKILLS_LUA = ROOT / "script" / "data" / "object_tables" / "attack_skills.lua"
RUNTIME_ATTACK_SKILLS = ROOT / "script" / "runtime" / "attack_skills.lua"
RUNTIME_AUTO_EFFECTS = ROOT / "script" / "runtime" / "auto_active_effects.lua"

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

MODIFIER_IDS = [
    201365014,
    201390101,
    201390102,
    201390103,
    201390104,
    201390105,
]


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def assert_contains(text, needle, message):
    assert needle in text, message


def main():
    language = load_json(LANGUAGE_PATH)
    ability_folderinfo = load_json(ABILITY_FOLDERINFO_PATH)
    modifier_folderinfo = load_json(MODIFIER_FOLDERINFO_PATH)

    for ability_id in ABILITY_IDS:
        path = ABILITY_DIR / f"{ability_id}.json"
        assert path.exists(), f"missing ability editor file: {path}"
        data = load_json(path)
        assert data["key"] == ability_id, f"ability {ability_id} key mismatch"
        assert data["uid"] == str(ability_id), f"ability {ability_id} uid mismatch"
        assert language.get(str(data["name"])), f"ability {ability_id} missing name language"
        assert language.get(str(data["description"])), f"ability {ability_id} missing description language"
        assert str(ability_id) in ability_folderinfo["d"], f"ability {ability_id} missing folder mapping"

    for modifier_id in MODIFIER_IDS:
        path = MODIFIER_DIR / f"{modifier_id}.json"
        assert path.exists(), f"missing modifier editor file: {path}"
        data = load_json(path)
        assert data["key"] == modifier_id, f"modifier {modifier_id} key mismatch"
        assert data["uid"] == str(modifier_id), f"modifier {modifier_id} uid mismatch"
        assert language.get(str(data["name"])), f"modifier {modifier_id} missing name language"
        assert language.get(str(data["description"])), f"modifier {modifier_id} missing description language"
        assert str(modifier_id) in modifier_folderinfo["d"], f"modifier {modifier_id} missing folder mapping"

    registry_text = REGISTRY_PATH.read_text(encoding="utf-8")
    attack_skill_loader = ATTACK_SKILLS_LUA.read_text(encoding="utf-8")
    runtime_attack_skills = RUNTIME_ATTACK_SKILLS.read_text(encoding="utf-8")
    runtime_auto_effects = RUNTIME_AUTO_EFFECTS.read_text(encoding="utf-8")

    assert_contains(registry_text, "basic_attack = 201390001", "registry missing basic_attack id")
    assert_contains(registry_text, "fighting_spirit_field = 201365014", "registry missing fighting_spirit_field id")
    assert_contains(attack_skill_loader, "editor_ability_key = RuntimeEditorIds.ability[row.id]", "attack skill loader should expose editor ability key")
    assert_contains(runtime_attack_skills, "ATTACK_STATUS_MODIFIER_KEYS", "runtime attack skills should consume status modifier ids")
    assert_contains(runtime_auto_effects, "MODIFIER_KEYS.rapid_overdrive", "runtime auto effects should consume rapid overdrive modifier id")
    assert_contains(runtime_auto_effects, "MODIFIER_KEYS.charge_breaker_rally", "runtime auto effects should consume charge breaker rally modifier id")

    print("runtime editor object sync checks passed")


if __name__ == "__main__":
    main()

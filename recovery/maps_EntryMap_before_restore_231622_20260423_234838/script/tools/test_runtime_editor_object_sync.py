#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import importlib.util
import json
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


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def kv_value(entry):
    if isinstance(entry, dict) and "value" in entry:
        return entry["value"]
    return entry


def assert_editor_kv_entry(kv, key, object_label):
    entry = kv[key]
    assert isinstance(entry, dict), f"{object_label} kv field {key} should use editor descriptor objects"
    assert entry.get("key") == key, f"{object_label} kv field {key} should preserve key metadata"
    assert "value" in entry, f"{object_label} kv field {key} should expose a value payload"


def assert_meaningful_visual_kv(kv, key, object_label):
    assert_editor_kv_entry(kv, key, object_label)
    value = kv_value(kv[key])
    assert value not in (None, ""), f"{object_label} kv field {key} should not be empty"
    if isinstance(value, (int, float)):
        assert value > 0, f"{object_label} kv field {key} should skip zero placeholders"


def assert_contains(text, needle, message):
    assert needle in text, message


def get_primary_projectile_effect(effect_field):
    if isinstance(effect_field, list) and effect_field:
        return int(effect_field[0])
    if isinstance(effect_field, dict):
        items = effect_field.get("items")
        if isinstance(items, list) and items:
            return int(items[0])
    return 0


def get_first_visible_stage_effect(effect_field):
    if isinstance(effect_field, dict):
        items = effect_field.get("items")
        if isinstance(items, list) and items:
            first = items[0]
            if isinstance(first, list) and first:
                return int(first[0])
            if isinstance(first, dict):
                inner = first.get("items")
                if isinstance(inner, list) and inner:
                    return int(inner[0])
    if isinstance(effect_field, list) and effect_field:
        first = effect_field[0]
        if isinstance(first, list) and first:
            return int(first[0])
    return 0


def treasure_runtime_id(item_id: int) -> str:
    return f"ITEM_{item_id - 201390200:03d}"


def load_sync_module():
    spec = importlib.util.spec_from_file_location(
        "sync_runtime_editor_objects_under_test",
        SYNC_RUNTIME_EDITOR_OBJECTS,
    )
    assert spec and spec.loader, "sync_runtime_editor_objects.py should be importable"
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_sync_runtime_editor_objects_reads_visible_stage_effects():
    sync = load_sync_module()
    ability_data = {
        "cst_sfx_list": {
            "__tuple__": True,
            "items": [[104001, [0, 0, 0], [0, 0, 0], [1.25, 1.25, 1.25], 0.4, "origin", True, True, 1, False]],
        },
        "hit_sfx_list": {
            "__tuple__": True,
            "items": [[104002, [0, 0, 0], [0, 0, 0], [0.75, 0.75, 0.75], 0.2, "origin", True, True, 1, False]],
        },
    }
    projectile_data = {"effect_foes": [101175], "effect_friend": [101175]}

    manifest = sync.build_visual_manifest(
        {"id": "test_skill", "name": "测试技能"},
        201390001,
        134267104,
        ability_data,
        projectile_data,
        {},
        {},
        {},
    )

    assert manifest["entry_cast_effect_id"] == 104001, "visible cast stage should feed the runtime manifest"
    assert manifest["entry_cast_scale"] == 1.25, "visible cast stage scale should be preserved"
    assert manifest["entry_cast_time"] == 0.4, "visible cast stage time should be preserved"
    assert manifest["entry_impact_effect_id"] == 104002, "visible hit stage should feed the runtime manifest"
    assert manifest["entry_impact_scale"] == 0.75, "visible hit stage scale should be preserved"
    assert manifest["entry_impact_time"] == 0.2, "visible hit stage time should be preserved"


def test_sync_runtime_editor_objects_preserves_extra_visible_stage_entries():
    sync = load_sync_module()
    ability_data = {
        "cst_sfx_list": {
            "__tuple__": True,
            "items": [
                [999001, [1, 2, 3], [4, 5, 6], [0.9, 0.9, 0.9], 0.2, "HeadM", False, False, 2, True],
                [999002, [0, 0, 0], [0, 0, 0], [1.0, 1.0, 1.0], 0.1, "origin", True, True, 1, False],
            ],
        }
    }

    sync.apply_visible_stage_sfx_fields(
        ability_data,
        {
            "entry_cast_effect_id": 104501,
            "entry_cast_scale": 1.4,
            "entry_cast_time": 0.55,
        },
    )

    items = ability_data["cst_sfx_list"]["items"]
    assert items[0][0] == 104501, "primary visible stage should mirror the synced effect id"
    assert items[0][1] == [1, 2, 3], "existing offset payload should be preserved"
    assert items[0][2] == [4, 5, 6], "existing rotation payload should be preserved"
    assert items[0][3] == [1.4, 1.4, 1.4], "synced scale should rewrite the visible payload"
    assert items[0][4] == 0.55, "synced time should rewrite the visible payload"
    assert items[0][5] == "HeadM", "existing socket should be preserved"
    assert items[0][6] is False, "existing visibility flags should be preserved"
    assert items[0][7] is False, "existing attachment flags should be preserved"
    assert items[0][8] == 2, "existing blend mode should be preserved"
    assert items[0][9] is True, "existing cleanup flag should be preserved"
    assert items[1][0] == 999002, "additional visible stage entries should remain intact"


def main():
    language = load_json(LANGUAGE_PATH)
    ability_folderinfo = load_json(ABILITY_FOLDERINFO_PATH)
    item_folderinfo = load_json(ITEM_FOLDERINFO_PATH)
    modifier_folderinfo = load_json(MODIFIER_FOLDERINFO_PATH)
    projectile_folderinfo = load_json(PROJECTILE_FOLDERINFO_PATH)

    for ability_id in ABILITY_IDS:
        path = ABILITY_DIR / f"{ability_id}.json"
        assert path.exists(), f"missing ability editor file: {path}"
        data = load_json(path)
        assert data["key"] == ability_id, f"ability {ability_id} key mismatch"
        assert data["uid"] == str(ability_id), f"ability {ability_id} uid mismatch"
        assert isinstance(data.get("kv"), dict), f"ability {ability_id} should expose visual manifest kv"
        assert set(data["kv"]).issubset(set(ABILITY_ALLOWED_KV_KEYS)), (
            f"ability {ability_id} should only keep stage-effect kv fields"
        )
        assert "entry_skill_id" not in data["kv"], f"ability {ability_id} should not duplicate runtime ids in kv"
        assert "entry_ability_id" not in data["kv"], f"ability {ability_id} should not duplicate ability id in kv"
        assert "entry_projectile_id" not in data["kv"], f"ability {ability_id} should not duplicate projectile id in kv"
        assert "entry_projectile_speed" not in data["kv"], f"ability {ability_id} should not store projectile motion kv"
        for kv_key in data["kv"]:
            assert_meaningful_visual_kv(data["kv"], kv_key, f"ability {ability_id}")
        for kv_key, field_name in ABILITY_VISIBLE_STAGE_FIELD_MAP.items():
            kv_effect_id = int(kv_value(data["kv"].get(kv_key)) or 0)
            visible_effect_id = get_first_visible_stage_effect(data.get(field_name))
            if kv_effect_id > 0:
                assert visible_effect_id == kv_effect_id, (
                    f"ability {ability_id} visible field {field_name} should mirror {kv_key}"
                )
        assert language.get(str(data["name"])), f"ability {ability_id} missing name language"
        assert language.get(str(data["description"])), f"ability {ability_id} missing description language"
        assert str(ability_id) in ability_folderinfo["d"], f"ability {ability_id} missing folder mapping"
        description = language[str(data["description"])]
        assert f"技能物编ID：{ability_id}" in description, f"ability {ability_id} description should include editor id"
        assert "投射物物编ID：" in description, f"ability {ability_id} description should include projectile id"
        assert "飞行特效ID：" in description, f"ability {ability_id} description should include projectile effect"

    for modifier_id in MODIFIER_IDS:
        path = MODIFIER_DIR / f"{modifier_id}.json"
        assert path.exists(), f"missing modifier editor file: {path}"
        data = load_json(path)
        assert data["key"] == modifier_id, f"modifier {modifier_id} key mismatch"
        assert data["uid"] == str(modifier_id), f"modifier {modifier_id} uid mismatch"
        assert language.get(str(data["name"])), f"modifier {modifier_id} missing name language"
        assert language.get(str(data["description"])), f"modifier {modifier_id} missing description language"
        assert str(modifier_id) in modifier_folderinfo["d"], f"modifier {modifier_id} missing folder mapping"

    for item_id in EQUIPMENT_ITEM_IDS:
        path = ITEM_DIR / f"{item_id}.json"
        assert path.exists(), f"missing equipment editor item: {path}"
        data = load_json(path)
        assert data["key"] == item_id, f"equipment item {item_id} key mismatch"
        assert data["uid"] == str(item_id), f"equipment item {item_id} uid mismatch"
        assert isinstance(data.get("kv"), dict), f"equipment item {item_id} should expose kv manifest"
        for kv_key in EQUIPMENT_REQUIRED_KV_KEYS:
            assert kv_key in data["kv"], f"equipment item {item_id} missing kv field {kv_key}"
            assert_editor_kv_entry(data["kv"], kv_key, f"equipment item {item_id}")
        assert kv_value(data["kv"]["entry_item_kind"]) == "equipment", f"equipment item {item_id} kind mismatch"
        assert kv_value(data["kv"]["entry_handler"]) == "editor_item_builtin", f"equipment item {item_id} handler mismatch"
        assert len(data["kv"]) <= 8, f"equipment item {item_id} kv should stay compact"

    equipment_082 = load_json(ITEM_DIR / "201390082.json")["kv"]
    assert kv_value(equipment_082["entry_passive_abilities"]) == "134256699@1", "洪荒之刃 passive ability id mismatch"

    equipment_085 = load_json(ITEM_DIR / "201390085.json")["kv"]
    assert kv_value(equipment_085["entry_active_ability"]) == "134272159@1", "弥勒杖 should expose active ability id"
    assert kv_value(equipment_085["entry_attr_pack"]), "弥勒杖 should expose attached attr pack"

    equipment_090 = load_json(ITEM_DIR / "201390090.json")["kv"]
    assert kv_value(equipment_090["entry_active_ability"]) == "134262702@1", "天玄蚀灵 should expose active ability id"
    assert kv_value(equipment_090["entry_passive_abilities"]) == "134250605@1", "天玄蚀灵 passive ability id mismatch"

    for projectile_id in PROJECTILE_IDS:
        path = PROJECTILE_DIR / f"{projectile_id}.json"
        assert path.exists(), f"missing projectile editor file: {path}"
        data = load_json(path)
        assert data["key"] == projectile_id, f"projectile {projectile_id} key mismatch"
        assert data["uid"] == str(projectile_id), f"projectile {projectile_id} uid mismatch"
        assert language.get(str(data["description"])), f"projectile {projectile_id} missing description language"
        assert str(projectile_id) in projectile_folderinfo["d"], f"projectile {projectile_id} missing folder mapping"
        assert isinstance(data.get("kv"), dict), f"projectile {projectile_id} should expose vfx manifest kv"
        assert set(data["kv"]).issubset(set(PROJECTILE_ALLOWED_KV_KEYS)), (
            f"projectile {projectile_id} should only keep projectile-visual kv fields"
        )
        assert 1 <= len(data["kv"]) <= 4, f"projectile {projectile_id} should keep a minimal kv footprint"
        for kv_key in data["kv"]:
            assert_meaningful_visual_kv(data["kv"], kv_key, f"projectile {projectile_id}")

        description = language[str(data["description"])]
        assert f"投射物物编ID：{projectile_id}" in description, f"projectile {projectile_id} description should include editor id"
        assert "飞行特效ID：" in description, f"projectile {projectile_id} description should list projectile effect"
        assert "特效：ID 无" not in description, f"projectile {projectile_id} description should skip zero-effect placeholders"
        assert "缩放 0 / 时长 0" not in description, f"projectile {projectile_id} description should skip zero stage payloads"

    basic_attack_projectile = load_json(PROJECTILE_DIR / "134267104.json")["kv"]
    assert kv_value(basic_attack_projectile["entry_projectile_speed"]) == 3760.0, (
        "basic attack projectile should expose flight speed"
    )
    assert kv_value(basic_attack_projectile["entry_projectile_time"]) == 2.9, (
        "basic attack projectile should expose flight time"
    )
    assert kv_value(basic_attack_projectile["entry_target_distance"]) == 28.0, (
        "basic attack projectile should expose impact convergence"
    )

    meteor_projectile = load_json(PROJECTILE_DIR / "201364747.json")["kv"]
    assert kv_value(meteor_projectile["entry_strike_delay"]) == 0.6, (
        "meteor projectile should expose delayed strike timing"
    )

    chain_lightning_projectile = load_json(PROJECTILE_DIR / "134278613.json")["kv"]
    assert kv_value(chain_lightning_projectile["entry_strike_delay"]) == 0.08, (
        "chain lightning projectile should expose short strike delay"
    )

    for item_id in TREASURE_ITEM_IDS:
        path = ITEM_DIR / f"{item_id}.json"
        runtime_id = treasure_runtime_id(item_id)
        assert path.exists(), f"missing treasure editor item: {path}"
        data = load_json(path)
        assert data["key"] == item_id, f"treasure item {item_id} key mismatch"
        assert data["uid"] == str(item_id), f"treasure item {item_id} uid mismatch"
        assert isinstance(data.get("kv"), dict), f"treasure item {item_id} should expose kv manifest"
        for kv_key in TREASURE_REQUIRED_KV_KEYS:
            assert kv_key in data["kv"], f"treasure item {item_id} missing kv field {kv_key}"
            assert_editor_kv_entry(data["kv"], kv_key, f"treasure item {item_id}")
        assert kv_value(data["kv"]["entry_item_kind"]) == "treasure", f"treasure item {item_id} kind mismatch"
        assert kv_value(data["kv"]["entry_runtime_treasure_id"]) == runtime_id, f"treasure item {item_id} runtime id mismatch"
        assert kv_value(data["kv"]["entry_handler"]) == "runtime.rewards", f"treasure item {item_id} handler mismatch"
        assert len(data["kv"]) <= 9, f"treasure item {item_id} kv should stay compact"
        assert language.get(str(data["name"])), f"treasure item {item_id} missing name language"
        assert language.get(str(data["description"])), f"treasure item {item_id} missing description language"
        assert str(item_id) in item_folderinfo["d"], f"treasure item {item_id} missing folder mapping"
        description = language[str(data["description"])]
        assert f"运行时宝物ID：{runtime_id}" in description, f"treasure item {item_id} description should include runtime id"
        assert f"宝物物编ID：{item_id}" in description, f"treasure item {item_id} description should include editor id"

    item_004 = load_json(ITEM_DIR / "201390204.json")["kv"]
    assert kv_value(item_004["entry_duration"]) == "timed:30s:immediate", "ITEM_004 should expose compact timed duration"
    assert "temporary_buff:物理暴击:add:0.5:30s" in kv_value(item_004["entry_effects"]), "ITEM_004 should expose crit effect summary"

    item_010 = load_json(ITEM_DIR / "201390210.json")["kv"]
    assert "refresh_count:skill_refresh_free:add:1:instant" in kv_value(item_010["entry_effects"]), "ITEM_010 should expose refresh summary"
    assert kv_value(item_010["entry_set"]) == "", "ITEM_010 should not expose set summary"

    item_012 = load_json(ITEM_DIR / "201390212.json")["kv"]
    assert "mechanic_toggle:randomize_base_stats:set:1:instant" in kv_value(item_012["entry_effects"]), "ITEM_012 should expose mechanic summary"

    item_015 = load_json(ITEM_DIR / "201390215.json")["kv"]
    assert "暴伤(2件)" in kv_value(item_015["entry_set"]), "ITEM_015 should expose set name"
    assert "ratio_bonus:物理暴击:add:0.05" in kv_value(item_015["entry_set"]), "ITEM_015 should expose set effect summary"

    registry_text = REGISTRY_PATH.read_text(encoding="utf-8")
    attack_skill_loader = ATTACK_SKILLS_LUA.read_text(encoding="utf-8")
    runtime_attack_skills = RUNTIME_ATTACK_SKILLS.read_text(encoding="utf-8")
    runtime_auto_effects = RUNTIME_AUTO_EFFECTS.read_text(encoding="utf-8")
    treasure_compat = TREASURE_COMPAT.read_text(encoding="utf-8")

    assert_contains(registry_text, "basic_attack = 201390001", "registry missing basic_attack id")
    assert_contains(registry_text, "projectile = {", "registry missing projectile section")
    assert_contains(registry_text, "fireball = 201364749", "registry missing fireball projectile id")
    assert_contains(registry_text, "treasure = {", "registry missing treasure section")
    assert_contains(registry_text, "ITEM_004 = 201390204", "registry missing ITEM_004 editor item id")
    assert_contains(registry_text, "ITEM_022 = 201390222", "registry missing ITEM_022 editor item id")
    assert_contains(registry_text, "fighting_spirit_field = 201365014", "registry missing fighting_spirit_field id")
    assert_contains(attack_skill_loader, "local editor_ability_key = RuntimeEditorIds.ability[row.id]", "attack skill loader should expose editor ability key")
    assert_contains(attack_skill_loader, "local editor_projectile_key = RuntimeEditorIds.projectile and RuntimeEditorIds.projectile[row.id] or nil", "attack skill loader should expose editor projectile key")
    assert "attack_skill_vfx.csv" not in attack_skill_loader, "attack skill loader should no longer source visuals from csv"
    assert_contains(attack_skill_loader, "get_editor_kv('abilityall', ability_key)", "attack skill loader should read ability editor kv manifests")
    assert_contains(attack_skill_loader, "get_editor_kv('projectileall', projectile_key)", "attack skill loader should read projectile editor kv manifests")
    assert_contains(attack_skill_loader, "local function unwrap_editor_kv_entry(raw)", "attack skill loader should unwrap editor kv descriptor values")
    assert_contains(attack_skill_loader, "'../editor_table/%s/%s.json'", "attack skill loader should support script-root relative editor_table lookups")
    assert_contains(attack_skill_loader, "local local_json_data = load_editor_json(table_name, object_key)", "attack skill loader should prefer local generated editor json")
    assert_contains(attack_skill_loader, "if local_json_data then", "attack skill loader should return local generated editor json when present")
    assert_contains(attack_skill_loader, "local ABILITY_VISIBLE_STAGE_FIELD_MAP = {", "attack skill loader should map visible ability stage fields")
    assert_contains(attack_skill_loader, "apply_visible_ability_vfx(result, ability_data)", "attack skill loader should read visible ability stage vfx as fallback")
    assert_contains(runtime_attack_skills, "ATTACK_STATUS_MODIFIER_KEYS", "runtime attack skills should consume status modifier ids")
    assert_contains(runtime_auto_effects, "MODIFIER_KEYS.rapid_overdrive", "runtime auto effects should consume rapid overdrive modifier id")
    assert_contains(runtime_auto_effects, "MODIFIER_KEYS.charge_breaker_rally", "runtime auto effects should consume charge breaker rally modifier id")
    assert_contains(treasure_compat, "local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'", "treasure compat should load runtime editor ids")
    assert_contains(treasure_compat, "editor_item_key = RuntimeEditorIds.treasure and RuntimeEditorIds.treasure[item.id] or nil", "treasure compat should expose editor item key")

    print("runtime editor object sync checks passed")


def test_runtime_editor_object_sync_main():
    main()


if __name__ == "__main__":
    main()

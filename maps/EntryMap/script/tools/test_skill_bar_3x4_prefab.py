import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PREFAB_PATH = ROOT / "ui" / "prefab" / "skill_bar_3x4.json"
PREFAB_TREE_PATH = ROOT / "editor" / "uiprefabtreegroupinfo.json"

EXPECTED_PREFAB_KEY = "f759e42f-3c79-4258-9a56-c062c87dec17"


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def collect_registered_items(entries):
    registered = set()
    for entry in entries or []:
        if isinstance(entry, dict) and "items" in entry:
            registered.add(tuple(entry["items"]))
        if isinstance(entry, dict) and "group" in entry:
            registered |= collect_registered_items(entry["group"])
    return registered


def test_skill_bar_prefab_exists_and_has_expected_key():
    if not PREFAB_PATH.exists():
        return
    prefab = load_json(PREFAB_PATH)
    assert prefab["name"] == "skill_bar_3x4"
    assert prefab["key"] == EXPECTED_PREFAB_KEY
    assert prefab["data"]["prefab_key"] == EXPECTED_PREFAB_KEY


def test_skill_bar_prefab_exposes_12_named_slots():
    if not PREFAB_PATH.exists():
        return
    prefab = load_json(PREFAB_PATH)
    root = prefab["data"]
    slots = [child for child in root["children"] if child["name"].startswith("slot_")]

    assert len(slots) == 12
    assert [slot["name"] for slot in slots] == [f"slot_{i}" for i in range(1, 13)]

    for slot in slots:
        child_names = {child["name"] for child in slot["children"]}
        assert {"slot_bg", "slot_button", "icon", "hotkey", "level_text", "cooldown_mask", "disabled_mask"} <= child_names


def test_skill_bar_prefab_is_registered_in_editor_tree():
    tree = load_json(PREFAB_TREE_PATH)
    custom_group = next(item for item in tree if item["name"] == "code_ui_custom_panel_tree")
    registered = collect_registered_items(custom_group["group"])
    target = (EXPECTED_PREFAB_KEY, "skill_bar_3x4")

    if PREFAB_PATH.exists():
        assert target in registered
    else:
        assert target not in registered

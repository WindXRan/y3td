from pathlib import Path
import json


ROOT = Path(__file__).resolve().parents[4]
UI_PATH = ROOT / "maps" / "EntryMap" / "ui" / "outgame.json"
TREE_PATH = ROOT / "maps" / "EntryMap" / "ui_tree" / "outgame_Tree.json"
PANEL_TREE_INFO_PATH = ROOT / "maps" / "EntryMap" / "editor" / "uipaneltreegroupinfo.json"


def assert_close_pair(actual, expected, eps=0.01):
    assert len(actual) == len(expected)
    for a, e in zip(actual, expected):
        assert abs(a - e) <= eps


def test_outgame_ui_exists_and_has_root_nodes():
    ui = json.loads(UI_PATH.read_text(encoding="utf-8"))
    assert ui["name"] == "outgame"
    assert ui["children"][0]["name"] == "大厅"
    layout = ui["children"][0]["children"][0]
    assert layout["name"] == "layout"
    child_names = {child["name"] for child in layout["children"]}
    assert "start" in child_names
    assert "left_2" in child_names
    assert "right_2" in child_names
    positions = {child["name"]: child["pos_data"]["items"][:2] for child in layout["children"] if "pos_data" in child}
    assert_close_pair(positions["left"], [180, 530])
    assert_close_pair(positions["left_2"], [958, 585])
    assert_close_pair(positions["right"], [1704, 530])
    assert_close_pair(positions["right_2"], [1704, 520])
    assert_close_pair(positions["footer"], [178, 70])
    assert_close_pair(positions["save_anchor"], [178, 474])
    percentages = {child["name"]: child["pos_data"]["items"][2:4] for child in layout["children"] if "pos_data" in child}
    assert_close_pair(percentages["left"], [9.375, 49.0741])
    assert_close_pair(percentages["left_2"], [49.8958, 54.1667])
    assert_close_pair(percentages["right"], [88.75, 49.0741])
    assert_close_pair(percentages["right_2"], [88.75, 48.1481])
    assert_close_pair(percentages["footer"], [9.2708, 6.4815])
    assert_close_pair(percentages["save_anchor"], [9.2708, 43.8889])


def test_outgame_mode_and_difficulty_slot_count_matches_reference():
    ui = json.loads(UI_PATH.read_text(encoding="utf-8"))
    layout = ui["children"][0]["children"][0]
    mode_list = next(child for child in layout["children"] if child["name"] == "left_2")["children"][0]["children"]
    difficulty_list = next(child for child in layout["children"] if child["name"] == "right_2")["children"][0]["children"]
    mode_names = [child["name"] for child in mode_list]
    difficulty_names = [child["name"] for child in difficulty_list]
    assert "主线模式" in mode_names
    assert "猎场模式" in mode_names
    assert difficulty_names[1:8] == ["mode1", "mode2", "mode3", "mode4", "mode5", "mode6", "mode7"]


def test_outgame_footer_slot_has_avatar_node():
    ui = json.loads(UI_PATH.read_text(encoding="utf-8"))
    layout = ui["children"][0]["children"][0]
    footer = next(child for child in layout["children"] if child["name"] == "footer")
    slot_1 = next(child for child in footer["children"] if child["name"] == "slot_1")
    child_names = {child["name"] for child in slot_1["children"]}
    assert "frame" in child_names
    assert "inner" in child_names
    assert "avatar" in child_names


def test_outgame_tree_exists():
    tree = json.loads(TREE_PATH.read_text(encoding="utf-8"))
    assert tree["name"] == "outgame"


def test_outgame_registered_in_editor_panel_tree():
    panel_tree_info = json.loads(PANEL_TREE_INFO_PATH.read_text(encoding="utf-8"))
    custom = next(item for item in panel_tree_info if item["name"] == "code_ui_custom_panel_tree")
    names = [entry["items"][1] for entry in custom["group"]]
    assert "outgame" in names

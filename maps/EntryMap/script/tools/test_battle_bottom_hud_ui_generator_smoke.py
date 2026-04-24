from pathlib import Path
import json


ROOT = Path(__file__).resolve().parents[4]
UI_PATH = ROOT / "maps" / "EntryMap" / "ui" / "BattleBottomHUD.json"
TREE_PATH = ROOT / "maps" / "EntryMap" / "ui_tree" / "BattleBottomHUD_Tree.json"
PANEL_TREE_INFO_PATH = ROOT / "maps" / "EntryMap" / "editor" / "uipaneltreegroupinfo.json"


def find_child(parent, name):
    return next(child for child in parent["children"] if child["name"] == name)


def test_bottom_hud_ui_exists():
    ui = json.loads(UI_PATH.read_text(encoding="utf-8"))
    assert ui["name"] == "BattleBottomHUD"
    layout = ui["children"][0]
    assert layout["name"] == "layout"
    child_names = {child["name"] for child in layout["children"]}
    assert "bottom_shell" in child_names
    assert "left_station" in child_names
    assert "center_hub" in child_names
    assert "right_station" in child_names
    assert "reference_overlay" not in child_names


def test_bottom_hud_contains_expected_runtime_nodes():
    ui = json.loads(UI_PATH.read_text(encoding="utf-8"))
    layout = ui["children"][0]
    center_hub = find_child(layout, "center_hub")
    center_names = {child["name"] for child in center_hub["children"]}
    assert "hero_panel" in center_names
    combat_module = find_child(center_hub, "combat_module")
    combat_parent = combat_module
    combat_names = {child["name"] for child in combat_parent["children"]}
    assert "skill_bar" in combat_names
    assert "buff_row" in combat_names
    assert "exp_bar" in combat_names
    assert "status_text" in combat_names
    assert "challenge_row" not in combat_names

    skill_bar = find_child(combat_parent, "skill_bar")
    slot_names = {child["name"] for child in skill_bar["children"]}
    assert {"skill_slot_1", "skill_slot_2", "skill_slot_3", "skill_slot_4", "skill_slot_5"}.issubset(slot_names)

    buff_row = find_child(combat_parent, "buff_row")
    buff_names = {child["name"] for child in buff_row["children"]}
    assert {"buff_slot_1", "buff_slot_2", "buff_slot_3", "buff_slot_4", "buff_slot_5"}.issubset(buff_names)
    for index in range(1, 6):
        buff_slot = find_child(buff_row, f"buff_slot_{index}")
        assert find_child(buff_slot, "icon").get("image") is None

    right_station = find_child(layout, "right_station")
    right_names = {child["name"] for child in right_station["children"]}
    assert "loadout_row" in right_names
    assert "consumable_panel" in right_names
    assert "hover_tip_panel" in right_names
    assert "card_panel" in right_names

    loadout_row = find_child(right_station, "loadout_row")
    loadout_names = {child["name"] for child in loadout_row["children"]}
    assert {"loadout_slot_1", "loadout_slot_2", "loadout_slot_3", "loadout_slot_4", "loadout_slot_5", "loadout_slot_6"}.issubset(loadout_names)
    loadout_slots = [
        find_child(loadout_row, f"loadout_slot_{index}")
        for index in range(1, 7)
    ]
    slot_xs = sorted({int(slot["pos_data"]["items"][0]) for slot in loadout_slots})
    slot_ys = sorted({int(slot["pos_data"]["items"][1]) for slot in loadout_slots})
    assert len(slot_xs) == 2
    assert len(slot_ys) == 3
    for slot in loadout_slots:
        assert find_child(slot, "icon").get("image") is None

    consumable_panel = find_child(right_station, "consumable_panel")
    consumable_names = {child["name"] for child in consumable_panel["children"]}
    assert {"slot_1", "slot_2", "slot_3"}.issubset(consumable_names)
    assert "slot_4" not in consumable_names
    for index in range(1, 4):
        consumable_slot = find_child(consumable_panel, f"slot_{index}")
        assert find_child(consumable_slot, "icon").get("image") is None

    card_panel = find_child(right_station, "card_panel")
    card_names = {child["name"] for child in card_panel["children"]}
    assert "draw_button" in card_names
    assert "reward_button" in card_names
    assert "kill_reward_button" in card_names
    assert "fish_button" in card_names
    assert {"card_slot_1", "card_slot_2", "card_slot_3", "card_slot_4", "card_slot_5", "card_slot_6", "card_slot_7", "card_slot_8"}.issubset(card_names)
    for index in range(1, 9):
        card_slot = find_child(card_panel, f"card_slot_{index}")
        assert find_child(card_slot, "icon").get("image") is None

    left_station = find_child(layout, "left_station")
    left_names = {child["name"] for child in left_station["children"]}
    assert "mini_map" in left_names
    assert "toggle_frame" in left_names
    assert "player_attr_list" in left_names
    assert "player_name" not in left_names
    assert "slot_1" not in left_names

    mini_map = find_child(left_station, "mini_map")
    mini_map_o = find_child(mini_map, "mini_map_o")
    mini_map_1 = find_child(mini_map_o, "mini_map_1")
    assert mini_map_1["type"] == 16

    player_attr_list = find_child(left_station, "player_attr_list")
    attr_names = {child["name"] for child in player_attr_list["children"]}
    assert {"battle_power_row", "hero_attack_row", "hero_defense_row", "hero_power_row", "hero_intelligence_row", "hero_agility_row"}.issubset(attr_names)

    hero_panel = find_child(center_hub, "hero_panel")
    hero_names = {child["name"] for child in hero_panel["children"]}
    assert "hero_name" in hero_names
    assert "hero_model" in hero_names
    assert "hero_hp_bg" in hero_names
    assert "hero_hp_text" in hero_names
    assert "hero_portrait" not in hero_names
    hero_model = find_child(hero_panel, "hero_model")
    assert hero_model["type"] == 6
    hero_name = find_child(hero_panel, "hero_name")
    assert hero_name["alignment"]["items"][0] == 1


def test_bottom_hud_tree_and_registration_exists():
    tree = json.loads(TREE_PATH.read_text(encoding="utf-8"))
    assert tree["name"] == "BattleBottomHUD"

    panel_tree_info = json.loads(PANEL_TREE_INFO_PATH.read_text(encoding="utf-8"))
    custom = next(item for item in panel_tree_info if item["name"] == "code_ui_custom_panel_tree")
    names = [entry["items"][1] for entry in custom["group"]]
    assert "BattleBottomHUD" in names

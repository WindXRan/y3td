from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LAYOUT = ROOT / "script" / "ui" / "choice_panel_layout.lua"
PANEL = ROOT / "script" / "ui" / "choice_panel.lua"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def assert_not_contains(content: str, needle: str, message: str) -> None:
    if needle in content:
        raise AssertionError(message)


def main() -> None:
    layout = LAYOUT.read_text(encoding="utf-8")
    panel = PANEL.read_text(encoding="utf-8")

    assert_contains(layout, "design_width = 300", "bond layout should still keep the dedicated prefab design width")
    assert_contains(layout, "design_height = 445", "bond layout should still keep the dedicated prefab design height")
    assert_contains(layout, "effect_area_y_by_bonus_count", "bond layout should still define effect area offsets by visible bonus count")

    assert_contains(panel, "card_model.render_prefab", "choice panel should honor model-selected prefabs")
    assert_contains(panel, "y3.ui_prefab.create(player, prefab_name, parent)", "bond cards should be created through ui prefab creation")
    assert_contains(panel, "layout_1.label_set_progress", "bond prefab renderer should bind the set progress node")
    assert_contains(panel, "get_node_child(card.bonus_area, 'label_bonus_1')", "bond prefab renderer should resolve bonus rows from the bonus area container")
    assert_contains(panel, "get_node_child(card.effect_area, 'label_effect_index')", "bond prefab renderer should resolve effect index from the effect area container")
    assert_contains(panel, "get_node_child(card.effect_area, 'label_set_body_3')", "bond prefab renderer should resolve set effect rows from the effect area container")
    assert_not_contains(
        panel,
        "local create_card = use_bond_cards and create_bond_choice_card or create_choice_card",
        "bond cards should no longer bypass prefab rendering with runtime-created card layouts",
    )

    prefab_path = ROOT / "ui" / "prefab" / "bond_choice_card.json"
    prefab = __import__("json").loads(prefab_path.read_text(encoding="utf-8"))["data"]
    children = prefab["children"][0]["children"]
    by_name = {child["name"]: child for child in children}
    effect_children = {child["name"]: child for child in by_name["layout_effect_area"]["children"]}
    bonus_children = {child["name"]: child for child in by_name["layout_bonus_area"]["children"]}

    assert by_name["image_bottom_shade"].get("visible", True) is False, "bond card prefab should hide the obsolete bottom shade by default"
    assert tuple(by_name["label_item_name"]["size"]) == (224.0, 34.0), "bond card item title width should expand to the shared content width"
    assert tuple(by_name["label_set_name"]["size"]) == (190.0, 34.0), "bond card set title width should match the bond layout"
    assert tuple(by_name["label_set_progress"]["size"]) == (132.0, 22.0), "bond card progress text width should match the bond layout"
    assert tuple(by_name["layout_bonus_area"]["size"]) == (224.0, 72.0), "bond card bonus area should use the wider content column"
    assert tuple(bonus_children["layout_bonus_area_bg"]["size"]) == (224.0, 72.0), "bond card bonus area background should fill the wider content column"
    assert tuple(by_name["layout_effect_area"]["size"]) == (244.0, 126.0), "bond card effect area should match the runtime bond layout size"
    assert tuple(effect_children["layout_effect_area_bg"]["size"]) == (244.0, 126.0), "bond card effect area background should match the runtime bond layout size"
    assert tuple(effect_children["label_effect_body"]["size"]) == (224.0, 38.0), "bond card effect body height should allow the structured two-line copy"

    print("choice panel bond stack layout static ok")


if __name__ == "__main__":
    main()

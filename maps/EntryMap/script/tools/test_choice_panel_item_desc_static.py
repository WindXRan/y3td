from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PANEL = ROOT / "script" / "ui" / "choice_panel.lua"
MODEL = ROOT / "script" / "runtime" / "choice_panel_model.lua"
ITEM_DESC_PREFAB = ROOT / "ui" / "prefab" / "物品说明.json"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def assert_not_contains(content: str, needle: str, message: str) -> None:
    if needle in content:
        raise AssertionError(message)


def main() -> None:
    panel = PANEL.read_text(encoding="utf-8")
    model = MODEL.read_text(encoding="utf-8")

    if not ITEM_DESC_PREFAB.exists():
        raise AssertionError("Expected item desc prefab to exist")

    assert_contains(panel, "local ITEM_DESC_PREFAB = '物品说明'", "choice panel should declare the item desc prefab constant")
    assert_contains(panel, "y3.ui_prefab.create(player, ITEM_DESC_PREFAB, parent)", "choice panel should create item desc prefab cards")
    assert_contains(panel, "basic.title.title_TEXT", "choice panel should bind item desc title node")
    assert_contains(panel, "basic.title.subtitle_TEXT", "choice panel should bind item desc subtitle node")
    assert_contains(panel, "basic.avatar.icon", "choice panel should bind item desc icon node")
    assert_contains(panel, "note.note_TEXT", "choice panel should bind item desc note node")
    assert_contains(panel, "attr_LIST", "choice panel should bind item desc attr list")
    assert_contains(panel, "descr_LIST", "choice panel should bind item desc descr list")
    assert_contains(panel, "min_visible_rows = 4", "choice panel should reserve four visible attr rows for stable card height")
    assert_contains(panel, "card.uses_item_desc_renderer == true", "choice panel should render item desc cards in the refresh loop")
    assert_not_contains(panel, "create_bond_choice_card", "choice panel should not keep the retired dedicated bond card builder")
    assert_not_contains(panel, "bond_choice_card", "choice panel should not reference the retired dedicated bond card prefab")
    assert_not_contains(panel, "layout.bond", "choice panel should not depend on the retired bond-only layout section")

    assert_contains(model, "use_item_desc_card = true", "choice panel model should mark cards for item desc rendering")
    assert_contains(model, "local function build_upgrade_item_desc_payload", "choice panel model should define a skill template helper")
    assert_contains(model, "local function build_bond_item_desc_payload", "choice panel model should define a bond template helper")
    assert_contains(model, "local function build_treasure_item_desc_payload", "choice panel model should define a treasure template helper")
    assert_contains(model, "local function build_mark_item_desc_payload", "choice panel model should define a mark template helper")
    assert_contains(model, "item_desc_payload = build_upgrade_item_desc_payload", "choice panel model should use the skill template helper")
    assert_contains(model, "item_desc_payload = build_bond_item_desc_payload", "choice panel model should use the bond template helper")
    assert_contains(model, "item_desc_payload = build_treasure_item_desc_payload", "choice panel model should use the treasure template helper")
    assert_contains(model, "item_desc_payload = build_mark_item_desc_payload", "choice panel model should use the mark template helper")
    assert_contains(model, "split_compound_bonus_segments", "choice panel model should split compound bonus text into multiple attr rows")

    print("choice panel item desc static ok")


if __name__ == "__main__":
    main()

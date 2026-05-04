import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PANEL_PATH = ROOT / "ui" / "panel_2.json"
UI_PANEL_TREE_PATH = ROOT / "editor" / "uipaneltreegroupinfo.json"


def test_editor_panel_tree_is_consistent_with_panel2_asset():
    data = json.loads(UI_PANEL_TREE_PATH.read_text(encoding="utf-8"))

    custom_tree = next(item for item in data if item.get("name") == "code_ui_custom_panel_tree")
    panel_names = [entry["items"][1] for entry in custom_tree.get("group", []) if isinstance(entry, dict) and "items" in entry]

    if PANEL_PATH.exists():
        assert "panel_2" in panel_names, "editor panel tree should register panel_2 so it appears in the editor"
    else:
        assert "panel_2" not in panel_names, "editor panel tree should not register missing panel_2"


if __name__ == "__main__":
    test_editor_panel_tree_is_consistent_with_panel2_asset()

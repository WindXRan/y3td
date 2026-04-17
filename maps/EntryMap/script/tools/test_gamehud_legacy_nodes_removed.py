import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GAMEHUD_PATH = ROOT / "ui" / "GameHUD.json"
REQUIRED_NAMES = {
    "GameHUD",
    "main",
    "main_unit",
    "main_hp_bar",
    "main_mp_bar",
    "inventory",
    "skill_list",
    "tips_node",
}


def walk_names(node):
    yield node.get("name")
    for child in node.get("children", []):
        yield from walk_names(child)


def test_gamehud_current_runtime_nodes_present():
    data = json.loads(GAMEHUD_PATH.read_text(encoding="utf-8"))
    all_names = set(walk_names(data))

    missing = REQUIRED_NAMES - all_names
    assert not missing, f"GameHUD current runtime nodes missing: {sorted(missing)}"
    assert "hud_root" not in all_names


if __name__ == "__main__":
    test_gamehud_current_runtime_nodes_present()

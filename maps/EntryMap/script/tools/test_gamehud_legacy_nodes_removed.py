import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GAMEHUD_PATH = ROOT / "ui" / "GameHUD.json"
LEGACY_NAMES = {
    "main_hp_bar",
    "main_mp_bar",
    "player_attr_list",
    "inventory",
    "bag_btn",
    "bag",
    "hero_1",
    "hero_2",
    "hero_3",
    "hero_4",
    "hero_5",
    "hero_6",
    "hero_7",
    "hero_8",
    "hero_9",
    "hero_10",
    "hero_11",
    "hero_12",
}


def walk_names(node):
    yield node.get("name")
    for child in node.get("children", []):
        yield from walk_names(child)


def test_gamehud_legacy_nodes_removed():
    data = json.loads(GAMEHUD_PATH.read_text(encoding="utf-8"))
    all_names = set(walk_names(data))

    assert "hud_root" in all_names

    remaining = LEGACY_NAMES & all_names
    assert not remaining, f"Legacy GameHUD nodes still present: {sorted(remaining)}"


if __name__ == "__main__":
    test_gamehud_legacy_nodes_removed()

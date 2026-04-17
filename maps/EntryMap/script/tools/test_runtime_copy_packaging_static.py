import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"
RUNTIME_HUD_PATH = ROOT / "ui" / "runtime_hud.lua"
RUNTIME_HUD_PANEL1_TOP_PATH = ROOT / "ui" / "runtime_hud_panel1_top.lua"
STAGES_CSV_PATH = ROOT / "data_csv" / "stages.csv"
PANEL_JSON_PATH = ROOT.parent / "ui" / "MainlineTaskPanel.json"
PANEL_TREE_PATH = ROOT.parent / "ui_tree" / "MainlineTaskPanel_Tree.json"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def find_node_text(node: dict, name: str):
    if not isinstance(node, dict):
        return None
    if node.get("name") == name:
        text = node.get("text")
        if isinstance(text, dict):
            items = text.get("items")
            if isinstance(items, list) and items:
                return items[0]
        return None
    for child in node.get("children", []):
        found = find_node_text(child, name)
        if found is not None:
            return found
    return None


def has_node(node: dict, name: str) -> bool:
    if not isinstance(node, dict):
        return False
    if node.get("name") == name:
        return True
    for child in node.get("children", []):
        if has_node(child, name):
            return True
    return False


def test_runtime_copy_uses_chapter_and_battle_objective_language() -> None:
    boot = read_text(BOOT_PATH)
    runtime_hud = read_text(RUNTIME_HUD_PATH)
    panel1_top = read_text(RUNTIME_HUD_PANEL1_TOP_PATH)
    stages_csv = read_text(STAGES_CSV_PATH)
    panel_json = json.loads(read_text(PANEL_JSON_PATH))
    panel_tree = json.loads(read_text(PANEL_TREE_PATH))

    assert "battle_objective_runtime = {" in boot

    assert "章节 1-1" in runtime_hud
    assert "string.format('章节 1-%d', wave_index)" in runtime_hud
    assert "主线 1-" not in runtime_hud

    assert "爬塔挑战" in panel1_top
    assert "目标：" in panel1_top
    assert "当前无层数挑战" in panel1_top
    assert "目标追踪" in panel1_top
    assert "自动任务" not in panel1_top
    assert "主线任务" not in panel1_top

    assert "章节 1-1" in stages_csv
    assert "主线 1-1" not in stages_csv

    assert panel_json.get("name") == "MainlineTaskPanel"
    assert has_node(panel_tree, "tracker_shortcut_chip_label") or has_node(panel_tree, "快捷键C")
    assert has_node(panel_tree, "tracker_shortcut_chip_key") or has_node(panel_tree, "快捷键C")
    assert has_node(panel_tree, "tracker_shortcut_chip_arrow") or has_node(panel_tree, "快捷键C")
    assert has_node(panel_tree, "tracker_card_border") or has_node(panel_tree, "image")


if __name__ == "__main__":
    test_runtime_copy_uses_chapter_and_battle_objective_language()
    print("runtime copy packaging static ok")

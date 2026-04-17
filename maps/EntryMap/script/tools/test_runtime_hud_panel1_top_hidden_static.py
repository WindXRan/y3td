from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HUD_PANEL1_TOP_PATH = ROOT / "script" / "ui" / "runtime_hud_panel1_top.lua"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_runtime_hud_panel1_top_hides_overlay_sections():
    content = HUD_PANEL1_TOP_PATH.read_text(encoding="utf-8")

    assert_contains(content, "runtime_hud.top_battle_cluster:set_visible(false)", "runtime_hud_panel1_top should hide top battle cluster")
    assert_contains(content, "runtime_hud.left_shortcut_panel:set_visible(false)", "runtime_hud_panel1_top should hide left shortcut panel")
    assert_contains(content, "runtime_hud.right_tracker_panel:set_visible(true)", "runtime_hud_panel1_top should keep right tracker panel visible")


if __name__ == "__main__":
    test_runtime_hud_panel1_top_hides_overlay_sections()

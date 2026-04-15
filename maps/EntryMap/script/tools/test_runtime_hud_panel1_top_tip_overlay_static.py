from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HUD_PANEL1_TOP_PATH = ROOT / "script" / "ui" / "runtime_hud_panel1_top.lua"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_runtime_hud_panel1_top_supports_timed_tip_overlay():
    content = HUD_PANEL1_TOP_PATH.read_text(encoding="utf-8")

    assert_contains(content, "panel1_tip_overlay_text", "panel1 top hud should store overlay tip text")
    assert_contains(content, "panel1_tip_overlay_timer", "panel1 top hud should store overlay timer")
    assert_contains(content, "env.y3.ltimer.wait", "panel1 top hud should restore tip text with a timer")
    assert_contains(content, "clear_tip_overlay(hud)", "panel1 top hud should clear overlay after timer")


if __name__ == "__main__":
    test_runtime_hud_panel1_top_supports_timed_tip_overlay()

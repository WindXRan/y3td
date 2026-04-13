from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HUD_PANEL1_TOP_PATH = ROOT / "script" / "ui" / "runtime_hud_panel1_top.lua"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_runtime_hud_panel1_top_clears_tip_overlay_on_reset():
    content = HUD_PANEL1_TOP_PATH.read_text(encoding="utf-8")

    assert_contains(
        content,
        "clear_tip_overlay(runtime_hud)",
        "panel1 top hud should clear temporary tip overlay when resetting bindings",
    )


if __name__ == "__main__":
    test_runtime_hud_panel1_top_clears_tip_overlay_on_reset()

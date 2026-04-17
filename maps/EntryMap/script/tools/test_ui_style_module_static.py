from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UI_STYLE_PATH = ROOT / "ui" / "style.lua"
RUNTIME_HUD_PATH = ROOT / "ui" / "runtime_hud.lua"
RUNTIME_HUD_PANEL1_TOP_PATH = ROOT / "ui" / "runtime_hud_panel1_top.lua"
BOND_TIP_PANEL_PATH = ROOT / "ui" / "bond_tip_panel.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_ui_style_module_exists_for_runtime_hud_stack() -> None:
    assert UI_STYLE_PATH.exists(), "ui/style.lua should exist for runtime HUD startup"

    content = read_text(UI_STYLE_PATH)
    assert "function M.apply_text" in content
    assert "node:set_text(value or '')" in content


def test_runtime_hud_stack_uses_ui_style_bridge() -> None:
    assert "require 'ui.style'" in read_text(RUNTIME_HUD_PATH)
    assert "require 'ui.style'" in read_text(RUNTIME_HUD_PANEL1_TOP_PATH)
    assert "require 'ui.style'" in read_text(BOND_TIP_PANEL_PATH)


if __name__ == "__main__":
    test_ui_style_module_exists_for_runtime_hud_stack()
    test_runtime_hud_stack_uses_ui_style_bridge()
    print("ui style module static ok")

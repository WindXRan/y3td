from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = ROOT / "ui" / "bond_tip_panel_layout.lua"
BOND_TIP_PANEL_PATH = ROOT / "ui" / "bond_tip_panel.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_bond_tip_panel_layout_module_exists() -> None:
    assert LAYOUT_PATH.exists(), "ui/bond_tip_panel_layout.lua should exist for runtime HUD startup"

    content = read_text(LAYOUT_PATH)
    assert "M.panel_name = 'CardSetEffectTipPanel'" in content
    assert "panel = 'CardSetEffectTipPanel.panel_card_set_tip'" in content
    assert "effect_area_y_by_bonus_count" in content


def test_bond_tip_panel_requires_layout_bridge() -> None:
    content = read_text(BOND_TIP_PANEL_PATH)
    assert "pcall(require, 'ui.bond_tip_panel_layout')" in content
    assert "is_layout_available" in content


if __name__ == "__main__":
    test_bond_tip_panel_layout_module_exists()
    test_bond_tip_panel_requires_layout_bridge()
    print("bond tip panel layout static ok")

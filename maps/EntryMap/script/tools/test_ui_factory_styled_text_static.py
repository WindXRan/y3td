from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FACTORY_PATH = ROOT / "ui" / "factory.lua"
RUNTIME_HUD_PATH = ROOT / "ui" / "runtime_hud.lua"
CHOICE_PANEL_PATH = ROOT / "ui" / "choice_panel.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_ui_factory_exposes_styled_text_helper() -> None:
    content = read_text(FACTORY_PATH)
    assert "local UIStyle = require 'ui.style'" in content
    assert "function api.create_styled_text" in content
    assert "UIStyle.apply_text(text, style_key, value or '')" in content
    assert "function api.apply_text_style" in content
    assert "UIStyle.apply_text(node, style_key, value or '')" in content


def test_hud_and_choice_panel_use_factory_styled_text() -> None:
    runtime_hud_content = read_text(RUNTIME_HUD_PATH)
    choice_panel_content = read_text(CHOICE_PANEL_PATH)

    assert "local create_styled_text = factory.create_styled_text or fallback_create_styled_text" in runtime_hud_content
    assert "local create_styled_text = factory.create_styled_text or fallback_create_styled_text" in choice_panel_content
    assert "local apply_text_style = factory.apply_text_style or fallback_apply_text_style" in choice_panel_content


if __name__ == "__main__":
    test_ui_factory_exposes_styled_text_helper()
    test_hud_and_choice_panel_use_factory_styled_text()
    print("ui factory styled text static ok")

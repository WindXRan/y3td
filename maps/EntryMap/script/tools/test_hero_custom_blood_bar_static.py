import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BATTLEFIELD = ROOT / "runtime" / "battlefield.lua"
SESSION_STATE = ROOT / "runtime" / "session_state.lua"
HERO_UNIT = ROOT.parent / "editor_table" / "editorunit" / "201390301.json"
FALLBACK_HERO_UNIT = ROOT.parent / "editor_table" / "editorunit" / "134274912.json"
CUSTOM_BLOOD_BAR_ID = 134251599


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_hero_editor_units_use_custom_blood_bar() -> None:
    hero_data = json.loads(HERO_UNIT.read_text(encoding="utf-8"))
    fallback_data = json.loads(FALLBACK_HERO_UNIT.read_text(encoding="utf-8"))
    assert hero_data["blood_bar"] == CUSTOM_BLOOD_BAR_ID, "hero editor unit should use the custom blood bar"
    assert fallback_data["blood_bar"] == CUSTOM_BLOOD_BAR_ID, "fallback hero editor unit should use the custom blood bar"


def test_runtime_assigns_custom_blood_bar() -> None:
    battlefield = BATTLEFIELD.read_text(encoding="utf-8")
    assert_contains(battlefield, "HERO_CUSTOM_BLOOD_BAR_ID = 134251599", "battlefield should define the custom hero blood bar id")
    assert_contains(battlefield, "apply_hero_custom_blood_bar(hero)", "battlefield should apply the custom blood bar on hero creation")
    assert_contains(battlefield, "STATE.hero_blood_bar_type = HERO_CUSTOM_BLOOD_BAR_ID", "battlefield should cache the hero blood bar id")
    assert_contains(battlefield, "STATE.hero_blood_bar_unit = hero", "battlefield should cache the hero blood bar unit")
    assert_contains(battlefield, "hero:set_blood_bar_type(HERO_CUSTOM_BLOOD_BAR_ID)", "battlefield should assign the custom blood bar at runtime")


def test_session_state_resets_custom_blood_bar_runtime() -> None:
    session_state = SESSION_STATE.read_text(encoding="utf-8")
    assert_contains(session_state, "STATE.hero_blood_bar_type = nil", "session_state should clear the cached hero blood bar id")
    assert_contains(session_state, "STATE.hero_blood_bar_unit = nil", "session_state should clear the cached hero blood bar unit")


if __name__ == "__main__":
    test_hero_editor_units_use_custom_blood_bar()
    test_runtime_assigns_custom_blood_bar()
    test_session_state_resets_custom_blood_bar_runtime()
    print("hero custom blood bar static ok")

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BOOT_PATH = ROOT / "script" / "runtime" / "boot.lua"
OUTGAME_PATH = ROOT / "script" / "ui" / "outgame.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_boot_enters_outgame_instead_of_autostarting_battle() -> None:
    source = read_text(BOOT_PATH)
    bootstrap_index = source.find("function M.bootstrap()")
    assert bootstrap_index != -1, "expected boot.lua to expose bootstrap"
    bootstrap_block = source[bootstrap_index:]

    assert "outgame_system.enter_outgame()" in bootstrap_block
    assert "session_state_system.start_selected_stage(" not in bootstrap_block


def test_outgame_has_hall_stage_defaults_and_single_mode_entry() -> None:
    source = read_text(OUTGAME_PATH)

    assert "local STAGE_PAGE_SIZE = 5" in source
    assert "local SINGLE_MODE_ID = 'standard'" in source
    assert "local SINGLE_MODE_LABEL = '主线模式'" in source
    assert "local mode_panel = resolve_ui('outgame.大厅.layout.left_2')" in source
    assert "local stage_slot_container = resolve_ui('outgame.大厅.layout.right_2.list')" in source
    assert "string.format('mode%d', index)" in source
    assert "outgame.大厅.layout.start" in source
    assert "outgame.大厅.layout.right.难度列表" in source
    assert "local hall_root = resolve_ui('outgame.大厅')" in source
    assert "profile.selected_stage_id = fallback_stage_id" in source
    assert "profile.selected_mode_id = SINGLE_MODE_ID" in source
    assert "STATE.selected_stage_id = stage_id" in source
    assert "STATE.selected_mode_id = mode_id" in source
    assert "api.start_selected_stage()" in source
    assert "selected_outgame_tab" not in source
    assert "selected_hall_section" not in source
    assert "create_fullscreen_root" not in source


if __name__ == "__main__":
    test_boot_enters_outgame_instead_of_autostarting_battle()
    test_outgame_has_hall_stage_defaults_and_single_mode_entry()
    print("outgame hall entry static ok")

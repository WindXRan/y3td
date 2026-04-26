from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
BOOT_PATH = ROOT / "maps" / "EntryMap" / "script" / "runtime" / "boot.lua"


def test_evolution_entry_refreshes_choice_panel_immediately():
    content = BOOT_PATH.read_text(encoding="utf-8")
    assert "local runtime_ui_helpers" in content
    assert "runtime_ui_helpers = RuntimeUIHelpers.create({" in content
    assert "show_pending_round_choice('evolution')" in content
    assert "show_mark_choices()" in content


def test_archive_panel_takes_priority_over_battle_hud_refresh():
    content = BOOT_PATH.read_text(encoding="utf-8")
    assert "if visible == true and STATE.archive_panel_visible == true then" in content
    assert "raw_set_battle_hud_visible(false)" in content
    assert "local function open_runtime_save_panel()" in content
    assert "STATE.choice_panel_hidden = true" in content
    assert "runtime_ui_helpers.destroy_choice_panel()" in content

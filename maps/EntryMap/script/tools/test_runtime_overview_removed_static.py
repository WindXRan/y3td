from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BOOT_PATH = ROOT / "script" / "runtime" / "boot.lua"
INPUT_EVENTS_PATH = ROOT / "script" / "runtime" / "input_events.lua"
HUD_PATH = ROOT / "script" / "ui" / "runtime_hud_v2.lua"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def assert_not_contains(content: str, needle: str, message: str) -> None:
    if needle in content:
        raise AssertionError(message)


def extract_between(content: str, start: str, end: str) -> str:
    start_index = content.find(start)
    if start_index < 0:
      raise AssertionError(f"missing start marker: {start}")
    end_index = content.find(end, start_index)
    if end_index < 0:
      raise AssertionError(f"missing end marker: {end}")
    return content[start_index:end_index]


def test_runtime_overview_removed_from_battle_ui():
    boot = BOOT_PATH.read_text(encoding="utf-8")
    input_events = INPUT_EVENTS_PATH.read_text(encoding="utf-8")
    hud = HUD_PATH.read_text(encoding="utf-8")
    status_body = extract_between(boot, "local function show_runtime_status()", "local function trigger_td_skills_on_hit")

    assert_not_contains(boot, "require 'ui.runtime_overview'", "boot.lua should not load runtime_overview UI anymore")
    assert_not_contains(boot, "RuntimeOverviewSystem.create", "boot.lua should not create runtime_overview UI anymore")
    assert_not_contains(boot, "ensure_runtime_overview =", "boot.lua should not expose runtime overview entry anymore")

    assert_not_contains(input_events, "ensure_runtime_overview", "input_events.lua should not open runtime overview anymore")
    assert_not_contains(input_events, "STATE.runtime_overview_mode = 'build'", "B hotkey should not switch runtime overview mode anymore")
    assert_contains(input_events, "show_runtime_status()", "B hotkey should fall back to text status output")

    assert_not_contains(hud, "toggle_overview", "runtime_hud_v2.lua should not toggle runtime overview anymore")
    assert_not_contains(hud, "总览 B", "runtime_hud_v2.lua should not show overview button label anymore")
    assert_not_contains(status_body, "show_attack_skill_loadout()", "show_runtime_status should not fan out to attack skill loadout anymore")
    assert_not_contains(status_body, "BondSystem.show_loadout(create_bond_env())", "show_runtime_status should not fan out to bond loadout anymore")
    assert_not_contains(status_body, "show_mark_loadout()", "show_runtime_status should not fan out to mark loadout anymore")
    assert_not_contains(status_body, "show_treasure_loadout()", "show_runtime_status should not fan out to treasure loadout anymore")


if __name__ == "__main__":
    test_runtime_overview_removed_from_battle_ui()

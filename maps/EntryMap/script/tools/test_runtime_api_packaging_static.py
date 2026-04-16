from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"
RUNTIME_HUD_PATH = ROOT / "ui" / "runtime_hud.lua"
RUNTIME_HUD_PANEL1_TOP_PATH = ROOT / "ui" / "runtime_hud_panel1_top.lua"
OUTGAME_PATH = ROOT / "ui" / "outgame.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_boot_exposes_split_runtime_packages() -> None:
    boot = read_text(BOOT_PATH)

    assert "stage_runtime = {" in boot
    assert "get_current_stage_text = function()" in boot
    assert "start_selected_stage = function(stage_id, mode_id)" in boot

    assert "battle_objective_runtime = {" in boot
    assert "mainline_runtime = {" in boot
    assert "get_summary = function()" in boot
    assert "get_tracker_state = function()" in boot
    assert "toggle_auto_track = function()" in boot


def test_outgame_boot_wires_stage_runtime_package() -> None:
    boot = read_text(BOOT_PATH)

    outgame_create_index = boot.find("outgame_system = OutgameSystem.create({")
    assert outgame_create_index != -1, "boot.lua should create the outgame system"

    input_events_index = boot.find("input_events_system = InputEventsSystem.create({", outgame_create_index)
    if input_events_index == -1:
        input_events_index = len(boot)

    outgame_create_block = boot[outgame_create_index:input_events_index]
    assert "stage_runtime = {" in outgame_create_block
    assert "start_selected_stage = function(stage_id, mode_id)" in outgame_create_block
    assert "get_current_stage_text = function()" in outgame_create_block


def test_consumers_use_split_runtime_packages() -> None:
    runtime_hud = read_text(RUNTIME_HUD_PATH)
    runtime_hud_panel1_top = read_text(RUNTIME_HUD_PANEL1_TOP_PATH)
    outgame = read_text(OUTGAME_PATH)

    assert "env.stage_runtime and env.stage_runtime.get_current_stage_text" in runtime_hud
    assert "env.get_current_stage_text" not in runtime_hud

    assert "env.battle_objective_runtime and env.battle_objective_runtime.get_tracker_state" in runtime_hud_panel1_top
    assert "env.battle_objective_runtime and env.battle_objective_runtime.get_summary" in runtime_hud_panel1_top
    assert "env.battle_objective_runtime and env.battle_objective_runtime.toggle_auto_track" in runtime_hud_panel1_top
    assert "env.mainline_runtime and env.mainline_runtime.get_tracker_state" not in runtime_hud_panel1_top
    assert "env.get_mainline_task_tracker_state" not in runtime_hud_panel1_top
    assert "env.get_mainline_task_summary" not in runtime_hud_panel1_top
    assert "env.toggle_mainline_task_auto_track" not in runtime_hud_panel1_top

    assert "env.stage_runtime and env.stage_runtime.start_selected_stage" in outgame
    assert "env.start_selected_stage" not in outgame


if __name__ == "__main__":
    test_boot_exposes_split_runtime_packages()
    test_consumers_use_split_runtime_packages()
    print("runtime api packaging static ok")

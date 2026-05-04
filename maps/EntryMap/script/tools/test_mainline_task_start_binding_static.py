from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"
INPUT_EVENTS_PATH = ROOT / "runtime" / "input_events.lua"
LOOPS_PATH = ROOT / "runtime" / "loops.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_boot_and_runtime_loops_wire_mainline_task_start_and_update() -> None:
    boot = read_text(BOOT_PATH)
    loops = read_text(LOOPS_PATH)

    assert "start_current_task_challenge = function()" in boot
    assert "return mainline_task_system and mainline_task_system.start_current_task_challenge" in boot
    assert "local update_mainline_task = env.update_mainline_task" in loops
    assert "if update_mainline_task then" in loops
    assert "update_mainline_task(0.25)" in loops


def test_input_events_binds_c_to_mainline_task_start() -> None:
    content = read_text(INPUT_EVENTS_PATH)

    assert "local start_current_task_challenge = env.start_current_task_challenge" in content
    assert "y3.game:event('键盘-按下', 'C', function()" in content
    assert "start_current_task_challenge()" in content


if __name__ == "__main__":
    test_boot_and_runtime_loops_wire_mainline_task_start_and_update()
    test_input_events_binds_c_to_mainline_task_start()
    print("mainline task start binding static ok")

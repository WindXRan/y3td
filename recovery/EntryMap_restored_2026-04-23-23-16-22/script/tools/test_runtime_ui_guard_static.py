from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SESSION_STATE_PATH = ROOT / "runtime" / "session_state.lua"
LOOPS_PATH = ROOT / "runtime" / "loops.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_stage_start_and_runtime_loops_guard_ui_failures() -> None:
    session_state = read_text(SESSION_STATE_PATH)
    loops = read_text(LOOPS_PATH)

    assert_contains(session_state, "local function try_initialize_battle_ui()", "session_state should guard battle ui init")
    assert_contains(session_state, "pcall(function()", "session_state should protect ui init with pcall")
    assert_contains(session_state, "try_initialize_battle_ui()", "stage start should use guarded ui init")
    assert_contains(session_state, "env.start_wave(1)", "stage start should still start wave 1")

    assert_contains(loops, "local function try_refresh_battle_ui()", "runtime loops should guard battle ui refresh")
    assert_contains(loops, "gameplay continues", "runtime loops should log that gameplay keeps running after ui failure")
    assert_contains(loops, "try_refresh_battle_ui()", "runtime loop should use guarded ui refresh")


if __name__ == "__main__":
    test_stage_start_and_runtime_loops_guard_ui_failures()
    print("runtime ui guard static ok")

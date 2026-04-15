from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"
BATTLEFIELD_PATH = ROOT / "runtime" / "battlefield.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_boot_wires_mainline_task_runtime_and_battlefield_callback() -> None:
    boot = read_text(BOOT_PATH)
    battlefield = read_text(BATTLEFIELD_PATH)

    assert "require('runtime.mainline_tasks').create({" in boot
    assert "get_mainline_task_summary = function()" in boot
    assert "on_mainline_task_cleared = function(task)" in boot
    assert "return mainline_task_system.handle_task_cleared(task)" in boot

    assert "if env.on_mainline_task_cleared then" in battlefield
    assert "env.on_mainline_task_cleared()" in battlefield


if __name__ == "__main__":
    test_boot_wires_mainline_task_runtime_and_battlefield_callback()
    print("mainline task boot integration static ok")

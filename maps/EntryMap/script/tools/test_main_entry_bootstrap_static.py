from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_PATH = ROOT / "main.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_main_bootstraps_entry_runtime() -> None:
    source = read_text(MAIN_PATH)

    assert "require 'entry_runtime'" in source
    assert "loaded_runtime.bootstrap()" in source
    assert "runtime_load_attempted" in source
    assert "bootstrapped = false" in source
    assert "y3.game:event('游戏-初始化'" in source
    assert "y3.ltimer.wait(0" in source


def test_main_no_longer_uses_demo_stub() -> None:
    source = read_text(MAIN_PATH)

    assert "print('Hello, Y3!')" not in source
    assert "每5秒显示一次文本" not in source
    assert "键盘-按下', 'SPACE'" not in source


if __name__ == "__main__":
    test_main_bootstraps_entry_runtime()
    test_main_no_longer_uses_demo_stub()
    print("main entry bootstrap static ok")

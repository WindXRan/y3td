from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAIN_PATH = ROOT / "script" / "main.lua"
BOOT_PATH = ROOT / "script" / "runtime" / "boot.lua"
SESSION_STATE_PATH = ROOT / "script" / "runtime" / "session_state.lua"
BATTLEFIELD_PATH = ROOT / "script" / "runtime" / "battlefield.lua"


def assert_not_contains(content: str, needle: str, message: str) -> None:
    if needle in content:
        raise AssertionError(message)


def test_startup_messages_removed():
    main = MAIN_PATH.read_text(encoding="utf-8")
    boot = BOOT_PATH.read_text(encoding="utf-8")
    session_state = SESSION_STATE_PATH.read_text(encoding="utf-8")
    battlefield = BATTLEFIELD_PATH.read_text(encoding="utf-8")

    assert_not_contains(main, "y3.config.log.toGame = true", "main.lua should not mirror debug logs into the game UI")
    assert_not_contains(boot, "局外选关已启动", "boot.lua should not push outgame startup copy into the game UI")
    assert_not_contains(boot, "开发模式坐标校准", "boot.lua should not push calibration help into the game UI")
    assert_not_contains(boot, "当前临时物编", "boot.lua should not push temp object notes into the game UI")
    assert_not_contains(boot, "调试快捷键已启用", "boot.lua should not push debug hotkey help into the game UI")
    assert_not_contains(boot, "GM 调试面板已挂到右上角", "boot.lua should not push GM panel intro into the game UI")
    assert_not_contains(session_state, "已进入 %s %s。", "session_state.lua should not push stage-entry copy into the game UI")
    assert_not_contains(battlefield, "开始，Boss 将在", "battlefield.lua should not push wave-start copy into the game UI")


if __name__ == "__main__":
    test_startup_messages_removed()

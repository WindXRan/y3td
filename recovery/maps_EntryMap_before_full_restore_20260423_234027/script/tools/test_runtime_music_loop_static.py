from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_PATH = ROOT / "runtime" / "audio.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_music_runtime_keeps_looping_and_recovers_when_track_ends() -> None:
    audio = read_text(AUDIO_PATH)

    assert_contains(audio, "music_watchdog = nil,", "audio runtime should track a music watchdog timer")
    assert_contains(audio, "local function is_sound_handle_alive(sound)", "audio runtime should validate the current bgm handle before skipping replay")
    assert_contains(audio, "if runtime.music_phase == normalized and is_sound_handle_alive(runtime.bgm_sound) then", "music phase switching should only reuse bgm when the current handle is still alive")
    assert_contains(audio, "local function ensure_music_watchdog()", "audio runtime should define a watchdog that keeps music looping")
    assert_contains(audio, "runtime.music_watchdog = y3.ltimer.loop(2.5, function()", "music watchdog should poll at a light interval to restore ended bgm tracks")
    assert_contains(audio, "if current.music_phase == 'result' then", "music watchdog should not revive bgm during battle result stingers")
    assert_contains(audio, "set_music_phase(current.music_phase or 'outgame')", "music watchdog should restart the current phase music when playback ends")
    assert_contains(audio, "loop = true,", "background music playback should request engine-level looping")


if __name__ == "__main__":
    test_music_runtime_keeps_looping_and_recovers_when_track_ends()
    print("runtime music loop static ok")

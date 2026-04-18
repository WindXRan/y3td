from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_PATH = ROOT / "runtime" / "audio.lua"
BOOT_PATH = ROOT / "runtime" / "boot.lua"
BATTLEFIELD_PATH = ROOT / "runtime" / "battlefield.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_enemy_death_audio_is_wired() -> None:
    audio = read_text(AUDIO_PATH)
    boot = read_text(BOOT_PATH)
    battlefield = read_text(BATTLEFIELD_PATH)

    assert_contains(audio, "enemy_death_heavy = {", "audio runtime should define heavy enemy death audio candidates")
    assert_contains(audio, "'134257420'", "audio runtime should keep the legacy heavy death sound id as first candidate")
    assert_contains(audio, "'126040'", "audio runtime should include a valid heavy death fallback")
    assert_contains(audio, "enemy_death_burst = {", "audio runtime should define burst enemy death audio candidates")
    assert_contains(audio, "'134257799'", "audio runtime should keep the legacy burst death sound id as first candidate")
    assert_contains(audio, "'126054'", "audio runtime should include a valid burst death fallback")
    assert_contains(audio, "local function play_enemy_death(unit, is_boss)", "audio runtime should expose enemy death audio helper")
    assert_contains(audio, "}, 'enemy_death_heavy')", "audio runtime should label heavy death audio resolution for debugging")
    assert_contains(audio, "}, 'enemy_death_burst')", "audio runtime should label burst death audio resolution for debugging")
    assert_contains(audio, "play_enemy_death = play_enemy_death", "audio runtime should return the enemy death audio helper")

    assert_contains(boot, "play_enemy_death_sound = function(unit, info)", "boot should wire enemy death audio into battlefield")
    assert_contains(boot, "audio_system.play_enemy_death(unit, info and info.kind == 'boss')", "boot should delegate enemy death audio to the audio system")

    assert_contains(battlefield, "local play_enemy_death_sound = env.play_enemy_death_sound", "battlefield should receive enemy death audio callback")
    assert_contains(battlefield, "play_enemy_death_sound(unit, info)", "battlefield death reaction should trigger audio")

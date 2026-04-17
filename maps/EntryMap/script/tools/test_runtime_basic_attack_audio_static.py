from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_PATH = ROOT / "runtime" / "audio.lua"
ATTACK_SKILLS_PATH = ROOT / "runtime" / "attack_skills.lua"
BOOT_PATH = ROOT / "runtime" / "boot.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_basic_attack_audio_is_wired() -> None:
    audio = read_text(AUDIO_PATH)
    attack_skills = read_text(ATTACK_SKILLS_PATH)
    boot = read_text(BOOT_PATH)

    assert_contains(audio, "basic_attack = '134257538'", "audio runtime should define a default basic attack sound id")
    assert_contains(audio, "local function play_for_unit(audio_id, unit, options)", "audio runtime should support unit-followed audio")
    assert_contains(audio, "local function play_basic_attack(unit)", "audio runtime should expose basic attack audio helper")
    assert_contains(audio, "play_basic_attack = play_basic_attack", "audio runtime should return the basic attack audio helper")

    assert_contains(attack_skills, "local play_basic_attack_sound = env.play_basic_attack_sound", "attack skills should accept a basic attack audio callback")
    assert_contains(attack_skills, "play_basic_attack_sound(STATE.hero)", "basic attack casts should trigger attack audio on the hero")

    assert_contains(boot, "play_basic_attack_sound = function(source_unit)", "boot should wire the basic attack audio callback into attack skills")
    assert_contains(boot, "audio_system.play_basic_attack(source_unit)", "boot should delegate basic attack audio to the audio system")


if __name__ == "__main__":
    test_basic_attack_audio_is_wired()
    print("runtime basic attack audio static ok")

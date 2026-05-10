from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"
BATTLEFIELD_PATH = ROOT / "runtime" / "battlefield.lua"
AUDIO_PATH = ROOT / "runtime" / "audio.lua"


def main() -> None:
    boot = BOOT_PATH.read_text(encoding="utf-8")
    battlefield = BATTLEFIELD_PATH.read_text(encoding="utf-8")

    assert not AUDIO_PATH.exists(), "runtime/audio.lua should not be required for direct enemy death sound"
    assert "require 'runtime.audio'" not in boot and 'require("runtime.audio")' not in boot
    assert "play_enemy_death_sound = function(unit, info, death_point)" in boot
    assert "local death_sound_id = 108959" in boot
    assert "GameAPI.set_player_listener_to_follow_unit" in boot
    assert "GameAPI.open_battle_music" in boot
    assert "GameAPI.set_role_all_sound_switch" in boot
    assert "GameAPI.play_3d_sound_for_player" in boot
    assert "GameAPI.play_sound_for_player" in boot
    assert "play_enemy_death_sound(unit, info, death_point)" in battlefield
    print("[OK] enemy death direct sound static passed")


if __name__ == "__main__":
    main()

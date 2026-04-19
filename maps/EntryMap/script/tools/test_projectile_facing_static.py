from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS = ROOT / "runtime" / "attack_skills.lua"
AUTO_ACTIVE_EFFECTS = ROOT / "runtime" / "auto_active_effects.lua"


def test_projectiles_face_their_flight_direction() -> None:
    attack_content = ATTACK_SKILLS.read_text(encoding="utf-8")
    auto_content = AUTO_ACTIVE_EFFECTS.read_text(encoding="utf-8")

    for content in (attack_content, auto_content):
        assert "PROJECTILE_FLIGHT_HEIGHT = 100" in content
        assert "angle = launch_angle," in content
        assert "projectile:set_height(PROJECTILE_FLIGHT_HEIGHT)" in content
        assert "projectile:set_facing(launch_angle)" in content
        assert "height = PROJECTILE_FLIGHT_HEIGHT," in content
        assert "init_angle = launch_angle," in content
        assert "rotate_time = 0.0," in content
        assert "face_angle = true," in content
        assert "miss_when_target_destroy = false," in content
        assert "miss_when_target_destroy = true," not in content
        assert "on_miss = function()" in content

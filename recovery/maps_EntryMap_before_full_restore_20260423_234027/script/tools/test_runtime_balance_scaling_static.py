from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BATTLE_BASE_RULES = ROOT / "data_csv" / "battle_base_rules.csv"
ENTRY_CONFIG = ROOT / "config" / "entry_config.lua"
ATTACK_SKILLS = ROOT / "runtime" / "attack_skills.lua"
AUTO_ACTIVE_EFFECTS = ROOT / "runtime" / "auto_active_effects.lua"
BATTLEFIELD = ROOT / "runtime" / "battlefield.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_runtime_balance_scaling_wiring() -> None:
    battle_base_rules = read_text(BATTLE_BASE_RULES)
    entry_config = read_text(ENTRY_CONFIG)
    attack_skills = read_text(ATTACK_SKILLS)
    auto_active_effects = read_text(AUTO_ACTIVE_EFFECTS)
    battlefield = read_text(BATTLEFIELD)

    assert_contains(battle_base_rules, "global_rules,enemy_move_speed_scale,0.5", "battle base rules should define enemy speed scale")
    assert_contains(battle_base_rules, "global_rules,enemy_spawn_batch_scale,1.5", "battle base rules should define enemy spawn batch scale")
    assert_contains(battle_base_rules, "global_rules,enemy_alive_cap_scale,1.5", "battle base rules should define enemy alive cap scale")
    assert_contains(battle_base_rules, "global_rules,total_enemy_soft_cap_scale,1.5", "battle base rules should define enemy soft cap scale")

    assert_contains(entry_config, "enemy_move_speed_scale = ENEMY_MOVE_SPEED_SCALE", "entry config should expose enemy move speed scale")
    assert_contains(entry_config, "enemy_spawn_batch_scale = ENEMY_SPAWN_BATCH_SCALE", "entry config should expose enemy spawn batch scale")
    assert_contains(entry_config, "enemy_alive_cap_scale = ENEMY_ALIVE_CAP_SCALE", "entry config should expose enemy alive cap scale")
    assert_contains(entry_config, "total_enemy_soft_cap = scale_positive_int(global_rules.total_enemy_soft_cap, TOTAL_ENEMY_SOFT_CAP_SCALE, 40)", "entry config should scale total enemy soft cap")

    assert_contains(attack_skills, "speed = tonumber(vfx and vfx.projectile_speed) or 1000", "attack skills runtime should launch with manifest projectile speed")

    assert_contains(auto_active_effects, "speed = tonumber(vfx and vfx.projectile_speed) or 1000", "auto active effects should launch with manifest projectile speed")

    assert_contains(battlefield, "factor = factor * (tonumber(CONFIG.enemy_move_speed_scale) or 1.0)", "battlefield should scale enemy move speed")
    assert_contains(battlefield, "local function get_wave_batch_bounds(wave)", "battlefield should centralize wave batch scaling")
    assert_contains(battlefield, "local function get_wave_max_alive(wave)", "battlefield should centralize alive cap scaling")
    assert_contains(battlefield, "local function get_scaled_challenge_batch_count(instance, batch)", "battlefield should centralize challenge batch scaling")


if __name__ == "__main__":
    test_runtime_balance_scaling_wiring()
    print("runtime balance scaling static ok")

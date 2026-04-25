from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BATTLEFIELD = ROOT / "runtime" / "battlefield.lua"
SCENE_CONFIG = ROOT / "data_csv" / "battlefield_scene_config.csv"
HERO_INIT_STATS = ROOT / "data_csv" / "hero_init_stats.csv"


def test_battlefield_has_spawn_speed_tuning() -> None:
    content = BATTLEFIELD.read_text(encoding="utf-8")

    assert "ENEMY_BASE_SPEED_FACTORS" in content
    assert "apply_spawn_enemy_speed_tuning" in content
    assert "unit:set_attr('移动速度', tuned_move_speed)" in content


def test_scene_slow_zones_stay_in_ranged_clear_profile() -> None:
    content = SCENE_CONFIG.read_text(encoding="utf-8")

    assert "slow_zone,,1,mid_slow_lane_outer,,,,,,,,0.64," in content
    assert "slow_zone,,2,mid_slow_lane_inner,,,,,,,,0.46," in content
    assert "slow_zone,,3,hero_front_slow_lane,,,,,,,,0.30," in content


def test_hero_init_range_stays_long_range() -> None:
    content = HERO_INIT_STATS.read_text(encoding="utf-8")

    assert "攻击范围,2000" in content

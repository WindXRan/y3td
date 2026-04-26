from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def assert_exists(path: Path) -> None:
    if not path.exists():
        raise AssertionError(f"expected merged csv to exist: {path}")


def assert_missing(path: Path) -> None:
    if path.exists():
        raise AssertionError(f"expected split csv to be removed: {path}")


def main() -> None:
    assert_exists(ROOT / "data_csv" / "choice_panel_config.csv")
    assert_exists(ROOT / "data_csv" / "battlefield_scene_config.csv")
    assert_exists(ROOT / "data_csv" / "hero_attr_config.csv")
    assert_exists(ROOT / "data_csv" / "hero_init_stats.csv")
    assert_exists(ROOT / "data_csv" / "challenges.csv")
    assert_exists(ROOT / "data_csv" / "evolution_nodes.csv")
    assert_exists(ROOT / "data_csv" / "waves.csv")
    assert_exists(ROOT / "data_csv" / "stages.csv")

    assert_missing(ROOT / "data_csv" / "choice_panel_badge_texts.csv")
    assert_missing(ROOT / "data_csv" / "choice_panel_refresh_costs.csv")
    assert_missing(ROOT / "data_csv" / "battlefield_points.csv")
    assert_missing(ROOT / "data_csv" / "battlefield_areas.csv")
    assert_missing(ROOT / "data_csv" / "battlefield_slow_zones.csv")
    assert_missing(ROOT / "data_csv" / "save_slots.csv")
    assert_missing(ROOT / "data_csv" / "panel_default_attrs.csv")
    assert_missing(ROOT / "data_csv" / "debug_hero_bonus_stats.csv")
    assert_missing(ROOT / "data_csv" / "challenge_batches.csv")
    assert_missing(ROOT / "data_csv" / "evolution_pool_rules.csv")
    assert_missing(ROOT / "data_csv" / "wave_spawn_segments.csv")
    assert_missing(ROOT / "data_csv" / "wave_main_attr_overrides.csv")
    assert_missing(ROOT / "data_csv" / "stage_mode_links.csv")

    print("csv merge targets present and split files removed")


if __name__ == "__main__":
    main()

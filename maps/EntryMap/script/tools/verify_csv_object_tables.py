from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]


def require_files(label: str, relative_paths: list[str]) -> None:
    missing = [path for path in relative_paths if not (ROOT / path).exists()]
    if missing:
        for path in missing:
            print(f"[FAIL] missing {path}")
        sys.exit(1)
    print(f"[OK] {label}")


require_files(
    "csv foundation files present",
    [
        "data/csv_loader.lua",
        "data/object_tables/treasure_catalog.lua",
        "data/object_tables/bond_nodes.lua",
        "data/object_tables/marks.lua",
        "data/object_tables/stages.lua",
        "data/object_tables/stage_modes.lua",
        "data/object_tables/hero_attr_config.lua",
        "data/object_tables/battle_base_config.lua",
    ],
)

require_files(
    "bond csv files present",
    [
        "data_csv/bond_nodes.csv",
        "data_csv/bond_node_attr.csv",
        "data_csv/bond_node_runtime.csv",
        "data_csv/bond_node_aliases.csv",
        "data_csv/bond_pick_rules.csv",
        "data_csv/bond_pick_weights.csv",
        "data_csv/bond_refresh_costs.csv",
        "data_csv/bond_draw_rules.csv",
        "data_csv/bond_group_choices.csv",
        "data_csv/bond_group_choice_paths.csv",
        "data_csv/bond_group_labels.csv",
        "data_csv/bond_root_sets.csv",
        "data_csv/bond_root_set_attr.csv",
        "data_csv/bond_root_set_runtime.csv",
        "data_csv/bond_runtime_aliases.csv",
        "data_csv/bond_runtime_attr_aliases.csv",
        "data_csv/bond_manual_color_keywords.csv",
        "data_csv/bond_per_second_attr_keys.csv",
    ],
)

require_files(
    "treasure csv files present",
    [
        "data_csv/treasures.csv",
        "data_csv/treasure_effects.csv",
        "data_csv/treasure_sets.csv",
        "data_csv/treasure_set_members.csv",
        "data_csv/treasure_set_effects.csv",
    ],
)

require_files(
    "second batch csv files present",
    [
        "data_csv/marks.csv",
        "data_csv/mark_bonus_attr.csv",
        "data_csv/mark_bonus_runtime.csv",
        "data_csv/mark_tags.csv",
        "data_csv/stages.csv",
        "data_csv/stage_modes.csv",
        "data_csv/stage_mode_links.csv",
        "data_csv/panel_default_attrs.csv",
        "data_csv/hero_init_stats.csv",
        "data_csv/debug_hero_bonus_stats.csv",
        "data_csv/battle_base_rules.csv",
    ],
)

require_files(
    "evolution node csv files present",
    [
        "data_csv/evolution_nodes.csv",
        "data_csv/evolution_pool_rules.csv",
        "data/object_tables/evolution_nodes.lua",
    ],
)

print("[OK] static CSV migration checks passed")

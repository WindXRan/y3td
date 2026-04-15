from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def require_files(label: str, relative_paths: list[str]) -> None:
    missing = [path for path in relative_paths if not (ROOT / path).exists()]
    if missing:
        for path in missing:
            print(f"[FAIL] missing {path}")
        sys.exit(1)
    print(f"[OK] {label}")


def run_check(label: str, command: list[str]) -> None:
    result = subprocess.run(
        command,
        cwd=ROOT.parent.parent.parent,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode != 0:
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        print(f"[FAIL] {label}")
        sys.exit(result.returncode or 1)
    sys.stdout.write(result.stdout)
    print(f"[OK] {label}")


require_files(
    "csv foundation files present",
    [
        "data/csv_loader.lua",
        "data/object_tables/attreffect.lua",
        "data/object_tables/treasure_catalog.lua",
        "data/object_tables/bond_nodes.lua",
        "data/object_tables/marks.lua",
        "data/object_tables/evolutions.lua",
        "data/object_tables/stages.lua",
        "data/object_tables/stage_modes.lua",
        "data/object_tables/hero_attr_config.lua",
        "data/object_tables/hero_level_progression.lua",
        "data/object_tables/gear_upgrade_config.lua",
        "data/object_tables/battle_base_config.lua",
        "data/object_tables/outgame_attr_bonus_config.lua",
        "tools/test_attreffect_csv_loader_smoke.lua",
    ],
)

require_files(
    "bond csv files present",
    [
        "data_csv/bond_nodes.csv",
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
        "data_csv/attreffect.csv",
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
        "data_csv/attreffect.csv",
        "data_csv/marks.csv",
        "data_csv/mark_tags.csv",
        "data_csv/stages.csv",
        "data_csv/stage_modes.csv",
        "data_csv/stage_mode_links.csv",
        "data_csv/hero_attr_config.csv",
        "data_csv/hero_init_stats.csv",
        "data_csv/hero_level_progression.csv",
        "data_csv/gear_upgrade_slots.csv",
        "data_csv/gear_upgrade_levels.csv",
        "data_csv/battle_base_rules.csv",
        "data_csv/battlefield_scene_config.csv",
        "data_csv/choice_panel_config.csv",
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

run_check(
    "attreffect csv loader smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_attreffect_csv_loader_smoke.lua"],
)

run_check(
    "treasure catalog consistency smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_treasure_catalog_consistency_smoke.lua"],
)

run_check(
    "marks catalog consistency smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_marks_catalog_consistency_smoke.lua"],
)

run_check(
    "mainline task rewards csv loader smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_mainline_task_rewards_csv_loader_smoke.lua"],
)

run_check(
    "mainline task runtime smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_mainline_task_runtime_smoke.lua"],
)

run_check(
    "mainline task rewards damage vocab static executed",
    ["py", "-3", "maps/EntryMap/script/tools/test_mainline_task_rewards_damage_vocab_static.py"],
)

run_check(
    "stages catalog consistency smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_stages_catalog_consistency_smoke.lua"],
)

run_check(
    "waves challenges catalog consistency smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_waves_challenges_catalog_consistency_smoke.lua"],
)

run_check(
    "bond catalog consistency smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_bond_catalog_consistency_smoke.lua"],
)

run_check(
    "hero level progression csv loader smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_hero_level_progression_csv_loader_smoke.lua"],
)

run_check(
    "gear upgrade config csv loader smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_gear_upgrade_config_csv_loader_smoke.lua"],
)

run_check(
    "outgame attr bonus config csv loader smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_outgame_attr_bonus_config_csv_loader_smoke.lua"],
)

run_check(
    "config catalog consistency smoke executed",
    ["lua", "maps/EntryMap/script/tools/test_config_catalog_consistency_smoke.lua"],
)

print("[OK] static CSV migration checks passed")

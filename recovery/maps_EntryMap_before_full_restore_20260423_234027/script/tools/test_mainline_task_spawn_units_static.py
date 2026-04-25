import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data_csv" / "mainline_task_rewards.csv"
EDITOR_UNIT_DIR = ROOT.parent / "editor_table" / "editorunit"

LEGACY_PLACEHOLDER_IDS = {
    "134280097",
    "134280098",
    "134280099",
    "134280100",
    "134222661",
}


def load_rows():
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def test_mainline_tasks_do_not_use_legacy_placeholder_units() -> None:
    rows = load_rows()
    used_ids = {row["spawn_unit_id"] for row in rows if row.get("spawn_unit_id")}
    assert not (used_ids & LEGACY_PLACEHOLDER_IDS)


def test_mainline_task_spawn_units_exist_and_match_task_tier() -> None:
    rows = load_rows()
    for row in rows:
        unit_id = row["spawn_unit_id"]
        assert unit_id, f'{row["id"]} is missing spawn_unit_id'
        assert (EDITOR_UNIT_DIR / f"{unit_id}.json").exists(), f'{row["id"]} references missing unit {unit_id}'

        if row["is_boss_task"] == "true":
            assert unit_id.startswith("4"), f'{row["id"]} boss task should use a 4xxxxx boss unit id'
        else:
            assert unit_id.startswith("2"), f'{row["id"]} normal task should use a 2xxxxx minion unit id'


if __name__ == "__main__":
    test_mainline_tasks_do_not_use_legacy_placeholder_units()
    test_mainline_task_spawn_units_exist_and_match_task_tier()
    print("mainline task spawn units static ok")

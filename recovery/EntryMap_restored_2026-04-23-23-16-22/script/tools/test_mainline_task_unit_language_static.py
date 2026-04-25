import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data_csv" / "mainline_task_rewards.csv"
EDITOR_UNIT_DIR = ROOT.parent / "editor_table" / "editorunit"
LANGUAGE_PATH = ROOT.parent / "zhlanguage.json"


def load_rows():
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def test_mainline_task_spawn_units_have_language_entries() -> None:
    with LANGUAGE_PATH.open("r", encoding="utf-8") as handle:
        language_map = json.load(handle)

    seen_unit_ids = set()
    for row in load_rows():
        unit_id = row["spawn_unit_id"]
        if unit_id in seen_unit_ids:
            continue
        seen_unit_ids.add(unit_id)

        with (EDITOR_UNIT_DIR / f"{unit_id}.json").open("r", encoding="utf-8") as handle:
            unit_data = json.load(handle)

        name_tid = str(unit_data["name"])
        assert language_map.get(name_tid), f"{unit_id} is missing zhlanguage entry for name tid {name_tid}"


if __name__ == "__main__":
    test_mainline_task_spawn_units_have_language_entries()
    print("mainline task unit language static ok")

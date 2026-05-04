import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MONSTER_TABLE_PATH = ROOT.parent / "tables" / "monster_maintask.json"
EDITOR_UNIT_DIR = ROOT.parent / "editor_table" / "editorunit"
LANGUAGE_PATH = ROOT.parent / "zhlanguage.json"


def load_rows():
    data = json.loads(MONSTER_TABLE_PATH.read_text(encoding="utf-8"))
    rows = data["table_data"]["data"]
    headers = rows[0]
    result = []
    for raw in rows[2:]:
        row = {
            str(header): raw[index]
            for index, header in enumerate(headers)
            if header is not None and raw[index] is not None
        }
        if row.get("key"):
            result.append(row)
    return result


def test_mainline_task_spawn_units_have_language_entries() -> None:
    with LANGUAGE_PATH.open("r", encoding="utf-8") as handle:
        language_map = json.load(handle)

    seen_unit_ids = set()
    for row in load_rows():
        unit_id = row["模型"]
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

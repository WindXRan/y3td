import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MONSTER_TABLE_PATH = ROOT.parent / "tables" / "monster_maintask.json"
EDITOR_UNIT_DIR = ROOT.parent / "editor_table" / "editorunit"

LEGACY_PLACEHOLDER_IDS = {
    "134280097",
    "134280098",
    "134280099",
    "134280100",
    "134222661",
}


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


def test_mainline_tasks_do_not_use_legacy_placeholder_units() -> None:
    rows = load_rows()
    used_ids = {row["模型"] for row in rows if row.get("模型")}
    assert not (used_ids & LEGACY_PLACEHOLDER_IDS)


def test_mainline_task_spawn_units_exist_and_match_task_tier() -> None:
    rows = load_rows()
    for row in rows:
        unit_id = row["模型"]
        assert unit_id, f'{row["key"]} is missing spawn unit model'
        assert (EDITOR_UNIT_DIR / f"{unit_id}.json").exists(), f'{row["key"]} references missing unit {unit_id}'

        if row["数量"] == "1":
            assert unit_id.startswith("4"), f'{row["key"]} boss task should use a 4xxxxx boss unit id'
        else:
            assert unit_id.startswith("2"), f'{row["key"]} normal task should use a 2xxxxx minion unit id'


if __name__ == "__main__":
    test_mainline_tasks_do_not_use_legacy_placeholder_units()
    test_mainline_task_spawn_units_exist_and_match_task_tier()
    print("mainline task spawn units static ok")

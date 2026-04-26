from __future__ import annotations

import csv
import json
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CSV_DIR = ROOT / "data_csv"
TABLE_DIR = ROOT.parent / "tables"
TABLE_GROUP_INFO = ROOT.parent / "editor" / "tableeditorgroupinfo.json"
MIN_COLUMNS = 20
MIN_ROWS = 55
EDITOR_TABLE_ALLOWLIST = {
    "attack_skills",
    "battle_base_rules",
    "battlefield_scene_config",
    "battlefield_unit_config",
    "bond_nodes",
    "bond_root_sets",
    "challenges",
    "choice_panel_config",
    "evolution_nodes",
    "gear_upgrade_affixes",
    "gear_upgrade_levels",
    "gear_upgrade_slots",
    "hero_attr_config",
    "hero_form_skills",
    "hero_init_stats",
    "hero_level_progression",
    "hero_roster",
    "mainline_task_rewards",
    "stages",
    "treasures",
    "waves",
}
MANUAL_TABLE_ALLOWLIST = {
    "config1",
    "herolist",
}


def cell_value(raw: str) -> str | None:
    return raw if raw != "" else None


def load_group_tid_map() -> dict[str, str]:
    if not TABLE_GROUP_INFO.exists():
        return {}
    try:
        group_info = json.loads(TABLE_GROUP_INFO.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    tid_by_name: dict[str, str] = {}
    for entry in group_info:
        items = entry.get("items") if isinstance(entry, dict) else None
        if isinstance(items, list) and len(items) >= 2:
            tid_by_name[str(items[1])] = str(items[0])
    return tid_by_name


def load_existing_table_tids() -> dict[str, str]:
    tid_by_name: dict[str, str] = {}
    if not TABLE_DIR.exists():
        return tid_by_name
    for table_path in TABLE_DIR.glob("*.json"):
        try:
            table = json.loads(table_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        tid = table.get("tid")
        if tid:
            tid_by_name[table_path.stem] = str(tid)
    return tid_by_name


def build_table(csv_path: Path, tid: str) -> dict:
    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise ValueError(f"{csv_path} has no header row")
        fields = list(reader.fieldnames)
        rows = [
            row
            for row in reader
            if any((row.get(field) or "") != "" for field in fields)
        ]

    width = max(MIN_COLUMNS, len(fields) + 1)

    def pad(row: list[str | None]) -> list[str | None]:
        return row + [None] * (width - len(row))

    data: list[list[str | None]] = []
    data.append(pad(["key", *fields]))
    data.append(pad(["int", *(["string"] * len(fields))]))
    for index, row in enumerate(rows, start=1):
        data.append(pad([str(index), *[cell_value(row.get(field) or "") for field in fields]]))

    while len(data) < MIN_ROWS:
        data.append([None] * width)

    return {
        "column_width": {},
        "table_data": {
            "column_desc": {},
            "data": data,
            "key": [0],
        },
        "table_type": 0,
        "tid": tid,
    }


def main() -> None:
    TABLE_DIR.mkdir(parents=True, exist_ok=True)

    csv_files = [
        csv_path
        for csv_path in sorted(CSV_DIR.glob("*.csv"))
        if csv_path.stem in EDITOR_TABLE_ALLOWLIST
    ]
    if not csv_files:
        raise SystemExit(f"No CSV files found in {CSV_DIR}")

    group_tid_by_name = load_group_tid_map()
    table_tid_by_name = load_existing_table_tids()
    csv_names = {csv_path.stem for csv_path in csv_files}

    group_info: list[dict] = []
    for csv_path in csv_files:
        table_name = csv_path.stem
        tid = group_tid_by_name.get(table_name) or table_tid_by_name.get(table_name) or str(uuid.uuid4())
        table = build_table(csv_path, tid)
        out_path = TABLE_DIR / f"{csv_path.stem}.json"
        out_path.write_text(
            json.dumps(table, ensure_ascii=False, indent=4),
            encoding="utf-8",
        )
        group_info.append(
            {
                "__tuple__": True,
                "items": [table["tid"], table_name],
            }
        )

    for table_path in sorted(TABLE_DIR.glob("*.json")):
        table_name = table_path.stem
        if table_name in csv_names:
            continue
        if table_name not in MANUAL_TABLE_ALLOWLIST:
            table_path.unlink()
            continue
        tid = group_tid_by_name.get(table_name) or table_tid_by_name.get(table_name)
        if not tid:
            continue
        group_info.append(
            {
                "__tuple__": True,
                "items": [tid, table_name],
            }
        )

    TABLE_GROUP_INFO.write_text(
        json.dumps(group_info, ensure_ascii=False, indent=1),
        encoding="utf-8",
    )

    print(f"generated {len(csv_files)} Y3 editor tables into {TABLE_DIR}")


if __name__ == "__main__":
    main()

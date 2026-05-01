from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ROSTER_PATH = ROOT / "data_csv" / "hero_roster.csv"
TODO_PATH = ROOT / "docs" / "hero_roster_model_id_todo.csv"


def read_csv_dict(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        return (reader.fieldnames or []), list(reader)


def main() -> None:
    if not TODO_PATH.exists():
        raise SystemExit(f"[FAIL] todo file not found: {TODO_PATH}")
    if not ROSTER_PATH.exists():
        raise SystemExit(f"[FAIL] hero roster file not found: {ROSTER_PATH}")

    roster_fields, roster_rows = read_csv_dict(ROSTER_PATH)
    _, todo_rows = read_csv_dict(TODO_PATH)

    todo_by_id: dict[str, str] = {}
    for row in todo_rows:
        hero_id = (row.get("id", "") or "").strip()
        target_model_id = (row.get("target_model_id", "") or "").strip()
        if hero_id == "" or target_model_id == "":
            continue
        # 仅接收纯数字 model id
        if not target_model_id.isdigit():
            raise SystemExit(f"[FAIL] invalid target_model_id for {hero_id}: {target_model_id}")
        todo_by_id[hero_id] = target_model_id

    updated = 0
    for row in roster_rows:
        hero_id = (row.get("id", "") or "").strip()
        target = todo_by_id.get(hero_id)
        if not target:
            continue
        current = (row.get("model_id", "") or "").strip()
        if current != target:
            row["model_id"] = target
            updated += 1

    with ROSTER_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=roster_fields)
        writer.writeheader()
        writer.writerows(roster_rows)

    print(f"[OK] applied hero roster model_id updates: {updated}")


if __name__ == "__main__":
    main()


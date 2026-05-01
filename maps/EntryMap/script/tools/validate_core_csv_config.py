from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_CSV = ROOT / "data_csv"


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        return list(reader)


def fail(msg: str) -> None:
    raise SystemExit(f"[FAIL] {msg}")


def parse_positive_int(raw: str, field: str, row_no: int) -> int:
    value = (raw or "").strip()
    if value == "":
        fail(f"第{row_no}行字段 {field} 不能为空")
    try:
        number = int(value)
    except ValueError:
        fail(f"第{row_no}行字段 {field} 需要整数，当前={value}")
    if number <= 0:
        fail(f"第{row_no}行字段 {field} 需要 > 0，当前={value}")
    return number


def validate_optional_number(raw: str, field: str, row_no: int) -> None:
    value = (raw or "").strip()
    if value == "":
        return
    try:
        float(value)
    except ValueError:
        fail(f"第{row_no}行字段 {field} 需要数字，当前={value}")


def validate_hero_roster() -> None:
    path = DATA_CSV / "hero_roster.csv"
    rows = read_rows(path)
    if not rows:
        fail("hero_roster.csv 为空")

    initial_rows = [r for r in rows if (r.get("is_initial_hero", "") or "").strip().lower() in {"1", "true", "yes"}]
    if len(initial_rows) != 1:
        fail(f"hero_roster.csv 必须且只能有 1 个初始英雄，当前 {len(initial_rows)} 个")

    initial = initial_rows[0]
    if not (initial.get("unit_id", "") or "").strip():
        fail("初始英雄缺少 unit_id")

    hero_ids: set[str] = set()
    for i, row in enumerate(rows, start=2):
        hero_id = (row.get("id", "") or "").strip()
        if hero_id == "":
            fail(f"hero_roster.csv 第{i}行缺少 id")
        if hero_id in hero_ids:
            fail(f"hero_roster.csv 存在重复 id: {hero_id}")
        hero_ids.add(hero_id)

        if not (row.get("unit_id", "") or "").strip():
            fail(f"hero_roster.csv 第{i}行缺少 unit_id")
        validate_optional_number(row.get("model_id", ""), "model_id", i)

def validate_waves() -> None:
    path = DATA_CSV / "waves.csv"
    rows = read_rows(path)
    if not rows:
        fail("waves.csv 为空")

    required = [
        "id",
        "main_template_unit_id",
        "boss_template_unit_id",
        "spawn_area_id",
        "boss_spawn_area_id",
    ]
    ids: set[str] = set()
    for i, row in enumerate(rows, start=2):
        for key in required:
            if not (row.get(key, "") or "").strip():
                fail(f"waves.csv 第{i}行缺少必填字段: {key}")
        wave_id = (row.get("id", "") or "").strip()
        if wave_id in ids:
            fail(f"waves.csv 存在重复 id: {wave_id}")
        ids.add(wave_id)

        parse_positive_int(row.get("main_template_unit_id", ""), "main_template_unit_id", i)
        parse_positive_int(row.get("boss_template_unit_id", ""), "boss_template_unit_id", i)
        parse_positive_int(row.get("batch_min", ""), "batch_min", i)
        parse_positive_int(row.get("batch_max", ""), "batch_max", i)
        parse_positive_int(row.get("max_alive", ""), "max_alive", i)

        validate_optional_number(row.get("main_model_id", ""), "main_model_id", i)
        validate_optional_number(row.get("boss_model_id", ""), "boss_model_id", i)
        validate_optional_number(row.get("main_hp_max", ""), "main_hp_max", i)
        validate_optional_number(row.get("main_attack", ""), "main_attack", i)
        validate_optional_number(row.get("main_armor", ""), "main_armor", i)
        validate_optional_number(row.get("boss_hp_max", ""), "boss_hp_max", i)
        validate_optional_number(row.get("boss_attack", ""), "boss_attack", i)
        validate_optional_number(row.get("boss_armor", ""), "boss_armor", i)

        batch_min = int((row.get("batch_min", "") or "0").strip())
        batch_max = int((row.get("batch_max", "") or "0").strip())
        if batch_max < batch_min:
            fail(f"waves.csv 第{i}行 batch_max({batch_max}) 不能小于 batch_min({batch_min})")


def main() -> None:
    validate_hero_roster()
    validate_waves()
    print("[OK] core csv config validation passed")


if __name__ == "__main__":
    main()

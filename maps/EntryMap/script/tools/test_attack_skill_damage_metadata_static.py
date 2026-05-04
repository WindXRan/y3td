#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path
import csv


ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS_CSV = ROOT / "data_csv" / "attack_skills.csv"
SECOND_BATCH_SKILLS_CSV = ROOT / "data_csv" / "attack_skill_second_batch_skills.csv"
BLUEPRINTS_OBJECT_TABLE = ROOT / "data" / "object_tables" / "attack_skill_second_batch_blueprints.lua"


def read_csv_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def test_attack_skills_csv_exposes_structured_damage_fields():
    rows = read_csv_rows(ATTACK_SKILLS_CSV)
    first = rows[0]
    assert "damage_form" in first, "attack_skills.csv must expose damage_form"
    assert "element" in first, "attack_skills.csv must expose element"
    assert "damage_label" in first, "attack_skills.csv must expose damage_label"


def test_second_batch_blueprints_use_structured_damage_metadata():
    rows = read_csv_rows(SECOND_BATCH_SKILLS_CSV)
    first = rows[0]
    assert "damage_form" in first, "second batch skills csv must expose damage_form"
    assert "element" in first, "second batch skills csv must expose element"
    assert "damage_label" in first, "second batch skills csv must expose damage_label"
    assert "ui_icon" in first, "second batch skills csv must expose ui_icon"

    content = BLUEPRINTS_OBJECT_TABLE.read_text(encoding="utf-8")
    assert "damage_form = row.damage_form" in content, "second batch blueprints object table must map damage_form"
    assert "element = row.element" in content, "second batch blueprints object table must map element"
    assert "damage_label = row.damage_label" in content, "second batch blueprints object table must map damage_label"
    assert "ui_icon = to_scalar(row.ui_icon)" in content, "second batch blueprints object table must map ui_icon"


def main() -> None:
    test_attack_skills_csv_exposes_structured_damage_fields()
    test_second_batch_blueprints_use_structured_damage_metadata()
    print("attack skill damage metadata static ok")


if __name__ == "__main__":
    main()

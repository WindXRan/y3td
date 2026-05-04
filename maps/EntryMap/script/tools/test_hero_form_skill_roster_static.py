from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read_rows(relative_path: str) -> list[dict[str, str]]:
    with (ROOT / relative_path).open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


roster_rows = read_rows("data_csv/hero_roster.csv")
skill_rows = read_rows("data_csv/hero_form_skills.csv")
mark_rows = read_rows("data_csv/marks.csv")

assert len(roster_rows) == 30, "hero_roster.csv should contain 30 heroes"
assert len(skill_rows) == 30, "hero_form_skills.csv should contain 30 skills"

roster_by_id = {row["id"]: row for row in roster_rows}
roster_by_unit_id = {row["unit_id"]: row for row in roster_rows}
skill_by_hero_id = {row["hero_id"]: row for row in skill_rows}

assert len(roster_by_id) == 30, "hero ids should be unique"
assert len(roster_by_unit_id) == 30, "unit ids should be unique"
assert len(skill_by_hero_id) == 30, "hero_id should be unique in hero_form_skills.csv"

rarity_counts = {"R": 0, "SR": 0, "SSR": 0, "UR": 0}
for row in roster_rows:
    rarity_counts[row["rarity"]] += 1
    assert row["skill_id"] == skill_by_hero_id[row["id"]]["id"], f"hero {row['id']} should point to its skill id"

assert rarity_counts == {"R": 12, "SR": 9, "SSR": 6, "UR": 3}, "rarity distribution should be 12/9/6/3"

for mark in mark_rows:
    unit_id = mark["hero_unit_id"]
    assert unit_id in roster_by_unit_id, f"current evolution hero_unit_id {unit_id} should map to hero_roster.csv"

print("hero form skill roster static ok")

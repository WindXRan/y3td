#!/usr/bin/env python3
from __future__ import annotations

import csv
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'data_csv'
VALIDATE = ROOT / 'tools' / 'validate_tables.py'


def read_rows(path: Path):
    with path.open('r', encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def write_rows(path: Path, rows, headers):
    with path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows)


def run_expect_fail(case_name: str, mutate):
    with tempfile.TemporaryDirectory() as td:
        dst = Path(td)
        shutil.copy(SRC / 'bond_skills.csv', dst / 'bond_skills.csv')
        shutil.copy(SRC / 'bond_skill_params.csv', dst / 'bond_skill_params.csv')
        mutate(dst)
        cp = subprocess.run(
            ['python', str(VALIDATE), '--tables', 'bond_skills', '--strict', '--csv-dir', str(dst)],
            capture_output=True,
            text=True,
            check=False,
        )
        if cp.returncode == 0:
            raise AssertionError(f'{case_name} should fail but passed')


def case_dup_skill(dst: Path):
    rows = read_rows(dst / 'bond_skills.csv')
    rows.append(dict(rows[0]))
    write_rows(dst / 'bond_skills.csv', rows, rows[0].keys())


def case_bad_damage(dst: Path):
    rows = read_rows(dst / 'bond_skills.csv')
    rows[0]['damage_type'] = '混合'
    write_rows(dst / 'bond_skills.csv', rows, rows[0].keys())


def case_missing_dragon(dst: Path):
    rows = read_rows(dst / 'bond_skill_params.csv')
    rows = [r for r in rows if not (r['skill_id'] == 'dragon_fireball' and r['param_key'] == 'line_width_default')]
    write_rows(dst / 'bond_skill_params.csv', rows, rows[0].keys())


def main():
    run_expect_fail('duplicate skill', case_dup_skill)
    run_expect_fail('invalid damage_type', case_bad_damage)
    run_expect_fail('missing dragon key', case_missing_dragon)
    print('OK negative table validation cases passed')


if __name__ == '__main__':
    main()

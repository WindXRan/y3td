#!/usr/bin/env python3
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'data_csv' / 'bond_skills_legacy_with_params.csv'
DST = ROOT / 'data_csv' / 'bond_skill_params.csv'


def main() -> int:
    if not SRC.exists():
        print(f'legacy source not found: {SRC}')
        return 1
    rows = list(csv.DictReader(SRC.open('r', encoding='utf-8-sig', newline='')))
    out = []
    for row in rows:
        sid = (row.get('skill_id') or '').strip()
        params = (row.get('params') or '').strip()
        if not sid or not params:
            continue
        for pair in params.split(';'):
            pair = pair.strip()
            if not pair or '=' not in pair:
                continue
            key, value = pair.split('=', 1)
            key = key.strip()
            value = value.strip()
            if not key:
                continue
            vtype = 'string'
            lower = value.lower()
            try:
                float(value)
                vtype = 'number'
            except ValueError:
                if lower in {'1', '0', 'true', 'false'}:
                    vtype = 'bool'
            out.append({
                'skill_id': sid,
                'param_key': key,
                'param_value': value,
                'value_type': vtype,
                'enabled': '1',
            })

    with DST.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['skill_id', 'param_key', 'param_value', 'value_type', 'enabled'])
        writer.writeheader()
        writer.writerows(out)
    print(f'written {len(out)} params -> {DST}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

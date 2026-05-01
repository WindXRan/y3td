#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_DIR = ROOT / 'data_csv'

VALID_SCOPES = {
    'bond_basic', 'bond_periodic', 'card_basic', 'card_periodic',
    'card_kill', 'dragon_fireball', 'card_arrow_rain',
    'basic_attack_profile',
}
VALID_TRIGGER_KINDS = {'basic_attack', 'periodic', 'kill', 'special'}
VALID_DAMAGE_TYPES = {'', '物理', '法术'}
VALID_VALUE_TYPES = {'number', 'bool', 'string'}


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(str(path))
    with path.open('r', encoding='utf-8-sig', newline='') as f:
        rows = list(csv.DictReader(f))
    if not rows:
        return rows
    first_key = next(iter(rows[0].keys()), None)
    if not first_key:
        return rows
    return [r for r in rows if (r.get(first_key) or '').strip() != '__字段说明__']


def parse_enabled(raw: str) -> bool:
    v = (raw or '').strip().lower()
    return v in ('', '1', 'true')


def check_bond_tables(strict: bool, csv_dir: Path) -> list[str]:
    errors: list[str] = []
    skills = read_csv(csv_dir / 'bond_skills.csv')
    params_path = csv_dir / 'bond_skill_params.csv'
    params = read_csv(params_path) if params_path.exists() else []

    by_id: dict[str, dict[str, str]] = {}
    skill_has_params_json: dict[str, bool] = {}
    for i, row in enumerate(skills, 2):
        if not parse_enabled(row.get('enabled', '1')):
            continue
        sid = (row.get('skill_id') or '').strip()
        if not sid:
            errors.append(f'bond_skills.csv:{i} skill_id 不能为空')
            continue
        if sid in by_id:
            errors.append(f'bond_skills.csv:{i} skill_id 重复: {sid}')
            continue
        scope = (row.get('scope') or '').strip()
        if scope not in VALID_SCOPES:
            errors.append(f'bond_skills.csv:{i} 非法 scope: {scope}')
        trigger_kind = (row.get('trigger_kind') or '').strip()
        if trigger_kind and trigger_kind not in VALID_TRIGGER_KINDS:
            errors.append(f'bond_skills.csv:{i} 非法 trigger_kind: {trigger_kind}')
        damage_type = (row.get('damage_type') or '').strip()
        if damage_type not in VALID_DAMAGE_TYPES:
            errors.append(f'bond_skills.csv:{i} 非法 damage_type: {damage_type}')
        params_json_raw = (row.get('params_json') or '').strip()
        has_params_json = bool(params_json_raw)
        if has_params_json:
            try:
                parsed = json.loads(params_json_raw)
                if not isinstance(parsed, dict):
                    errors.append(f'bond_skills.csv:{i} params_json 必须是对象')
            except Exception as exc:  # noqa: BLE001
                errors.append(f'bond_skills.csv:{i} params_json 解析失败: {exc}')
        skill_has_params_json[sid] = has_params_json
        by_id[sid] = row

    dragon_keys = set()
    is_long_param_table = bool(params) and 'param_key' in params[0]
    wide_params_by_skill: dict[str, dict[str, str]] = {}
    if is_long_param_table:
        for i, row in enumerate(params, 2):
            if not parse_enabled(row.get('enabled', '1')):
                continue
            sid = (row.get('skill_id') or '').strip()
            key = (row.get('param_key') or '').strip()
            val = (row.get('param_value') or '').strip()
            vtype = (row.get('value_type') or '').strip().lower()
            if not sid:
                errors.append(f'bond_skill_params.csv:{i} skill_id 不能为空')
                continue
            if sid not in by_id:
                errors.append(f'bond_skill_params.csv:{i} 悬挂参数 skill_id 不存在: {sid}')
                continue
            if not key:
                errors.append(f'bond_skill_params.csv:{i} param_key 不能为空')
            if vtype not in VALID_VALUE_TYPES:
                errors.append(f'bond_skill_params.csv:{i} 非法 value_type: {vtype}')
            elif vtype == 'number':
                try:
                    float(val)
                except ValueError:
                    errors.append(f'bond_skill_params.csv:{i} number 解析失败: {val}')
            elif vtype == 'bool':
                if val.lower() not in {'1', '0', 'true', 'false'}:
                    errors.append(f'bond_skill_params.csv:{i} bool 解析失败: {val}')
            if sid == 'dragon_fireball' and not skill_has_params_json.get(sid, False):
                dragon_keys.add(key)
    else:
        for row in params:
            if not parse_enabled(row.get('enabled', '1')):
                continue
            sid = (row.get('skill_id') or '').strip()
            if not sid or sid not in by_id:
                continue
            wide_params_by_skill[sid] = row

    required_dragon = {'line_distance_default', 'line_width_default', 'tick_interval'}
    dragon_row = by_id.get('dragon_fireball')
    if dragon_row:
        if skill_has_params_json.get('dragon_fireball', False):
            try:
                obj = json.loads((dragon_row.get('params_json') or '').strip())
                missing = sorted(k for k in required_dragon if k not in obj)
                if missing:
                    errors.append(f'dragon_fireball params_json 缺关键参数: {", ".join(missing)}')
            except Exception:
                pass
        else:
            if is_long_param_table:
                missing = sorted(required_dragon - dragon_keys)
            else:
                row = wide_params_by_skill.get('dragon_fireball', {})
                missing = sorted(
                    k for k in required_dragon
                    if not str((row.get(k) or '')).strip()
                )
            if missing:
                errors.append(f'dragon_fireball 缺关键参数: {", ".join(missing)}')

    if strict and errors:
        return errors
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--tables', default='all')
    parser.add_argument('--strict', action='store_true')
    parser.add_argument('--csv-dir', default=str(CSV_DIR))
    args = parser.parse_args()
    csv_dir = Path(args.csv_dir)

    try:
        if args.tables in ('all', 'bond_skills'):
            errors = check_bond_tables(args.strict, csv_dir)
        else:
            print(f'unsupported tables: {args.tables}')
            return 2
    except Exception as exc:  # noqa: BLE001
        print(f'validate exception: {exc}')
        return 2

    if errors:
        for err in errors:
            print(f'[FAIL] {err}')
        return 1
    print('[OK] table validation passed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

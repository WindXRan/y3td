#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EDITOR_TABLE = ROOT / "editor_table"
RAW_OBJECT_DIRS = {
    "ability": ROOT / "ability",
    "item": ROOT / "item",
    "modifier": ROOT / "modifier",
    "projectile": ROOT / "projectile",
    "unit": ROOT / "unit",
}

EDITOR_TABLE_DIRS = {
    "abilityall": EDITOR_TABLE / "abilityall",
    "editoritem": EDITOR_TABLE / "editoritem",
    "modifierall": EDITOR_TABLE / "modifierall",
    "projectileall": EDITOR_TABLE / "projectileall",
    "editorunit": EDITOR_TABLE / "editorunit",
}

NUMERIC_JSON = re.compile(r"^[0-9]+\.json$")


@dataclass
class Issue:
    scope: str
    path: str
    message: str


def infer_editor_table_type(data: dict) -> str:
    keys = set(data.keys())
    if "ability_cast_type" in keys:
        return "abilityall"
    if "modifier_type" in keys:
        return "modifierall"
    if "move_channel" in keys and "max_duration" in keys:
        return "projectileall"
    if "item_billboard_type" in keys or "maximum_stacking" in keys:
        return "editoritem"
    if "common_atk_type" in keys or "attack_phy_grow" in keys or "ori_speed" in keys:
        return "editorunit"
    return "unknown"


def audit_editor_table() -> list[Issue]:
    issues: list[Issue] = []
    for scope, folder in EDITOR_TABLE_DIRS.items():
        if not folder.exists():
            issues.append(Issue(scope, str(folder), "目录不存在"))
            continue
        for path in sorted(folder.glob("*.json")):
            if not NUMERIC_JSON.match(path.name):
                issues.append(Issue(scope, str(path), "文件名不是纯数字ID.json"))
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception as exc:
                issues.append(Issue(scope, str(path), f"JSON解析失败: {exc}"))
                continue

            key = data.get("key")
            if key is None:
                issues.append(Issue(scope, str(path), "缺少 key 字段"))
            elif str(key) != path.stem:
                issues.append(Issue(scope, str(path), f"key({key}) 与文件名({path.stem})不一致"))

            inferred = infer_editor_table_type(data)
            if inferred != "unknown" and inferred != scope:
                issues.append(Issue(scope, str(path), f"类型疑似错放: 推断为 {inferred}"))
    return issues


def audit_raw_object_dirs() -> list[Issue]:
    issues: list[Issue] = []
    for scope, folder in RAW_OBJECT_DIRS.items():
        if not folder.exists():
            issues.append(Issue(scope, str(folder), "目录不存在"))
            continue
        for path in sorted(folder.glob("*.json")):
            if not NUMERIC_JSON.match(path.name):
                issues.append(Issue(scope, str(path), "文件名不是纯数字ID.json"))
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception as exc:
                issues.append(Issue(scope, str(path), f"JSON解析失败: {exc}"))
                continue

            trigger_groups = data.get("trigger_group_info")
            if not isinstance(trigger_groups, list):
                issues.append(Issue(scope, str(path), "缺少 trigger_group_info 列表"))
                continue

            matched = False
            for entry in trigger_groups:
                if isinstance(entry, dict) and str(entry.get("key", "")) == path.stem:
                    matched = True
                    break
            if not matched:
                issues.append(Issue(scope, str(path), "trigger_group_info.key 与文件名不一致"))
    return issues


def main() -> int:
    issues = []
    issues.extend(audit_editor_table())
    issues.extend(audit_raw_object_dirs())

    if not issues:
        print("OK: 物编文件夹分类与命名校验通过")
        return 0

    print(f"FAIL: 发现 {len(issues)} 个问题")
    for issue in issues[:200]:
        print(f"[{issue.scope}] {issue.path} :: {issue.message}")
    if len(issues) > 200:
        print(f"... 其余 {len(issues)-200} 个问题已省略")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

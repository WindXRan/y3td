#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RULE_FILE = ROOT / "data" / "object_tables" / "bond_effect_runtime_rules.lua"


def fail(msg: str) -> None:
    raise SystemExit(msg)


def main() -> None:
    text = RULE_FILE.read_text(encoding="utf-8")

    errors: list[str] = []

    if "max_target_count = 0" in text:
        errors.append("禁止出现 max_target_count = 0（语义不清）。")

    # AOE 规则不应设置最大命中数（用户约束）；点名链可保留 max_target_count。
    aoe_blocks = re.finditer(r"\['([^']+)'\]\s*=\s*\{([\s\S]*?)\n  \},", text)
    for m in aoe_blocks:
        name = m.group(1)
        body = m.group(2)
        has_aoe = ("aoe_radius" in body) or ("storm_radius" in body) or ("radius" in body and "arrow_rain" in body)
        has_cap = "max_target_count" in body
        if has_aoe and has_cap and name not in ("雷电法王",):
            errors.append(f"{name}: AOE 规则不应设置 max_target_count。")

    # 伤害类型只能 物理/法术/真实
    for bad in re.findall(r"damage_type\s*=\s*'([^']+)'", text):
        if bad not in ("物理", "法术", "真实"):
            errors.append(f"非法 damage_type: {bad}")

    if errors:
        fail("[bond_rules_strict] FAIL\n- " + "\n- ".join(errors))

    print("[bond_rules_strict] PASS")


if __name__ == "__main__":
    main()


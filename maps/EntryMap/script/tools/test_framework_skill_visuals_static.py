from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "script" / "runtime" / "sample_skills.lua"


def fail(msg: str) -> None:
    print(f"[FAIL] {msg}")
    sys.exit(1)


def main() -> None:
    text = SRC.read_text(encoding="utf-8")
    blocks = re.findall(
        r"register_framework_def\('([^']+)'\s*,\s*\{(.*?)\}\)",
        text,
        re.S,
    )
    if not blocks:
        fail("未找到 register_framework_def 调用")

    required = {
        "sf_line_pierce": ("cast", "hit", "projectile_key"),
        "sf_area_burst": ("warning", "impact", "hit"),
        "sf_area_tick": ("warning", "cast", "hit"),
        "sf_chain_bounce": ("hit",),
    }

    for skill_id, body in blocks:
        if skill_id not in required:
            continue
        for key in required[skill_id]:
            if not re.search(rf"{key}\s*=", body):
                fail(f"{skill_id} 缺少 visual.{key}")
            if re.search(rf"{key}\s*=\s*0\b", body):
                fail(f"{skill_id} 的 visual.{key} 不能为 0")

    print(f"[PASS] framework visuals static check ok: {len(blocks)} registrations")


if __name__ == "__main__":
    main()

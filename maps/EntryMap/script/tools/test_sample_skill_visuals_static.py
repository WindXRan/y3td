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
    m = re.search(r"local SAMPLE_VISUALS = \{(.*?)\n  \}", text, re.S)
    if not m:
        fail("未找到 SAMPLE_VISUALS 表")
    block = m.group(1)

    sample_blocks = re.findall(r"\n    ([a-zA-Z0-9_]+)\s*=\s*\{(.*?)\n    \},", block, re.S)
    if not sample_blocks:
        fail("未解析到任何 sample visual 配置")

    required_particles = ("cast", "impact", "hit")
    projectile_required = {
        "arrow_rain", "blizzard", "line_lance", "meteor_grid", "orbit_blade",
        "chain_arc", "fan_barrage", "burn_field", "boomerang_blade", "mark_execute",
        "sg_guanyu_qinglong", "sg_zhaoyun_charge", "sg_zhuge_stars", "sg_lvbu_cleave",
    }

    for sample_id, body in sample_blocks:
        for key in required_particles:
            if re.search(rf"{key}\s*=\s*0\b", body):
                fail(f"{sample_id} 的 {key} 不能为 0")
            if not re.search(rf"{key}\s*=", body):
                fail(f"{sample_id} 缺少 {key}")
        if sample_id in projectile_required:
            if re.search(r"projectile_key\s*=\s*0\b", body):
                fail(f"{sample_id} 的 projectile_key 不能为 0")
            if "projectile_key" not in body:
                fail(f"{sample_id} 缺少 projectile_key")

    print(f"[PASS] sample visuals static check ok: {len(sample_blocks)} entries")


if __name__ == "__main__":
    main()

#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FILES = [
    ROOT / "entry_objects" / "attack_skills" / "basic_attack.lua",
    ROOT / "data_csv" / "attack_skills.csv",
]


def test_core_skill_copy_no_longer_uses_old_element_magic_phrasing():
    banned = ["能量魔法", "电系魔法", "冰系魔法", "火系物理", "物理伤害。"]
    joined = "\n".join(path.read_text(encoding="utf-8") for path in FILES)
    for needle in banned:
        assert needle not in joined, f"old phrasing should be removed: {needle}"


def main() -> None:
    test_core_skill_copy_no_longer_uses_old_element_magic_phrasing()
    print("xianxia damage copy static ok")


if __name__ == "__main__":
    main()

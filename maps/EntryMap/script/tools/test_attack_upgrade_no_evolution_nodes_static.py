#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


UPGRADES = Path(__file__).resolve().parents[1] / "runtime" / "attack_upgrades.lua"


def main() -> None:
    content = UPGRADES.read_text(encoding="utf-8")

    expected_bucket_block = """local BLUEPRINT_BUCKET_ORDER = {
    'common',
    'excellent',
    'rare',
  }"""
    if expected_bucket_block not in content:
        raise AssertionError("新版初始技能 G 池仍然保留了进化节点桶")

    if "if card.lane == 'legendary' then" in content:
        raise AssertionError("新版初始技能 G 池不应继续处理 legendary 进化节点")

    print("attack upgrade no evolution nodes static ok")


if __name__ == "__main__":
    main()

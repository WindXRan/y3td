#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


UPGRADES = Path(__file__).resolve().parents[1] / 'runtime' / 'attack_upgrades.lua'


def assert_contains(needle: str, message: str) -> None:
    content = UPGRADES.read_text(encoding='utf-8')
    if needle not in content:
        raise AssertionError(message)


def main() -> None:
    assert_contains(
        "def.can_offer = def.can_offer or function()\n      return get_attack_skill(def.skill_id) ~= nil\n    end",
        '常规技能强化缺少“仅已解锁技能可投放”的默认前置',
    )
    print('attack upgrade offer gating ok')


if __name__ == '__main__':
    main()

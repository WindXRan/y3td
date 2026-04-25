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
        'local function build_blueprint_unlock_upgrades()',
        '升级系统缺少从第二批蓝图生成解锁卡的入口函数',
    )
    assert_contains(
        'for _, blueprint in ipairs(ATTACK_SKILL_BLUEPRINTS.list or {}) do',
        '升级系统没有遍历第二批技能蓝图',
    )
    assert_contains(
        'if not ATTACK_SKILL_DEFS[blueprint.id] then',
        '升级系统没有跳过尚未实现施法的第二批技能',
    )
    assert_contains(
        'for _, upgrade in ipairs(build_blueprint_unlock_upgrades()) do',
        '升级系统没有把蓝图生成的解锁卡并入总升级池',
    )
    print('attack upgrade blueprint unlocks ok')


if __name__ == '__main__':
    main()

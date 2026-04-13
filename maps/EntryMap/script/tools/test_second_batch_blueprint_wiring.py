#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS_INIT = ROOT / 'entry_objects' / 'attack_skills' / 'init.lua'
ATTACK_SKILLS_OBJECT_TABLE = ROOT / 'data' / 'object_tables' / 'attack_skills.lua'
BOOT = ROOT / 'runtime' / 'boot.lua'
UPGRADES = ROOT / 'runtime' / 'attack_upgrades.lua'


def assert_contains(path: Path, needle: str, message: str) -> None:
    content = path.read_text(encoding='utf-8')
    if needle not in content:
        raise AssertionError(f'{message}: {path}')


def main() -> None:
    assert_contains(
        ATTACK_SKILLS_INIT,
        "return require 'data.object_tables.attack_skills'",
        'attack_skills init 没有桥接到 csv object table',
    )
    assert_contains(
        ATTACK_SKILLS_OBJECT_TABLE,
        "local SecondBatchBlueprints = require 'entry_objects.attack_skill_blueprints.second_batch_skills'",
        'attack_skills object table 没有加载第二批攻击技能蓝图',
    )
    assert_contains(
        ATTACK_SKILLS_OBJECT_TABLE,
        'blueprints = SecondBatchBlueprints',
        'attack_skills object table 没有导出第二批技能蓝图对象',
    )
    assert_contains(
        BOOT,
        'local ATTACK_SKILL_BLUEPRINTS = AttackSkillObjects.blueprints',
        'boot 没有缓存攻击技能蓝图引用',
    )
    assert_contains(
        BOOT,
        'ATTACK_SKILL_BLUEPRINTS = ATTACK_SKILL_BLUEPRINTS,',
        'boot 没有把攻击技能蓝图传给升级系统',
    )
    assert_contains(
        UPGRADES,
        'local ATTACK_SKILL_BLUEPRINTS = env.ATTACK_SKILL_BLUEPRINTS',
        'attack_upgrades 没有接收第二批攻击技能蓝图',
    )
    print('second batch blueprint wiring ok')


if __name__ == '__main__':
    main()

#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / 'runtime' / 'boot.lua'
REWARDS = ROOT / 'runtime' / 'rewards.lua'


def assert_contains(path: Path, needle: str, message: str) -> None:
    content = path.read_text(encoding='utf-8')
    if needle not in content:
      raise AssertionError(f'{message}: {path}')


def main() -> None:
    assert_contains(
        REWARDS,
        'api.apply_treasure_bonus_to_attack_skill = apply_treasure_bonus_to_attack_skill',
        '奖励系统没有导出攻击技能宝物加成应用函数',
    )
    assert_contains(
        RUNTIME,
        'local function apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)',
        '运行时没有定义攻击技能宝物加成转发函数',
    )
    assert_contains(
        RUNTIME,
        'return reward_system.apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)',
        '运行时没有将攻击技能宝物加成转发到奖励系统',
    )
    print('attack skill bonus wiring ok')


if __name__ == '__main__':
    main()

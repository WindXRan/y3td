#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
LUA = Path.home() / 'AppData' / 'Local' / 'Programs' / 'Lua' / '5.4.8' / 'lua.exe'


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        encoding='utf-8',
        errors='replace',
        capture_output=True,
        check=False,
    )


def assert_ok(result: subprocess.CompletedProcess[str], message: str) -> None:
    if result.returncode != 0:
        raise AssertionError(f'{message}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}')


def main() -> None:
    smoke = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local cfg = require('entry_data.hero_attr_config') "
        "assert(cfg.hero_init_stats['攻击白字'] == 46) "
        "assert(cfg.hero_init_stats['攻击绿字'] == 0) "
        "assert(cfg.hero_init_stats['生命白字'] == 900) "
        "assert(cfg.hero_init_stats['生命绿字'] == 0) "
        "assert(cfg.hero_init_stats['力量白字'] == 0) "
        "assert(cfg.hero_init_stats['力量绿字'] == 0) "
        "assert(cfg.hero_init_stats['敏捷白字'] == 0) "
        "assert(cfg.hero_init_stats['敏捷绿字'] == 0) "
        "assert(cfg.hero_init_stats['智力白字'] == 0) "
        "assert(cfg.hero_init_stats['智力绿字'] == 0) "
        "assert(cfg.hero_init_stats['物理暴击'] == 10) "
        "assert(cfg.hero_init_stats['物理暴伤'] == 25) "
        "assert(cfg.hero_init_stats['命中'] == 0) "
        "assert(cfg.hero_init_stats['挑战伤害'] == 0) "
        "assert(cfg.hero_init_stats['精控伤害'] == 0) "
        "assert(cfg.hero_init_stats['冻结伤害'] == 0) "
        "assert(cfg.hero_init_stats['最终攻击'] == 0) "
        "assert(cfg.hero_init_stats['最终生命'] == 0) "
        "assert(cfg.hero_init_stats['最终护甲'] == 0) "
        "assert(cfg.hero_init_stats['攻击结算值'] == 0) "
        "assert(cfg.hero_init_stats['生命结算值'] == 0) "
        "assert(cfg.hero_init_stats['护甲结算值'] == 0) "
        "assert(cfg.hero_init_stats['每秒生命'] == 0) "
        "assert(cfg.hero_init_stats['杀敌护甲'] == 0) "
        "assert(cfg.debug_hero_bonus_stats['攻击'] == 72) "
        "assert(cfg.debug_hero_bonus_stats['生命'] == 1400) "
        "print('hero_attr_config smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_config smoke failed')


if __name__ == '__main__':
    main()

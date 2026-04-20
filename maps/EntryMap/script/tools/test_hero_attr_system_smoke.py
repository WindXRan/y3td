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
        "local system = require('runtime.hero_attr_system').create() "
        "local hero = { attrs = {} } "
        "function hero:set_attr(name, value) self.attrs[name] = value end "
        "function hero:add_attr(name, value) self.attrs[name] = (self.attrs[name] or 0) + value end "
        "function hero:get_attr(name) return self.attrs[name] or 0 end "
        "function hero:is_exist() return true end "
        "local state = { resources = { gold = 0, wood = 0 }, hero_attr_runtime = {} } "
        "system.init_hero_attrs(hero, { ['攻击'] = 100, ['力量'] = 50, ['敏捷'] = 30, ['智力'] = 20, ['生命'] = 200 }) "
        "assert(system.normalize_name('物理攻击') == '攻击') "
        "assert(system.get_attr(hero, '物理攻击') == 100) "
        "system.add_attr(hero, '每秒攻击', 5) "
        "system.add_attr(hero, '每秒金币', 5) "
        "system.tick_per_second_growth(hero, 1.0, state) "
        "assert(system.get_attr(hero, '攻击') == 105) "
        "assert(state.resources.gold == 5) "
        "system.add_attr(hero, '杀敌攻击', 2) "
        "system.add_attr(hero, '杀敌生命', 3) "
        "system.apply_kill_growth(hero, state) "
        "assert(system.get_attr(hero, '攻击') == 107) "
        "assert(system.get_attr(hero, '生命') == 203) "
        "system.add_attr(hero, '最终攻击', 10) "
        "system.add_attr(hero, '最终生命', 20) "
        "system.add_attr(hero, '最终护甲', 30) "
        "system.rebuild_derived_attrs(hero) "
        "assert(system.get_attr(hero, '最终攻击') == 10) "
        "assert(system.get_attr(hero, '最终生命') == 20) "
        "assert(system.get_attr(hero, '最终护甲') == 30) "
        "assert(system.get_attr(hero, '攻击结算值') > 107) "
        "assert(system.get_attr(hero, '生命结算值') > 203) "
        "assert(system.get_attr(hero, '护甲结算值') >= 0) "
        "system.snapshot(hero, state) "
        "assert(state.hero_attr_runtime['攻击'] == 107) "
        "print('hero_attr_system smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_system smoke failed')


if __name__ == '__main__':
    main()

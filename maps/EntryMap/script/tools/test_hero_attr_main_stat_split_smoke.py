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
        "local hero = { attrs = {}, kv = {} } "
        "function hero:set_attr(name, value) self.attrs[name] = value end "
        "function hero:get_attr(name) return self.attrs[name] or 0 end "
        "function hero:kv_save(key, value) self.kv[key] = value end "
        "function hero:kv_load(key, _) return self.kv[key] end "
        "function hero:kv_has(key) return self.kv[key] ~= nil end "
        "system.init_hero_attrs(hero, { ['攻击白字'] = 10, ['力量白字'] = 50, ['力量绿字'] = 20, ['敏捷白字'] = 30, ['敏捷绿字'] = 5, ['智力白字'] = 40, ['智力绿字'] = 15 }) "
        "assert(system.get_attr(hero, '力量') == 70, 'expected strength total') "
        "assert(system.get_attr(hero, '敏捷') == 35, 'expected agility total') "
        "assert(system.get_attr(hero, '智力') == 55, 'expected intelligence total') "
        "assert(system.get_attr(hero, '最终力量') == 70, 'expected final strength without ratios') "
        "assert(system.get_attr(hero, '最终敏捷') == 35, 'expected final agility without ratios') "
        "assert(system.get_attr(hero, '最终智力') == 55, 'expected final intelligence without ratios') "
        "assert(system.get_attr(hero, '攻击结算值') == 26, 'expected attack to include split main stats') "
        "print('hero_attr_main_stat_split smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_main_stat_split smoke failed')


if __name__ == '__main__':
    main()

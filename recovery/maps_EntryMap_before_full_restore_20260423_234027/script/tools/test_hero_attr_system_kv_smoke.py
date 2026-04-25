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
        "y3 = { const = { UnitAttr = { ['生命'] = 1, ['攻击'] = 2, ['攻击速度'] = 3 } } } "
        "local system = require('runtime.hero_attr_system').create() "
        "local hero = { attrs = {}, kv = {} } "
        "function hero:set_attr(name, value) self.attrs[name] = value end "
        "function hero:add_attr(name, value) self.attrs[name] = (self.attrs[name] or 0) + value end "
        "function hero:get_attr(name) return self.attrs[name] or 0 end "
        "function hero:kv_save(key, value) self.kv[key] = value end "
        "function hero:kv_load(key, _) return self.kv[key] end "
        "function hero:kv_has(key) return self.kv[key] ~= nil end "
        "function hero:is_exist() return true end "
        "system.init_hero_attrs(hero, { ['攻击'] = 46, ['生命'] = 900, ['攻击速度'] = 95, ['最终攻击'] = 10 }) "
        "hero.attrs['攻击'] = 0 "
        "hero.attrs['生命'] = 0 "
        "hero.attrs['攻击速度'] = 0 "
        "assert(system.get_attr(hero, '攻击') == 46, 'expected attack from kv') "
        "assert(system.get_attr(hero, '生命') == 900, 'expected life from kv') "
        "assert(system.get_attr(hero, '攻击速度') == 95, 'expected attack speed from kv') "
        "assert(system.get_attr(hero, '最终攻击') == 10, 'expected final attack from kv') "
        "system.add_attr(hero, '攻击', 4) "
        "assert(system.get_attr(hero, '攻击') == 50, 'expected kv add attr to work') "
        "print('hero_attr_system kv smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_system kv smoke failed')


if __name__ == '__main__':
    main()

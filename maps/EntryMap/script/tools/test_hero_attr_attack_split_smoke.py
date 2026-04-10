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
        "system.init_hero_attrs(hero, { ['攻击白字'] = 46, ['攻击绿字'] = 12, ['最终攻击'] = 10 }) "
        "assert(system.get_attr(hero, '攻击白字') == 46, 'expected white attack') "
        "assert(system.get_attr(hero, '攻击绿字') == 12, 'expected green attack') "
        "assert(system.get_attr(hero, '攻击') == 58, 'expected attack to equal white + green') "
        "assert(system.get_attr(hero, '攻击结算值') > 58, 'expected final attack bonus applied after sum') "
        "print('hero_attr_attack_split smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_attack_split smoke failed')


if __name__ == '__main__':
    main()

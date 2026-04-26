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
        "y3 = { const = { UnitAttr = { ['生命'] = 'hp_cur', ['最大生命'] = 'hp_max', ['物理攻击'] = 'attack_phy' } } } "
        "local system = require('runtime.hero_attr_system').create() "
        "local hero = { attrs = {}, kv = {} } "
        "function hero:set_attr(name, value) self.attrs[name] = value end "
        "function hero:get_attr(name) return self.attrs[name] or 0 end "
        "function hero:kv_save(key, value) self.kv[key] = value end "
        "function hero:kv_load(key, _) return self.kv[key] end "
        "function hero:kv_has(key) return self.kv[key] ~= nil end "
        "system.init_hero_attrs(hero, { ['攻击白字'] = 60, ['生命'] = 900 }) "
        "assert((hero.attrs['最大生命'] or 0) == 900, 'expected engine hp_max synced to 900') "
        "assert((system.get_attr(hero, '生命结算值') or 0) == 900, 'expected life final value 900') "
        "assert((hero.attrs['物理攻击'] or 0) == system.get_attr(hero, '攻击结算值'), 'expected engine physical attack synced to final attack') "
        "print('hero_attr_system sync hp_max smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_system sync engine hp_max smoke failed')


if __name__ == '__main__':
    main()

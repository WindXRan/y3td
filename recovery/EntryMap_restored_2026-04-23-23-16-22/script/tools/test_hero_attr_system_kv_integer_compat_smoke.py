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
        "y3 = { const = { UnitAttr = {} } } "
        "local system = require('runtime.hero_attr_system').create() "
        "local hero = { attrs = {}, kv = { ['__hero_attr__:攻击'] = 46 } } "
        "function hero:set_attr(name, value) self.attrs[name] = value end "
        "function hero:get_attr(name) return self.attrs[name] or 0 end "
        "function hero:kv_save(key, value) self.kv[key] = value end "
        "function hero:kv_has(key) return self.kv[key] ~= nil end "
        "function hero:kv_load(key, lua_type) "
        "  if lua_type == 'number' then error('ea_kv_type_error') end "
        "  return self.kv[key] "
        "end "
        "assert(system.get_attr(hero, '攻击') == 46, 'expected integer kv fallback to work') "
        "print('hero_attr_system kv integer compat smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_system kv integer compat smoke failed')


if __name__ == '__main__':
    main()

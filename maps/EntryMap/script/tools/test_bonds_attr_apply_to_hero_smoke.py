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
        "local bonds = require('runtime.bonds') "
        "local hero = { attrs = {} } "
        "function hero:is_exist() return true end "
        "function hero:get_attr(name) return self.attrs[name] or 0 end "
        "function hero:add_attr(name, value) self.attrs[name] = (self.attrs[name] or 0) + value end "
        "local state = { bond_runtime = bonds.create_runtime(), hero = hero, resources = { wood = 0 } } "
        "assert(bonds.unlock_node(state, 'bond_growth_core')) "
        "assert(bonds.unlock_node(state, 'bond_growth_strength')) "
        "local hero_attr_system = { "
        "  add_attr = function(unit, name, value) unit:add_attr(name, value) end, "
        "  rebuild_derived_attrs = function() end "
        "} "
        "bonds.refresh_effects({ STATE = state, hero_attr_system = hero_attr_system, sync_basic_attack_ability = function() end }) "
        "assert((hero:get_attr('力量') or 0) >= 100, 'expected bond static attr applied to hero') "
        "print('bonds attr apply to hero smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'bonds attr apply to hero smoke failed')


if __name__ == '__main__':
    main()

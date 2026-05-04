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
        "local state = { bond_runtime = bonds.create_runtime(), resources = { wood = 999 }, bond_draw_count = 0 } "
        "assert(bonds.unlock_node(state, 'bond_archery_core')) "
        "assert(bonds.unlock_node(state, 'bond_archery_core_burst')) "
        "assert(bonds.unlock_node(state, 'bond_archery_core_stance')) "
        "assert(bonds.unlock_node(state, 'bond_archery_barrage')) "
        "local choices = bonds.get_candidate_nodes(state) "
        "local moon_blade_index = nil "
        "for i, def in ipairs(choices) do "
        "  if def.id == 'bond_archery_barrage_moon_blade' then moon_blade_index = i break end "
        "end "
        "assert(moon_blade_index ~= nil, 'archery second card should be unlockable after barrage') "
        "local old_random = math.random "
        "math.random = function(n) if n == #choices then return moon_blade_index end return 1 end "
        "assert(bonds.try_draw({ STATE = state, message = function() end })) "
        "math.random = old_random "
        "local choice = assert(state.bond_runtime.current_choices[1]) "
        "assert(choice.node_id == 'bond_archery_barrage_moon_blade', 'expected second barrage card choice') "
        "assert(string.find(choice.title_text or '', '1/4', 1, true) ~= nil, 'barrage branch should use 1/4 progress before unlock') "
        "assert(string.find(choice.title_text or '', '3/3', 1, true) == nil, 'barrage branch should not show root-set progress 3/3') "
        "print('bonds branch progress smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'bonds branch progress smoke failed')


if __name__ == '__main__':
    main()

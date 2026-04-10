#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
LUA = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe')
LUAC = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\luac.exe')
GEAR = ROOT / 'script' / 'runtime' / 'gear_upgrades.lua'


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
    syntax = run([str(LUAC), '-p', str(GEAR)])
    assert_ok(syntax, 'runtime/gear_upgrades.lua syntax check failed')

    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local gear = require('runtime.gear_upgrades') "
        "local state = { resources = { gold = 50000 } } "
        "gear.ensure_runtime(state) "
        "local runtime = assert(state.gear_state) "
        "assert(runtime.items.weapon.level == 1, 'weapon should start at level 1') "
        "assert(runtime.items.focus.level == 1, 'focus should start at level 1') "
        "assert(runtime.items.emblem.level == 1, 'emblem should start at level 1') "
        "assert(gear.get_pending_choice_kind(state) == nil, 'gear should not start with pending choice') "
        "local cost = gear.get_upgrade_cost('weapon', 1) "
        "assert(cost == 100, 'weapon level 1 upgrade should cost 100 gold') "
        "local level_after_single = assert(gear.try_upgrade_levels({ STATE = state, message = function() end }, 'weapon', 1)) "
        "assert(level_after_single == 2, 'single upgrade should reach level 2') "
        "assert(runtime.items.weapon.level == 2, 'weapon level should be 2 after single upgrade') "
        "local reached = assert(gear.try_upgrade_levels({ STATE = state, message = function() end }, 'weapon', 8)) "
        "assert(reached == 10, 'weapon should stop at level 10 before pending affix') "
        "assert(runtime.items.weapon.level == 10, 'weapon level should be 10 at first affix node') "
        "assert(runtime.pending_affix_choice ~= nil, 'level 10 should queue affix choice') "
        "assert(runtime.pending_affix_choice.slot == 'weapon', 'queued affix should belong to weapon') "
        "assert(runtime.awaiting_choice == true and runtime.current_choices and #runtime.current_choices == 3, 'affix node should open 3 choices') "
        "assert(gear.get_pending_choice_kind(state) == 'gear', 'gear pending kind should be gear') "
        "assert(gear.apply_affix_choice({ STATE = state, message = function() end }, 1) == true, 'affix choice should apply') "
        "assert(runtime.awaiting_choice == false and runtime.pending_affix_choice == nil, 'affix choice should clear pending state') "
        "assert(#runtime.items.weapon.affixes == 1, 'weapon should gain one affix after choice') "
        "local before_multi = runtime.items.focus.level "
        "local multi_reached = assert(gear.try_upgrade_levels({ STATE = state, message = function() end }, 'focus', 10)) "
        "assert(multi_reached == 10, '10-level upgrade should stop at first affix node instead of skipping it') "
        "assert(runtime.items.focus.level == 10 and before_multi == 1, 'focus should advance from 1 to 10') "
        "assert(runtime.awaiting_choice == true, 'focus should now be waiting for affix choice') "
        "assert(gear.apply_affix_choice({ STATE = state, message = function() end }, 2) == true, 'focus affix choice should apply') "
        "assert(#runtime.items.focus.affixes == 1, 'focus should gain one affix after choice') "
        "assert(type(gear.build_slot_text(state, 'weapon')) == 'string', 'slot text should be printable') "
        "print('runtime gear upgrades smoke ok')"
    )

    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)
    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)
    assert_ok(smoke, 'runtime gear upgrades smoke failed')

    print('runtime gear upgrades smoke ok')


if __name__ == '__main__':
    main()

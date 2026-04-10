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
        "local defs = require('runtime.hero_attr_defs') "
        "local panel = require('runtime.hero_attr_panel') "
        "local snapshot = { ['生命白字'] = 900, ['生命绿字'] = 120, ['生命'] = 1020, ['护甲白字'] = 10, ['护甲绿字'] = 5, ['护甲'] = 15 } "
        "local chunks = panel.build_chunks(snapshot, defs, function() return 0 end) "
        "local text = table.concat(chunks, '\\n') "
        "assert(string.find(text, '生命: 1020', 1, true), 'expected total life in panel') "
        "assert(not string.find(text, '生命白字: 900', 1, true), 'expected white life hidden in panel') "
        "assert(not string.find(text, '生命绿字: 120', 1, true), 'expected green life hidden in panel') "
        "assert(string.find(text, '护甲: 15', 1, true), 'expected total armor in panel') "
        "assert(string.find(text, '护甲白字: 10', 1, true), 'expected white armor in panel') "
        "assert(string.find(text, '护甲绿字: 5', 1, true), 'expected green armor in panel') "
        "print('hero_attr_panel_defense_split smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_panel_defense_split smoke failed')


if __name__ == '__main__':
    main()

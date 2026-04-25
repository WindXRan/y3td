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
        "local snapshot = { ['攻击白字'] = 46, ['攻击绿字'] = 12, ['攻击'] = 58, ['攻击范围'] = 250, ['攻击速度'] = 95, ['生命白字'] = 900, ['生命'] = 900, ['攻击结算值'] = 64 } "
        "local chunks = panel.build_chunks(snapshot, defs, function() return 0 end) "
        "local text = table.concat(chunks, '\\n') "
        "assert(string.find(text, '攻击: 58', 1, true), 'expected total attack in panel') "
        "assert(string.find(text, '攻击白字: 46', 1, true), 'expected white attack in panel') "
        "assert(string.find(text, '攻击绿字: 12', 1, true), 'expected green attack in panel') "
        "print('hero_attr_panel_attack_split smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_panel_attack_split smoke failed')


if __name__ == '__main__':
    main()

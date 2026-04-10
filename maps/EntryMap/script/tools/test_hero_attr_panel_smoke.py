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
        "local snapshot = { ['攻击'] = 46, ['攻击范围'] = 250, ['攻击速度'] = 95, ['生命'] = 900, ['攻击结算值'] = 46, ['生命结算值'] = 900 } "
        "local chunks = panel.build_chunks(snapshot, defs, function() return 0 end) "
        "local text = table.concat(chunks, '\\n') "
        "assert(string.find(text, '攻击速度: 95', 1, true), 'expected attack speed in panel') "
        "assert(string.find(text, '攻击: 46', 1, true), 'expected attack in panel') "
        "assert(string.find(text, '生命: 900', 1, true), 'expected life in panel') "
        "assert(not string.find(text, '每秒金币: 0', 1, true), 'expected zero resource attrs hidden') "
        "print('hero_attr_panel smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_panel smoke failed')


if __name__ == '__main__':
    main()

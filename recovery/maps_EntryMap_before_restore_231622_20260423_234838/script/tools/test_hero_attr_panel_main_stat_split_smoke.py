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
        "local snapshot = { ['力量'] = 70, ['力量白字'] = 50, ['力量绿字'] = 20, ['敏捷'] = 35, ['敏捷白字'] = 30, ['敏捷绿字'] = 5, ['智力'] = 55, ['智力白字'] = 40, ['智力绿字'] = 15 } "
        "local chunks = panel.build_chunks(snapshot, defs, function() return 0 end) "
        "local text = table.concat(chunks, '\\n') "
        "assert(string.find(text, '力量: 70', 1, true), 'expected total strength in panel') "
        "assert(string.find(text, '力量白字: 50', 1, true), 'expected white strength in panel') "
        "assert(string.find(text, '力量绿字: 20', 1, true), 'expected green strength in panel') "
        "assert(string.find(text, '敏捷: 35', 1, true), 'expected total agility in panel') "
        "assert(string.find(text, '敏捷白字: 30', 1, true), 'expected white agility in panel') "
        "assert(string.find(text, '敏捷绿字: 5', 1, true), 'expected green agility in panel') "
        "assert(string.find(text, '智力: 55', 1, true), 'expected total intelligence in panel') "
        "assert(string.find(text, '智力白字: 40', 1, true), 'expected white intelligence in panel') "
        "assert(string.find(text, '智力绿字: 15', 1, true), 'expected green intelligence in panel') "
        "print('hero_attr_panel_main_stat_split smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_panel_main_stat_split smoke failed')


if __name__ == '__main__':
    main()

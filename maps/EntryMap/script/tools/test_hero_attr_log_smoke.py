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
        "local attr_log = require('runtime.hero_attr_log') "
        "local text = attr_log.build_summary('spawn', { ['攻击'] = 46, ['攻击速度'] = 95, ['生命'] = 900, ['最终攻击'] = 0.15, ['攻击结算值'] = 53 }, 'hp=900') "
        "assert(string.find(text, '[hero_attr] spawn', 1, true), 'expected label in log') "
        "assert(string.find(text, '攻击=46', 1, true), 'expected attack in log') "
        "assert(string.find(text, '攻击速度=95', 1, true), 'expected attack speed in log') "
        "assert(string.find(text, '生命=900', 1, true), 'expected life in log') "
        "assert(string.find(text, '最终攻击=15%', 1, true), 'expected final attack percent in log') "
        "assert(string.find(text, '攻击结算值=53', 1, true), 'expected final attack value in log') "
        "assert(string.find(text, 'hp=900', 1, true), 'expected extra text in log') "
        "print('hero_attr_log smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_log smoke failed')


if __name__ == '__main__':
    main()

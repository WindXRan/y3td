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
        "local nodes = require('runtime.bond_nodes') "
        "for _, def in ipairs(nodes.list) do "
        "for attr_name in pairs(def.attr or {}) do "
        "assert(attr_name ~= '物理攻击') "
        "assert(attr_name ~= '最大生命') "
        "assert(attr_name ~= '暴击率') "
        "assert(attr_name ~= '暴击伤害') "
        "assert(attr_name ~= '命中率') "
        "assert(attr_name ~= 'BOSS伤害') "
        "assert(attr_name ~= '精英伤害') "
        "assert(attr_name ~= '冻伤伤害') "
        "end "
        "end "
        "print('bond_nodes attr names smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'bond_nodes attr names smoke failed')


if __name__ == '__main__':
    main()

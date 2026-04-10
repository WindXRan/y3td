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
        "assert(type(defs.list) == 'table') "
        "assert(type(defs.by_name) == 'table') "
        "assert(type(defs.aliases) == 'table') "
        "assert(defs.aliases['物理攻击'] == '攻击') "
        "assert(defs.aliases['最大生命'] == '生命') "
        "assert(defs.aliases['暴击率'] == '物理暴击') "
        "assert(defs.by_name['攻击'].category == '伤害属性') "
        "assert(defs.by_name['生命'].category == '防守属性') "
        "assert(defs.by_name['每秒金币'].category == '资源属性') "
        "assert(defs.by_name['力量增幅'].category == '增幅属性') "
        "assert(defs.by_name['火系伤害'].category == '其他属性') "
        "assert(defs.by_name['攻击'].persist == true) "
        "assert(defs.by_name['最终攻击'].is_ratio == true) "
        "assert(defs.by_name['最终生命'].is_ratio == true) "
        "assert(defs.by_name['最终护甲'].is_ratio == true) "
        "assert(defs.by_name['攻击结算值'].derived_output == true) "
        "assert(defs.by_name['生命结算值'].derived_output == true) "
        "assert(defs.by_name['护甲结算值'].derived_output == true) "
        "assert(defs.aliases['最终攻击增幅'] == '最终攻击') "
        "assert(defs.aliases['最终生命增幅'] == '最终生命') "
        "assert(defs.aliases['最终护甲增幅'] == '最终护甲') "
        "assert(defs.by_name['攻击增幅'].is_ratio == true) "
        "assert(defs.by_name['每秒攻击'].growth_kind == 'per_second') "
        "assert(defs.by_name['杀敌攻击'].growth_kind == 'on_kill') "
        "assert(defs.default_values['攻击'] == 0) "
        "assert(defs.default_values['生命'] == 0) "
        "assert(defs.default_values['攻击范围'] == 0) "
        "print('hero_attr_defs smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'hero_attr_defs smoke failed')


if __name__ == '__main__':
    main()

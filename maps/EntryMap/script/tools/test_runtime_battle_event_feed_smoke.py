#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
LUA = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe')
LUAC = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\luac.exe')
BATTLE_EVENT_FEED = ROOT / 'script' / 'runtime' / 'battle_event_feed.lua'


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
    syntax = run([str(LUAC), '-p', str(BATTLE_EVENT_FEED)])
    assert_ok(syntax, 'runtime/battle_event_feed.lua syntax check failed')

    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local feed = require('runtime.battle_event_feed') "
        "assert(type(feed.create_runtime) == 'function') "
        "assert(type(feed.push_event) == 'function') "
        "assert(type(feed.update) == 'function') "
        "assert(type(feed.get_visible_entries) == 'function') "
        "local runtime = feed.create_runtime() "
        "assert(runtime.max_visible == 4) "
        "assert(runtime.max_history == 12) "
        "feed.push_event(runtime, '发起经验挑战，梦魔虎开始进攻', { now = 1, style = 'warning', duration = 6 }) "
        "feed.push_event(runtime, '技能免费刷新次数 +1', { now = 2, style = 'reward', duration = 8 }) "
        "local visible = feed.get_visible_entries(runtime, 2, 4) "
        "assert(#visible == 2, 'two active entries should be visible') "
        "assert(visible[1].text == '发起经验挑战，梦魔虎开始进攻') "
        "assert(visible[2].text == '技能免费刷新次数 +1') "
        "assert(visible[1].style == 'warning') "
        "assert(visible[2].style == 'reward') "
        "feed.push_event(runtime, '获得1张能量技能卡，希文王1星效果触发，能量伤害+1%', { now = 3, style = 'rare', duration = 10 }) "
        "feed.push_event(runtime, '瘟疫散播效果触发，额外获取1份残骸', { now = 4, style = 'reward', duration = 10 }) "
        "feed.push_event(runtime, '挑战次数 +1，当前 2/3', { now = 5, style = 'positive', duration = 10 }) "
        "local visible_capped = feed.get_visible_entries(runtime, 5, 4) "
        "assert(#visible_capped == 4, 'visible entries should respect max_visible cap') "
        "assert(visible_capped[1].text == '技能免费刷新次数 +1', 'oldest visible entry should roll forward once over cap') "
        "feed.update(runtime, 10.5) "
        "local visible_after_expire = feed.get_visible_entries(runtime, 10.5, 4) "
        "assert(#visible_after_expire == 3, 'expired entries should be removed by time') "
        "assert(visible_after_expire[1].text == '获得1张能量技能卡，希文王1星效果触发，能量伤害+1%') "
        "for i = 1, 16 do "
        "feed.push_event(runtime, '事件' .. tostring(i), { now = 20 + i, duration = 30 }) "
        "end "
        "assert(#runtime.entries == 12, 'history should be capped to max_history') "
        "local latest = feed.get_visible_entries(runtime, 40, 4) "
        "assert(#latest == 4, 'latest visible list should still be capped to max_visible') "
        "assert(latest[1].text == '事件13') "
        "assert(latest[4].text == '事件16') "
    )

    with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False, encoding='utf-8') as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)

    try:
        smoke = run([str(LUA), str(smoke_path)])
        assert_ok(smoke, 'runtime.battle_event_feed smoke test failed')
    finally:
        smoke_path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()

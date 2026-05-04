#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INPUT_EVENTS_LUA = ROOT / 'script' / 'runtime' / 'input_events.lua'
BOOT_LUA = ROOT / 'script' / 'runtime' / 'boot.lua'


def assert_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    input_events = INPUT_EVENTS_LUA.read_text(encoding='utf-8')
    boot = BOOT_LUA.read_text(encoding='utf-8')

    assert_contains(input_events, 'local open_save_panel = env.open_save_panel', 'input events 应接收局内存档打开接口')
    assert_contains(input_events, "y3.game:event('键盘-按下', 'P', function()", 'input events 应注册局内存档快捷键 P')
    assert_contains(input_events, 'if not is_battle_active() or not open_save_panel then', '局内存档快捷键应仅在战斗中生效')
    assert_contains(input_events, 'open_save_panel()', '局内存档快捷键应直接打开统一存档面板接口')

    assert_contains(boot, 'open_save_panel = function()', 'runtime boot 应把存档打开接口注入输入系统')
    assert_contains(boot, 'outgame_system.open_save_panel', 'runtime boot 应把存档打开请求转发给 outgame system')

    print('[OK] save entry battle access static passed')


if __name__ == '__main__':
    main()

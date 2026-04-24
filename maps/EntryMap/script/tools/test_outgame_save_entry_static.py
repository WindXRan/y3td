#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUTGAME_LUA = ROOT / 'script' / 'ui' / 'outgame.lua'


def assert_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def assert_not_contains(text: str, needle: str, message: str) -> None:
    if needle in text:
        raise AssertionError(message)


def main() -> None:
    content = OUTGAME_LUA.read_text(encoding='utf-8')

    assert_contains(
        content,
        "y3.save_data.load_table(env.get_player(), SAVE_SLOT, true)",
        'outgame 应显式以 disable_cover=true 读取局外档'
    )
    assert_contains(content, 'local function ensure_save_entry_ui(ui)', 'outgame 缺少局外存档卡片创建逻辑')
    assert_contains(content, 'local function bind_save_entry(ui)', 'outgame 缺少局外存档入口点击逻辑')
    assert_contains(content, "bind_save_entry(ui)", 'outgame 应在 UI 绑定阶段挂上存档入口事件')
    assert_contains(content, "set_text_if_alive(save_entry.button, '打开存档')", 'outgame 存档卡片按钮应显示为打开存档')
    assert_contains(content, 'function api.open_save_panel()', 'outgame 应抽出可复用的存档面板打开接口，供局内入口复用')
    assert_contains(content, 'if api.open_save_panel() then', 'outgame 存档卡片按钮应复用统一的打开接口')
    assert_contains(content, 'local profile = load_profile()', 'outgame 存档入口应直接读取当前局外档')
    assert_contains(content, 'message(build_save_status_detail(profile))', 'outgame 存档入口当前应直接展示存档详情文本')
    assert_contains(content, '当前会话使用内存态默认档', 'outgame 应保留内存态原因说明文案')

    assert_not_contains(
        content,
        "message('局外存档槽位暂不可用，本次会话将使用内存态。错误：' .. tostring(result))",
        'outgame 不应在自动读档失败时直接往屏幕打白字'
    )
    assert_not_contains(
        content,
        "message('局外存档读取失败，本次会话将使用内存态默认档。错误：' .. tostring(defaults_dirty_or_err))",
        'outgame 不应在默认档兜底时直接往屏幕打白字'
    )
    assert_not_contains(
        content,
        "message(string.format('局外存档已手动上传到槽位 %d。', SAVE_SLOT))",
        'outgame 存档卡片按钮不应再承担手动上传行为'
    )

    print('[OK] outgame save entry static passed')


if __name__ == '__main__':
    main()

#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path
import json


ROOT = Path(__file__).resolve().parents[2]
TOP_JSON = ROOT / 'ui' / 'top.json'
PANEL_TREE_INFO = ROOT / 'editor' / 'uipaneltreegroupinfo.json'
RUNTIME_HUD_LUA = ROOT / 'script' / 'ui' / 'runtime_hud.lua'


def assert_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    top = json.loads(TOP_JSON.read_text(encoding='utf-8'))
    panel_tree_info = json.loads(PANEL_TREE_INFO.read_text(encoding='utf-8'))
    runtime_hud = RUNTIME_HUD_LUA.read_text(encoding='utf-8')

    top_root = next(child for child in top['children'] if child['name'] == 'top')
    left_buttons = next(child for child in top_root['children'] if child['name'] == 'left_buttons')
    left_button_names = [child['name'] for child in left_buttons['children']]

    assert 'btn_save' in left_button_names, 'top 顶栏应包含存档按钮'
    assert 'brand_mark' in left_button_names, 'top 顶栏应包含左侧徽记区'
    assert 'btn_exit' in left_button_names, 'top 顶栏应保留退出按钮'
    assert 'btn_pause' in left_button_names, 'top 顶栏应保留暂停按钮'
    assert 'btn_setting' in left_button_names, 'top 顶栏应保留设置按钮'
    assert 'btn_powerup' in left_button_names, 'top 顶栏应保留强化按钮'
    assert 'btn_hotkey' in left_button_names, 'top 顶栏应保留键位按钮'
    expected_order = ['left_buttons_bg', 'brand_mark', 'btn_exit', 'btn_pause', 'btn_setting', 'btn_save', 'btn_powerup', 'btn_hotkey']
    assert left_button_names == expected_order, f'top 顶栏结构顺序应为 {expected_order}，实际为 {left_button_names}'

    custom = next(item for item in panel_tree_info if item['name'] == 'code_ui_custom_panel_tree')
    top_entry = next(entry for entry in custom['group'] if entry['items'][1] == 'top')
    assert top_entry['items'][0] == top['uid'], 'top 面板注册 uid 应与 top.json 保持一致'

    assert_contains(runtime_hud, "set_text_if_alive(resolve_ui('top.top.left_buttons.btn_save'), '存档')", 'runtime hud 应显式设置顶部存档按钮文案')
    assert_contains(runtime_hud, "bind_click_once('top_save', resolve_ui('top.top.left_buttons.btn_save'), function()", 'runtime hud 应绑定顶部存档按钮点击事件')
    assert_contains(runtime_hud, 'if open_save_panel and open_save_panel() ~= false then', '顶部存档按钮应复用统一存档打开接口')

    print('[OK] top save entry static passed')


if __name__ == '__main__':
    main()

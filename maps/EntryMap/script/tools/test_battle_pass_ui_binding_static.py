#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UI_JSON = ROOT / 'ui' / '通行证系统.json'
UI_LUA = ROOT / 'script' / 'ui' / 'battle_pass.lua'


def collect_node_types(node: dict, path: str = '', result: dict | None = None) -> dict[str, int]:
    result = result or {}
    name = node.get('name', '')
    current = f'{path}.{name}' if path and name else name
    if current:
        result[current] = node.get('type')
    for child in node.get('children', []):
        if isinstance(child, dict):
            collect_node_types(child, current, result)
    return result


def assert_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    ui_data = json.loads(UI_JSON.read_text(encoding='utf-8'))
    node_types = collect_node_types(ui_data)

    open_label_path = '通行证系统.按钮区域.仓库按钮'
    open_icon_path = '通行证系统.按钮区域.仓库按钮.仓库按钮图标'
    login_tab_path = '通行证系统.通行证界面.左侧区域.登陆奖励'

    if node_types.get(open_label_path) != 3:
        raise AssertionError('通行证入口文本节点类型应为 3，用于覆盖文本/点击区域兼容路径')
    if node_types.get(open_icon_path) != 1:
        raise AssertionError('通行证入口图标节点类型应为 1，作为真实按钮入口')
    if node_types.get(login_tab_path) != 3:
        raise AssertionError('通行证页签节点类型应为 3，回归时需要继续兼容非按钮节点绑定')

    content = UI_LUA.read_text(encoding='utf-8')
    assert_contains(content, 'local function can_bind_fast_event(ui)', 'battle pass ui 缺少 fast event 保护函数')
    assert_contains(content, 'local function ensure_open_hotspot(ui)', 'battle pass ui 缺少左上角入口热区兜底')
    assert_contains(
        content,
        "if runtime[field_name] == true or not can_bind_fast_event(ui_node) then",
        'battle pass ui 点击绑定应先确认节点支持 add_fast_event'
    )
    assert_contains(content, "bind_click_once(runtime.ui.open_hotspot", 'battle pass ui 应给左上角整块区域补透明点击热区')

    print('[OK] battle pass ui binding static passed')


if __name__ == '__main__':
    main()

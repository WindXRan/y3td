#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PREFAB = ROOT / 'ui' / 'prefab' / 'choice_panel.json'
BUTTON_PREFAB = ROOT / 'ui' / 'prefab' / 'choice_button.json'
LAYOUT = ROOT / 'script' / 'ui' / 'choice_panel_text_layout.lua'
PANEL_LAYOUT = ROOT / 'script' / 'ui' / 'choice_panel_layout.lua'
PANEL = ROOT / 'script' / 'ui' / 'choice_panel.lua'


def collect_paths(node: dict, path: str = '') -> set[str]:
    name = node.get('name', '')
    current = f'{path}.{name}' if path else name
    paths = {current}
    for child in node.get('children', []):
        if isinstance(child, dict) and 'children' in child:
            paths.update(collect_paths(child, current))
    return paths


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def main() -> None:
    prefab_data = json.loads(PREFAB.read_text(encoding='utf-8'))['data']
    paths = collect_paths(prefab_data)
    button_prefab_data = json.loads(BUTTON_PREFAB.read_text(encoding='utf-8'))['data']
    button_paths = collect_paths(button_prefab_data)

    for required in (
        'choice_panel.layout_1.background',
        'choice_panel.layout_1.button',
        'choice_panel.layout_1.icon',
        'choice_panel.layout_1.name',
        'choice_panel.layout_1.subtitle_name',
        'choice_panel.layout_1.rarity_background.rarity_text',
        'choice_panel.layout_1.desc_text.value_desc',
        'choice_panel.layout_1.desc_text.effect_desc.effect_name',
        'choice_panel.layout_1.desc_text.effect_desc.effect_text',
    ):
        if required not in paths:
            raise AssertionError(f'choice_panel prefab 缺少节点：{required}')

    for required in (
        'choice_button.layout_1',
        'choice_button.layout_1.button_1',
        'choice_button.layout_1.label_2',
    ):
        if required not in button_paths:
            raise AssertionError(f'choice_button prefab 缺少节点：{required}')

    layout_content = LAYOUT.read_text(encoding='utf-8')
    panel_layout_content = PANEL_LAYOUT.read_text(encoding='utf-8')
    assert_contains(layout_content, 'MAX_VALUE_LINES = 2', '属性文本上限应为 2 行')
    assert_contains(layout_content, 'MAX_EFFECT_LINES = 3', '效果文本上限应为 3 行')
    assert_contains(layout_content, 'function M.build_text_layout(body_blocks)', '缺少文本布局主函数')

    panel_content = PANEL.read_text(encoding='utf-8')
    assert_contains(panel_content, 'y3.ui_prefab.create(player, \'choice_panel\', parent)', '三选一卡片应改为创建 choice_panel prefab')
    assert_contains(panel_content, 'y3.ui_prefab.create(player, \'choice_button\', parent)', '底部操作按钮应改为创建 choice_button prefab')
    assert_contains(panel_content, "layout_1.label_2", '底部操作按钮应绑定占位文本节点 label_2')
    assert_contains(panel_content, "layout_1.desc_text.value_desc", '面板应绑定 value_desc 节点')
    assert_contains(panel_content, "layout_1.subtitle_name", '面板应绑定 subtitle_name 节点')
    assert_contains(panel_content, "layout_1.desc_text.effect_desc.effect_text", '面板应绑定 effect_text 节点')

    assert_contains(panel_layout_content, 'y = 36', '底部按钮应整体下移到新的 y 坐标')

    print('choice panel prefab wiring ok')


if __name__ == '__main__':
    main()

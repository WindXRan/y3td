#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PREFAB = ROOT / 'ui' / 'prefab' / 'choice_panel.json'
BUTTON_PREFAB = ROOT / 'ui' / 'prefab' / 'choice_button.json'
LAYOUT = ROOT / 'script' / 'ui' / 'choice_panel_text_layout.lua'
PANEL_LAYOUT = ROOT / 'script' / 'ui' / 'choice_panel_layout.lua'
PANEL = ROOT / 'script' / 'ui' / 'choice_panel.lua'
LUA = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe')


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


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=ROOT.parents[1],
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
    prefab_data = json.loads(PREFAB.read_text(encoding='utf-8'))['data']
    paths = collect_paths(prefab_data)
    button_prefab_data = json.loads(BUTTON_PREFAB.read_text(encoding='utf-8'))['data']
    button_paths = collect_paths(button_prefab_data)

    for required in (
        'choice_panel.layout_1.background',
        'choice_panel.layout_1.button',
        'choice_panel.layout_1.icon',
        'choice_panel.layout_1.set_name',
        'choice_panel.layout_1.name',
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
    assert_contains(layout_content, 'function M.build_segment_rows(config)', '缺少手动高亮分段布局函数')

    panel_content = PANEL.read_text(encoding='utf-8')
    assert_contains(panel_content, "y3.ui_prefab.create(player, 'choice_panel', parent)", '三选一卡片应改为创建 choice_panel prefab')
    assert_contains(panel_content, "y3.ui_prefab.create(player, 'choice_button', parent)", '底部操作按钮应改为创建 choice_button prefab')
    assert_contains(panel_content, 'layout_1.label_2', '底部操作按钮应绑定占位文本节点 label_2')
    assert_contains(panel_content, 'layout_1.desc_text.value_desc', '面板应绑定 value_desc 节点')
    assert_contains(panel_content, 'layout_1.desc_text.effect_desc.effect_text', '面板应绑定 effect_text 节点')
    assert_contains(panel_content, 'TextLayout.build_segment_rows', '三选一高亮文本应通过统一的分段布局函数计算位置')

    assert_contains(panel_layout_content, 'y = 36', '底部按钮应整体下移到新的 y 坐标')

    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local layout = require('ui.choice_panel_text_layout') "
        "local rows = layout.build_segment_rows({ "
        "left = 100, top = 300, font_size = 20, line_height = 28, default_color = 'white', "
        "estimate_width = function(text, size) return #tostring(text) * size end, "
        "blocks = { "
        "{ text = '攻击力 + 50', segments = { { text = '攻击力', color = 'green' }, { text = ' + ', color = 'white' }, { text = '50', color = 'cyan' } } }, "
        "{ text = '暴击率 + 5%', segments = { { text = '暴击率', color = 'green' }, { text = ' + ', color = 'white' }, { text = '5%', color = 'cyan' } } } "
        "} }) "
        "assert(#rows == 2) "
        "assert(rows[1].y == 300) "
        "assert(rows[2].y == 272) "
        "assert(rows[1].segments[1].x == 100) "
        "assert(rows[1].segments[2].x > rows[1].segments[1].x) "
        "assert(rows[1].segments[3].x > rows[1].segments[2].x) "
    )

    with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False, encoding='utf-8') as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)

    try:
        smoke = run([str(LUA), str(smoke_path)])
        assert_ok(smoke, 'choice panel text segment layout smoke failed')
    finally:
        smoke_path.unlink(missing_ok=True)

    print('choice panel prefab wiring ok')


if __name__ == '__main__':
    main()

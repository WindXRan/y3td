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

    panel_layout = prefab_data['children'][0]
    panel_by_name = {child['name']: child for child in panel_layout['children']}
    desc_root = panel_by_name['desc_text']
    desc_by_name = {child['name']: child for child in desc_root['children']}
    effect_desc = desc_by_name['effect_desc']
    effect_by_name = {child['name']: child for child in effect_desc['children']}
    if tuple(panel_by_name['icon']['size']['items']) != (156.0, 156.0):
        raise AssertionError('choice_panel prefab 图标区域应收敛到 156x156')
    if tuple(panel_by_name['set_name']['size']['items']) != (460.0, 42.0):
        raise AssertionError('choice_panel prefab 套装标题区域应扩展到 460x42')
    if tuple(panel_by_name['name']['size']['items']) != (500.0, 84.0):
        raise AssertionError('choice_panel prefab 主标题区域应压缩到 500x84')
    if tuple(desc_root['size']['items']) != (390.0, 188.0):
        raise AssertionError('choice_panel prefab 描述区应扩展到 390x188')
    if tuple(desc_by_name['value_desc']['size']['items']) != (390.0, 52.0):
        raise AssertionError('choice_panel prefab 属性描述区域应扩展到 390x52')
    if tuple(effect_desc['size']['items']) != (390.0, 124.0):
        raise AssertionError('choice_panel prefab 效果容器应扩展到 390x124')
    if tuple(effect_by_name['effect_name']['size']['items']) != (390.0, 34.0):
        raise AssertionError('choice_panel prefab 效果标题区域应扩展到 390x34')
    if tuple(effect_by_name['effect_text']['size']['items']) != (390.0, 88.0):
        raise AssertionError('choice_panel prefab 效果正文区域应扩展到 390x88')

    for required in (
        'choice_button.layout_1',
        'choice_button.layout_1.button_1',
        'choice_button.layout_1.label_2',
    ):
        if required not in button_paths:
            raise AssertionError(f'choice_button prefab 缺少节点：{required}')

    button_layout = button_prefab_data['children'][0]
    if tuple(button_layout['size']['items']) != (220, 60):
        raise AssertionError('choice_button prefab 根布局应收敛到 220x60 设计尺寸')
    button_button = next(child for child in button_layout['children'] if child.get('name') == 'button_1')
    button_bg = next(child for child in button_layout['children'] if child.get('name') == 'image_3')
    button_label = next(child for child in button_layout['children'] if child.get('name') == 'label_2')
    if tuple(button_button['size']['items']) != (220.0, 60.0):
        raise AssertionError('choice_button prefab 的点击区域应为 220x60')
    if tuple(button_bg['size']['items']) != (220.0, 60.0):
        raise AssertionError('choice_button prefab 的底图应与按钮设计尺寸一致')
    if tuple(button_label['size']['items']) != (196.0, 60.0):
        raise AssertionError('choice_button prefab 的文案区域应控制在按钮内')

    layout_content = LAYOUT.read_text(encoding='utf-8')
    panel_layout_content = PANEL_LAYOUT.read_text(encoding='utf-8')
    assert_contains(layout_content, 'MAX_VALUE_LINES = 2', '属性文本上限应为 2 行')
    assert_contains(layout_content, 'MAX_EFFECT_LINES = 3', '效果文本上限应为 3 行')
    assert_contains(layout_content, 'function M.build_text_layout(body_blocks)', '缺少文本布局主函数')
    assert_contains(layout_content, 'function M.build_segment_rows(config)', '缺少手动高亮分段布局函数')

    panel_content = PANEL.read_text(encoding='utf-8')
    assert_contains(panel_content, "card_model and card_model.render_prefab", '三选一卡片应支持模型层指定渲染 prefab')
    assert_contains(panel_content, "y3.ui_prefab.create(player, prefab_name, parent)", '三选一卡片应通过 prefab 名称变量创建')
    assert_contains(panel_content, "y3.ui_prefab.create(player, 'choice_button', parent)", '底部操作按钮应改为创建 choice_button prefab')
    assert_contains(panel_content, 'layout_1.label_2', '底部操作按钮应绑定占位文本节点 label_2')
    assert_contains(panel_content, "layout_1.image_3", '底部操作按钮应绑定底板节点 image_3')
    assert_contains(panel_content, "skin.get_button_style('choice_panel_action')", '底部操作按钮应使用 choice_panel_action 皮肤槽位')
    assert_contains(panel_content, "apply_text_style(label_node, 'choice_panel.action_label'", '底部操作按钮文字应走统一样式表')
    assert_contains(panel_content, 'skin.images.choice_panel', '三选一卡面资源应走 choice_panel 语义资源槽')
    assert_contains(panel_content, 'get_card_frame_image(card_model.quality)', '普通/稀有/史诗卡框应通过质量映射到语义资源槽')
    assert_contains(panel_content, 'get_badge_bg_image(card_model.quality)', '品质徽记底板应通过质量映射到语义资源槽')
    assert_contains(panel_content, 'card.background:set_image(', '三选一卡面应主动设置底板图片')
    assert_contains(panel_content, 'card.decoration:set_image(', '三选一卡面应主动设置边框图片')
    assert_contains(panel_content, 'card.rarity_background:set_image(', '三选一卡面应主动设置徽记底板图片')
    assert_contains(panel_content, 'layout_1.desc_text.value_desc', '面板应绑定 value_desc 节点')
    assert_contains(panel_content, 'layout_1.desc_text.effect_desc.effect_text', '面板应绑定 effect_text 节点')
    assert_contains(panel_content, 'TextLayout.build_segment_rows', '三选一高亮文本应通过统一的分段布局函数计算位置')
    assert_contains(
        panel_content,
        'render_value_highlights(card, text_layout.value_blocks)',
        '普通三选一卡片应在 value_desc 分支重新渲染属性彩色分段'
    )
    assert_contains(
        panel_content,
        'render_effect_highlights(card, text_layout.effect_blocks)',
        '普通三选一卡片应在 effect_text 分支重新渲染效果彩色分段'
    )

    assert_contains(panel_layout_content, 'y = 20', '底部按钮应整体下移到新的 y 坐标')
    assert_contains(panel_content, 'root:set_z_order(9824 + (index or 0))', '底部操作按钮层级应显著高于卡片和高亮文本')
    assert_contains(panel_content, 'stage_shell:set_image(ui_res.common.empty)', '三选一外层大底板应清空图片资源')
    assert_contains(panel_content, 'stage_shell:set_image_color(255, 255, 255, 0)', '三选一外层大底板应完全透明')

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

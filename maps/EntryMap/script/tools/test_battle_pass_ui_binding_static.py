#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UI_JSON_CANDIDATES = [
    ROOT / 'ui' / '通行证系统.json',
    ROOT / 'ui' / '存档系统.json',
]
SIGN_UI_JSON = ROOT / 'ui' / '签到系统.json'
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
    ui_path = next((candidate for candidate in UI_JSON_CANDIDATES if candidate.exists()), None)
    if ui_path is None:
        raise AssertionError('未找到 通行证系统.json 或 存档系统.json，无法校验 battle pass 画板')

    ui_data = json.loads(ui_path.read_text(encoding='utf-8'))
    node_types = collect_node_types(ui_data)
    sign_ui_data = json.loads(SIGN_UI_JSON.read_text(encoding='utf-8'))
    sign_node_types = collect_node_types(sign_ui_data)
    panel_root_name = ui_data.get('name') or ui_path.stem

    open_label_path = f'{panel_root_name}.按钮区域.仓库按钮'
    open_icon_path = f'{panel_root_name}.按钮区域.仓库按钮.仓库按钮图标'
    login_tab_paths = [
        f'{panel_root_name}.通行证界面.左侧区域.登陆奖励',
        f'{panel_root_name}.通行证界面.左侧区域.左侧区域list.登陆奖励',
    ]

    if node_types.get(open_label_path) != 3:
        raise AssertionError('通行证入口文本节点类型应为 3，用于覆盖文本/点击区域兼容路径')
    if node_types.get(open_icon_path) != 1:
        raise AssertionError('通行证入口图标节点类型应为 1，作为真实按钮入口')
    login_tab_type = next((node_types.get(path) for path in login_tab_paths if node_types.get(path) is not None), None)
    if login_tab_type != 3:
        raise AssertionError('通行证页签节点类型应为 3，回归时需要继续兼容非按钮节点绑定')
    if sign_node_types.get('签到系统.活动') != 7:
        raise AssertionError('签到系统活动面板节点类型应为 7，供通行证初始化时主动收起')

    content = UI_LUA.read_text(encoding='utf-8')
    assert_contains(content, 'local function can_bind_fast_event(ui)', 'battle pass ui 缺少 fast event 保护函数')
    assert_contains(content, 'local function ensure_open_hotspot(ui)', 'battle pass ui 缺少左上角入口热区兜底')
    assert_contains(content, 'local function ensure_save_count_label(ui)', 'battle pass ui 应为摘要容器补真实文本节点')
    assert_contains(content, 'local function resolve_panel_ui(path)', 'battle pass ui 应兼容 存档系统 / 通行证系统 两套画板命名')
    assert_contains(content, 'local function prepare_pass_grid_for_lua(ui)', 'battle pass ui 应在刷新前接管通行证网格，清理旧触发器残留节点')
    assert_contains(content, 'local function get_reward_cell_label(item, track, compact_mode)', 'battle pass ui 应统一生成免费/付费格子的 Lua 文案')
    assert_contains(content, 'local function rebuild_pass_grid(ui, model, compact_mode)', 'battle pass ui 应由 Lua 完整重建每级三格列表')
    assert_contains(content, 'local function is_battle_compact_mode()', 'battle pass ui 应在局内启用紧凑布局判定')
    assert_contains(content, 'local function get_compact_pass_subtitle(model)', 'battle pass ui 应在局内使用紧凑副标题')
    assert_contains(content, 'set_visible_if_alive(ui.current_exp_group, not compact_mode)', 'battle pass ui 局内应隐藏顶部长标签避免挤压')
    assert_contains(
        content,
        "if runtime[field_name] == true or not can_bind_fast_event(ui_node) then",
        'battle pass ui 点击绑定应先确认节点支持 add_fast_event'
    )
    assert_contains(content, "bind_click_once(runtime.ui.open_hotspot", 'battle pass ui 应给左上角整块区域补透明点击热区')
    assert_contains(content, 'set_visible_if_alive(activity_panel_root, false)', 'battle pass ui 初始化时应先收起签到活动面板，避免吞掉点击')
    assert_contains(content, 'set_visible_if_alive(ui.button_area, visible)', 'battle pass ui 应保持原通行证按钮区域常驻可见')
    assert_contains(content, 'set_visible_if_alive(button_area, true)', 'battle pass ui 初始化时应恢复原通行证按钮区域')
    assert_contains(content, 'set_visible_if_alive(ui.activity_panel_root, false)', 'battle pass ui 打开时应主动收起签到活动面板')
    assert_contains(content, "bind_click_once(save_count, function()", 'battle pass ui 应允许通过右上摘要切换试水页')
    assert_contains(content, 'runtime.ui.save_count_label = ensure_save_count_label(runtime.ui)', 'battle pass ui 应初始化右上摘要文本节点')
    assert_contains(content, 'ui.save_count_label or ui.save_count', 'battle pass ui 应优先把摘要文字写到真实文本节点上')
    assert_contains(content, 'local function is_panel_session_available()', 'battle pass ui 应统一收敛局内/局外可打开判定')
    assert_contains(content, "return STATE.session_phase == 'outgame' or STATE.session_phase == 'battle'", 'battle pass ui 应允许局内和局外两种会话访问')
    assert_contains(content, 'if is_panel_session_available() then', 'battle pass ui 点击后应在局内也刷新面板内容')
    assert_contains(content, 'function api.open_panel(page_key)', 'battle pass ui 应提供运行时打开面板接口，供外部存档按钮复用')
    assert_contains(content, 'open_panel(page_key or PAGE_PASS)', 'battle pass ui 的外部打开接口应默认进入征战之路页')

    print('[OK] battle pass ui binding static passed')


if __name__ == '__main__':
    main()

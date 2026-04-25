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

    assert_contains(content, "for index = 1, 5 do", 'outgame 应绑定左侧 5 条任务槽位')
    assert_contains(content, "outgame.大厅.layout.left.task_%d", 'outgame 应从静态画板读取任务节点')
    assert_contains(content, "outgame.大厅.layout.footer.slot_%d", 'outgame 应从静态画板读取底部玩家槽位')
    assert_contains(content, "resolve_ui(base_path .. '.avatar')", 'outgame 应绑定底部玩家头像节点')
    assert_contains(content, 'refresh_daily_rows(ui, profile, selected_stage_id)', 'outgame 应刷新左侧任务区')
    assert_contains(content, 'refresh_reward_card(ui, profile, selected_stage_id)', 'outgame 应刷新奖励卡片')
    assert_contains(content, 'refresh_footer(ui, profile)', 'outgame 应刷新底部玩家位')
    assert_contains(content, 'set_image_url_if_alive(slot.avatar, payload_value, payload_aid)', 'outgame 应支持平台头像 url 刷新')
    assert_contains(content, 'set_image_if_alive(slot.avatar, payload_value)', 'outgame 应支持本地头像资源回退')
    assert_contains(content, "set_text_if_alive(ui.header_tip, build_header_tip_text(profile, selected_stage_id, selected_mode_id))", 'outgame 顶部提示应复用统一提示构建逻辑')
    assert_contains(content, 'local function set_non_outgame_ui_visible(visible)', 'outgame 应统一切换非局外 UI 显隐')
    assert_contains(content, "set_non_outgame_ui_visible(false)", '进入局外时应隐藏非局外 UI')
    assert_contains(content, "set_non_outgame_ui_visible(true)", '离开局外时应恢复非局外 UI')

    assert_not_contains(content, "resolve_ui('outgame.大厅.layout.start_anchor.button_bg')", 'outgame 不应继续绑定不存在的 start_anchor 节点')
    assert_not_contains(content, "resolve_ui(base_path .. '.模式.banner')", 'outgame 不应继续依赖不存在的 banner 节点')
    assert_not_contains(content, "resolve_ui(base_path .. '.模式.subtitle')", 'outgame 不应继续依赖不存在的 subtitle 节点')

    print('[OK] outgame ui binding static passed')


if __name__ == '__main__':
    main()

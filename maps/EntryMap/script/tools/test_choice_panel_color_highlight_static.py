#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PANEL = ROOT / 'script' / 'ui' / 'choice_panel.lua'


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def main() -> None:
    panel_content = PANEL.read_text(encoding='utf-8')

    assert_contains(
        panel_content,
        "get_body_color(text_layout.value_color)",
        '普通三选一卡片应将布局层产出的属性颜色回流到 value_desc'
    )
    assert_contains(
        panel_content,
        "get_body_color(text_layout.effect_color)",
        '普通三选一卡片应将布局层产出的效果颜色回流到 effect_text'
    )

    print('choice panel color highlight wiring ok')


if __name__ == '__main__':
    main()

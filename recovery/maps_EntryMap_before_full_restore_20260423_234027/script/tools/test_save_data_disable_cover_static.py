#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SAVE_DATA_LUA = ROOT / 'script' / 'y3' / 'util' / 'save_data.lua'


def assert_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    content = SAVE_DATA_LUA.read_text(encoding='utf-8')

    assert_contains(
        content,
        'local resolved_disable_cover = disable_cover ~= false',
        'save_data.load_table 应把 nil/true 统一归一到 disable_cover=true'
    )
    assert_contains(
        content,
        'if last_table[2] == resolved_disable_cover then',
        'save_data.load_table 应按归一化后的 disable_cover 判断缓存复用'
    )
    assert_contains(
        content,
        'if resolved_disable_cover then',
        'save_data.load_table 应按归一化后的 disable_cover 选择读取分支'
    )
    assert_contains(
        content,
        'last_table[2] = resolved_disable_cover',
        'save_data.load_table 应缓存归一化后的 disable_cover'
    )

    print('[OK] save data disable cover static passed')


if __name__ == '__main__':
    main()

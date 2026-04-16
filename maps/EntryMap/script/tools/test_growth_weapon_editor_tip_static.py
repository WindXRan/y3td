#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TIP = ROOT / 'ui' / 'growth_weapon_item_tip.lua'


def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    source = TIP.read_text(encoding='utf-8')

    require(source, "物品说明.物品说明.shopTip", 'expected editor tip root path')
    require(source, "物品说明.物品说明.shopTip.basic.title.title_TEXT", 'expected title text path')
    require(source, "物品说明.物品说明.shopTip.basic.title.subtitle_TEXT", 'expected subtitle text path')
    require(source, "物品说明.物品说明.shopTip.basic.avatar.icon", 'expected icon path')
    require(source, "物品说明.物品说明.shopTip.attr_LIST", 'expected attr list path')
    require(source, "物品说明.物品说明.shopTip.descr_LIST", 'expected descr list path')

    print('[OK] growth weapon editor tip static passed')


if __name__ == '__main__':
    main()

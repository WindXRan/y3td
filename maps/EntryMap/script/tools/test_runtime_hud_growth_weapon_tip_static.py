#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / 'ui' / 'runtime_hud.lua'


def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    source = HUD.read_text(encoding='utf-8')

    require(source, "local GrowthWeaponItemTip = require 'ui.growth_weapon_item_tip'", 'expected editor-backed growth weapon tip require')
    require(source, 'local function bind_default_item_slot_hover(runtime_hud)', 'expected default item slot hover binder')
    require(source, "string.format('GameHUD.main.goods.equip_slot_bg_%d.goods', slot)", 'expected default item slot path binding')
    require(source, "local function show_growth_weapon_tip(anchor_ui)", 'expected shared growth weapon tip show helper')
    require(source, "GameHUD.main.inventory.equip_slot_bg_1.equip_slot_1", 'expected editor-authored growth weapon slot path')
    require(source, "growth_weapon_tip.show_for_anchor", 'expected runtime hud to delegate tip rendering to editor tip binder')
    require(source, "set_equip_slot_use_operation('无')", 'expected growth weapon slot left click to be disabled')
    require(source, "set_equip_slot_drag_operation('无')", 'expected growth weapon slot drag to be disabled')
    require(source, 'bond_slot_bar:set_visible(false)', 'expected middle bond slot bar to stay hidden')
    require(source, 'bind_default_item_slot_hover(STATE.runtime_hud)', 'expected runtime hud to register default item slot hover')

    print('[OK] runtime hud growth weapon tip static passed')


if __name__ == '__main__':
    main()

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
    require(source, 'runtime_hud.editor_bottom_inventory_slots and runtime_hud.editor_bottom_inventory_slots[1] or nil', 'expected growth weapon slot to resolve runtime inventory slot first')
    require(source, 'runtime_hud.editor_bottom_inventory_anchors = runtime_hud.bottom_backpack_slots or {}', 'expected bottom_bg backpack slots to drive hover anchors')
    require(source, 'runtime_hud.editor_bottom_inventory_slots = runtime_hud.editor_bottom_inventory_slots or {}', 'expected runtime slot list cache for true item slots')
    require(source, 'runtime_hud.growth_weapon_tip_anchor = anchor_ui', 'expected growth weapon tip to bind against display anchor')
    require(source, "local function show_growth_weapon_tip(anchor_ui)", 'expected shared growth weapon tip show helper')
    require(source, 'local function resolve_inventory_slot_ui(slot)', 'expected runtime hud to centralize real inventory slot lookup')
    require(source, "GameHUD.layout_3.inventory.equip_slot_bg_1.equip_slot_1", 'expected runtime hud to keep legacy inventory fallback path')
    require(source, "string.format('GameHUD.layout_3.inventory.equip_slot_bg_%d.equip_slot_1', slot)", 'expected every bottom slot to bind to the real GameHUD equip slot child')
    require(source, "growth_weapon_tip.show_for_anchor", 'expected runtime hud to delegate tip rendering to editor tip binder')
    require(source, "call_ui_method_safely(slot_ui, 'set_equip_slot_use_operation', '无')", 'expected growth weapon slot left click to be disabled safely')
    require(source, "call_ui_method_safely(slot_ui, 'set_equip_slot_drag_operation', '无')", 'expected growth weapon slot drag to be disabled safely')
    require(source, "call_ui_method_safely(slot_ui, 'set_ui_unit_slot', STATE.hero, y3.const.SlotType.BAR, slot - 1)", 'expected inventory slot binding to use safe calls')
    require(source, 'bond_slot_bar:set_visible(false)', 'expected middle bond slot bar to stay hidden')
    require(source, 'bind_default_item_slot_hover(STATE.runtime_hud)', 'expected runtime hud to register default item slot hover')

    print('[OK] runtime hud growth weapon tip static passed')


if __name__ == '__main__':
    main()

#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT = ROOT / 'runtime' / 'boot.lua'


def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    source = BOOT.read_text(encoding='utf-8')

    require(source, 'build_growth_weapon_tip_payload = function()', 'expected boot env to expose growth weapon tip payload builder')
    require(source, "return GearUpgrades.build_tip_payload(STATE, 'weapon', CONFIG.gear_upgrade_config, y3.item)", 'expected boot payload builder to delegate to gear upgrades')
    require(source, 'get_growth_weapon_item_key = function()', 'expected boot env to expose growth weapon item key')
    require(source, 'return slot_cfg and slot_cfg.item_key or nil', 'expected boot env to read configured growth weapon item key')

    print('[OK] boot growth weapon tip integration static passed')


if __name__ == '__main__':
    main()

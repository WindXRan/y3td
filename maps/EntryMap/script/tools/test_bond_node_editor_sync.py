#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ABILITY_CONFIG = ROOT / 'script' / 'tools' / 'bond_node_ability_config.json'
LANGUAGE = ROOT / 'zhlanguage.json'
ABILITY_DIR = ROOT / 'editor_table' / 'abilityall'


def xencode(text):
    if isinstance(text, bytes):
        return text
    return text.encode('utf-8')


def murmur3_hash(key, seed=0):
    key = bytearray(xencode(key))

    def fmix(value):
        value ^= value >> 16
        value = (value * 0x85EBCA6B) & 0xFFFFFFFF
        value ^= value >> 13
        value = (value * 0xC2B2AE35) & 0xFFFFFFFF
        value ^= value >> 16
        return value

    length = len(key)
    nblocks = length // 4
    h1 = seed
    c1 = 0xCC9E2D51
    c2 = 0x1B873593

    for block_start in range(0, nblocks * 4, 4):
        k1 = (
            (key[block_start + 3] << 24)
            | (key[block_start + 2] << 16)
            | (key[block_start + 1] << 8)
            | key[block_start + 0]
        )
        k1 = (c1 * k1) & 0xFFFFFFFF
        k1 = ((k1 << 15) | (k1 >> 17)) & 0xFFFFFFFF
        k1 = (c2 * k1) & 0xFFFFFFFF
        h1 ^= k1
        h1 = ((h1 << 13) | (h1 >> 19)) & 0xFFFFFFFF
        h1 = (h1 * 5 + 0xE6546B64) & 0xFFFFFFFF

    tail_index = nblocks * 4
    k1 = 0
    tail_size = length & 3
    if tail_size >= 3:
        k1 ^= key[tail_index + 2] << 16
    if tail_size >= 2:
        k1 ^= key[tail_index + 1] << 8
    if tail_size >= 1:
        k1 ^= key[tail_index + 0]
    if tail_size > 0:
        k1 = (k1 * c1) & 0xFFFFFFFF
        k1 = ((k1 << 15) | (k1 >> 17)) & 0xFFFFFFFF
        k1 = (k1 * c2) & 0xFFFFFFFF
        h1 ^= k1

    unsigned_val = fmix(h1 ^ length)
    if unsigned_val & 0x80000000 == 0:
        return unsigned_val
    return -((unsigned_val ^ 0xFFFFFFFF) + 1)


def main():
    config_list = json.loads(ABILITY_CONFIG.read_text(encoding='utf-8'))
    language = json.loads(LANGUAGE.read_text(encoding='utf-8'))

    for item in config_list:
        ability_path = ABILITY_DIR / f"{item['id']}.json"
        ability = json.loads(ability_path.read_text(encoding='utf-8'))
        expected_name_hash = murmur3_hash(item['name'])
        expected_desc_hash = murmur3_hash(f"{item['name']}_desc")

        assert ability['name'] == expected_name_hash, (
            f"{item['id']} name hash mismatch: expected {expected_name_hash}, got {ability['name']}"
        )
        assert ability['description'] == expected_desc_hash, (
            f"{item['id']} desc hash mismatch: expected {expected_desc_hash}, got {ability['description']}"
        )
        assert ability['ability_icon'] == item['icon'], (
            f"{item['id']} icon mismatch: expected {item['icon']}, got {ability['ability_icon']}"
        )
        assert language.get(str(expected_name_hash)) == item['name'], (
            f"{item['id']} missing language name mapping for {item['name']}"
        )
        assert language.get(str(expected_desc_hash)) == item['description'], (
            f"{item['id']} missing language desc mapping for {item['name']}"
        )

    print('bond node editor sync ok')


if __name__ == '__main__':
    main()

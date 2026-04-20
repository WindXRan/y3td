#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ABILITY_CONFIG = ROOT / 'script' / 'tools' / 'bond_node_ability_config.json'
LANGUAGE = ROOT / 'zhlanguage.json'
ABILITY_DIR = ROOT / 'editor_table' / 'abilityall'
LUA = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe')


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


def write_json(path, payload):
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=4) + '\n',
        encoding='utf-8',
    )


def append_language_entries(path, original_text, pending_entries):
    if not pending_entries:
        return

    text = original_text.rstrip('\r\n')
    body, _ = text.rsplit('\n', 1)
    last_line_index = body.rfind('\n')
    if last_line_index >= 0:
        prefix = body[: last_line_index + 1]
        last_line = body[last_line_index + 1 :]
    else:
        prefix = ''
        last_line = body

    if not last_line.rstrip().endswith(','):
        last_line = f'{last_line}, '

    appended_lines = []
    entry_items = list(pending_entries.items())
    for index, (key, value) in enumerate(entry_items):
        line = f'    {json.dumps(key, ensure_ascii=True)}: {json.dumps(value, ensure_ascii=True)}'
        if index < len(entry_items) - 1:
            line += ', '
        appended_lines.append(line)

    new_text = prefix + last_line + '\n' + '\n'.join(appended_lines) + '\n}\n'
    path.write_text(new_text, encoding='utf-8')


def load_config_from_bond_nodes():
    lua_source = """
package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path
local BondNodes = require('runtime.bond_nodes')

local function escape_json(text)
    text = tostring(text or '')
    text = text:gsub('\\\\', '\\\\\\\\')
    text = text:gsub('"', '\\\\"')
    text = text:gsub('\\n', '\\\\n')
    text = text:gsub('\\r', '')
    return text
end

local function build_description(def)
    local desc = ''
    if type(def.desc) == 'table' then
        desc = '当前：' .. tostring(def.desc.single or '')
        if def.desc.advanced and def.desc.advanced ~= '' then
            desc = desc .. '\\n' .. tostring(def.desc.advanced)
        end
    else
        desc = tostring(def.desc or '')
    end
    return desc
end

io.write('[\\n')
for index, def in ipairs(BondNodes.list) do
    local item = string.format(
        '  {"type":"ability","name":"%s","id":%d,"icon":%d,"description":"%s"}',
        escape_json(def.display_name),
        def.editor_skill_id or 0,
        def.icon or 0,
        escape_json(build_description(def))
    )
    if index < #BondNodes.list then
        item = item .. ','
    end
    io.write(item .. '\\n')
end
io.write(']\\n')
"""

    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(lua_source)
        temp_path = Path(handle.name)

    try:
        result = subprocess.run(
            [str(LUA), str(temp_path)],
            cwd=ROOT.parents[1],
            text=True,
            encoding='utf-8',
            errors='replace',
            capture_output=True,
            check=False,
        )
    finally:
        temp_path.unlink(missing_ok=True)

    if result.returncode != 0:
        raise RuntimeError(
            'failed to load bond nodes from lua\n'
            f'STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}'
        )

    return json.loads(result.stdout)


def main():
    config_list = load_config_from_bond_nodes()
    write_json(ABILITY_CONFIG, config_list)
    language_text = LANGUAGE.read_text(encoding='utf-8')
    language = json.loads(language_text)
    updated_count = 0
    pending_language_entries = {}
    language_replace_count = 0

    for item in config_list:
        ability_path = ABILITY_DIR / f"{item['id']}.json"
        ability = json.loads(ability_path.read_text(encoding='utf-8'))
        name_hash = murmur3_hash(item['name'])
        desc_hash = murmur3_hash(f"{item['name']}_desc")
        changed = False

        if ability.get('name') != name_hash:
            ability['name'] = name_hash
            changed = True
        if ability.get('description') != desc_hash:
            ability['description'] = desc_hash
            changed = True
        if ability.get('ability_icon') != item['icon']:
            ability['ability_icon'] = item['icon']
            changed = True

        if changed:
            write_json(ability_path, ability)
            updated_count += 1

        name_key = str(name_hash)
        desc_key = str(desc_hash)
        if language.get(name_key) != item['name']:
            if name_key in language:
                language_replace_count += 1
            language[name_key] = item['name']
            pending_language_entries[name_key] = item['name']
        if language.get(desc_key) != item['description']:
            if desc_key in language:
                language_replace_count += 1
            language[desc_key] = item['description']
            pending_language_entries[desc_key] = item['description']

    if pending_language_entries:
        if language_replace_count > 0:
            LANGUAGE.write_text(
                json.dumps(language, ensure_ascii=True, indent=4) + '\n',
                encoding='utf-8',
            )
        else:
            append_language_entries(LANGUAGE, language_text, pending_language_entries)

    print(
        'synced bond node editor content: '
        f'{len(config_list)} entries, '
        f'{updated_count} ability files changed, '
        f'{len(pending_language_entries)} language entries updated'
    )


if __name__ == '__main__':
    main()

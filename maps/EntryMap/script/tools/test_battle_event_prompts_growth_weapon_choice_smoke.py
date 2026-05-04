#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
LUA = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe')


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        encoding='utf-8',
        errors='replace',
        capture_output=True,
        check=False,
    )


def assert_ok(result: subprocess.CompletedProcess[str], message: str) -> None:
    if result.returncode != 0:
        raise AssertionError(f'{message}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}')


def main() -> None:
    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local factory = require('runtime.battle_event_prompts') "
        "local gear = require('runtime.gear_upgrades') "
        "local messages = {} "
        "local state = { session_phase = 'battle', resources = { gold = 9999 }, choice_panel_hidden = true } "
        "local hero = {} "
        "function hero:is_exist() return true end "
        "state.hero = hero "
        "local api = factory.create({ "
        "  STATE = state, "
        "  GearUpgrades = gear, "
        "  CONFIG = { gear_upgrade_config = require('data.tables.gear_upgrade_config') }, "
        "  message = function(text) messages[#messages + 1] = tostring(text) end, "
        "  ensure_round_choice_available = function() return true end, "
        "  sync_gear_runtime_effects = function() end, "
        "  get_audio_system = function() return nil end, "
        "  get_message_prompt_system = function() return nil end, "
        "  get_runtime_hud_system = function() return nil end, "
        "  get_inventory_panel_system = function() return nil end, "
        "  BattleEventFeedSystem = { push_event = function() return true end }, "
        "  create_battle_event_feed_runtime = function() return {} end, "
        "  infer_battle_event_style = function() return 'info' end "
        "}) "
        "assert(api.try_upgrade_growth_weapon('smoke') == true, 'first upgrade should succeed') "
        "assert(state.gear_state.items.weapon.level == 2, 'first upgrade should reach level 2') "
        "assert(state.gear_state.awaiting_choice == false, 'non-affix nodes should not open a choice') "
        "for _ = 1, 8 do "
        "  assert(api.try_upgrade_growth_weapon('smoke') == true, 'growth weapon upgrade should keep succeeding before lv10') "
        "end "
        "assert(state.gear_state.items.weapon.level == 10, 'weapon should reach level 10 after 9 upgrades') "
        "assert(state.gear_state.awaiting_choice == true, 'level 10 should open a pending affix choice') "
        "assert(state.gear_state.pending_affix_choice ~= nil, 'level 10 should keep pending affix choice data') "
        "assert(#state.gear_state.items.weapon.affixes == 0, 'reaching an affix node should not auto-apply the first affix') "
        "assert(state.choice_panel_hidden == false, 'affix node should reopen the choice panel') "
        "assert(messages[#messages] == '成长武器达到 Lv.10，出现 3 个不同品质的词条，请选择其一。', 'affix node should prompt the three-choice message') "
        "print('battle event prompts growth weapon choice smoke ok') "
    )

    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)
    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)
    assert_ok(smoke, 'battle event prompts growth weapon choice smoke failed')

    print('battle event prompts growth weapon choice smoke ok')


if __name__ == '__main__':
    main()


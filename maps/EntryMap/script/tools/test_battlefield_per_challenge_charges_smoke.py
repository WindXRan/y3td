#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
LUA = Path.home() / 'AppData' / 'Local' / 'Programs' / 'Lua' / '5.4.8' / 'lua.exe'


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
    smoke = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local battlefield_mod = require('runtime.battlefield') "
        "local STATE = { "
        "  session_phase = 'battle', game_finished = false, awaiting_upgrade = false, active_challenges = {}, "
        "  challenge_charge_map = { gold_trial = 1, wood_trial = 2 }, "
        "  challenge_recover_elapsed_map = { gold_trial = 0, wood_trial = 0 }, "
        "  all_enemies = { add_unit = function() end, remove_unit = function() end }, total_enemy_alive = 0, enemy_info_map = {}, "
        "  resources = { gold = 0, wood = 0 }, total_kills = 0, defeated_boss_waves = {}, skill_runtime = { bonus_gold_on_kill = 0, medbot_every = 0, medbot_heal = 0 }, "
        "} "
        "local messages = {} "
        "local api = battlefield_mod.create({ "
        "  STATE = STATE, "
        "  CONFIG = { "
        "    challenge_rules = { max_charges = 2, recover_sec = 999 }, total_enemy_soft_cap = 99, areas = {}, "
        "    challenges = { "
        "      gold_trial = { id = 'gold_trial', name = '金币挑战', cost_charge = 1, duration_sec = 10, recover_sec = 10, spawn_area_id = 'a', unit_id = 1, batches = { { time_sec = 999, count = 1 } }, reward = {}, kill_reward = {} }, "
        "      wood_trial = { id = 'wood_trial', name = '木材挑战', cost_charge = 1, duration_sec = 10, recover_sec = 30, spawn_area_id = 'a', unit_id = 1, batches = { { time_sec = 999, count = 1 } }, reward = {}, kill_reward = {} } "
        "    } "
        "  }, "
        "  y3 = { object = { unit = { [1] = { data = {} } } }, unit = { create_unit = function() return {} end }, ltimer = { wait = function(_, fn) if fn then fn() end end } }, "
        "  message = function(text) messages[#messages + 1] = text end, design_seconds = function(v) return v end, random_point_in_area = function() return {} end, "
        "  hero_attr_system = {}, set_attr_pack = function() end, add_attr_pack = function() end, get_enemy_player = function() return {} end, get_player = function() return {} end, "
        "  award_rewards = function() end, build_reward_with_bond_bonus = function(reward) return reward end, handle_bond_enemy_kill = function() end, heal_hero = function() end, on_hero_damage = function() end "
        "}) "
        "api.try_start_challenge('gold_trial') "
        "api.try_start_challenge('wood_trial') "
        "assert(STATE.challenge_charge_map.gold_trial == 0, 'gold challenge charge should be consumed independently') "
        "assert(STATE.challenge_charge_map.wood_trial == 1, 'wood challenge charge should be consumed independently') "
        "api.update_challenge_charges(10) "
        "assert(STATE.challenge_charge_map.gold_trial == 1, 'gold challenge charge should recover independently') "
        "assert(STATE.challenge_charge_map.wood_trial == 1, 'wood challenge should wait for its own recover_sec') "
        "assert(STATE.challenge_recover_elapsed_map.gold_trial == 0, 'gold challenge recover timer should reset after refill') "
        "assert(STATE.challenge_recover_elapsed_map.wood_trial == 10, 'wood challenge should keep its own elapsed timer') "
        "print('battlefield per challenge charges smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'battlefield per-challenge charges smoke failed')


if __name__ == '__main__':
    main()

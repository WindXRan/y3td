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
        "local unit_seq = 0 "
        "local awarded = {} "
        "local group = { units = {} } "
        "function group:add_unit(unit) self.units[unit] = true end "
        "function group:remove_unit(unit) self.units[unit] = nil end "
        "local function new_point() return { get_x = function() return 0 end, get_y = function() return 0 end } end "
        "local function new_unit() "
        "  unit_seq = unit_seq + 1 "
        "  local unit = { id = unit_seq, attrs = { ['移动速度'] = 100 }, events = {}, removed = false } "
        "  function unit:get_attr(name) return self.attrs[name] or 0 end "
        "  function unit:set_attr(name, value) self.attrs[name] = value end "
        "  function unit:set_hp(_) end "
        "  function unit:set_reward_exp(_) end "
        "  function unit:attack_move(_) end "
        "  function unit:event(name, fn) self.events[name] = fn end "
        "  function unit:is_exist() return not self.removed end "
        "  function unit:is_in_group(target) return target.units[self] == true end "
        "  function unit:get_point() return new_point() end "
        "  function unit:remove() self.removed = true end "
        "  return unit "
        "end "
        "local STATE = { "
        "  session_phase = 'battle', game_finished = false, awaiting_upgrade = false, "
        "  active_challenges = {}, challenge_charges = 1, challenge_recover_elapsed = 0, "
        "  all_enemies = group, total_enemy_alive = 0, enemy_info_map = {}, "
        "  resources = { gold = 0, wood = 0 }, total_kills = 0, defeated_boss_waves = {}, skill_runtime = { bonus_gold_on_kill = 0, medbot_every = 0, medbot_heal = 0 }, "
        "} "
        "local api = battlefield_mod.create({ "
        "  STATE = STATE, "
        "  CONFIG = { "
        "    challenge_rules = { max_charges = 3, recover_sec = 100 }, "
        "    total_enemy_soft_cap = 99, "
        "    areas = { challenge_spawn_mid = { x_min = 0, x_max = 1, y_min = 0, y_max = 1, z = 0 } }, "
        "    challenges = { "
        "      test_trial = { "
        "        id = 'test_trial', name = '测试挑战', cost_charge = 1, duration_sec = 30, spawn_area_id = 'challenge_spawn_mid', "
        "        unit_id = 2, batches = { { time_sec = 0, count = 2 } }, "
        "        reward = { gold = 20, wood = 5, exp = 0 }, "
        "        kill_reward = { gold = 3, wood = 1, exp = 0 }, "
        "      } "
        "    } "
        "  }, "
        "  y3 = { "
        "    object = { unit = { [2] = { data = {} } } }, "
        "    unit = { create_unit = function(_, _, _, _) return new_unit() end }, "
        "    ltimer = { wait = function(_, fn) if fn then fn() end end }, "
        "  }, "
        "  message = function() end, design_seconds = function(v) return v end, random_point_in_area = function() return new_point() end, "
        "  hero_attr_system = {}, set_attr_pack = function() end, add_attr_pack = function() end, "
        "  get_enemy_player = function() return {} end, get_player = function() return {} end, "
        "  award_rewards = function(reward, source_text, silent) awarded[#awarded + 1] = { gold = reward.gold or 0, wood = reward.wood or 0, exp = reward.exp or 0, source = source_text, silent = silent } end, "
        "  build_reward_with_bond_bonus = function(reward) return reward end, "
        "  handle_bond_enemy_kill = function() end, heal_hero = function() end, on_hero_damage = function() end, "
        "}) "
        "api.try_start_challenge('test_trial') "
        "api.update_challenges(0) "
        "local instance = STATE.active_challenges['test_trial'] "
        "assert(instance ~= nil, 'challenge instance should exist') "
        "assert(#instance.infos == 2, 'challenge should spawn configured monster count') "
        "instance.infos[1].unit.events['单位-死亡']() "
        "assert(#awarded == 1, 'first challenge kill should grant one reward entry') "
        "assert(awarded[1].gold == 3 and awarded[1].wood == 1, 'kill reward should match config') "
        "instance.infos[2].unit.events['单位-死亡']() "
        "assert(#awarded == 3, 'second kill plus success should add reward entries') "
        "assert(awarded[2].gold == 3 and awarded[2].wood == 1, 'second kill reward should match config') "
        "assert(awarded[3].gold == 20 and awarded[3].wood == 5, 'challenge success reward should remain intact') "
        "print('battlefield challenge kill reward smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'battlefield challenge kill reward smoke failed')


if __name__ == '__main__':
    main()

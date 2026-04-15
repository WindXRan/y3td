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
        "local session_state_mod = require('runtime.session_state') "
        "local gear = require('runtime.gear_upgrades') "
        "local state = {} "
        "local system = session_state_mod.create({ "
        "  STATE = state, "
        "  CONFIG = { "
        "    challenges = {}, "
        "    challenge_rules = { initial_charges = 1 }, "
        "    points = { hero_spawn = { x = 0, y = 0, z = 0 }, defense_point = { x = 0, y = 0, z = 0 } }, "
        "    stages = { by_id = { ['1-1'] = { stage_id = '1-1', content_source_stage_id = '1-1', mode_ids = { 'standard' } } } }, "
        "    stage_modes = { by_id = { standard = { mode_id = 'standard' } } }, "
        "    gear_upgrade_config = require('data.object_tables.gear_upgrade_config'), "
        "  }, "
        "  y3 = { unit_group = { create = function() return {} end } }, "
        "  message = function() end, "
        "  make_point = function(data) return data end, "
        "  get_resource_rules = function() return { initial_gold = 0, initial_wood = 0 } end, "
        "  create_bond_runtime = function() return {} end, "
        "  create_battle_event_feed_runtime = function() return {} end, "
        "  create_effect_debug_runtime = function() return {} end, "
        "  create_mark_runtime = function() return {} end, "
        "  create_treasure_runtime = function() return {} end, "
        "  create_skill_runtime = function() return {} end, "
        "  create_attack_skill_state = function() return {} end, "
        "  destroy_choice_panel = function() end, "
        "  battlefield_system = { cleanup_battle_units = function() end }, "
        "  hero_attr_system = { snapshot = function() end, log_snapshot = function() end }, "
        "  get_player = function() return { set_hostility = function() end } end, "
        "  get_enemy_player = function() return { set_hostility = function() end } end, "
        "  create_hero = function() return { get_hp = function() return 100 end } end, "
        "  initialize_hero_progression = function() end, "
        "  setup_basic_attack_ability = function() end, "
        "  ensure_runtime_hud = function() end, "
        "  set_battle_hud_visible = function() end, "
        "  refresh_runtime_hud = function() end, "
        "  get_outgame_system = function() return nil end, "
        "  start_wave = function() end, "
        "  ensure_gear_runtime = function(state_arg, config_arg) return gear.ensure_runtime(state_arg, config_arg) end, "
        "}) "
        "assert(system.start_selected_stage('1-1', 'standard') == true, 'start_selected_stage should succeed') "
        "assert(state.gear_state ~= nil, 'gear_state should be initialized on stage start') "
        "assert(state.gear_state.items.weapon ~= nil, 'weapon slot should exist on stage start') "
        "assert(state.gear_state.items.weapon.level == 1, 'weapon should start at level 1 on stage start') "
        "print('session state grants level1 weapon smoke ok') "
    )

    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)
    try:
        result = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)
    assert_ok(result, 'session state level1 weapon smoke failed')


if __name__ == '__main__':
    main()

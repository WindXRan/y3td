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


def test_session_state_battle_pass_skill_guard_smoke() -> None:
    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local session_state_mod = require('runtime.session_state') "
        "local state = {} "
        "local started_waves = {} "
        "local system = session_state_mod.create({ "
        "  STATE = state, "
        "  CONFIG = { "
        "    challenges = {}, "
        "    challenge_rules = { initial_charges = 1 }, "
        "    points = { hero_spawn = { x = 0, y = 0, z = 0 }, defense_point = { x = 100, y = 0, z = 0 } }, "
        "    stages = { by_id = { ['1-1'] = { stage_id = '1-1', content_source_stage_id = '1-1', mode_ids = { 'standard' } } } }, "
        "    stage_modes = { by_id = { standard = { mode_id = 'standard' } } }, "
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
        "  get_player = function() return { set_hostility = function() end } end, "
        "  get_enemy_player = function() return { set_hostility = function() end } end, "
        "  create_hero = function() return { get_hp = function() return 100 end } end, "
        "  initialize_hero_progression = function() end, "
        "  collect_battle_pass_attack_skill_ids = function() error('battle_pass_collect_failed') end, "
        "  unlock_attack_skill = function() error('battle_pass_unlock_should_not_block_stage_start') end, "
        "  setup_basic_attack_ability = function() end, "
        "  ensure_runtime_hud = function() end, "
        "  set_battle_hud_visible = function() end, "
        "  refresh_runtime_hud = function() end, "
        "  enter_battle_audio = function() end, "
        "  get_outgame_system = function() return nil end, "
        "  start_wave = function(index) started_waves[#started_waves + 1] = index end, "
        "}) "
        "assert(system.start_selected_stage('1-1', 'standard') == true, 'start_selected_stage should survive battle pass collect failure') "
        "assert(state.session_phase == 'battle', 'session should still enter battle phase') "
        "assert(#started_waves == 1 and started_waves[1] == 1, 'stage start should still trigger wave 1 after battle pass failure') "
        "print('session state battle pass skill guard smoke ok') "
    )

    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)
    try:
        result = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)
    assert_ok(result, 'session state battle pass skill guard smoke failed')


if __name__ == '__main__':
    test_session_state_battle_pass_skill_guard_smoke()

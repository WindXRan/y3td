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
        "local state = {} "
        "local cleanup_calls = 0 "
        "local start_wave_calls = 0 "
        "local visible_calls = {} "
        "local refresh_calls = 0 "
        "local hero_removed = false "
        "local system = session_state_mod.create({ "
        "  STATE = state, "
        "  CONFIG = { "
        "    challenges = {}, "
        "    challenge_rules = { initial_charges = 1 }, "
        "    points = { hero_spawn = { x = 0, y = 0, z = 0 }, defense_point = { x = 0, y = 0, z = 0 } }, "
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
        "  battlefield_system = { cleanup_battle_units = function() "
        "    cleanup_calls = cleanup_calls + 1 "
        "    if state.hero and state.hero.is_exist and state.hero:is_exist() then state.hero:remove() end "
        "  end }, "
        "  hero_attr_system = { snapshot = function() end, log_snapshot = function() end }, "
        "  get_player = function() return { set_hostility = function() end } end, "
        "  get_enemy_player = function() return { set_hostility = function() end } end, "
        "  create_hero = function() "
        "    local removed = false "
        "    return { "
        "      get_hp = function() return 100 end, "
        "      get_bar_cnt = function() return 0 end, "
        "      set_bar_cnt = function() end, "
        "      has_item_by_key = function() return false end, "
        "      add_item = function() return { get_key = function() return 0 end } end, "
        "      is_exist = function() return removed ~= true end, "
        "      remove = function() removed = true; hero_removed = true end, "
        "    } "
        "  end, "
        "  initialize_hero_progression = function() end, "
        "  setup_basic_attack_ability = function() end, "
        "  ensure_runtime_hud = function() error('ui exploded') end, "
        "  set_battle_hud_visible = function() end, "
        "  refresh_runtime_hud = function() end, "
        "  get_outgame_system = function() return { "
        "    set_ui_visible = function(visible) visible_calls[#visible_calls + 1] = visible end, "
        "    refresh_ui = function() refresh_calls = refresh_calls + 1 end, "
        "  } end, "
        "  start_wave = function() start_wave_calls = start_wave_calls + 1 end, "
        "}) "
        "assert(system.start_selected_stage('1-1', 'standard') == false, 'stage start should fail when battle ui init fails') "
        "assert(state.session_phase == 'outgame', 'session should roll back to outgame after ui init failure') "
        "assert(start_wave_calls == 0, 'ui init failure should not start waves') "
        "assert(cleanup_calls >= 2, 'cleanup should run before start and during rollback') "
        "assert(hero_removed == true, 'rollback should remove created hero') "
        "assert(#visible_calls >= 1 and visible_calls[#visible_calls] == true, 'outgame ui should be shown again') "
        "assert(refresh_calls >= 1, 'outgame ui should refresh after rollback') "
        "print('session state ui init failure smoke ok') "
    )

    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)
    try:
        result = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)
    assert_ok(result, 'session state ui init failure smoke failed')


if __name__ == '__main__':
    main()

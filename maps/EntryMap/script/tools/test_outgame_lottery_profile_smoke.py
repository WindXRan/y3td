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
        "local outgame_mod = require('ui.outgame') "
        "local api = outgame_mod.create({ "
        "  STATE = {}, "
        "  CONFIG = { "
        "    stages = { list = { { stage_id = '1-1', display_name = '章节 1-1', mode_ids = { 'standard' } } }, by_id = { ['1-1'] = { stage_id = '1-1', display_name = '章节 1-1', mode_ids = { 'standard' } } } }, "
        "    stage_modes = { by_id = { standard = { mode_id = 'standard', display_name = '标准模式' } } }, "
        "    save_slots = { outgame_profile = 1 }, "
        "    outgame_attr_bonus_config = { by_stage_mode = {} }, "
        "    outgame_lottery_pool_catalog = require('data.object_tables.outgame_lottery_pool_catalog'), "
        "    outgame_lottery_pool_rules = require('data.object_tables.outgame_lottery_pool_rules') "
        "  }, "
        "  y3 = { "
        "    save_data = { load_table = function() return {} end, upload_save_data = function() end }, "
        "    ui = { get_ui = function() return nil end, get_window_width = function() return 1920 end, get_window_height = function() return 1080 end } "
        "  }, "
        "  message = function() end, "
        "  play_ui_click = function() end, "
        "  ensure_music_loop = function() end, "
        "  get_player = function() return {} end, "
        "  set_battle_hud_visible = function() end, "
        "  start_selected_stage = function() return true end "
        "}) "
        "assert(api.get_selected_lottery_pool() == 'treasure_hunt_pool_1', 'expected default selected lottery pool') "
        "local before = api.get_lottery_snapshot() "
        "assert(before.pool_state.first_single_consumed == false, 'expected first single not consumed') "
        "assert(before.pool_state.first_ten_consumed == false, 'expected first ten not consumed') "
        "api.add_lottery_draw_count('treasure_hunt_pool_1', 1, 'n_east', 'N') "
        "local after_single = api.get_lottery_snapshot('treasure_hunt_pool_1') "
        "assert(after_single.pool_draw_count == 1, 'expected pool draw count after single') "
        "assert(after_single.pool_state.first_single_consumed == true, 'expected first single consumed') "
        "assert(after_single.pool_state.draws_since_pity_hit == 1, 'expected pity counter after N draw') "
        "api.add_lottery_draw_count('treasure_hunt_pool_1', 10, 'ssr_big_joker', 'SSR') "
        "local after_ten = api.get_lottery_snapshot('treasure_hunt_pool_1') "
        "assert(after_ten.pool_state.first_ten_consumed == true, 'expected first ten consumed') "
        "assert(after_ten.pool_state.draws_since_pity_hit == 0, 'expected pity counter reset on SSR') "
        "assert(after_ten.pool_rules.pity_guarantee_rarity == 'SSR', 'expected pity target rarity') "
        "print('outgame lottery profile smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'outgame lottery profile smoke failed')


if __name__ == '__main__':
    main()

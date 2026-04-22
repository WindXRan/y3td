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
        "local seq = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 } "
        "local cursor = 0 "
        "local function next_rand(min_v, max_v) "
        "  cursor = cursor + 1 "
        "  local value = seq[cursor] or min_v "
        "  if value < min_v then value = min_v end "
        "  if value > max_v then value = max_v end "
        "  return value "
        "end "
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
        "  random_int = next_rand, "
        "  y3 = { "
        "    save_data = { load_table = function() return { outgame_treasure_hunt = { points = 100 } } end, upload_save_data = function() end }, "
        "    ui = { get_ui = function() return nil end, get_window_width = function() return 1920 end, get_window_height = function() return 1080 end } "
        "  }, "
        "  message = function() end, "
        "  play_ui_click = function() end, "
        "  ensure_music_loop = function() end, "
        "  get_player = function() return {} end, "
        "  set_battle_hud_visible = function() end, "
        "  start_selected_stage = function() return true end "
        "}) "
        "local ok_single, single = api.draw_lottery('treasure_hunt_pool_1', 1) "
        "assert(ok_single == true, 'expected single draw success') "
        "assert(single.cost == 1, 'expected single draw cost') "
        "assert(#single.rewards == 1, 'expected one reward') "
        "assert(single.rewards[1].rarity == 'SR' or single.rewards[1].rarity == 'SSR', 'expected first single guarantee to reach SR+') "
        "assert(single.points_after == 99, 'expected points after first single draw') "
        "local ok_dup, dup = api.draw_lottery('treasure_hunt_pool_1', 1) "
        "assert(ok_dup == true, 'expected duplicate single draw success') "
        "assert(dup.refund_points >= 0, 'expected duplicate refund field') "
        "local api2 = outgame_mod.create({ "
        "  STATE = {}, "
        "  CONFIG = { "
        "    stages = { list = { { stage_id = '1-1', display_name = '章节 1-1', mode_ids = { 'standard' } } }, by_id = { ['1-1'] = { stage_id = '1-1', display_name = '章节 1-1', mode_ids = { 'standard' } } } }, "
        "    stage_modes = { by_id = { standard = { mode_id = 'standard', display_name = '标准模式' } } }, "
        "    save_slots = { outgame_profile = 1 }, "
        "    outgame_attr_bonus_config = { by_stage_mode = {} }, "
        "    outgame_lottery_pool_catalog = require('data.object_tables.outgame_lottery_pool_catalog'), "
        "    outgame_lottery_pool_rules = require('data.object_tables.outgame_lottery_pool_rules') "
        "  }, "
        "  random_int = next_rand, "
        "  y3 = { "
        "    save_data = { load_table = function() return { outgame_treasure_hunt = { points = 1000 } } end, upload_save_data = function() end }, "
        "    ui = { get_ui = function() return nil end, get_window_width = function() return 1920 end, get_window_height = function() return 1080 end } "
        "  }, "
        "  message = function() end, "
        "  play_ui_click = function() end, "
        "  ensure_music_loop = function() end, "
        "  get_player = function() return {} end, "
        "  set_battle_hud_visible = function() end, "
        "  start_selected_stage = function() return true end "
        "}) "
        "local ok_ten, ten = api2.draw_lottery('treasure_hunt_pool_1', 10) "
        "assert(ok_ten == true, 'expected ten draw success') "
        "assert(ten.cost == 10, 'expected ten draw cost') "
        "assert(#ten.rewards == 10, 'expected ten rewards') "
        "local has_ssr = false "
        "for _, reward in ipairs(ten.rewards) do if reward.rarity == 'SSR' then has_ssr = true end end "
        "assert(has_ssr == true, 'expected first ten guarantee SSR') "
        "print('outgame lottery draw smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'outgame lottery draw smoke failed')


if __name__ == '__main__':
    main()

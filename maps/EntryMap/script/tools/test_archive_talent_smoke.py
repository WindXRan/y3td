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
        "local upload_count = 0 "
        "local saved_profile = { "
        "  archive_rewards = { talent_points = 2, talents = {} }, "
        "  stage_progress = { "
        "    ['1-1'] = { standard_unlocked = true, standard_cleared = false }, "
        "    ['1-2'] = { standard_unlocked = false, standard_cleared = false } "
        "  } "
        "} "
        "local api = outgame_mod.create({ "
        "  STATE = {}, "
        "  CONFIG = { "
        "    stages = { list = { "
        "      { stage_id = '1-1', display_name = '章节 1-1', mode_ids = { 'standard' }, content_source_stage_id = '1-1' }, "
        "      { stage_id = '1-2', display_name = '章节 1-2', mode_ids = { 'standard' }, content_source_stage_id = '1-2' } "
        "    }, by_id = { "
        "      ['1-1'] = { stage_id = '1-1', display_name = '章节 1-1', mode_ids = { 'standard' }, content_source_stage_id = '1-1' }, "
        "      ['1-2'] = { stage_id = '1-2', display_name = '章节 1-2', mode_ids = { 'standard' }, content_source_stage_id = '1-2' } "
        "    } }, "
        "    stage_modes = { by_id = { standard = { mode_id = 'standard', display_name = '标准模式' } } }, "
        "    save_slots = { outgame_profile = 1 }, "
        "    outgame_attr_bonus_config = { by_stage_mode = {} } "
        "  }, "
        "  y3 = { "
        "    save_data = { "
        "      load_table = function() return saved_profile end, "
        "      upload_save_data = function() upload_count = upload_count + 1 end "
        "    }, "
        "    ui = { get_ui = function() return nil end, get_window_width = function() return 1920 end, get_window_height = function() return 1080 end } "
        "  }, "
        "  message = function() end, "
        "  get_player = function() return {} end, "
        "  set_battle_hud_visible = function() end "
        "}) "
        "api.load_profile() "
        "assert(api.debug_get_archive_talent_points() == 2, 'expected seeded talent points') "
        "local locked_ok = api.debug_upgrade_archive_talent('output_8') "
        "assert(locked_ok == false, 'expected late talent to require column points') "
        "local ok = api.debug_upgrade_archive_talent('output_1') "
        "assert(ok == true, 'expected first output talent to upgrade') "
        "assert(api.debug_get_archive_talent_level('output_1') == 1, 'expected output_1 level 1') "
        "assert(saved_profile.hero_attr_bonus_stats['攻击白字'] == 10, 'expected output_1 to add saved attack bonus') "
        "assert(api.debug_get_archive_talent_points() == 1, 'expected one point spent') "
        "local ok2 = api.debug_upgrade_archive_talent('output_3') "
        "assert(ok2 == true, 'expected second-tier talent to unlock after one output point') "
        "assert(api.debug_get_archive_talent_level('output_3') == 1, 'expected output_3 level 1') "
        "assert(saved_profile.hero_attr_bonus_stats['攻击速度'] == 1, 'expected output_3 to add saved attack speed bonus') "
        "assert(api.debug_get_archive_talent_points() == 0, 'expected all seeded points spent') "
        "api.apply_battle_result({ stage_id = '1-1', is_win = true, reached_wave_index = 5 }) "
        "assert(api.debug_get_archive_talent_points() == 1, 'expected first standard clear to grant one point') "
        "api.apply_battle_result({ stage_id = '1-1', is_win = true, reached_wave_index = 5 }) "
        "assert(api.debug_get_archive_talent_points() == 1, 'expected repeat clear not to grant duplicate point') "
        "assert(saved_profile.stage_progress['1-2'].standard_unlocked == true, 'expected next stage unlock') "
        "assert(upload_count >= 3, 'expected upgrades and first clear to upload save') "
        "print('archive talent smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'archive talent smoke failed')


if __name__ == '__main__':
    main()

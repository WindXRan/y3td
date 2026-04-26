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
        "  stage_progress = { "
        "    ['1-1'] = { standard_unlocked = true, standard_cleared = true }, "
        "    ['1-2'] = { standard_unlocked = true, standard_cleared = false } "
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
        "  get_player = function() return { get_map_level = function() return 2 end, get_sign_in_days = function() return 0 end } end, "
        "  set_battle_hud_visible = function() end "
        "}) "
        "api.load_profile() "
        "local ok, msg = api.debug_claim_archive_universal_reward('pass', 'pass_badge_1') "
        "assert(ok == true, 'expected cleared difficulty reward to be claimable') "
        "assert(saved_profile.archive_rewards.pool_score == 50, 'expected pass reward to add pool score') "
        "assert(saved_profile.archive_rewards.claimed_universal['pass:pass_badge_1'] == true, 'expected claim marker') "
        "local again_ok = api.debug_claim_archive_universal_reward('pass', 'pass_badge_1') "
        "assert(again_ok == false, 'expected duplicate claim to be rejected') "
        "local locked_ok = api.debug_claim_archive_universal_reward('pass', 'pass_badge_2') "
        "assert(locked_ok == false, 'expected uncleared difficulty reward to be locked') "
        "local map_ok = api.debug_claim_archive_universal_reward('map', 'map_badge_2') "
        "assert(map_ok == false, 'expected honor tab entries to be preview/save-state entries, not claim rewards') "
        "assert(saved_profile.archive_rewards.honor_levels.honor_level_1 == true, 'expected honor level defaults to be stored in archive rewards') "
        "assert(saved_profile.archive_rewards.pool_score == 50, 'expected honor tab preview not to add score') "
        "assert(upload_count >= 1, 'expected successful claims to mark profile dirty') "
        "print('archive universal reward smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'archive universal reward smoke failed')


if __name__ == '__main__':
    main()

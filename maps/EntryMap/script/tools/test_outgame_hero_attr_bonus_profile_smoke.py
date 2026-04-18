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
        "local saved_profile = { "
        "  stage_progress = { "
        "    ['1-1'] = { standard_unlocked = true, standard_cleared = true, challenge_unlocked = true, challenge_cleared = true }, "
        "    ['1-2'] = { standard_unlocked = true, standard_cleared = false, challenge_unlocked = false, challenge_cleared = false } "
        "  }, "
        "  battle_pass = { "
        "    season_id = 'season_1', "
        "    exp = 600, "
        "    paid_unlocked = true, "
        "    claimed_free = { ['1'] = true }, "
        "    claimed_paid = { ['1'] = true, ['2'] = true } "
        "  } "
        "} "
        "local api = outgame_mod.create({ "
        "  STATE = {}, "
        "  CONFIG = { "
        "    stages = { list = { "
        "      { stage_id = '1-1', display_name = '章节 1-1', mode_ids = { 'standard', 'challenge' }, content_source_stage_id = '1-1' }, "
        "      { stage_id = '1-2', display_name = '章节 1-2', mode_ids = { 'standard', 'challenge' }, content_source_stage_id = '1-2' } "
        "    }, by_id = { "
        "      ['1-1'] = { stage_id = '1-1', display_name = '章节 1-1', mode_ids = { 'standard', 'challenge' }, content_source_stage_id = '1-1' }, "
        "      ['1-2'] = { stage_id = '1-2', display_name = '章节 1-2', mode_ids = { 'standard', 'challenge' }, content_source_stage_id = '1-2' } "
        "    } }, "
        "    stage_modes = { by_id = { "
        "      standard = { mode_id = 'standard', display_name = '标准模式' }, "
        "      challenge = { mode_id = 'challenge', display_name = '挑战模式' } "
        "    } }, "
        "    save_slots = { outgame_profile = 1 }, "
        "    outgame_attr_bonus_config = { "
        "      list = { "
        "        { stage_id = '1-1', mode_id = 'standard', attr_name = '攻击白字', value = 6 }, "
        "        { stage_id = '1-1', mode_id = 'standard', attr_name = '生命白字', value = 120 }, "
        "        { stage_id = '1-1', mode_id = 'challenge', attr_name = '攻击范围', value = 50 } "
        "      }, "
        "      by_stage_mode = { "
        "        ['1-1'] = { "
        "          standard = { ['攻击白字'] = 6, ['生命白字'] = 120 }, "
        "          challenge = { ['攻击范围'] = 50 } "
        "        } "
        "      } "
        "    } "
        "  }, "
        "  y3 = { "
        "    save_data = { "
        "      load_table = function() return saved_profile end, "
        "      upload_save_data = function() end "
        "    }, "
        "    ui = { get_ui = function() return nil end, get_window_width = function() return 1920 end, get_window_height = function() return 1080 end } "
        "  }, "
        "  message = function() end, "
        "  get_player = function() return {} end, "
        "  set_battle_hud_visible = function() end, "
        "  start_selected_stage = function() return true end "
        "}) "
        "local profile = api.load_profile() "
        "assert(profile.hero_attr_bonus_stats['攻击白字'] == 10, 'expected stage and battle pass attack bonus to merge') "
        "assert(profile.hero_attr_bonus_stats['生命白字'] == 200, 'expected stage and paid battle pass hp bonus to merge') "
        "assert(profile.hero_attr_bonus_stats['攻击范围'] == 110, 'expected challenge and paid battle pass range bonus to merge') "
        "assert(profile.selected_stage_id == '1-2', 'expected highest unlocked standard stage to be selected') "
        "assert(profile.selected_mode_id == 'standard', 'expected invalid saved mode to normalize to standard') "
        "assert(profile.battle_pass.exp == 600, 'expected existing battle pass exp to be preserved') "
        "print('outgame hero attr bonus profile smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'outgame hero attr bonus profile smoke failed')


if __name__ == '__main__':
    main()

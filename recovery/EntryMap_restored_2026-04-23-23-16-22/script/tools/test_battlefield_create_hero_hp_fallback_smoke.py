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
        "local battlefield = require('runtime.battlefield').create({ "
        "STATE = { hero_spawn_point = {}, resources = { gold = 0, wood = 0 } }, "
        "CONFIG = { unit_ids = { hero = 1 }, hero_init_stats = { ['生命'] = 900 }, debug_time_scale = 1, debug_hero_bonus_stats = {} }, "
        "y3 = { object = { unit = { [1] = { data = {} } } }, ltimer = { wait = function(_, fn) if fn then fn() end end } }, "
        "message = function() end, design_seconds = function(v) return v end, random_point_in_area = function() return {} end, "
        "hero_attr_system = { "
        "  init_hero_attrs = function(hero, seed) for k, v in pairs(seed) do hero:set_attr(k, v) end end, "
        "  set_attr = function(hero, name, value) hero:set_attr(name, value) end, "
        "  add_attr = function(hero, name, value) hero:add_attr(name, value) end, "
        "  rebuild_derived_attrs = function() end, "
        "  get_attr = function(hero, name) if name == '生命结算值' then return 0 end return hero:get_attr(name) end, "
        "}, "
        "set_attr_pack = function() end, add_attr_pack = function() end, "
        "get_player = function() "
        "  return { "
        "    create_unit = function(_, _, _, _) "
        "      local hero = { attrs = {}, hp = 0 } "
        "      function hero:set_name(_) end "
        "      function hero:set_attr(name, value) self.attrs[name] = value end "
        "      function hero:add_attr(name, value) self.attrs[name] = (self.attrs[name] or 0) + value end "
        "      function hero:get_attr(name) return self.attrs[name] or 0 end "
        "      function hero:add_state(_) end "
        "      function hero:stop() end "
        "      function hero:set_hp(value) self.hp = value end "
        "      function hero:get_common_attack() return nil end "
        "      function hero:event(_, _) end "
        "      function hero:is_exist() return true end "
        "      return hero "
        "    end, "
        "    select_unit = function() end, "
        "  } "
        "end, "
        "on_hero_damage = function() end, "
        "}) "
        "local hero = battlefield.create_hero() "
        "assert(hero.hp == 900, 'expected hero hp fallback to base life, got ' .. tostring(hero.hp)) "
        "print('battlefield create_hero hp fallback smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'battlefield create_hero hp fallback smoke failed')


if __name__ == '__main__':
    main()

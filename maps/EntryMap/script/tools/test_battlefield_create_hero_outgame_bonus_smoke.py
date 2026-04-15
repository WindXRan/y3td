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
        "local function create_field(config, state) "
        "  local battlefield = battlefield_mod.create({ "
        "    STATE = state, "
        "    CONFIG = config, "
        "    y3 = { object = { unit = { [1] = { data = {} } } }, ltimer = { wait = function(_, fn) if fn then fn() end end } }, "
        "    message = function() end, design_seconds = function(v) return v end, random_point_in_area = function() return {} end, "
        "    hero_attr_system = { "
        "      init_hero_attrs = function(hero, seed) for k, v in pairs(seed) do hero:set_attr(k, v) end end, "
        "      set_attr = function(hero, name, value) hero:set_attr(name, value) end, "
        "      add_attr = function(hero, name, value) hero:add_attr(name, value) end, "
        "      rebuild_derived_attrs = function() end, "
        "      get_attr = function(hero, name) return hero:get_attr(name) end, "
        "    }, "
        "    set_attr_pack = function() end, add_attr_pack = function() end, "
        "    get_player = function() "
        "      return { "
        "        create_unit = function(_, _, _, _) "
        "          local hero = { attrs = {}, hp = 0 } "
        "          function hero:set_name(_) end "
        "          function hero:set_attr(name, value) self.attrs[name] = value end "
        "          function hero:add_attr(name, value) self.attrs[name] = (self.attrs[name] or 0) + value end "
        "          function hero:get_attr(name) return self.attrs[name] or 0 end "
        "          function hero:add_state(_) end "
        "          function hero:stop() end "
        "          function hero:set_hp(value) self.hp = value end "
        "          function hero:get_hp() return self.hp end "
        "          function hero:get_common_attack() return nil end "
        "          function hero:event(_, _) end "
        "          function hero:is_exist() return true end "
        "          return hero "
        "        end, "
        "        select_unit = function() end, "
        "      } "
        "    end, "
        "    on_hero_damage = function() end, "
        "  }) "
        "  return battlefield.create_hero() "
        "end "
        "local config = { "
        "  unit_ids = { hero = 1 }, "
        "  hero_init_stats = { ['攻击'] = 46, ['生命'] = 900, ['攻击范围'] = 1400 }, "
        "  debug_time_scale = 1, "
        "  debug_hero_bonus_stats = {}, "
        "} "
        "local state = { hero_spawn_point = {}, resources = { gold = 0, wood = 0 }, outgame_profile = { hero_attr_bonus_stats = { ['攻击'] = 20, ['生命'] = 100, ['攻击范围'] = 60 } } } "
        "local hero = create_field(config, state) "
        "assert(hero:get_attr('攻击') == 66, 'expected outgame bonus attack to be added, got ' .. tostring(hero:get_attr('攻击'))) "
        "assert(hero:get_attr('生命') == 1000, 'expected outgame bonus life to be added, got ' .. tostring(hero:get_attr('生命'))) "
        "assert(hero:get_attr('攻击范围') == 1460, 'expected outgame bonus range to be added, got ' .. tostring(hero:get_attr('攻击范围'))) "
        "print('battlefield create_hero outgame bonus smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'battlefield create_hero outgame bonus smoke failed')


if __name__ == '__main__':
    main()

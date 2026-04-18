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
        "local rewards = require('runtime.rewards') "
        "local hero_attr_calls = { snapshot = 0, init = 0 } "
        "local selected_unit = nil "
        "local hero = { "
        "  attrs = { ['攻击范围'] = 1400, ['生命结算值'] = 900, ['生命'] = 900 }, "
        "  snapshot_pack = { ['攻击范围'] = 1400, ['生命结算值'] = 900, ['生命'] = 900 }, "
        "  kv = {}, hp = 450, level = 8, exp = 12, ability_point = 3, facing = 90, key = 999001 "
        "} "
        "function hero:is_exist() return true end "
        "function hero:get_hp() return self.hp end "
        "function hero:set_hp(value) self.hp = value end "
        "function hero:get_level() return self.level end "
        "function hero:set_level(value) self.level = value end "
        "function hero:get_exp() return self.exp end "
        "function hero:set_exp(value) self.exp = value end "
        "function hero:get_ability_point() return self.ability_point end "
        "function hero:set_ability_point(value) self.ability_point = value end "
        "function hero:get_facing() return self.facing end "
        "function hero:set_facing(value) self.facing = value end "
        "function hero:get_key() return self.key end "
        "function hero:set_attr(name, value) self.attrs[name] = value end "
        "function hero:add_attr(name, value) self.attrs[name] = (self.attrs[name] or 0) + value end "
        "function hero:get_attr(name) return self.attrs[name] or 0 end "
        "function hero:kv_save(key, value) self.kv[key] = value end "
        "function hero:kv_load(key, _) return self.kv[key] end "
        "function hero:kv_has(key) return self.kv[key] ~= nil end "
        "function hero:add_state(_) end "
        "function hero:stop() end "
        "function hero:get_common_attack() return nil end "
        "function hero:event(_, _) end "
        "function hero:transformation(unit_key, _) "
        "  self.key = unit_key "
        "  self.attrs = { ['攻击范围'] = 1, ['生命结算值'] = 300, ['生命'] = 300 } "
        "  self.kv = {} "
        "end "
        "local hero_attr_system = { "
        "  snapshot = function(unit, state) "
        "    hero_attr_calls.snapshot = hero_attr_calls.snapshot + 1 "
        "    local pack = {} "
        "    for k, v in pairs(unit.snapshot_pack) do pack[k] = v end "
        "    state.hero_attr_runtime = pack "
        "    return pack "
        "  end, "
        "  init_hero_attrs = function(unit, seed) "
        "    hero_attr_calls.init = hero_attr_calls.init + 1 "
        "    unit.attrs = {} "
        "    unit.kv = {} "
        "    unit.snapshot_pack = {} "
        "    for k, v in pairs(seed or {}) do "
        "      unit:set_attr(k, v) "
        "      unit.snapshot_pack[k] = v "
        "    end "
        "  end, "
        "  add_attr = function(unit, name, value) unit:add_attr(name, value) end, "
        "  get_attr = function(unit, name) return unit:get_attr(name) end, "
        "} "
        "local sync_basic_attack_count = 0 "
        "local api = rewards.create({ "
        "  STATE = { hero = hero, hero_common_attack = nil, attack_skill_state = nil }, "
        "  message = function() end, "
        "  round_number = function(value) return math.floor((value or 0) + 0.5) end, "
        "  y3 = { object = { unit = { [100001] = { data = {} } } } }, "
        "  hero_attr_system = hero_attr_system, "
        "  add_attr_pack = function(unit, pack) "
        "    for name, value in pairs(pack or {}) do "
        "      if value ~= nil and value ~= 0 then "
        "        hero_attr_system.add_attr(unit, name, value) "
        "      end "
        "    end "
        "  end, "
        "  sync_basic_attack_ability = function() sync_basic_attack_count = sync_basic_attack_count + 1 end, "
        "  setup_basic_attack_ability = function() sync_basic_attack_count = sync_basic_attack_count + 1 end, "
        "  get_player = function() return { select_unit = function(_, unit) selected_unit = unit end } end, "
        "  heal_hero = function() end, "
        "  collect_bond_route_tags = function() return {} end, "
        "}) "
        "local runtime = api.create_evolution_runtime() "
        "runtime.awaiting_choice = true "
        "runtime.current_choices = { api.EVOLUTION_DEFS.battle_scar_mark } "
        "runtime.owned_mark_ids = runtime.owned_evolution_ids "
        "runtime.ordered_mark_ids = runtime.ordered_evolution_ids "
        "runtime.applied = { attr = {}, runtime = {}, attack_skill = {} } "
        "api.get_evolution_runtime = function() return runtime end "
        "api.get_mark_runtime = api.get_evolution_runtime "
        "api.apply_evolution_choice(1) "
        "assert(hero.key == 100001, 'expected hero to transform into battle_scar_mark unit') "
        "assert(hero_attr_calls.init >= 1, 'expected hero runtime attrs to be restored after transformation') "
        "assert((hero:get_attr('攻击范围') or 0) >= 1400, 'expected restored attack range to survive transformation, got ' .. tostring(hero:get_attr('攻击范围'))) "
        "assert(selected_unit == hero, 'expected transformed hero to stay selected') "
        "assert(sync_basic_attack_count >= 1, 'expected basic attack ability sync after evolution transform') "
        "print('rewards evolution transform attr restore smoke ok') "
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke)
        temp_path = Path(handle.name)
    try:
        result = run([str(LUA), str(temp_path)])
    finally:
        temp_path.unlink(missing_ok=True)
    assert_ok(result, 'rewards evolution transform attr restore smoke failed')


if __name__ == '__main__':
    main()

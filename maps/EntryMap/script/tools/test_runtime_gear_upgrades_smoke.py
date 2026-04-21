#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
LUA = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe')
LUAC = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\luac.exe')
GEAR = ROOT / 'script' / 'runtime' / 'gear_upgrades.lua'


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
    syntax = run([str(LUAC), '-p', str(GEAR)])
    assert_ok(syntax, 'runtime/gear_upgrades.lua syntax check failed')

    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local gear = require('runtime.gear_upgrades') "
        "local hero_attr_system = require('runtime.hero_attr_system').create() "
        "local config = { gear_upgrade_config = require('data.object_tables.gear_upgrade_config') } "
        "local state = { resources = { gold = 500000 } } "
        "local hero = { attrs = {}, hp = 0 } "
        "function hero:get_attr(name) return self.attrs[name] or 0 end "
        "function hero:set_attr(name, value) self.attrs[name] = value end "
        "function hero:is_exist() return true end "
        "function hero:set_hp(value) self.hp = value end "
        "function hero:get_hp() return self.hp end "
        "hero_attr_system.init_hero_attrs(hero, { ['攻击'] = 100, ['生命'] = 1000, ['护甲'] = 10, ['力量'] = 20, ['敏捷'] = 20, ['智力'] = 20 }) "
        "gear.ensure_runtime(state, config.gear_upgrade_config) "
        "local runtime = assert(state.gear_state) "
        "assert(runtime.items.weapon.level == 1, 'weapon should start at level 1') "
        "assert(runtime.items.weapon.weapon_id == 'weapon_default', 'weapon should carry the configured weapon id') "
        "assert(runtime.items.focus == nil, 'focus should be removed') "
        "assert(runtime.items.emblem == nil, 'emblem should be removed') "
        "assert(gear.get_pending_choice_kind(state) == nil, 'gear should not start with pending choice') "
        "local cost = gear.get_upgrade_cost('weapon', 1, config.gear_upgrade_config) "
        "assert(cost == 50, 'weapon level 1 upgrade should cost 50 gold') "
        "assert(gear.get_upgrade_cost('weapon', 21, config.gear_upgrade_config) == 1050, 'weapon level 21 upgrade should use the linear 1050 gold cost') "
        "assert(gear.get_upgrade_cost('weapon', 91, config.gear_upgrade_config) == 4550, 'weapon level 91 upgrade should use the linear 4550 gold cost') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'level 1 should apply runtime bonuses immediately') "
        "assert(hero_attr_system.get_attr(hero, '攻击') == 110, 'level 1 should add the first 10 attack bonus') "
        "assert(hero_attr_system.get_attr(hero, '力量') == 22, 'level 1 should add 2 strength') "
        "assert(hero_attr_system.get_attr(hero, '敏捷') == 22, 'level 1 should add 2 agility') "
        "assert(hero_attr_system.get_attr(hero, '智力') == 22, 'level 1 should add 2 intelligence') "
        "local level_after_single = assert(gear.try_upgrade_levels({ STATE = state, CONFIG = config, message = function() end }, 'weapon', 1)) "
        "assert(level_after_single == 2, 'single upgrade should reach level 2') "
        "assert(runtime.items.weapon.level == 2, 'weapon level should be 2 after single upgrade') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'level 2 should apply runtime bonuses') "
        "assert(hero_attr_system.get_attr(hero, '攻击') == 120, 'level 2 should accumulate 20 attack growth') "
        "assert(hero_attr_system.get_attr(hero, '力量') == 24, 'level 2 should accumulate 4 strength growth') "
        "assert(hero_attr_system.get_attr(hero, '敏捷') == 24, 'level 2 should accumulate 4 agility growth') "
        "assert(hero_attr_system.get_attr(hero, '智力') == 24, 'level 2 should accumulate 4 intelligence growth') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == false, 're-sync without change should be stable') "
        "local reached = assert(gear.try_upgrade_levels({ STATE = state, CONFIG = config, message = function() end }, 'weapon', 8)) "
        "assert(reached == 10, 'weapon should stop at level 10 before pending affix') "
        "assert(runtime.items.weapon.level == 10, 'weapon level should be 10 at first affix node') "
        "assert(runtime.pending_affix_choice ~= nil, 'level 10 should queue affix choice') "
        "assert(runtime.pending_affix_choice.slot == 'weapon', 'queued affix should belong to weapon') "
        "assert(runtime.awaiting_choice == true and runtime.current_choices and #runtime.current_choices == 3, 'affix node should open 3 choices') "
        "assert(runtime.current_choices[1].display_name == '力量 +50', 'first configured affix should be deterministic for smoke coverage') "
        "assert(gear.get_pending_choice_kind(state) == 'gear', 'gear pending kind should be gear') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'level 10 should apply accumulated level bonuses before affix choice') "
        "assert(hero_attr_system.get_attr(hero, '攻击') == 200, 'level 10 should accumulate 100 attack growth') "
        "assert(hero_attr_system.get_attr(hero, '力量') == 40, 'level 10 should accumulate 20 strength growth') "
        "assert(hero_attr_system.get_attr(hero, '敏捷') == 40, 'level 10 should accumulate 20 agility growth') "
        "assert(hero_attr_system.get_attr(hero, '智力') == 40, 'level 10 should accumulate 20 intelligence growth') "
        "assert(gear.apply_affix_choice({ STATE = state, CONFIG = config, message = function() end }, 1) == true, 'affix choice should apply') "
        "assert(runtime.awaiting_choice == false and runtime.pending_affix_choice == nil, 'affix choice should clear pending state') "
        "assert(#runtime.items.weapon.affixes == 1, 'weapon should gain one affix after choice') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'affix choice should change runtime bonuses') "
        "assert(hero_attr_system.get_attr(hero, '力量') == 90, 'first affix should add strength on top of the level growth') "
        "assert(hero_attr_system.get_attr(hero, '攻击结算值') > 216, 'derived attack value should increase after the strength affix') "
        "for _ = 1, 9 do "
        "  local reached_level = assert(gear.try_upgrade_levels({ STATE = state, CONFIG = config, message = function() end }, 'weapon', 10)) "
        "  assert(reached_level % 10 == 0, 'weapon should stop on each affix node') "
        "  assert(runtime.awaiting_choice == true, 'weapon should wait for affix choice at each node') "
        "  assert(gear.apply_affix_choice({ STATE = state, CONFIG = config, message = function() end }, 1) == true, 'weapon affix choice should apply at each node') "
        "  assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'each node should refresh runtime bonuses') "
        "end "
        "assert(runtime.items.weapon.level == 100, 'weapon should now be able to reach level 100') "
        "assert(#runtime.items.weapon.affixes == 10, 'weapon should gain 10 affixes by level 100') "
        "assert(gear.try_upgrade_levels({ STATE = state, CONFIG = config, message = function() end }, 'weapon', 1) == 100, 'weapon should stay capped at level 100') "
        "assert(type(gear.build_slot_text(state, 'weapon')) == 'string', 'slot text should be printable') "
        "local tip_state = { resources = { gold = 9999 } } "
        "gear.ensure_runtime(tip_state, config.gear_upgrade_config) "
        "local fake_item_api = { "
        "  get_name_by_key = function() return '洪荒之刃' end, "
        "  get_icon_id_by_key = function() return 123456 end, "
        "} "
        "local payload = gear.build_tip_payload(tip_state, 'weapon', config.gear_upgrade_config, fake_item_api) "
        "assert(payload.title_text == '洪荒之刃', 'expected payload title text') "
        "assert(payload.cost_text == '升级所需：50 金币', 'expected payload cost text') "
        "assert(payload.attr_lines[1] == '+10攻击力', 'expected payload attack line') "
        "assert(payload.attr_lines[2] == '+2力量', 'expected payload strength line') "
        "assert(payload.attr_lines[3] == '+2敏捷', 'expected payload agility line') "
        "assert(payload.attr_lines[4] == '+2智力', 'expected payload intelligence line') "
        "assert(type(payload.affix_lines[1]) == 'table', 'expected payload affix row structure') "
        "assert(payload.affix_lines[1].title == '当前词缀', 'expected payload affix title') "
        "assert(payload.affix_lines[1].body == '暂无词缀', 'expected payload affix fallback') "
        "print('runtime gear upgrades smoke ok')"
    )

    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)
    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)
    assert_ok(smoke, 'runtime gear upgrades smoke failed')

    print('runtime gear upgrades smoke ok')


if __name__ == '__main__':
    main()

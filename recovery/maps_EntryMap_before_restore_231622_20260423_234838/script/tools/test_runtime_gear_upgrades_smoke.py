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
        "local messages = {} "
        "local function capture_message(text) messages[#messages + 1] = tostring(text) end "
        "local state = { resources = { gold = 50000 } } "
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
        "assert(cost == 100, 'weapon level 1 upgrade should cost 100 gold') "
        "assert(gear.get_upgrade_cost('weapon', 21, config.gear_upgrade_config) == 200, 'weapon level 21 upgrade should use configured second high band cost') "
        "assert(gear.get_upgrade_cost('weapon', 91, config.gear_upgrade_config) == 550, 'weapon level 91 upgrade should use configured top band cost') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == false, 'level 1 should not add any runtime bonus yet') "
        "local level_after_single = assert(gear.try_upgrade_levels({ STATE = state, CONFIG = config, message = capture_message }, 'weapon', 1)) "
        "assert(level_after_single == 2, 'single upgrade should reach level 2') "
        "assert(runtime.items.weapon.level == 2, 'weapon level should be 2 after single upgrade') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'level 2 should apply runtime bonuses') "
        "assert(hero_attr_system.get_attr(hero, '攻击') == 102, 'level 2 should add the level 1 attack bonus') "
        "assert(hero_attr_system.get_attr(hero, '生命') == 1008, 'level 2 should add the level 1 life bonus') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == false, 're-sync without change should be stable') "
        "local reached = assert(gear.try_upgrade_levels({ STATE = state, CONFIG = config, message = capture_message }, 'weapon', 8)) "
        "assert(reached == 10, 'weapon should stop at level 10 before pending affix') "
        "assert(runtime.items.weapon.level == 10, 'weapon level should be 10 at first affix node') "
        "assert(runtime.pending_affix_choice ~= nil, 'level 10 should queue affix choice') "
        "assert(runtime.pending_affix_choice.slot == 'weapon', 'queued affix should belong to weapon') "
        "assert(runtime.awaiting_choice == true and runtime.current_choices and #runtime.current_choices == 3, 'affix node should open 3 choices') "
        "assert(runtime.current_choices[1].quality == 'common', 'first weapon affix choice should be the common tier candidate') "
        "assert(runtime.current_choices[2].quality == 'rare', 'second weapon affix choice should be the rare tier candidate') "
        "assert(runtime.current_choices[3].quality == 'epic', 'third weapon affix choice should be the epic tier candidate') "
        "assert(runtime.current_choices[1].display_name == '砺锋', 'common affix candidate should be deterministic for smoke coverage') "
        "assert(runtime.current_choices[2].display_name == '重弓', 'rare affix candidate should be deterministic for smoke coverage') "
        "assert(runtime.current_choices[3].display_name == '猎心', 'epic affix candidate should be deterministic for smoke coverage') "
        "assert(gear.get_pending_choice_kind(state) == 'gear', 'gear pending kind should be gear') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'level 10 should apply accumulated level bonuses before affix choice') "
        "assert(hero_attr_system.get_attr(hero, '攻击') == 118, 'level 10 should accumulate 9 levels of attack growth') "
        "assert(hero_attr_system.get_attr(hero, '生命') == 1072, 'level 10 should accumulate 9 levels of life growth') "
        "assert(gear.apply_affix_choice({ STATE = state, CONFIG = config, message = capture_message }, 1) == true, 'affix choice should apply') "
        "assert(runtime.awaiting_choice == false and runtime.pending_affix_choice == nil, 'affix choice should clear pending state') "
        "assert(#runtime.items.weapon.affixes == 1, 'weapon should gain one affix after choice') "
        "assert(messages[#messages] == '成长武器获得 [普通] 词条：砺锋。', 'affix choice should emit a confirmation message for the selected affix') "
        "assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'affix choice should change runtime bonuses') "
        "assert(runtime.items.weapon.affixes[1].quality == 'common', 'applied affix should preserve its quality for downstream UI') "
        "assert(hero_attr_system.get_attr(hero, '攻击') == 148, 'first common affix should add attack to the hero attr system') "
        "assert(hero_attr_system.get_attr(hero, '攻击结算值') > 148, 'derived attack value should increase after the attack affix') "
        "for _ = 1, 9 do "
        "  local reached_level = assert(gear.try_upgrade_levels({ STATE = state, CONFIG = config, message = capture_message }, 'weapon', 10)) "
        "  assert(reached_level % 10 == 0, 'weapon should stop on each affix node') "
        "  assert(runtime.awaiting_choice == true, 'weapon should wait for affix choice at each node') "
        "  assert(gear.apply_affix_choice({ STATE = state, CONFIG = config, message = capture_message }, 1) == true, 'weapon affix choice should apply at each node') "
        "  assert(gear.sync_runtime_bonuses(state, hero, config.gear_upgrade_config, hero_attr_system) == true, 'each node should refresh runtime bonuses') "
        "end "
        "assert(runtime.items.weapon.level == 100, 'weapon should now be able to reach level 100') "
        "assert(#runtime.items.weapon.affixes == 10, 'weapon should gain 10 affixes by level 100') "
        "assert(gear.try_upgrade_levels({ STATE = state, CONFIG = config, message = capture_message }, 'weapon', 1) == 100, 'weapon should stay capped at level 100') "
        "assert(type(gear.build_slot_text(state, 'weapon')) == 'string', 'slot text should be printable') "
        "local tip_state = { resources = { gold = 9999 } } "
        "gear.ensure_runtime(tip_state, config.gear_upgrade_config) "
        "local fake_item_api = { "
        "  get_name_by_key = function() return '洪荒之刃' end, "
        "  get_icon_id_by_key = function() return 123456 end, "
        "  attr_pick_by_key = function() return { '物理攻击', '暴击率' } end, "
        "  get_attribute_by_key = function(_, key) "
        "    if key == '物理攻击' then return 31 end "
        "    if key == '暴击率' then return 0.25 end "
        "    return 0 "
        "  end, "
        "} "
        "local payload = gear.build_tip_payload(tip_state, 'weapon', config.gear_upgrade_config, fake_item_api) "
        "assert(payload.title_text == '洪荒之刃', 'expected payload title text') "
        "assert(payload.cost_text == '升级所需：100 金币', 'expected payload cost text') "
        "assert(payload.attr_lines[1] == '物理攻击 +31', 'expected payload attr line') "
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

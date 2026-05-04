#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
LUA = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe')


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
    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local session_state_mod = require('runtime.session_state') "
        "local gear = require('runtime.gear_upgrades') "
        "local equipment_catalog = require('data.tables.equipment_catalog') "
        "local state = {} "
        "local granted_items = {} "
        "local bar_counts = {} "
        "local system = session_state_mod.create({ "
        "  STATE = state, "
        "  CONFIG = { "
        "    challenges = {}, "
        "    challenge_rules = { initial_charges = 1 }, "
        "    points = { hero_spawn = { x = 0, y = 0, z = 0 }, defense_point = { x = 0, y = 0, z = 0 } }, "
        "    stages = { by_id = { ['1-1'] = { stage_id = '1-1', content_source_stage_id = '1-1', mode_ids = { 'standard' } } } }, "
        "    stage_modes = { by_id = { standard = { mode_id = 'standard' } } }, "
        "    gear_upgrade_config = require('data.tables.gear_upgrade_config'), "
        "  }, "
        "  y3 = { unit_group = { create = function() return {} end } }, "
        "  message = function() end, "
        "  make_point = function(data) return data end, "
        "  get_resource_rules = function() return { initial_gold = 0, initial_wood = 0 } end, "
        "  create_bond_runtime = function() return {} end, "
        "  create_battle_event_feed_runtime = function() return {} end, "
        "  create_effect_debug_runtime = function() return {} end, "
        "  create_mark_runtime = function() return {} end, "
        "  create_treasure_runtime = function() return {} end, "
        "  create_skill_runtime = function() return {} end, "
        "  create_attack_skill_state = function() return {} end, "
        "  destroy_choice_panel = function() end, "
        "  battlefield_system = { cleanup_battle_units = function() end }, "
        "  hero_attr_system = { snapshot = function() end, log_snapshot = function() end }, "
        "  get_player = function() return { set_hostility = function() end } end, "
        "  get_enemy_player = function() return { set_hostility = function() end } end, "
        "  create_hero = function() "
        "    return { "
        "      get_hp = function() return 100 end, "
        "      get_bar_cnt = function() return bar_counts[#bar_counts] or 0 end, "
        "      set_bar_cnt = function(_, value) bar_counts[#bar_counts + 1] = value end, "
        "      has_item_by_key = function(_, item_key) "
        "        for _, entry in ipairs(granted_items) do "
        "          if entry.item_key == item_key then return true end "
        "        end "
        "        return false "
        "      end, "
        "      add_item = function(_, item_key, slot_type) "
        "        granted_items[#granted_items + 1] = { item_key = item_key, slot_type = slot_type } "
        "        return { get_key = function() return item_key end } "
        "      end, "
        "    } "
        "  end, "
        "  initialize_hero_progression = function() end, "
        "  setup_basic_attack_ability = function() end, "
        "  ensure_runtime_hud = function() end, "
        "  set_battle_hud_visible = function() end, "
        "  refresh_runtime_hud = function() end, "
        "  get_outgame_system = function() return nil end, "
        "  start_wave = function() end, "
        "  ensure_gear_runtime = function(state_arg, config_arg) return gear.ensure_runtime(state_arg, config_arg) end, "
        "  sync_gear_items_to_hero = function(state_arg, hero_arg, config_arg) return gear.sync_items_to_hero(state_arg, hero_arg, config_arg) end, "
        "}) "
        "assert(system.start_selected_stage('1-1', 'standard') == true, 'start_selected_stage should succeed') "
        "assert(state.gear_state ~= nil, 'gear_state should be initialized on stage start') "
        "assert(state.gear_state.items.weapon ~= nil, 'weapon slot should exist on stage start') "
        "assert(state.gear_state.items.weapon.level == 1, 'weapon should start at level 1 on stage start') "
        "local growth_weapon_item_key = state.gear_state.items.weapon.item_key "
        "local expected_drag_test_items = {} "
        "local seen_item_keys = { [growth_weapon_item_key] = true } "
        "for _, item_key in ipairs(equipment_catalog.test_loadout_ids) do "
        "  if not seen_item_keys[item_key] then "
        "    expected_drag_test_items[#expected_drag_test_items + 1] = item_key "
        "    seen_item_keys[item_key] = true "
        "  end "
        "end "
        "assert(#bar_counts >= 1 and bar_counts[#bar_counts] >= equipment_catalog.bar_slot_count, 'hero should expose the full visible item bar for sync testing') "
        "assert(#granted_items == 1 + #expected_drag_test_items, 'hero should receive the growth weapon plus the deduplicated drag test items on stage start') "
        "assert(granted_items[1].item_key == 201390082, 'growth weapon should use the configured item key') "
        "assert(granted_items[1].slot_type == '物品栏', 'growth weapon should enter the visible item bar') "
        "for index, item_key in ipairs(expected_drag_test_items) do "
        "  local entry = granted_items[index + 1] "
        "  assert(entry ~= nil, 'missing drag test item grant at index ' .. tostring(index)) "
        "  assert(entry.item_key == item_key, 'drag test item key mismatch at index ' .. tostring(index)) "
        "  assert(entry.slot_type == '物品栏', 'drag test item should enter the visible item bar at index ' .. tostring(index)) "
        "end "
        "print('session state grants level1 weapon smoke ok') "
    )

    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)
    try:
        result = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)
    assert_ok(result, 'session state level1 weapon smoke failed')


if __name__ == '__main__':
    main()


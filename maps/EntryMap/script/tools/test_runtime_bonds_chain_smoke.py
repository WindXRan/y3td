#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
BONDS = ROOT / 'script' / 'runtime' / 'bonds.lua'
NODE_DEFS = ROOT / 'script' / 'runtime' / 'bond_nodes.lua'
REWARDS = ROOT / 'script' / 'runtime' / 'rewards.lua'
CHOICE_PANEL_MODEL = ROOT / 'script' / 'runtime' / 'choice_panel_model.lua'
OVERVIEW_MODEL = ROOT / 'script' / 'runtime' / 'overview_model.lua'
BOOT = ROOT / 'script' / 'runtime' / 'boot.lua'
BONDS_CHAIN = ROOT / 'script' / 'runtime' / 'bonds_chain.lua'
INPUT_EVENTS = ROOT / 'script' / 'runtime' / 'input_events.lua'
ATTACK_SKILLS = ROOT / 'script' / 'runtime' / 'attack_skills.lua'
ATTACK_UPGRADES = ROOT / 'script' / 'runtime' / 'attack_upgrades.lua'
AUTO_ACTIVE_EFFECTS = ROOT / 'script' / 'runtime' / 'auto_active_effects.lua'
AUTO_ACTIVE_EFFECT_DEFS = ROOT / 'script' / 'entry_objects' / 'auto_active_effects.lua'
BOND_ABILITY_CONFIG = ROOT / 'script' / 'tools' / 'bond_node_ability_config.json'
FIGHTING_SPIRIT_MODIFIER = ROOT / 'editor_table' / 'modifierall' / '201365014.json'
LUA = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe')
LUAC = Path(r'C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\luac.exe')


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


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def assert_not_contains(content: str, needle: str, message: str) -> None:
    if needle in content:
        raise AssertionError(message)


def main() -> None:
    syntax = run([str(LUAC), '-p', str(BONDS)])
    assert_ok(syntax, 'runtime/bonds.lua syntax check failed')

    smoke_source = (
            "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
            "local bonds = require('runtime.bonds') "
            "local state = { bond_runtime = bonds.create_runtime(), resources = { wood = 0 } } "
            "assert(type(bonds.create_runtime) == 'function') "
            "assert(type(bonds.try_draw) == 'function') "
            "assert(type(bonds.apply_choice) == 'function') "
            "assert(type(bonds.notify_attack_skill_cast) == 'function') "
            "assert(type(bonds.collect_route_tags) == 'function') "
            "assert(type(bonds.has_route_tag) == 'function') "
            "assert(bonds.can_unlock_node(state, 'bond_growth_agility') == true) "
            "assert(bonds.can_unlock_node(state, 'bond_growth_demon_hunter') == false) "
            "local bond_nodes = require('runtime.bond_nodes') "
            "local defs = bond_nodes.by_id "
            "assert(defs.bond_growth_agility.display_name == '敏捷') "
            "assert(string.find(defs.bond_growth_agility.desc.single, '木材', 1, true) ~= nil, '敏捷应带木材收益文案') "
            "assert(defs.bond_growth_demon_hunter.display_name == '猎魔人') "
            "assert(defs.bond_growth_bow_god.display_name == '弓神') "
            "assert(defs.bond_critical_deadly.display_name == '致命') "
            "assert(defs.bond_archery_multishot.display_name == '多重箭') "
            "assert(defs.bond_magic_elementalist.display_name == '元素师') "
            "assert(string.find(defs.bond_magic_mage.desc.single, '技能伤害', 1, true) ~= nil, '魔法师应突出法术增伤') "
            "assert(string.find(defs.bond_magic_mage.desc.single, '魔爆术', 1, true) ~= nil or string.find(defs.bond_magic_mage.desc.advanced, '魔爆术', 1, true) ~= nil, '魔法师节点应承接法术套装的魔爆术语义') "
            "assert(defs.bond_economy_greed.display_name == '贪婪') "
            "assert(string.find(defs.bond_economy_greed.desc.single, '击杀金币收益', 1, true) ~= nil, '贪婪应突出金币收益') "
            "assert(defs.bond_economy_challenge.display_name == '挑战') "
            "assert(string.find(defs.bond_economy_challenge.desc.single, '杀敌经验', 1, true) ~= nil or string.find(defs.bond_economy_challenge.desc.single, '杀敌加成', 1, true) ~= nil or string.find(defs.bond_economy_challenge.desc.advanced, '杀敌经验', 1, true) ~= nil, '挑战节点应承接经济图里的经验/杀敌多多语义') "
            "assert(string.find(defs.bond_body_life.desc.advanced, '血誓', 1, true) ~= nil, '生命应指向体术分支') "
            "assert(defs.bond_body_tactics.display_name == '战术') "
            "assert(defs.bond_body_charge_breaker.display_name == '陷阵') "
            "assert(string.find(defs.bond_body_blood_oath.desc.single, '每100点生命上限', 1, true) ~= nil or string.find(defs.bond_body_blood_oath.desc.advanced, '每100点生命上限', 1, true) ~= nil, '血誓节点应体现生命上限转属性') "
            "assert(string.find(defs.bond_body_blood_oath.desc.single, '生命值 +500', 1, true) ~= nil or string.find(defs.bond_body_blood_oath.desc.advanced, '生命值 +500', 1, true) ~= nil, '血誓节点应体现生命值+500套装结果') "
            "assert(string.find(defs.bond_critical_deadly.desc.single, '非暴击伤害', 1, true) ~= nil or string.find(defs.bond_critical_deadly.desc.single, '魔法暴击', 1, true) ~= nil or string.find(defs.bond_critical_deadly.desc.advanced, '非暴击伤害', 1, true) ~= nil, '致命节点应体现图片版暴击转化语义') "
            "assert(string.find(defs.bond_critical_cannon.desc.single, '致命攻击', 1, true) ~= nil or string.find(defs.bond_critical_cannon.desc.single, '致命魔法', 1, true) ~= nil or string.find(defs.bond_critical_cannon.desc.advanced, '致命攻击', 1, true) ~= nil, '大炮节点应体现图片版大炮条目') "
            "assert(string.find(defs.bond_archery_barrage.desc.single, '攻击范围', 1, true) ~= nil, '广射节点应体现攻击范围成长') "
            "assert(string.find(defs.bond_archery_shooting.desc.single, '穿云箭', 1, true) ~= nil or string.find(defs.bond_archery_shooting.desc.advanced, '穿云箭', 1, true) ~= nil, '射术节点应体现穿云箭语义') "
            "assert(string.find(defs.bond_archery_multishot.desc.single, '多重', 1, true) ~= nil or string.find(defs.bond_archery_multishot.desc.advanced, '多重', 1, true) ~= nil, '多重箭节点应体现多重箭数量或伤害') "
            "for _, def in ipairs(bond_nodes.list) do "
            "assert(def.icon ~= nil, 'missing icon for ' .. def.id) "
            "assert(def.editor_skill_id ~= nil, 'missing editor_skill_id for ' .. def.id) "
            "assert(type(def.desc) == 'table', 'missing desc table for ' .. def.id) "
            "assert(type(def.desc.single) == 'string' and def.desc.single ~= '', 'missing single desc for ' .. def.id) "
            "if #(def.next_ids or {}) > 0 then "
            "assert(type(def.desc.advanced) == 'string' and def.desc.advanced ~= '', 'missing advanced desc for ' .. def.id) "
            "end "
            "local ability_file = io.open('maps/EntryMap/editor_table/abilityall/' .. tostring(def.editor_skill_id) .. '.json', 'r') "
            "assert(ability_file ~= nil, 'missing ability json for ' .. def.id) "
            "if ability_file then ability_file:close() end "
            "end "
            "local node = assert(bonds.unlock_node(state, 'bond_growth_agility')) "
            "assert(node.id == 'bond_growth_agility') "
            "assert((state.resources.wood or 0) == 50, '敏捷节点应在解锁时发放木材 +50') "
            "local slot_text = bonds.build_slot_text(state, 1) "
            "assert(string.find(slot_text, '+100', 1, true) ~= nil, 'slot text should include current effect summary') "
            "local progress_lines = bonds.build_progress_lines(state, 6) "
            "assert(#progress_lines > 0, 'bond progress lines should not be empty') "
            "assert(string.find(progress_lines[1], '1/3', 1, true) ~= nil, 'bond progress lines should include subtree progress') "
            "assert(bonds.can_unlock_node(state, 'bond_growth_demon_hunter') == true) "
            "local hero = { attrs = { ['最大生命'] = 1000 }, hp = 1000 } "
            "function hero:is_exist() return true end "
            "function hero:get_attr(key) return self.attrs[key] or 0 end "
            "function hero:add_attr(key, delta) self.attrs[key] = (self.attrs[key] or 0) + delta end "
            "function hero:get_hp() return self.hp end "
            "function hero:play_animation() end "
            "state.hero = hero "
            "assert(bonds.unlock_node(state, 'bond_magic_mage')) "
            "assert(math.abs(bonds.get_runtime_bonus(state, 'skill_damage_bonus') - 0.075) < 0.0001, '魔法师节点应按图片版提供 7.5% 法术向增伤') "
            "bonds.notify_attack_skill_cast({ STATE = state }, { id = 'arcane_arrow' }, nil) "
            "bonds.update_effects({ STATE = state, y3 = { helper = { tonumber = tonumber } } }, 1) "
            "assert(math.abs(bonds.get_runtime_bonus(state, 'all_damage_bonus') - 0.12) < 0.0001) "
            "assert(state.bond_runtime.arcane_empower_remaining == 2) "
            "bonds.update_effects({ STATE = state, y3 = { helper = { tonumber = tonumber } } }, 2) "
            "assert((bonds.get_runtime_bonus(state, 'all_damage_bonus') or 0) == 0) "
            "assert(state.bond_runtime.arcane_empower_remaining == 0) "
            "local draw_state = { bond_runtime = bonds.create_runtime(), resources = { wood = 999 }, bond_draw_count = 0 } "
            "assert(bonds.try_draw({ STATE = draw_state, message = function() end })) "
            "local draw_choice = assert(draw_state.bond_runtime.current_choices[1]) "
            "assert(type(draw_choice.current_text) == 'string' and draw_choice.current_text ~= '') "
            "assert(type(draw_choice.value_text) == 'string' and draw_choice.value_text ~= '') "
            "assert(type(draw_choice.effect_title) == 'string' and draw_choice.effect_title ~= '') "
            "assert(type(draw_choice.effect_text) == 'string' and draw_choice.effect_text ~= '') "
            "if #(draw_choice.next_ids or {}) > 0 then "
            "assert(type(draw_choice.next_text) == 'string' and draw_choice.next_text ~= '') "
            "end "
            "local preview_text = bonds.build_choice_preview_text(1, draw_choice) "
            "assert(string.find(preview_text, '1.', 1, true) ~= nil, 'choice preview should keep index prefix') "
            "assert(string.find(preview_text, ' | ', 1, true) ~= nil, 'choice preview should include compact summary') "
            "local attack_skills = require('runtime.attack_skills') "
            "local target = {} "
            "local attack_state = { hero = { is_exist = function() return true end, get_point = function() return {} end }, attack_skill_state = { slots = { [1] = nil, [2] = { id = 'test_spell', cast_range = 600, range_bonus = 0, repeat_count = 1, base_cooldown = 1, cooldown_reduction = 0, cooldown_remaining = 0 } } } } "
            "local notify_count = 0 "
            "local old_random = math.random "
            "math.random = function() return 0 end "
            "local selector = {} "
            "function selector:is_enemy(_) return self end "
            "function selector:in_range(_, _) return self end "
            "function selector:sort_type(_) return self end "
            "function selector:pick() return { target } end "
            "local sys = attack_skills.create({ "
            "STATE = attack_state, "
            "y3 = { selector = { create = function() return selector end }, helper = { tonumber = tonumber } }, "
            "round_number = function(v) return math.floor((v or 0) + 0.5) end, "
            "message = function() end, "
            "ATTACK_SKILL_DEFS = { basic_attack = { base_range = 250, damage_type = '物理' } }, "
            "ATTACK_SKILL_VFX = {}, "
            "get_player = function() return {} end, "
            "get_hero_point = function() return {} end, "
            "get_bond_runtime_bonus = function(key) if key == 'skill_echo_chance' then return 1 end return 0 end, "
            "is_bond_active = function() return false end, "
            "is_active_enemy = function(unit) return unit == target end, "
            "create_attack_skill_instance = function() return {} end, "
            "deal_skill_damage = function() end, "
            "get_damage_bonus_multiplier = function() return 1 end, "
            "get_enemies_in_range = function() return {} end, "
            "try_trigger_hunter_first_hit = function() end, "
            "notify_bond_attack_skill_cast = function() notify_count = notify_count + 1 end, "
            "notify_auto_active_basic_attack = function() end, "
            "notify_auto_active_skill_cast = function() end "
            "}) "
            "sys.update_attack_skills(0.1) "
            "math.random = old_random "
            "assert(notify_count == 2) "
            "local reward_state = { bond_runtime = bonds.create_runtime() } "
            "assert(bonds.unlock_node(reward_state, 'bond_body_fortress')) "
            "local route_tags = bonds.collect_route_tags(reward_state) "
            "assert(route_tags.fortress == true) "
            "assert(bonds.has_route_tag(reward_state, 'fortress') == true) "
            "local rewards = require('runtime.rewards') "
            "local reward_api = rewards.create({ "
            "STATE = reward_state, "
            "message = function() end, "
            "round_number = function(v) return math.floor((v or 0) + 0.5) end, "
            "add_attr_pack = function() end, "
            "sync_basic_attack_ability = function() end, "
            "heal_hero = function() end, "
            "collect_bond_route_tags = function() return bonds.collect_route_tags(reward_state) end "
            "}) "
            "local treasure_runtime = reward_api.get_treasure_runtime() "
            "for treasure_id in pairs(reward_api.TREASURE_DEFS) do "
            "if treasure_id ~= 'echo_codex' and treasure_id ~= 'heart_guard_mirror' then "
            "treasure_runtime.discarded_treasure_ids[treasure_id] = true "
            "end "
            "end "
            "old_random = math.random "
            "math.random = function(a, b) "
            "if a and b then return a end "
            "return 0.5 "
            "end "
            "local treasure_choices = reward_api.pick_treasure_choices(1) "
            "math.random = old_random "
            "assert(#treasure_choices == 1) "
            "assert(treasure_choices[1].id == 'heart_guard_mirror') "
            "local compatibility_state = { bond_runtime = bonds.create_runtime() } "
            "assert(bonds.unlock_node(compatibility_state, 'bond_magic_mage')) "
            "assert(bonds.unlock_node(compatibility_state, 'bond_magic_trick')) "
            "assert(bonds.unlock_node(compatibility_state, 'bond_magic_haste')) "
            "assert(bonds.unlock_node(compatibility_state, 'bond_magic_elementalist')) "
            "assert(bonds.has_route_tag(compatibility_state, 'resonance') == true) "
            "assert(bonds.has_route_tag(compatibility_state, 'auto_spell_burst') == true) "
            "assert(bonds.has_route_tag(compatibility_state, 'auto_spell_burst_amp') == true) "
            "assert(bonds.has_route_tag(compatibility_state, 'auto_haste_reset') == true) "
            "assert(bonds.has_route_tag(compatibility_state, 'burn') == true) "
            "assert(bonds.has_route_tag(compatibility_state, 'cold_tide') == true) "
            "assert(bonds.has_route_tag(compatibility_state, 'shock') == true) "
            "local auto_active_effects = require('runtime.auto_active_effects') "
            "local auto_damage_count = 0 "
            "local stun_buff_count = 0 "
            "local enemy_debuff_count = 0 "
            "local debuff_target = { "
            "is_exist = function() return true end, "
            "get_attr = function(_, attr) if attr == '护甲' or attr == '物理攻击' then return 100 end return 100 end, "
            "get_hp = function() return 100 end, "
            "get_point = function() return {} end, "
            "add_attr = function() end, "
            "add_buff = function(_, data) if data and data.key == 117 then stun_buff_count = stun_buff_count + 1 end if data and data.key == 201365014 then enemy_debuff_count = enemy_debuff_count + 1 end return {} end "
            "} "
            "local auto_env = { "
            "STATE = { hero = hero, attack_skill_state = { slots = { [1] = nil, [2] = { id = 'test_spell', cooldown_remaining = 1 } }, by_id = { test_spell = { id = 'test_spell', cooldown_remaining = 1 } } } }, "
            "y3 = { "
            "helper = { tonumber = tonumber }, "
            "particle = { create = function() return { is_exist = function() return false end, remove = function() end } end }, "
            "projectile = { create = function() return { is_exist = function() return false end, remove = function() end, mover_target = function() end } end }, "
            "ltimer = { wait = function(_, fn) fn() end }, "
            "game = { str_to_modifier_key = function(name) if name == '晕眩' then return 9001 end if name == '斗气压制' then return 201365014 end return 0 end } "
            "}, "
            "ATTACK_SKILL_VFX = {}, "
            "get_player = function() return {} end, "
            "is_bond_active = function() return false end, "
            "has_bond_route_tag = function(tag) return tag == 'auto_spell_burst' or tag == 'auto_spell_burst_amp' or tag == 'auto_haste_reset' or tag == 'auto_fighting_spirit' or tag == 'auto_blood_demon_burst' end, "
            "is_active_enemy = function() return true end, "
            "get_enemies_in_range = function() return { debuff_target } end, "
            "deal_skill_damage = function() auto_damage_count = auto_damage_count + 1 end, "
            "heal_hero = function() end "
            "} "
            "function hero:add_attr() end "
            "function hero:get_hp() return 20 end "
            "local auto_sys = auto_active_effects.create(auto_env) "
            "auto_sys.update(0.25) "
            "assert(auto_damage_count > 0) "
            "assert(enemy_debuff_count > 0) "
            "old_random = math.random "
            "math.random = function() return 0 end "
            "auto_sys.handle_attack_skill_cast({ id = 'test_spell' }, nil) "
            "auto_sys.update(0.25) "
            "math.random = old_random "
            "assert(auto_env.STATE.attack_skill_state.by_id.test_spell.cooldown_remaining == 0) "
            "assert(stun_buff_count > 0) "
            "local attack_upgrades = require('runtime.attack_upgrades') "
            "local upgrade_state = { "
            "skill_points = 1, "
            "resources = { wood = 999 }, "
            "current_wave_index = 1, "
            "attack_skill_state = { unlock_offer_fail_streak = 0 } "
            "} "
            "local basic_attack = { "
            "damage_ratio = 1, split_count = 0, split_ratio = 0, boss_bonus_ratio = 0, "
            "range_bonus = 0, armor_break_ratio = 0, armor_break_duration = 0, armor_break_max_stacks = 0 "
            "} "
            "local random_values = { 0, 0.30, 0, 0 } "
            "local random_index = 0 "
            "old_random = math.random "
            "math.random = function(a, b) "
            "random_index = random_index + 1 "
            "local value = random_values[random_index] or 0 "
            "if a and b then return a end "
            "return value "
            "end "
            "local upgrade_sys = attack_upgrades.create({ "
            "STATE = upgrade_state, "
            "message = function() end, "
            "get_attack_skill = function(skill_id) if skill_id == 'basic_attack' then return basic_attack end return nil end, "
            "get_empty_attack_skill_slot = function() return 2 end, "
            "get_unlocked_attack_skill_count = function() return 1 end, "
            "get_upgrade_pick_count = function() return 0 end, "
            "record_upgrade_pick = function() end, "
            "unlock_attack_skill = function(skill_id) return { id = skill_id, name = skill_id }, 2, true end, "
            "sync_basic_attack_ability = function() end, "
            "build_attack_skill_slot_text = function() return '' end, "
            "is_bond_active = function() return false end, "
            "has_active_treasure = function() return false end, "
            "collect_bond_route_tags = function() return { arcane_arrow = true } end "
            "}) "
            "upgrade_sys.show_upgrade_choices() "
            "math.random = old_random "
            "assert(upgrade_state.current_upgrade_choices[1].key == 'unlock_arcane_arrow') "
            "local choice_panel_model = require('runtime.choice_panel_model') "
            "local choice_panel_api = choice_panel_model.create({ "
            "STATE = { bond_runtime = { current_offer_round = { free_refresh_left = 0, refresh_paid_count = 0 }, current_choices = { { "
            "quality = 'rare', "
            "title_text = '体术(0/3)', "
            "subtitle_text = '体魄', "
            "desc_text = '占位描述', "
            "current_text = '当前：敏捷 +100。', "
            "advanced_text = '进阶：杀敌敏捷 +0.1，每秒敏捷 +0.2。', "
            "next_text = '后继：猎魔人。', "
            "value_text = '生命值+100\\n力量+50', "
            "effect_title = '激活[体术]链式效果：', "
            "effect_text = '斗气场域：每秒对周围1200范围内的敌人造成(60%)力量自适应伤害' "
            "} } }, choice_panel_hidden = false }, "
            "message = function() end, "
            "BondSystem = { refresh_choice = function() return true end }, "
            "ATTACK_SKILL_DEFS = {}, "
            "TREASURE_DEFS = {}, "
            "get_pending_round_choice_kind = function() return 'bond' end, "
            "get_treasure_runtime = function() return {} end, "
            "get_treasure_quality_label = function() return '' end, "
            "get_treasure_active_count = function() return 0 end, "
            "pick_treasure_choices = function() return {} end, "
            "create_bond_env = function() return {} end, "
            "refresh_upgrade_choices = function() return false end "
            "}) "
            "local panel_model = assert(choice_panel_api.get_current_choice_panel_model()) "
            "assert(#panel_model.cards == 1) "
            "assert(panel_model.cards[1].title_text == '体术(0/3)') "
            "assert(panel_model.cards[1].subtitle_text == '体魄') "
            "assert(#(panel_model.cards[1].body_blocks or {}) >= 2, 'bond choice body blocks should show current and follow-up info') "
            "local overview_model = require('runtime.overview_model') "
            "local overview_api = overview_model.create({ "
            "STATE = { "
            "session_phase = 'battle', "
            "runtime_overview_mode = 'build', "
            "bond_runtime = { awaiting_choice = true, current_choices = { { display_name = '敏捷', current_text = '当前：敏捷 +100。' } } }, "
            "resources = { gold = 0, wood = 0 }, "
            "skill_points = 0, "
            "active_challenges = {}, "
            "total_enemy_alive = 0 "
            "}, "
            "CONFIG = { challenge_rules = { max_charges = 3 } }, "
            "round_number = function(v) return math.floor((v or 0) + 0.5) end, "
            "get_current_wave = function() return { name = 'wave' } end, "
            "get_boss_name = function() return 'boss' end, "
            "get_pending_round_choice_kind = function() return 'bond' end, "
            "get_hero_progress_text = function() return 'Lv.1' end, "
            "get_reward_queue_count = function() return 0 end, "
            "get_reward_queue = function() return {} end, "
            "get_mark_runtime = function() return {} end, "
            "get_treasure_runtime = function() return {} end, "
            "get_treasure_quality_label = function() return '' end, "
            "get_treasure_active_count = function() return 0 end, "
            "get_mark_active_count = function() return 0 end, "
            "build_treasure_slot_text = function(slot) return '宝物位' .. tostring(slot) end, "
            "build_mark_slot_text = function(slot) return '烙印位' .. tostring(slot) end, "
            "get_bond_runtime_bonus = function() return 0 end, "
            "get_treasure_reward_ratio = function() return 0 end, "
            "get_treasure_passive_income = function() return 0 end, "
            "build_attack_skill_slot_text = function(slot) return '技能位' .. tostring(slot) end, "
            "build_bond_slot_text = function(slot) return '羁绊位' .. tostring(slot) end, "
            "build_bond_choice_preview_text = function(index, choice) return string.format('%d. %s | %s', index, choice.display_name, choice.current_text) end, "
            "build_bond_progress_lines = function() return { '成长 · 敏捷线 1/3 | 可选：猎魔人' } end "
            "}) "
            "local overview = overview_api.get_runtime_overview_model() "
            "assert(#(overview.sections.pending.lines or {}) >= 3) "
            "assert(string.find(overview.sections.pending.lines[2], '1.', 1, true) ~= nil, 'overview should show bond choice preview lines') "
            "assert(string.find(overview.sections.pending.lines[2], ' | ', 1, true) ~= nil, 'overview preview should keep compact summary structure') "
            "assert(string.find(overview.sections.progress.lines[1], '1/3', 1, true) ~= nil, 'overview should show bond progress lines') "
            "print('runtime bonds chain smoke ok')"
    )
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', suffix='.lua', delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)
    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)
    assert_ok(smoke, 'runtime bonds smoke failed')

    choice_panel_content = CHOICE_PANEL_MODEL.read_text(encoding='utf-8')
    overview_content = OVERVIEW_MODEL.read_text(encoding='utf-8')
    boot_content = BOOT.read_text(encoding='utf-8')
    bonds_chain_content = BONDS_CHAIN.read_text(encoding='utf-8')
    bond_nodes_content = NODE_DEFS.read_text(encoding='utf-8')
    input_events_content = INPUT_EVENTS.read_text(encoding='utf-8')
    attack_skills_content = ATTACK_SKILLS.read_text(encoding='utf-8')
    attack_upgrades_content = ATTACK_UPGRADES.read_text(encoding='utf-8')
    auto_active_effects_content = AUTO_ACTIVE_EFFECTS.read_text(encoding='utf-8')
    auto_active_effect_defs_content = AUTO_ACTIVE_EFFECT_DEFS.read_text(encoding='utf-8')
    rewards_content = REWARDS.read_text(encoding='utf-8')
    ability_config_content = BOND_ABILITY_CONFIG.read_text(encoding='utf-8')

    assert_contains(choice_panel_content, '羁绊节点', 'choice_panel_model.lua should render chain-node wording')
    assert_contains(overview_content, 'build_bond_progress_lines', 'overview_model.lua should render bond progress bridge text')
    assert_contains(overview_content, 'progress = {', 'overview_model.lua should expose progress section key')
    assert_not_contains(overview_content, 'swallowed = {', 'overview_model.lua should not keep swallowed section key')
    assert_contains(overview_content, '链路进度', 'overview_model.lua should expose bond progress title')
    assert_contains(boot_content, '链式羁绊', 'boot.lua should expose chain-bond wording')
    assert_contains(boot_content, 'show_bond_progress', 'boot.lua should expose bond progress bridge')
    assert_not_contains(boot_content, 'show_swallowed_bonds', 'boot.lua should not keep swallowed progress bridge')
    assert_not_contains(boot_content, 'build_swallowed_bond_text', 'boot.lua should not keep swallowed bond text bridge')
    assert_contains(boot_content, 'collect_bond_route_tags', 'boot.lua should inject bond route tags into rewards')
    assert_contains(input_events_content, 'show_bond_progress', 'input_events.lua should use bond progress handler')
    assert_not_contains(input_events_content, 'show_swallowed_bonds', 'input_events.lua should not keep swallowed progress handler')
    assert_contains(bonds_chain_content, 'function M.show_bond_progress', 'bonds_chain.lua should expose bond progress output')
    assert_not_contains(bonds_chain_content, 'function M.show_swallowed_bonds', 'bonds_chain.lua should not keep swallowed progress output')
    assert_not_contains(bonds_chain_content, 'function M.build_swallowed_bond_text', 'bonds_chain.lua should remove swallowed bond text helper')
    assert_not_contains(bonds_chain_content, 'swallowed_bonds = {},', 'bonds_chain.lua should not keep swallowed bond runtime field')
    assert_contains(bond_nodes_content, "display_name = '猎魔人'", 'bond_nodes.lua should expose xmind growth chain naming')
    assert_contains(bond_nodes_content, "display_name = '多重箭'", 'bond_nodes.lua should expose archery chain naming')
    assert_contains(bond_nodes_content, "display_name = '元素师'", 'bond_nodes.lua should expose magic chain naming')
    assert_contains(bond_nodes_content, "display_name = '陷阵'", 'bond_nodes.lua should expose body chain naming')
    assert_contains(ability_config_content, '"name": "敏捷"', 'bond ability config should mirror new root node name')
    assert_contains(ability_config_content, '"name": "猎魔人"', 'bond ability config should mirror growth branch name')
    assert_contains(ability_config_content, '"name": "元素师"', 'bond ability config should mirror magic branch name')
    assert_contains(ability_config_content, '"name": "陷阵"', 'bond ability config should mirror body branch name')
    assert_contains(attack_skills_content, 'notify_bond_attack_skill_cast', 'attack_skills.lua should notify bond skill-cast hook')
    assert_not_contains(attack_skills_content, 'local is_bond_active = env.is_bond_active', 'attack_skills.lua should not depend on env.is_bond_active anymore')
    assert_contains(attack_upgrades_content, 'collect_bond_route_tags', 'attack_upgrades.lua should consume bond route tags')
    assert_not_contains(attack_upgrades_content, 'LEGACY_BOND_ROUTE_TAG_FALLBACKS', 'attack_upgrades.lua should not keep legacy bond route tag fallbacks')
    assert_contains(auto_active_effects_content, 'has_bond_route_tag', 'auto_active_effects.lua should consume bond route tags')
    assert_contains(auto_active_effects_content, 'add_buff', 'auto_active_effects.lua should apply buff-based control/debuff hooks')
    assert_not_contains(auto_active_effects_content, 'local is_bond_active = env.is_bond_active', 'auto_active_effects.lua should not depend on env.is_bond_active anymore')
    assert_contains(auto_active_effects_content, 'stun = 117', 'auto_active_effects.lua should use fixed stun modifier key to avoid load-time string conversion crashes')
    assert_not_contains(auto_active_effects_content, "str_to_modifier_key and str_to_modifier_key('", 'auto_active_effects.lua should not resolve modifier keys from localized names during module create')
    assert_not_contains(boot_content, '  is_bond_active = is_bond_active,', 'boot.lua should not inject env.is_bond_active into attack_skills anymore')
    assert_contains(boot_content, 'str_to_modifier_key', 'boot.lua should wire modifier key lookup for auto effects')
    assert_contains(auto_active_effect_defs_content, "modifier_key = 201365014", 'auto_active_effect defs should bind fighting spirit debuff resource id')
    assert FIGHTING_SPIRIT_MODIFIER.exists(), 'fighting spirit modifier resource should exist'
    assert_contains(rewards_content, 'best_with_tags', 'rewards.lua should read best_with_tags for treasure weighting')

    print('runtime bonds chain smoke ok')


if __name__ == '__main__':
    main()

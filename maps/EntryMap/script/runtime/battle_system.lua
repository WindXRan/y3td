-- battle_system.lua — 战场系统统一入口
-- 合并了 battlefield, auto_active_effects
-- 提供统一的战场系统 API

local BattleSystem = {}

local battlefield = require 'runtime.battlefield'
local auto_active_effects = require 'runtime.auto_active_effects'

BattleSystem.battlefield = battlefield
BattleSystem.auto_effects = auto_active_effects

-- 从 battlefield 转发
BattleSystem.update = battlefield.update
BattleSystem.force_spawn_boss = battlefield.force_spawn_boss
BattleSystem.execute_enemy = battlefield.execute_enemy
BattleSystem.get_current_wave = battlefield.get_current_wave
BattleSystem.get_boss_name = battlefield.get_boss_name
BattleSystem.spawn_enemy = battlefield.spawn_enemy
BattleSystem.create_hero = battlefield.create_hero
BattleSystem.is_active_enemy = battlefield.is_active_enemy
BattleSystem.get_enemy_runtime_info = battlefield.get_enemy_runtime_info
BattleSystem.is_boss_runtime_enemy = battlefield.is_boss_runtime_enemy
BattleSystem.is_elite_runtime_enemy = battlefield.is_elite_runtime_enemy

-- 从 auto_active_effects 转发
BattleSystem.update_auto_effects = auto_active_effects.update
BattleSystem.force_trigger_effect = auto_active_effects.force_trigger_effect
BattleSystem.handle_basic_attack_cast = auto_active_effects.handle_basic_attack_cast
BattleSystem.handle_attack_skill_cast = auto_active_effects.handle_attack_skill_cast

return BattleSystem

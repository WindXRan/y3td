--[[
  boot.lua — 运行时入口及总协调
  职责：创建 STATE、初始化全局、加载子系统、注册事件、返回 RuntimeEntry
  加载顺序原则：先数据表 → 工具模块 → 核心状态 → 业务系统（按依赖排序）
  所有业务系统模块均已自初始化（require 时自动设置 _G.xxx），无需 create() 调用
--]]

-- 数据表和配置（无运行时依赖，可最先加载）
local CONFIG = require 'config.entry_config'
local AttackSkillObjects = require 'data.tables.skill.attack_skills'
_G.AttackSkillObjects = AttackSkillObjects

-- 工具模块（无 _G 依赖，纯函数/工厂）
local GearUpgrades = require 'runtime.gear_upgrades'
local BootCore = require 'runtime.boot_core'
local BootCombat = require 'runtime.boot_combat'
local BootHelpers = require 'runtime.boot_helpers'
local BootUIEnhancements = require 'runtime.boot_ui_enhancements'
local EventBus = require 'runtime.event_bus'
local RuntimeEntry = {}
local projectile_override_hook_installed = false
local helper_signals_started = false

-- 前向声明
local STATE
local hero_attr_system
local reward_system
local attr_choice_system
local audio_system

local trace_boot = BootHelpers.trace_boot

local function ensure_helper_signals()
  if helper_signals_started or not y3.game.is_debug_mode() then
    return
  end

  helper_signals_started = true

  y3.ltimer.wait(1, function()
    print('[Y3_HELPER_READY]')
  end)

  y3.ltimer.loop(5, function()
    print('[HEARTBEAT]')
  end)
end
_G.ensure_helper_signals = ensure_helper_signals

trace_boot('chunk loaded')

-- 阶段1：核心状态初始化 — 创建 STATE、设置 _G 全局
-- 此后的 require 可安全读取 _G.STATE / _G.CONFIG
local boot_core = BootCore.create({
  AttackSkillObjects = AttackSkillObjects,
})

local ATTACK_SKILL_DEFS = boot_core.ATTACK_SKILL_DEFS
local ATTACK_SKILL_BLUEPRINTS = boot_core.ATTACK_SKILL_BLUEPRINTS
local ATTACK_SKILL_SLOT_COUNT = boot_core.ATTACK_SKILL_SLOT_COUNT
local SkillRuntime = boot_core.SkillRuntime
local create_attack_skill_instance = boot_core.create_attack_skill_instance
_G.create_attack_skill_instance = create_attack_skill_instance
local SkillState = boot_core.SkillState

STATE = boot_core.create_initial_state()
STATE.effect_debug_runtime = nil
STATE.fixed_camera_enabled = true
_G.CONFIG = CONFIG
_G.STATE = STATE
_G.SkillRuntime = SkillRuntime
_G.SkillState = SkillState
_G.ATTACK_SKILL_DEFS = ATTACK_SKILL_DEFS
_G.ATTACK_SKILL_BLUEPRINTS = ATTACK_SKILL_BLUEPRINTS
_G.ATTACK_SKILL_SLOT_COUNT = ATTACK_SKILL_SLOT_COUNT

-- Buff 系统（使用 snake_case 统一导出）
local buff_system = require 'runtime.buff_system'
_G.buff_system_tick = buff_system.tick

local function install_projectile_override_hook()
  if projectile_override_hook_installed then
    return
  end
  if not y3 or not y3.projectile or type(y3.projectile.create) ~= 'function' then
    return
  end
  projectile_create_original = y3.projectile.create
  y3.projectile.create = function(args, ...)
    local forced_key = tonumber(STATE and STATE.debug_force_projectile_key) or 0
    if forced_key > 0 and type(args) == 'table' then
      local copied = {}
      for k, v in pairs(args) do
        if k ~= 'skip_projectile_override' then
          copied[k] = v
        end
      end
      if args.skip_projectile_override ~= true then
        copied.key = math.floor(forced_key)
      end
      args = copied
    end
    return projectile_create_original(args, ...)
  end
  projectile_override_hook_installed = true
end

install_projectile_override_hook()

-- 阶段2：基础能力 — Buff、投射物校验、玩家工具函数
local ProjectileNameGuard = require 'runtime.projectile_name_guard'
ProjectileNameGuard.validate({
  y3 = y3,
}, {
  134255250,
})

local function get_player()
  return BootHelpers.get_player()
end

local function get_enemy_player()
  return BootHelpers.get_enemy_player()
end

_G.get_player = get_player
_G.get_enemy_player = get_enemy_player

-- 工具函数（薄转发层，全部直接挂 _G，自初始化）
require 'runtime.boot_utils'

-- 运行时事件处理（message / heal_hero / handle_battle_finished / create_bond_env）
require 'runtime.boot_event'

BootCombat.set_heal_hero(_G.heal_hero)

-- 阶段3：RuntimeEntry API — 相机控制、UI 可见性、战斗结束回调
-- 这些方法在 RuntimeEntry 表上，返回给 entry_runtime.lua
function RuntimeEntry.has_valid_hero()
  return _G.STATE.hero and _G.STATE.hero.is_exist and _G.STATE.hero:is_exist()
end

-- 相机控制（提取到独立模块）
require 'runtime.boot_camera'
RuntimeEntry.apply_fixed_camera_mode = _G.apply_fixed_camera_mode
RuntimeEntry.sync_fixed_camera_mode = _G.sync_fixed_camera_mode
RuntimeEntry.toggle_fixed_camera = _G.toggle_fixed_camera

-- UI 显隐控制（提取到独立模块）
require 'runtime.boot_ui_phase'

-- 英雄属性系统（自初始化，require 时设置 _G.hero_attr_system）
local function sync_gear_runtime_effects(state, hero, config)
  return GearUpgrades.sync_runtime_bonuses(state, hero, config, hero_attr_system)
end
_G.sync_gear_runtime_effects = sync_gear_runtime_effects

-- 加载英雄属性模块
local hero_attr_module = require 'runtime.hero_attr_system'
hero_attr_system = _G.hero_attr_system

do
  local ratio = CONFIG
      and CONFIG.hero_progression
      and CONFIG.hero_progression.main_stat_attack_ratio
      or nil
  if hero_attr_module and hero_attr_module.set_main_stat_attack_ratio and ratio ~= nil then
    hero_attr_module.set_main_stat_attack_ratio(ratio)
  end
end

require 'runtime.hero_model'

local round_number = BootHelpers.round_number
local design_seconds = BootHelpers.design_seconds
_G.round_number = round_number
_G.design_seconds = design_seconds

RuntimeEntry.emit_skill_hit_feedback = BootCombat.emit_skill_hit_feedback

BootHelpers.set_get_bond_runtime_bonus(_G.get_bond_runtime_bonus)

local handle_bond_hero_pre_hurt = BootCombat.handle_bond_hero_pre_hurt
local trigger_td_skills_on_hit = BootCombat.trigger_td_skills_on_hit

-- 阶段5：核心玩法系统 — 升级、奖励、音频（自初始化）
-- 此时 STATE / hero_attr_system / audio_system 前向声明已就绪
require 'runtime.progression'
_G.get_hero_max_level = _G.progression_system.get_hero_max_level
_G.sync_hero_progression = _G.progression_system.sync_hero_progression
_G.sync_hero_progress_from_engine = _G.progression_system.sync_hero_progress_from_engine

require 'runtime.rewards'
reward_system = _G.reward_system

attr_choice_system = reward_system

require 'runtime.audio'
audio_system = _G.audio_system


-- 阶段6：回合选择系统（拆分为独立模块）
require 'runtime.round_choice'

EventBus.subscribe('wave_started', function(wave_index)
  if audio_system and audio_system.handle_wave_started then
    audio_system.handle_wave_started(wave_index)
  end
  if reward_system and reward_system.handle_wave_started then
    return reward_system.handle_wave_started(wave_index)
  end
end)

EventBus.subscribe('boss_spawned', function(boss_info)
  if audio_system and audio_system.handle_boss_spawned then
    audio_system.handle_boss_spawned(boss_info)
  end
  if reward_system and reward_system.handle_boss_spawned then
    return reward_system.handle_boss_spawned()
  end
end)

EventBus.subscribe('boss_warning', function(wave, remain)
  if audio_system and audio_system.handle_boss_warning then
    return audio_system.handle_boss_warning(wave, remain)
  end
  return nil
end)

EventBus.subscribe('challenge_started', function(instance)
  if audio_system and audio_system.handle_challenge_started then
    audio_system.handle_challenge_started(instance)
  end
  if reward_system and reward_system.handle_challenge_started then
    return reward_system.handle_challenge_started(instance)
  end
end)

EventBus.subscribe('challenge_finished', function(instance, is_success)
  if audio_system and audio_system.handle_challenge_finished then
    audio_system.handle_challenge_finished(instance, is_success)
  end
  if reward_system and reward_system.handle_challenge_finished then
    return reward_system.handle_challenge_finished(instance, is_success)
  end
end)

EventBus.subscribe('hero_be_hurt', function()
  if audio_system and audio_system.handle_hero_be_hurt then
    audio_system.handle_hero_be_hurt()
  end
  if reward_system and reward_system.handle_hero_be_hurt then
    return reward_system.handle_hero_be_hurt()
  end
end)

EventBus.subscribe('hero_damage', trigger_td_skills_on_hit)
EventBus.subscribe('formula_damage_override', BootCombat.apply_formula_damage_override)
EventBus.subscribe('hero_before_hurt', handle_bond_hero_pre_hurt)
EventBus.subscribe('hero_attr_changed', _G.snapshot_hero_attrs)
EventBus.subscribe('finish_game', _G.handle_battle_finished)

-- 阶段7：技能系统 — 伤害模板 → 技能框架 → 样本技能 → 生成技能 → 运行时
-- 所有技能模块自初始化，依赖 _G.STATE/_G.CONFIG 等全局
-- 加载顺序有严格依赖：框架 → 样本 → 生成（register_all） → 攻击技能运行时
require 'runtime.skill_damage_templates'
require 'runtime.skill_framework'
require 'runtime.sample_skills'
require 'runtime.generated_skills'
require 'runtime.attack_skills'


do
  local generated_api = _G.generated_skills_api
  local count, defs = generated_api.register_all()
  print('[boot] 批量注册技能完成: ' .. tostring(count) .. ' 个')
  if AttackSkillObjects and AttackSkillObjects.vfx_by_id then
    for _, def in ipairs(defs) do
      if def.id and def.visual then
        if not AttackSkillObjects.vfx_by_id[def.id] then
          AttackSkillObjects.vfx_by_id[def.id] = {}
        end
        local visual = def.visual
        local vfx = AttackSkillObjects.vfx_by_id[def.id]
        if visual.cast then vfx.cast_particle = visual.cast end
        if visual.impact then vfx.impact_particle = visual.impact end
        if visual.hit then vfx.hit_particle = visual.hit end
        if visual.projectile_key then vfx.projectile_key = visual.projectile_key end
        if visual.projectile_height then vfx.projectile_height = visual.projectile_height end
        if visual.projectile_time then vfx.projectile_time = visual.projectile_time end
        if visual.warning then vfx.warning_particle = visual.warning end
      end
    end
  end
end

_G.ATTACK_SKILL_VFX = AttackSkillObjects and AttackSkillObjects.vfx_by_id

require 'runtime.auto_active_effects'
_G.force_trigger_effect = _G.auto_active_effects_system.force_trigger_effect

require 'runtime.effect_debug'

require 'runtime.battlefield'
_G.force_spawn_boss = _G.battlefield_system.force_spawn_boss
_G.execute_enemy = _G.battlefield_system.execute_enemy

BootUIEnhancements.set_apply_round_choice(_G.apply_round_choice)

-- 阶段8：UI 系统 — HUD、提示面板、武器提示、结算面板
-- runtime_hud 和 attr_tips_panel 使用 create() 初始化
local runtime_hud_module = require 'ui.runtime_hud'
local hud = runtime_hud_module.create()
_G.hud_system = hud

STATE.attr_tips_panel = require('runtime.attr_tips_panel').create()
if STATE.attr_tips_panel and STATE.attr_tips_panel.init then
  STATE.attr_tips_panel.init()
end

require 'runtime.runtime_ui_helpers'

_G.runtime_ui_helpers.__raw_refresh_choice_panel = _G.runtime_ui_helpers.refresh_choice_panel
_G.runtime_ui_helpers.refresh_choice_panel = BootUIEnhancements.refresh_choice_panel
_G.runtime_ui_helpers.install_panel_systems()

local growth_weapon_item_tip = require('ui.growth_weapon_item_tip').create()
_G.growth_weapon_item_tip = growth_weapon_item_tip

local result_panel = require('ui.result_panel').create()
_G.result_panel = result_panel

-- 阶段9：调试系统 — 调试动作、调试工具、战斗自动接受
require 'runtime.debug_actions'

require 'runtime.debug_tools'

-- 调试系统（使用统一的存根对象）
local gm_bond_effects_stub = {
  ensure_board = function() end,
  toggle_board = function() end,
  refresh_board = function() end,
}

require 'runtime.battle_auto_acceptance'

_G.gm_bond_effects = gm_bond_effects_stub
_G.attr_choice = attr_choice_system

-- 阶段10：Session/Runtime 设置 — 状态重置、事件注册、主循环、启动序列
-- boot_session_setup：处理 session 级别状态（跨战斗生命周期）
-- boot_runtime_setup：处理运行时事件注册和循环
_G.RuntimeEntry = RuntimeEntry
RuntimeEntry._session_bundle = require('runtime.boot_session_setup').create()

_G.reset_session_state = RuntimeEntry._session_bundle.reset_session_state
_G.is_battle_active = RuntimeEntry._session_bundle.is_battle_active

RuntimeEntry._runtime_bundle = require('runtime.boot_runtime_setup').create()

RuntimeEntry.register_runtime_events = RuntimeEntry._runtime_bundle.register_runtime_events
RuntimeEntry.start_runtime_loops = RuntimeEntry._runtime_bundle.start_runtime_loops
RuntimeEntry.run_bootstrap_sequence = RuntimeEntry._runtime_bundle.run_bootstrap_sequence

function RuntimeEntry.bootstrap()
  RuntimeEntry.run_bootstrap_sequence()
end

_G.RuntimeEntry = RuntimeEntry
return RuntimeEntry

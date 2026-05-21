--[[
  boot.lua — 运行时入口及总协调
  职责：创建 STATE、初始化全局、加载子系统、注册事件、返回 RuntimeEntry
  加载顺序原则：先数据表 → 工具模块 → 核心状态 → 业务系统（按依赖排序）

  全局命名空间规范：
  - _G.STATE / _G.CONFIG：核心状态和配置
  - _G.SYSTEM：统一的系统服务定位器
  - 工具函数通过模块导出（如 AreaUtils, BattleUtils 等）

  模块加载编号体系（详见 docs/总册/模块加载顺序方案.md）：
  1xx — 基础数据    2xx — 工具模块      3xx — 核心状态与Buff
  4xx — 英雄系统    5xx — 核心玩法      6xx — 战斗系统
  7xx — UI系统      8xx — 调试系统      9xx — 局外系统

  已解决的隐式依赖：
  ✅ D2: boot_helpers 已合并到 boot_utils，不再独立存在
--]]

-- ============================================================
-- [1xx] 阶段1：基础数据 — 数据表和配置（无运行时依赖，可最先加载）
-- 加载项: [110] config.entry_config
-- ============================================================
local CONFIG = require 'config.entry_config'                              -- [110]

-- 统一系统命名空间
_G.SYSTEM = _G.SYSTEM or {}

-- ============================================================
-- [2xx] 阶段2：工具模块 — 纯函数/工厂，部分有隐式依赖
-- ============================================================
local ok_gear, GearUpgrades = pcall(require, 'runtime.progression.gear_upgrades')
if not ok_gear then GearUpgrades = {} end
local BootCore      = require 'runtime.core.boot_core'                         -- [210]
local BootCombat    = require 'runtime.core.boot_combat'                       -- [230]
_G.BootCombat = BootCombat
-- Export BootCombat functions to _G for modules that access them directly
_G.get_current_hero = BootCombat.get_current_hero
_G.get_hero_point = BootCombat.get_hero_point
_G.get_hero_attack = BootCombat.get_hero_attack
_G.get_primary_target = BootCombat.get_primary_target
_G.launch_projectile_from_hero = BootCombat.launch_projectile_from_hero
_G.spawn_particle = BootCombat.spawn_particle
_G.is_active_enemy = BootCombat.is_active_enemy
_G.get_enemy_runtime_info = BootCombat.get_enemy_runtime_info
_G.is_boss_runtime_enemy = BootCombat.is_boss_runtime_enemy
_G.is_elite_runtime_enemy = BootCombat.is_elite_runtime_enemy
_G.get_hero_facing_towards = function(target)
  local hero = _G.STATE and _G.STATE.hero
  if not hero or not hero:is_exist() or not target then return 0 end
  local ok_hero, hero_x, hero_y = pcall(function() return hero:get_x(), hero:get_y() end)
  if not ok_hero then return 0 end
  local ok_target, tx, ty = pcall(function() return target:get_x(), target:get_y() end)
  if not ok_target then return 0 end
  return math.atan(ty - hero_y, tx - hero_x)
end
_G.award_rewards = function(reward, reason, is_silent)
  local rs = _G.reward_system
  if rs and rs.award_rewards then
    return rs.award_rewards(reward, reason, is_silent)
  end
end
-- ✅ D2 已消除: boot_helpers 已合并到 boot_utils，不再需要薄包装
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers                        -- [221]
local BootUIEnhancements = require 'runtime.core.boot_ui_enhancements'         -- [250]
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

-- ============================================================
-- [3xx] 阶段3：核心状态与Buff — 创建 STATE、设置 _G 全局
-- 此后所有模块可安全读取 _G.STATE / _G.CONFIG
-- ============================================================

-- 阶段1：核心状态初始化 — 创建 STATE、设置 _G 全局
-- 此后的 require 可安全读取 _G.STATE / _G.CONFIG
local boot_core = BootCore.create()

STATE = boot_core.create_initial_state()
STATE.fixed_camera_enabled = true
_G.CONFIG = CONFIG
_G.STATE = STATE

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

-- 阶段2：基础能力 — Buff、玩家工具函数

-- get_player 已在 boot_utils.lua 中定义，此处不再重复定义

local function get_enemy_player()
  return BootHelpers.get_enemy_player()
end

_G.get_enemy_player = get_enemy_player

-- 工具函数（薄转发层，全部直接挂 _G，自初始化）
require 'runtime.core.boot_utils'

-- 运行时事件处理（message / heal_hero）
-- 已合并到 runtime.boot_utils，不再单独 require boot_event

BootCombat.set_heal_hero(_G.heal_hero)

-- 阶段3：RuntimeEntry API — 相机控制、UI 可见性、战斗结束回调
-- 这些方法在 RuntimeEntry 表上，返回给 entry_runtime.lua
function RuntimeEntry.has_valid_hero()
  return _G.STATE.hero and _G.STATE.hero.is_exist and _G.STATE.hero:is_exist()
end

-- 相机控制和 UI 显隐已在 boot_utils 中实现
RuntimeEntry.apply_fixed_camera_mode = _G.apply_fixed_camera_mode
RuntimeEntry.sync_fixed_camera_mode = _G.sync_fixed_camera_mode
RuntimeEntry.toggle_fixed_camera = _G.toggle_fixed_camera

-- ============================================================
-- [4xx] 阶段4：英雄系统
-- ⚠ D9: hero_model:10 在模块顶层读取 _G.STATE，必须在 STATE 创建之后
-- ============================================================

-- 英雄属性系统（已禁用，使用编辑器自带属性系统）
_G.hero_attr_system = {
  get_attr = function(unit, name)
    if not unit or not unit.get_attr then return 0 end
    local v = unit:get_attr(name)
    return tonumber(v) or 0
  end,
  add_attr = function() end,
  set_attr = function() end,
  init_hero_attrs = function() end,
  rebuild_derived_attrs = function() end,
  snapshot = function() end,
  log_snapshot = function() end,
  get_attack_power = function(unit)
    if not unit or not unit.get_attr then return 0 end
    return tonumber(unit:get_attr('攻击')) or 0
  end,
}
_G.SYSTEM.hero_attr = _G.hero_attr_system
local hero_attr_system = _G.hero_attr_system

pcall(require, 'runtime.heroes.hero_model')
_G.SYSTEM.hero_model = _G.hero_model

local round_number = BootHelpers and BootHelpers.round_number
local design_seconds = BootHelpers and BootHelpers.design_seconds
_G.round_number = round_number
_G.design_seconds = design_seconds

-- ============================================================
-- [5xx] 阶段5：核心玩法 — 升级、奖励、音频、回合选择
-- ⚠ D4: progression 在模块顶层读取 _G.hero_attr_system
-- ⚠ D5: progression 惰性访问 _G.reward_system / _G.attr_choice_system
-- ============================================================
pcall(require, 'runtime.progression.progression')
if _G.progression_system then
  _G.get_hero_max_level = _G.progression_system.get_hero_max_level
  _G.sync_hero_progression = _G.progression_system.sync_hero_progression
  _G.sync_hero_progress_from_engine = _G.progression_system.sync_hero_progress_from_engine
  _G.SYSTEM.progression = _G.progression_system
end

pcall(require, 'runtime.progression.rewards')
reward_system = _G.reward_system
_G.SYSTEM.reward = reward_system

attr_choice_system = reward_system

pcall(require, 'runtime.audio.audio')
audio_system = _G.audio_system
_G.SYSTEM.audio = audio_system


-- [5xx] 回合选择系统（拆分为独立模块）
pcall(require, 'runtime.rounds.round_choice')

local AudioUtils = require 'runtime.audio.audio_utils'

_G.play_ui_click = function()
  return AudioUtils.play_click()
end

_G.play_ui_error = function()
  return AudioUtils.play_error()
end

_G.play_basic_attack_sound = function(source_unit)
  if audio_system and audio_system.play_basic_attack then
    return audio_system.play_basic_attack(source_unit)
  end
  return AudioUtils.play_basic_attack(source_unit)
end

_G.play_enemy_death_sound = function(unit, info, death_point)
  if audio_system and audio_system.play_enemy_death then
    return audio_system.play_enemy_death(unit, info and info.kind == 'boss', death_point)
  end
  return AudioUtils.play_enemy_death(unit, info and info.kind == 'boss', death_point)
end

y3.game:event_on('hero_attr_changed', function(trg)
  _G.AttrUtils.snapshot_hero_attrs()
end)

-- ============================================================
-- [6xx] 阶段6：战斗系统
-- ============================================================
-- [6xx] 战场系统
local ok_battle, BattleSystem = pcall(require, 'runtime.combat.battle_system')
if not ok_battle then
  print('[boot] ERROR loading battle_system: ' .. tostring(BattleSystem))
  BattleSystem = {}
end
_G.SYSTEM.battle = BattleSystem

_G.force_spawn_boss = BattleSystem.force_spawn_boss or function() end
_G.execute_enemy = BattleSystem.execute_enemy or function() end

-- [635] 攻击技能运行时
pcall(require, 'runtime.attack_skills')

-- [640] 技能处理器
pcall(require, 'runtime.combat.skill_handlers')

-- ============================================================
-- [7xx] 阶段7：UI 系统
-- ============================================================
local ok_ui, UISystem = pcall(require, 'runtime.ui.ui_system')
if not ok_ui then UISystem = {} end
_G.SYSTEM.ui = UISystem

local runtime_hud_module = UISystem.hud or {}
local hud = runtime_hud_module.create and runtime_hud_module.create() or {}
_G.hud_system = hud
_G.set_battle_hud_visible = function(visible)
  if hud and hud.set_battle_hud_visible then
    return hud.set_battle_hud_visible(visible)
  end
  return false
end

local ok_attr_tips, attr_tips_panel_mod = pcall(require, 'runtime.ui.attr_tips_panel')
if not ok_attr_tips then attr_tips_panel_mod = {} end
STATE.attr_tips_panel = attr_tips_panel_mod.create and attr_tips_panel_mod.create() or {}
if STATE.attr_tips_panel and STATE.attr_tips_panel.init then
  STATE.attr_tips_panel.init()
end

local runtime_ui_helpers = UISystem.helpers or {}
if runtime_ui_helpers.refresh_choice_panel then
  runtime_ui_helpers.__raw_refresh_choice_panel = runtime_ui_helpers.refresh_choice_panel
end
if BootUIEnhancements and BootUIEnhancements.refresh_choice_panel then
  runtime_ui_helpers.refresh_choice_panel = BootUIEnhancements.refresh_choice_panel
end
if runtime_ui_helpers.install_panel_systems then
  runtime_ui_helpers.install_panel_systems()
end

-- 导出 UI 函数到 _G，供 loops.lua / session_state 调用
_G.ensure_runtime_hud = function()
  return runtime_ui_helpers.ensure_runtime_hud and runtime_ui_helpers.ensure_runtime_hud()
end
_G.ensure_choice_panel = function()
  return runtime_ui_helpers.ensure_choice_panel and runtime_ui_helpers.ensure_choice_panel()
end
_G.refresh_runtime_hud = function()
  return runtime_ui_helpers.refresh_runtime_hud and runtime_ui_helpers.refresh_runtime_hud()
end
_G.refresh_choice_panel = function()
  return runtime_ui_helpers.refresh_choice_panel and runtime_ui_helpers.refresh_choice_panel()
end
_G.refresh_inventory_panel = function()
  return runtime_ui_helpers.refresh_inventory_panel and runtime_ui_helpers.refresh_inventory_panel()
end

-- ============================================================
-- [8xx] 阶段8：调试系统
-- ============================================================
local ok_debug, DebugSystem = pcall(require, 'runtime.debug.debug_system')
if not ok_debug then DebugSystem = {} end
_G.SYSTEM.debug = DebugSystem

local ok_battle_auto, battle_sys_for_auto = pcall(require, 'runtime.combat.battle_system')
if not ok_battle_auto then battle_sys_for_auto = {} end
_G.update_battle_auto_acceptance = (battle_sys_for_auto.auto_acceptance and battle_sys_for_auto.auto_acceptance.update) or function() end
_G.SYSTEM.battle_auto_acceptance = battle_sys_for_auto.auto_acceptance or {}
_G.attr_choice = attr_choice_system
_G.SYSTEM.attr_choice = attr_choice_system



-- loops.lua 所需的 _G.update_passive_resources 包装
_G.update_passive_resources = function(dt)
  local STATE = _G.STATE
  if not STATE or not _G.resource_system then return end
  if BootHelpers and BootHelpers.update_passive_resources then
    BootHelpers.update_passive_resources(dt, STATE, _G.resource_system)
  end
end

-- ============================================================
-- [9xx] 阶段9：局外系统
-- ⚠ D6: outgame_system.create 闭包访问 _G.audio_system, _G.hud_system
-- ⚠ D7: session_state.create 闭包访问多个系统
-- ============================================================
_G.RuntimeEntry = RuntimeEntry

local ok_outgame, OutgameSystem = pcall(require, 'runtime.outgame.outgame_system')
if not ok_outgame then OutgameSystem = {} end
_G.SYSTEM.outgame = OutgameSystem

_G.RuntimeEntry.validate_config = function()
  local battle = _G.SYSTEM.battle
  return battle and battle.battlefield and battle.battlefield.validate_config and battle.battlefield.validate_config()
end

-- [D7] 断言已移除，允许缺失模块继续运行
local session_state_system = nil
if OutgameSystem.session and OutgameSystem.session.create then
  session_state_system = OutgameSystem.session.create({
    create_hero = function()
      local battle = _G.SYSTEM.battle
      local bfs = battle and battle.battlefield
      local hero = bfs and bfs.create_hero(250)
      if _G.STATE.fixed_camera_enabled == true then
        _G.RuntimeEntry.sync_fixed_camera_mode()
      end
      if hero and _G.hero_attr_system and _G.CONFIG and _G.CONFIG.hero_init_stats then
        _G.hero_attr_system.init_hero_attrs(hero, _G.CONFIG.hero_init_stats)
      end
      
      -- 让英雄无法移动
      if hero and hero.set_move_speed then
        hero:set_move_speed(0)
        print('[HERO] 英雄已设置为无法移动')
      end
      
      if hero then
        hero:event('单位-死亡', function()
          print('[HERO DEATH] 英雄死亡')
          y3.game:event_notify('hero_death')
          if _G.STATE and _G.STATE.hero == hero then
            hero:revive()
            local max_hp = hero:get_attr('生命') or hero:get_attr('hp_max') or 1000
            if max_hp <= 0 then
              max_hp = 1000
            end
            hero:set_hp(max_hp)
            y3.game:event_notify('hero_revive')
            print('[HERO REVIVE] 英雄已复活，血量恢复至 ' .. max_hp)
          end
        end)
      end
      
      -- 在英雄前方创建测试靶子（无法移动的敌人）
      if hero and bfs then
        local ok, hero_pos = pcall(function() return hero:get_point() end)
        if ok and hero_pos and hero_pos.x then
          -- 在英雄前方1000单位处创建靶子
          local target_pos = y3.point.create(hero_pos.x + 1000, hero_pos.y, hero_pos.z)
          local enemy_player = y3.player(2)
          local target_unit = y3.unit.create({
            player = enemy_player,
            unit_id = 'monster_001',
            point = target_pos,
            angle = 180,
          })
          if target_unit then
            target_unit:set_move_speed(0)
            target_unit:set_max_hp(99999)
            target_unit:set_hp(99999)
            print('[TEST TARGET] 在英雄前方创建了测试靶子')
          end
        else
          print('[TEST TARGET] 无法获取英雄位置，跳过创建靶子')
        end
      end
      
      return hero
    end,
  })
end

local outgame_system = {}
if OutgameSystem.outgame and OutgameSystem.outgame.create then
  outgame_system = OutgameSystem.outgame.create({
    STATE = _G.STATE,
    CONFIG = _G.CONFIG,
    y3 = y3,
    message = _G.message,
    play_ui_click = function()
      local audio = _G.audio_system
      return audio and audio.play_ui_click and audio.play_ui_click() or nil
    end,
    ensure_music_loop = function()
      local audio = _G.audio_system
      return audio and audio.ensure_music_loop and audio.ensure_music_loop() or nil
    end,
    get_player = y3.player.get_main_player,
    set_battle_hud_visible = function(visible)
      local hud = _G.hud_system
      if hud and hud.set_battle_hud_visible then
        return hud.set_battle_hud_visible(visible)
      end
      return false
    end,
    stage_runtime = {
      get_current_stage_text = function()
        return '第1关'
      end,
      start_selected_stage = session_state_system and session_state_system.start_selected_stage,
    },
  })
end

_G.outgame_system = outgame_system
_G.session_state_system = session_state_system or {}

RuntimeEntry._session_bundle = {
  session_state_system = session_state_system or {},
  outgame_system = outgame_system,
  is_battle_active = session_state_system and session_state_system.is_battle_active or function() return false end,
  reset_battle_state = session_state_system and session_state_system.reset_battle_state or function() end,
  reset_session_state = session_state_system and session_state_system.reset_session_state or function() end,
}

_G.reset_session_state = RuntimeEntry._session_bundle.reset_session_state
_G.is_battle_active = RuntimeEntry._session_bundle.is_battle_active

local ok_boot_setup, boot_runtime_setup = pcall(require, 'runtime.core.boot_runtime_setup')
if not ok_boot_setup then boot_runtime_setup = {} end
RuntimeEntry._runtime_bundle = boot_runtime_setup and boot_runtime_setup.create() or {}

RuntimeEntry.register_runtime_events = RuntimeEntry._runtime_bundle.register_runtime_events or function() end
RuntimeEntry.start_runtime_loops = RuntimeEntry._runtime_bundle.start_runtime_loops or function() end
RuntimeEntry.run_bootstrap_sequence = RuntimeEntry._runtime_bundle.run_bootstrap_sequence or function() end

function RuntimeEntry.bootstrap()
  RuntimeEntry.run_bootstrap_sequence()
end

_G.sync_basic_attack_ability = function()
  local hero = _G.STATE and _G.STATE.hero
  if not hero or not hero:is_exist() then
    print('[sync_basic_attack_ability] Hero not found')
    return
  end
  
  print('[sync_basic_attack_ability] Setting up skill 100001001 as basic attack')
  local skill = hero:find_ability('英雄', 100001001)
  if skill then
    print('[sync_basic_attack_ability] Found skill 100001001, enabling autocast')
    skill:set_autocast(true)
  else
    print('[sync_basic_attack_ability] Skill 100001001 not found on hero')
  end
end

_G.RuntimeEntry = RuntimeEntry
return RuntimeEntry

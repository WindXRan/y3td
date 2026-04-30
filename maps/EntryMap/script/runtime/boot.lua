local CONFIG = require 'config.entry_config'
local BondSystem = require 'runtime.bonds_chain'
local AttackSkillObjects = require 'data.object_tables.attack_skills'
local SkillDamageTemplates = require 'runtime.skill_damage_templates'
local BondDrawConfig = require 'data.object_tables.bond_draw_config'
local BondNodeObjects = require 'data.object_tables.bond_nodes'
local QualityImageTable = require 'data.object_tables.quality_image_table'
local EvolutionObjects = require 'data.object_tables.marks'
local ProgressionSystem = require 'runtime.progression'
local BattlefieldSystem = require 'runtime.battlefield'
local DebugToolsSystem = require 'runtime.debug_tools'
local DebugActionsSystem = require 'runtime.debug_actions'
local GmBondEffectsSystem = require 'runtime.gm_bond_effects'
local OverviewModelSystem = require 'runtime.overview_model'
local BootHeroTujian = require 'runtime.boot_hero_tujian'
local BootEvents = require 'runtime.boot_events'
local BootLoops = require 'runtime.boot_loops'
local BootInput = require 'runtime.boot_input'
local BootSession = require 'runtime.boot_session'
local BattleEventPromptsFactory = require 'runtime.battle_event_prompts'
local RuntimeUIHelpers = require 'runtime.runtime_ui_helpers'
local RuntimeHudSystem = require 'ui.runtime_hud'
local OutgameSystem = require 'ui.outgame'
local AttackSkillsSystem = require 'runtime.attack_skills'
local AutoActiveEffectsSystem = require 'runtime.auto_active_effects'
local CannonSkill134258724System = require 'runtime.cannon_skill_134258724'
local BondSetEffectsSystem = require 'runtime.bond_set_effects'
local BondModifierEffects = require 'runtime.bond_modifier_effects'
local BondEffectsTestFramework = require 'runtime.bond_effects_test_framework'
local BattleAutoAcceptanceSystem = require 'runtime.battle_auto_acceptance'
local EffectDebugSystem = require 'runtime.effect_debug'
local BattleEventFeedSystem = require 'runtime.battle_event_feed'
local RewardSystem = require 'runtime.rewards'
local GearUpgrades = require 'runtime.gear_upgrades'
local AttrChoices = require 'runtime.attr_choices'
local HeroSelectionRangeSystem = require 'runtime.hero_selection_range'
local HeroAttrSystem = require 'runtime.hero_attr_system'
local HeroAttrDefs = require 'runtime.hero_attr_defs'
local HeroAttrPanel = require 'runtime.hero_attr_panel'
local SampleSkillsSystem = require 'runtime.sample_skills'
local ProjectileNameGuard = require 'runtime.projectile_name_guard'
local BootCore = require 'runtime.boot_core'
local BootDevCommands = require 'runtime.boot_dev_commands'
local BootBootstrapSequence = require 'runtime.boot_bootstrap_sequence'
local RuntimeEntry = {}
local projectile_create_original = nil
local projectile_override_hook_installed = false
local helper_signals_started = false
heal_hero = nil
progression_system = nil
battlefield_system = nil
debug_tools_system = nil
debug_actions_system = nil
gm_bond_effects_system = nil
runtime_hud_system = nil
choice_panel_system = nil
runtime_ui_helpers = nil
overview_model_system = nil
outgame_system = nil
session_state_system = nil
input_events_system = nil
runtime_loops_system = nil
hero_tujian_panel_system = nil
attack_skills_system = nil
auto_active_effects_system = nil
battle_auto_acceptance_system = nil
cannon_skill_134258724_system = nil
bond_set_effects_system = nil
local effect_debug_system = nil
reward_system = nil
attr_choice_system = nil
audio_system = nil
hero_selection_range_system = nil
sample_skills_system = nil
message = nil
ensure_round_choice_available = nil
get_enemies_in_range = nil
deal_skill_damage = nil
local hero_attr_system = HeroAttrSystem.create()
do
  local ratio = CONFIG
      and CONFIG.hero_progression
      and CONFIG.hero_progression.main_stat_attack_ratio
      or nil
  if HeroAttrSystem and HeroAttrSystem.set_main_stat_attack_ratio and ratio ~= nil then
    HeroAttrSystem.set_main_stat_attack_ratio(ratio)
  end
end

local function trace_boot(message)
  if log and log.info then
    log.info('[entry_runtime] ' .. tostring(message))
  end
end

-- 兼容旧热更闭包：部分历史逻辑会按全局名调用这两个函数。
if type(_G.collect_units_in_line) ~= 'function' then
  _G.collect_units_in_line = function(_, _, _, _, _, _, fallback_target)
    if fallback_target and fallback_target.is_exist and fallback_target:is_exist() then
      return { fallback_target }
    end
    return {}
  end
end
if type(_G.get_hero) ~= 'function' then
  _G.get_hero = function(env)
    local hero = env and env.STATE and env.STATE.hero
    if hero and hero.is_exist and hero:is_exist() then
      return hero
    end
    return nil
  end
end
if type(_G.get_hero_attr) ~= 'function' then
  _G.get_hero_attr = function(env, name)
    local hero = env and env.STATE and env.STATE.hero
    if hero and hero.is_exist and hero:is_exist() then
      local hero_attr_system = env and env.hero_attr_system
      if hero_attr_system and hero_attr_system.get_attr then
        return tonumber(hero_attr_system.get_attr(hero, name)) or 0
      end
      if hero.get_attr then
        return tonumber(hero:get_attr(name)) or 0
      end
    end
    return 0
  end
end

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

trace_boot('chunk loaded')

local boot_core = BootCore.create({
  AttackSkillObjects = AttackSkillObjects,
})

local ATTACK_SKILL_DEFS = boot_core.ATTACK_SKILL_DEFS
local ATTACK_SKILL_BLUEPRINTS = boot_core.ATTACK_SKILL_BLUEPRINTS
local ATTACK_SKILL_SLOT_COUNT = boot_core.ATTACK_SKILL_SLOT_COUNT
local create_skill_runtime = boot_core.create_skill_runtime
local create_attack_skill_instance = boot_core.create_attack_skill_instance
local create_attack_skill_state = boot_core.create_attack_skill_state
local STATE

local BOND_ROUTE_META_BY_TAG = {}

for _, node_def in ipairs(BondNodeObjects.list or {}) do
  for _, tag in ipairs(node_def.route_tags or {}) do
    if tag and tag ~= '' and not BOND_ROUTE_META_BY_TAG[tag] then
      BOND_ROUTE_META_BY_TAG[tag] = {
        icon = node_def.icon,
        title = node_def.display_name,
        tip_text = node_def.desc and (node_def.desc.advanced or node_def.desc.single) or nil,
      }
    end
  end
end

local function safe_get_unit_icon(unit_key)
  if not unit_key or not y3 or not y3.unit or not y3.unit.get_icon_by_key then
    return nil
  end
  local ok, icon = pcall(y3.unit.get_icon_by_key, unit_key)
  if ok then
    return icon
  end
  return nil
end

local function safe_get_buff_icon(buff_key)
  if not buff_key or not y3 or not y3.buff or not y3.buff.get_icon_by_key then
    return nil
  end
  local ok, icon = pcall(y3.buff.get_icon_by_key, buff_key)
  if ok then
    return icon
  end
  return nil
end

local function safe_get_buff_name(buff_key)
  if not buff_key or not y3 or not y3.buff or not y3.buff.get_name_by_key then
    return nil
  end
  local ok, name = pcall(y3.buff.get_name_by_key, buff_key)
  if ok then
    return name
  end
  return nil
end

local function has_valid_icon(icon)
  if icon == nil then
    return false
  end
  local n = tonumber(icon)
  if n ~= nil then
    return n ~= 0
  end
  return true
end

local function build_bottom_status_effect_entry(effect_def, snapshot)
  if not effect_def or not snapshot or snapshot.active ~= true then
    return nil
  end

  local icon
  local title
  local lines = {}

  if effect_def.source_type == 'bond' then
    local meta = BOND_ROUTE_META_BY_TAG[effect_def.source_id] or {}
    icon = meta.icon
    title = meta.title
    if meta.tip_text and meta.tip_text ~= '' then
      lines[#lines + 1] = tostring(meta.tip_text)
    end
  elseif effect_def.source_type == 'mark' then
    local mark_def = EvolutionObjects.by_id and EvolutionObjects.by_id[effect_def.source_id] or nil
    icon = mark_def and safe_get_unit_icon(mark_def.hero_unit_id) or nil
    title = mark_def and mark_def.name or nil
    if mark_def and mark_def.summary and mark_def.summary ~= '' then
      lines[#lines + 1] = tostring(mark_def.summary)
    end
  end

  if not icon then
    icon = safe_get_buff_icon(effect_def.modifier_key)
  end
  if not title or title == '' then
    title = safe_get_buff_name(effect_def.modifier_key) or effect_def.id or '魔法效果'
  end

  local cooldown = tonumber(snapshot.cooldown) or 0
  if cooldown > 0 then
    lines[#lines + 1] = string.format('冷却中：%.1fs', cooldown)
  end
  local counter = tonumber(snapshot.counter) or 0
  if counter > 0 then
    lines[#lines + 1] = string.format('层数：%d', math.floor(counter + 0.5))
  end
  if #lines == 0 then
    lines[#lines + 1] = '当前已激活。'
  end

  return {
    id = tostring(effect_def.id or title or 'status_effect'),
    icon = icon,
    modifier_key = tonumber(effect_def.modifier_key) or nil,
    tip_title = tostring(title or '魔法效果'),
    tip_text = table.concat(lines, '\n'),
  }
end

local function build_runtime_bond_status_entries(limit, taken_modifier_keys)
  local entries = {}
  limit = math.max(0, tonumber(limit) or 0)
  if limit <= 0 or not STATE or not STATE.bond_runtime then
    return entries
  end
  local status_map = STATE.bond_runtime.modifier_runtime_status
  if type(status_map) ~= 'table' then
    return entries
  end

  for status_id, runtime_entry in pairs(status_map) do
    if #entries >= limit then
      break
    end
    local buff = runtime_entry and runtime_entry.buff or nil
    if buff and buff.is_exist and buff:is_exist() and buff.get_key then
      local modifier_key = tonumber(buff:get_key()) or 0
      if modifier_key > 0 and not (taken_modifier_keys and taken_modifier_keys[modifier_key]) then
        local icon = safe_get_buff_icon(modifier_key)
        if has_valid_icon(icon) then
          local title = (buff.get_name and buff:get_name()) or ''
          if title == '' then
            title = safe_get_buff_name(modifier_key) or tostring(status_id or modifier_key)
          end
          local lines = {}
          local desc = (buff.get_description and buff:get_description()) or ''
          if desc ~= '' then
            lines[#lines + 1] = tostring(desc)
          end
          local stack = (buff.get_stack and tonumber(buff:get_stack())) or 0
          if stack > 1 then
            lines[#lines + 1] = string.format('层数：%d', math.floor(stack + 0.5))
          end
          local left_time = (buff.get_time and tonumber(buff:get_time())) or 0
          if left_time > 0 and left_time < 86400 then
            lines[#lines + 1] = string.format('持续：%.1fs', left_time)
          end
          if #lines == 0 then
            lines[#lines + 1] = '当前已激活。'
          end
          entries[#entries + 1] = {
            id = string.format('bond_runtime_%s', tostring(status_id or modifier_key)),
            icon = icon,
            modifier_key = modifier_key,
            tip_title = tostring(title),
            tip_text = table.concat(lines, '\n'),
          }
        end
      end
    end
  end

  return entries
end

local function build_hero_buff_status_entries(limit, taken_modifier_keys)
  local entries = {}
  limit = math.max(0, tonumber(limit) or 0)
  if limit <= 0 or not STATE or not STATE.hero then
    return entries
  end
  local hero = STATE.hero
  if not (hero and hero.is_exist and hero:is_exist() and hero.get_buffs) then
    return entries
  end

  local ok, buff_list = pcall(hero.get_buffs, hero)
  if not ok or type(buff_list) ~= 'table' then
    return entries
  end

  local grouped = {}
  local ordered_keys = {}
  for _, buff in ipairs(buff_list) do
    if buff and buff.is_exist and buff:is_exist() and buff.get_key then
      local modifier_key = tonumber(buff:get_key()) or 0
      if modifier_key > 0 and not (taken_modifier_keys and taken_modifier_keys[modifier_key]) then
        local icon_visible = true
        if buff.is_icon_visible then
          local ok_visible, visible = pcall(buff.is_icon_visible, buff)
          if ok_visible then
            icon_visible = visible == true
          end
        end
        local icon = safe_get_buff_icon(modifier_key)
        if icon_visible and has_valid_icon(icon) then
          local group = grouped[modifier_key]
          if not group then
            local title = (buff.get_name and buff:get_name()) or ''
            if title == '' then
              title = safe_get_buff_name(modifier_key) or tostring(modifier_key)
            end
            local desc = (buff.get_description and buff:get_description()) or ''
            group = {
              key = modifier_key,
              icon = icon,
              title = tostring(title),
              desc = tostring(desc or ''),
              max_stack = 0,
              max_time = 0,
            }
            grouped[modifier_key] = group
            ordered_keys[#ordered_keys + 1] = modifier_key
          end
          local stack = (buff.get_stack and tonumber(buff:get_stack())) or 0
          if stack > group.max_stack then
            group.max_stack = stack
          end
          local left_time = (buff.get_time and tonumber(buff:get_time())) or 0
          if left_time > group.max_time then
            group.max_time = left_time
          end
        end
      end
    end
  end

  for _, modifier_key in ipairs(ordered_keys) do
    if #entries >= limit then
      break
    end
    local group = grouped[modifier_key]
    if group then
      local lines = {}
      if group.desc ~= '' then
        lines[#lines + 1] = group.desc
      end
      if group.max_stack > 1 then
        lines[#lines + 1] = string.format('层数：%d', math.floor(group.max_stack + 0.5))
      end
      if group.max_time > 0 and group.max_time < 86400 then
        lines[#lines + 1] = string.format('持续：%.1fs', group.max_time)
      end
      if #lines == 0 then
        lines[#lines + 1] = '当前已激活。'
      end
      entries[#entries + 1] = {
        id = string.format('hero_buff_%d', modifier_key),
        icon = group.icon,
        modifier_key = modifier_key,
        tip_title = group.title,
        tip_text = table.concat(lines, '\n'),
      }
    end
  end

  return entries
end

local function get_bottom_status_effect_entries(max_slots)
  local entries = {}
  local limit = math.max(0, tonumber(max_slots) or 5)
  if limit == 0 then
    return entries
  end

  local taken_modifier_keys = {}
  local function push_entry(entry)
    if not entry or #entries >= limit then
      return
    end
    entries[#entries + 1] = entry
    local modifier_key = tonumber(entry.modifier_key) or 0
    if modifier_key > 0 then
      taken_modifier_keys[modifier_key] = true
    end
  end

  if #entries < limit then
    for _, entry in ipairs(build_runtime_bond_status_entries(limit - #entries, taken_modifier_keys)) do
      push_entry(entry)
      if #entries >= limit then
        break
      end
    end
  end

  if #entries < limit then
    for _, entry in ipairs(build_hero_buff_status_entries(limit - #entries, taken_modifier_keys)) do
      push_entry(entry)
      if #entries >= limit then
        break
      end
    end
  end

  if #entries < limit
      and auto_active_effects_system
      and auto_active_effects_system.get_effect_defs
      and auto_active_effects_system.get_effect_runtime_snapshot then
    for _, effect_def in ipairs(auto_active_effects_system.get_effect_defs() or {}) do
      if #entries >= limit then
        break
      end
      local snapshot = auto_active_effects_system.get_effect_runtime_snapshot(effect_def.id)
      push_entry(build_bottom_status_effect_entry(effect_def, snapshot))
    end
  end

  return entries
end

local function resolve_damage_meta(damage)
  local function normalize_damage_type(raw)
    local value = tostring(raw or '')
    if value == '物理' then
      return '物理'
    end
    if value == '法术' or value == '魔法' then
      return '法术'
    end
    if value == '真实' then
      return '真实'
    end
    return '法术'
  end

  if type(damage) == 'table' then
    local resolved_damage_type = normalize_damage_type(damage.damage_type)
    return {
      damage_type = resolved_damage_type,
      damage_form = damage.damage_form or (resolved_damage_type == '物理' and 'weapon' or 'spell'),
      -- 五行伤害已移除：统一按非元素伤害处理。
      element = 'none',
      damage_label = resolved_damage_type == '物理' and '兵刃伤害' or '术法伤害',
    }
  end

  local legacy_damage_type = normalize_damage_type(damage)
  return {
    damage_type = legacy_damage_type,
    damage_form = legacy_damage_type == '物理' and 'weapon' or 'spell',
    element = 'none',
    damage_label = legacy_damage_type == '物理' and '兵刃伤害' or '术法伤害',
  }
end

local function create_bond_runtime()
  return BondSystem.create_runtime()
end

local function create_battle_event_feed_runtime()
  return BattleEventFeedSystem.create_runtime()
end

local function create_effect_debug_runtime()
  return EffectDebugSystem.create_runtime()
end

STATE = boot_core.create_initial_state()
STATE.effect_debug_runtime = nil
STATE.fixed_camera_enabled = true

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

ProjectileNameGuard.validate({
  y3 = y3,
}, {
  134255250,
})

local function get_player()
  return y3.player(CONFIG.player_id)
end

local function get_enemy_player()
  return y3.player(CONFIG.enemy_player_id)
end

function RuntimeEntry.has_valid_hero()
  return STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist()
end

function RuntimeEntry.apply_fixed_camera_mode(enabled)
  local player = get_player()
  if not player or not y3.camera then
    return false
  end

  if enabled == true then
    if not RuntimeEntry.has_valid_hero() then
      return false
    end
    if y3.camera.set_tps_follow_unit then
      y3.camera.set_tps_follow_unit(player, STATE.hero, 1, 0, -60, 0, 0, 220, 1800)
    elseif y3.camera.set_camera_follow_unit then
      y3.camera.set_camera_follow_unit(player, STATE.hero, 0, 0, 220)
    end
    if y3.camera.disable_camera_move then
      y3.camera.disable_camera_move(player)
    end
    if y3.camera.set_moving_with_mouse then
      y3.camera.set_moving_with_mouse(player, false)
    end
    return true
  end

  if y3.camera.cancel_tps_follow_unit then
    y3.camera.cancel_tps_follow_unit(player)
  end
  if y3.camera.cancel_camera_follow_unit then
    y3.camera.cancel_camera_follow_unit(player)
  end
  if y3.camera.enable_camera_move then
    y3.camera.enable_camera_move(player)
  end
  if y3.camera.set_moving_with_mouse then
    y3.camera.set_moving_with_mouse(player, true)
  end
  return true
end

function RuntimeEntry.sync_fixed_camera_mode()
  return RuntimeEntry.apply_fixed_camera_mode(STATE.fixed_camera_enabled == true)
end

function RuntimeEntry.toggle_fixed_camera()
  STATE.fixed_camera_enabled = not (STATE.fixed_camera_enabled == true)
  local ok = RuntimeEntry.sync_fixed_camera_mode()
  if message then
    if STATE.fixed_camera_enabled then
      message(ok and '已切换为固定视角（F12 可切换）。' or '已设为固定视角：等待英雄创建后生效。')
    else
      message('已切换为自由视角（F12 可切换）。')
    end
  end
  return STATE.fixed_camera_enabled
end

local function set_ui_root_visible(path, visible)
  local player = get_player()
  if not player or not y3 or not y3.ui or not y3.ui.get_ui then
    return false
  end
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui or (ui.is_removed and ui:is_removed()) then
    return false
  end
  if ui.set_visible then
    ui:set_visible(visible == true)
    return true
  end
  return false
end

local function enforce_runtime_ui_phase(is_battle)
  if is_battle == true then
    local hidden_in_battle = {
      'outgame',
      'ArchivePanel',
      'ArchivePageProfile',
      'ArchivePageEquipment',
      'ArchivePageTalent',
      'ArchivePageUniversal',
      'ArchivePageChest',
      'ArchivePagePool',
      'LoadingPanel',
      'LogoPanel',
      'win',
      'loss',
      'CommonTip',
      'SceneUI',
    }
    for _, path in ipairs(hidden_in_battle) do
      set_ui_root_visible(path, false)
    end
    return
  end

  local hidden_outside_battle = {
    'top',
    'BattleBottomHUD',
    'GameHUD',
    'Choice_Panel',
    'BondSwallowPanel',
    'CommonTip',
    'SceneUI',
    'LoadingPanel',
    'LogoPanel',
    'win',
    'loss',
  }
  for _, path in ipairs(hidden_outside_battle) do
    set_ui_root_visible(path, false)
  end
end

local function infer_battle_event_style(text)
  local content = tostring(text or '')
  if content == '' then
    return 'neutral'
  end
  if string.find(content, '获得', 1, true)
      or string.find(content, '奖励', 1, true)
      or string.find(content, '刷新次数', 1, true)
      or string.find(content, '金币 +', 1, true)
      or string.find(content, '木材 +', 1, true)
      or string.find(content, '经验 +', 1, true) then
    return 'reward'
  end
  if string.find(content, '开始', 1, true)
      or string.find(content, '进攻', 1, true)
      or string.find(content, '警告', 1, true)
      or string.find(content, '失败', 1, true)
      or string.find(content, '不足', 1, true) then
    return 'warning'
  end
  if string.find(content, '稀有', 1, true)
      or string.find(content, '史诗', 1, true)
      or string.find(content, '1星效果触发', 1, true) then
    return 'rare'
  end
  if string.find(content, '+1', 1, true)
      or string.find(content, '恢复', 1, true)
      or string.find(content, '升级', 1, true)
      or string.find(content, '解锁', 1, true) then
    return 'positive'
  end
  return 'neutral'
end

local BattleEventPrompts = BattleEventPromptsFactory.create({
  STATE = STATE,
  BattleEventFeedSystem = BattleEventFeedSystem,
  create_battle_event_feed_runtime = create_battle_event_feed_runtime,
  infer_battle_event_style = infer_battle_event_style,
  GearUpgrades = GearUpgrades,
  CONFIG = CONFIG,
  get_message_prompt_system = function()
    return STATE.message_prompt_system
  end,
  get_audio_system = function()
    return audio_system
  end,
  get_runtime_hud_system = function()
    return runtime_hud_system
  end,
  get_inventory_panel_system = function()
    return STATE.inventory_panel_system
  end,
  message = function(text)
    return message(text)
  end,
  ensure_round_choice_available = function(allowed_kind)
    return ensure_round_choice_available(allowed_kind)
  end,
  sync_gear_runtime_effects = function(state, hero, config)
    return GearUpgrades.sync_runtime_bonuses(state, hero, config, hero_attr_system)
  end,
})


message = function(text)
  if log and log.info then
    log.info('[entry_runtime] ' .. tostring(text))
  end
  if STATE.session_phase == 'battle' then
    BattleEventPrompts.push_battle_event(text)
    return
  end
  get_player():display_message(text)
end

local function make_point(data)
  return y3.point.create(data.x, data.y, data.z or 0)
end

local function round_number(value)
  return math.floor((value or 0) + 0.5)
end

local create_bond_env
local award_rewards
local show_mark_choices
local show_treasure_choices
local show_attack_skill_loadout
local emit_damage_debug_visual
local try_open_queued_treasure_round
local is_battle_active
local reset_battle_state
local reset_session_state
local set_battle_hud_visible
local mainline_task_system

progression_system = ProgressionSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  round_number = round_number,
  message = message,
  hero_attr_system = hero_attr_system,
  on_hero_level_up = function(level)
    if attr_choice_system and attr_choice_system.grant_diamond then
      attr_choice_system.grant_diamond(1, level)
    end
    if reward_system and reward_system.try_queue_evolution_node_for_level then
      reward_system.try_queue_evolution_node_for_level(level)
    end
  end,
})

attr_choice_system = AttrChoices.create({
  STATE = STATE,
  hero_attr_system = hero_attr_system,
  message = message,
})

local function sync_basic_attack_ability()
  return attack_skills_system.sync_basic_attack_ability()
end

local function setup_basic_attack_ability()
  return attack_skills_system.setup_basic_attack_ability()
end

local function set_attr_pack(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end

  for attr_name, value in pairs(attr_pack) do
    if value ~= nil then
      unit:set_attr(attr_name, value)
    end
  end
end

local function add_attr_pack(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end

  for attr_name, value in pairs(attr_pack) do
    if value ~= nil and value ~= 0 then
      unit:add_attr(attr_name, value)
    end
  end
end

local function add_hero_attr_pack(unit, attr_pack)
  if not unit or not attr_pack then
    return
  end

  for attr_name, value in pairs(attr_pack) do
    if value ~= nil and value ~= 0 then
      hero_attr_system.add_attr(unit, attr_name, value)
    end
  end
  hero_attr_system.rebuild_derived_attrs(unit)
end

local function snapshot_hero_attrs()
  if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
    return nil
  end
  return hero_attr_system.snapshot(STATE.hero, STATE)
end

local function build_runtime_attr_dialog_chunks()
  local snapshot = snapshot_hero_attrs()
  if snapshot and hero_attr_system and hero_attr_system.log_snapshot then
    hero_attr_system.log_snapshot(STATE.hero, 'show_runtime_attr_dialog', nil, STATE)
  end
  return HeroAttrPanel.build_chunks(snapshot, HeroAttrDefs, function(name)
    return hero_attr_system.get_attr(STATE.hero, name)
  end)
end

local function show_runtime_attr_dialog()
  local attr_tips_panel = STATE.attr_tips_panel_system
  if attr_tips_panel and attr_tips_panel.toggle then
    local visible = attr_tips_panel.toggle()
    if visible ~= nil then
      return visible
    end
  end
  if runtime_hud_system and runtime_hud_system.toggle_attr_panel then
    local visible = runtime_hud_system.toggle_attr_panel()
    if visible ~= nil then
      return visible
    end
  end
  local chunks = build_runtime_attr_dialog_chunks()
  for index, text in ipairs(chunks) do
    y3.ltimer.wait((index - 1) * 0.08, function()
      get_player():display_message(text)
    end)
  end
end

reward_system = RewardSystem.create({
  STATE = STATE,
  message = message,
  round_number = round_number,
  y3 = y3,
  hero_attr_system = hero_attr_system,
  add_attr_pack = add_hero_attr_pack,
  sync_basic_attack_ability = sync_basic_attack_ability,
  setup_basic_attack_ability = setup_basic_attack_ability,
  get_player = get_player,
  heal_hero = function(amount)
    return heal_hero(amount)
  end,
  collect_bond_route_tags = function()
    return BondSystem.collect_route_tags(STATE)
  end,
})

audio_system = nil

mainline_task_system = require('runtime.mainline_tasks').create({
  STATE = STATE,
  CONFIG = CONFIG,
  round_number = round_number,
  message = message,
  add_hero_attr_pack = add_hero_attr_pack,
  award_rewards = function(reward, source_text, silent)
    return award_rewards(reward, source_text, silent)
  end,
  queue_treasure_round = function(source_type, source_name)
    return reward_system.queue_treasure_round(source_type, source_name)
  end,
  start_mainline_task_challenge = function(task)
    return battlefield_system and battlefield_system.start_mainline_task_challenge and
        battlefield_system.start_mainline_task_challenge(task) or nil
  end,
})

show_mark_choices = function()
  return reward_system.show_evolution_choices()
end

show_treasure_choices = function()
  return reward_system.show_treasure_choices()
end

try_open_queued_treasure_round = function()
  return reward_system.try_process_reward_queue()
end

local function get_hero_progression_rules()
  return progression_system.get_hero_progression_rules()
end

local function get_resource_rules()
  return progression_system.get_resource_rules()
end

local function update_bond_effects(dt)
  BondSystem.update_effects(create_bond_env(), dt)
end

local function update_auto_active_effects(dt)
  if auto_active_effects_system then
    auto_active_effects_system.update(dt)
  end
  if STATE.hero_form_skills_system then
    STATE.hero_form_skills_system.update(dt)
  end
end

local function update_effect_debug(dt)
  if effect_debug_system then
    effect_debug_system.update(dt)
  end
end

local function update_enemy_statuses(dt)
  return attack_skills_system.update_enemy_statuses(dt)
end

local ReservedRuntimeApi = {}

function ReservedRuntimeApi.point_to_table(point)
  return debug_tools_system.point_to_table(point)
end

function ReservedRuntimeApi.format_point(point)
  return debug_tools_system.format_point(point)
end

local function design_seconds(seconds)
  if CONFIG.debug_time_scale <= 0 then
    return seconds
  end
  return seconds / CONFIG.debug_time_scale
end

local function get_area(area_id)
  return debug_tools_system.get_area(area_id)
end

local function random_point_in_area(area_id)
  local area = get_area(area_id)
  if not area then
    return STATE.defense_point
  end

  local x = math.random(area.x_min, area.x_max)
  local y = math.random(area.y_min, area.y_max)
  return y3.point.create(x, y, area.z or 0)
end

function ReservedRuntimeApi.get_area_size(area_id)
  return debug_tools_system.get_area_size(area_id)
end

local function get_hero_point()
  if not STATE.hero or not STATE.hero:is_exist() then
    return nil
  end
  return STATE.hero:get_point()
end

function ReservedRuntimeApi.update_point_config(point_key, point)
  return debug_tools_system.update_point_config(point_key, point)
end

function ReservedRuntimeApi.recenter_area(area_id, center_point, width, height, offset_x, offset_y)
  return debug_tools_system.recenter_area(area_id, center_point, width, height, offset_x, offset_y)
end

function ReservedRuntimeApi.dump_calibration_file()
  return debug_tools_system.dump_calibration_file()
end

function ReservedRuntimeApi.show_calibration_help()
  return debug_tools_system.show_calibration_help()
end

local function debug_message(text)
  return debug_tools_system.debug_message(text)
end

local function show_debug_hotkey_help()
  return debug_tools_system.show_debug_hotkey_help()
end

local register_dev_commands

function ReservedRuntimeApi.has_unit_data(unit_id)
  return battlefield_system.has_unit_data(unit_id)
end

local function is_active_enemy(unit)
  return battlefield_system.is_active_enemy(unit)
end

function RuntimeEntry.can_receive_skill_damage(target)
  if not target or not target.is_exist or not target:is_exist() then
    return false
  end
  if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and target == STATE.hero then
    return false
  end
  if is_active_enemy(target) then
    return true
  end
  if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and STATE.hero.is_enemy then
    local ok, is_enemy_to_hero = pcall(STATE.hero.is_enemy, STATE.hero, target)
    if ok and is_enemy_to_hero == true then
      return true
    end
  end
  return false
end

local function get_enemy_runtime_info(unit)
  return battlefield_system.get_enemy_runtime_info(unit)
end

local function is_boss_runtime_enemy(info)
  return battlefield_system.is_boss_runtime_enemy(info)
end

local function is_elite_runtime_enemy(info)
  return battlefield_system.is_elite_runtime_enemy(info)
end

local function get_bond_runtime_bonus(key)
  local mark_runtime = STATE.mark_runtime
  local mark_bonus = 0
  if mark_runtime and mark_runtime.applied and mark_runtime.applied.runtime then
    mark_bonus = mark_runtime.applied.runtime[key] or 0
  end
  return BondSystem.get_runtime_bonus(STATE, key) + mark_bonus
end

local function get_combat_bonus(key)
  return get_bond_runtime_bonus(key) + reward_system.get_treasure_runtime_bonus(key)
end

local function get_formula_damage_runtime()
  local runtime = STATE.formula_damage_runtime
  if not runtime then
    runtime = {
      by_target = setmetatable({}, { __mode = 'k' }),
    }
    STATE.formula_damage_runtime = runtime
  end
  if not runtime.by_target then
    runtime.by_target = setmetatable({}, { __mode = 'k' })
  end
  return runtime
end

local function get_runtime_seconds()
  if y3 and y3.game and y3.game.current_game_run_time then
    return y3.game.current_game_run_time()
  end
  return 0
end

local function reserve_formula_damage(target, amount, meta)
  amount = math.max(0, tonumber(amount) or 0)
  if amount <= 0 or not target or not is_active_enemy(target) then
    return false
  end

  local runtime = get_formula_damage_runtime()
  local queue = runtime.by_target[target]
  if not queue then
    queue = {}
    runtime.by_target[target] = queue
  end

  queue[#queue + 1] = {
    damage = amount,
    source = STATE.hero,
    created_at = get_runtime_seconds(),
    meta = meta,
  }

  while #queue > 8 do
    table.remove(queue, 1)
  end
  return true
end

local function consume_formula_damage(target, source)
  if not target or not is_active_enemy(target) then
    return nil
  end
  if source and STATE.hero and source ~= STATE.hero then
    return nil
  end

  local runtime = get_formula_damage_runtime()
  local queue = runtime.by_target[target]
  if not queue or #queue <= 0 then
    return nil
  end

  local now = get_runtime_seconds()
  while #queue > 0 do
    local item = table.remove(queue, 1)
    if item and (now <= 0 or (now - (item.created_at or now)) <= 2.0) then
      if not item.source or not source or item.source == source then
        if #queue <= 0 then
          runtime.by_target[target] = nil
        end
        return item.damage
      end
    end
  end

  runtime.by_target[target] = nil
  return nil
end

local function apply_formula_damage_override(data)
  local damage_instance = data and data.damage_instance or nil
  if not damage_instance or not damage_instance.set_damage then
    return false
  end

  local target = data.target_unit or data.unit
  local final_damage = consume_formula_damage(target, data.source_unit)
  if not final_damage or final_damage <= 0 then
    return false
  end

  local ok = pcall(function()
    damage_instance:set_damage(final_damage)
  end)
  return ok == true
end

create_bond_env = function()
  return {
    STATE = STATE,
    message = message,
    round_number = round_number,
    y3 = y3,
    hero_attr_system = hero_attr_system,
    heal_hero = heal_hero,
    sync_basic_attack_ability = sync_basic_attack_ability,
    is_active_enemy = is_active_enemy,
    get_enemy_runtime_info = get_enemy_runtime_info,
    is_boss_runtime_enemy = is_boss_runtime_enemy,
    is_elite_runtime_enemy = is_elite_runtime_enemy,
    get_enemies_in_range = get_enemies_in_range,
    deal_skill_damage = deal_skill_damage,
    emit_damage_debug = function(visual)
      emit_damage_debug_visual(visual, nil)
    end,
    reserve_formula_damage = reserve_formula_damage,
    basic_attack_damage_type = ATTACK_SKILL_DEFS.basic_attack.damage_type,
    get_player = get_player,
    report_auto_acceptance_event = function(payload)
      if battle_auto_acceptance_system and battle_auto_acceptance_system.record_event then
        battle_auto_acceptance_system.record_event(payload)
      end
    end,
  }
end

get_enemies_in_range = function(center, radius, except_unit, max_count)
  local result = {}
  local selector = y3.selector.create()
      :is_enemy(get_player())
      :in_range(center, radius)
      :sort_type('由近到远')

  if max_count and max_count > 0 then
    selector:count(max_count + (except_unit and 1 or 0))
  end

  local picked = selector:pick()

  for _, unit in ipairs(picked) do
    if unit ~= except_unit and is_active_enemy(unit) then
      result[#result + 1] = unit
    end
  end

  return result
end

local function get_ui_preferences()
  return STATE.ui_preferences or {}
end

local function is_damage_text_hidden()
  return get_ui_preferences().hide_damage_text == true
end

local function is_hit_effect_hidden()
  return get_ui_preferences().hide_hit_effects == true
end

local function resolve_runtime_text_type(text_type)
  if is_damage_text_hidden() then
    return nil
  end
  return text_type
end

local function resolve_damage_text_type(damage_form, visual)
  if visual and visual.text_type then
    return visual.text_type
  end

  if damage_form == 'weapon' then
    return 'physics'
  end

  return 'magic'
end

local function get_target_hp_ratio(target)
  if not target or not target:is_exist() then
    return 1
  end
  local max_hp = y3.helper.tonumber(target:get_attr('生命')) or y3.helper.tonumber(target:get_attr('最大生命')) or 0
  if max_hp <= 0 then
    return 1
  end
  return math.max(0, (target:get_hp() or 0) / max_hp)
end

local function get_unit_point_snapshot(unit)
  if not unit or not unit.is_exist or not unit:is_exist() then
    return nil
  end
  local point = unit:get_point()
  if not point or not point.move then
    return nil
  end
  return point:move()
end

local function get_unit_max_hp(unit)
  if not unit or not unit.is_exist or not unit:is_exist() then
    return 0
  end
  return y3.helper.tonumber(unit:get_attr('生命')) or y3.helper.tonumber(unit:get_attr('最大生命')) or 0
end

local function normalize_ratio(value)
  local number = y3.helper.tonumber(value) or 0
  if math.abs(number) > 1 then
    return number / 100
  end
  return number
end

local function get_hero_attr_value(name)
  if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
    return 0
  end
  local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name) or STATE.hero:get_attr(name)
  return y3.helper.tonumber(value) or 0
end

local function get_hero_attr_ratio(name)
  return normalize_ratio(get_hero_attr_value(name))
end

local function get_damage_bonus_multiplier(target, context)
  local multiplier = 1
  multiplier = multiplier * (1 + get_combat_bonus('all_damage_bonus'))

  if context and context.is_skill then
    multiplier = multiplier * (1 + get_combat_bonus('skill_damage_bonus'))
  end
  if context and context.is_basic_attack then
    multiplier = multiplier * (1 + get_combat_bonus('normal_attack_damage_bonus'))
  end

  local info = get_enemy_runtime_info(target)
  if is_boss_runtime_enemy(info) then
    multiplier = multiplier * (1 + get_combat_bonus('boss_damage_bonus'))
  end
  if is_elite_runtime_enemy(info) then
    multiplier = multiplier * (1 + get_combat_bonus('elite_damage_bonus'))
  end
  if info and info.kind == 'challenge' then
    multiplier = multiplier * (1 + get_combat_bonus('challenge_damage_bonus'))
  end

  local execute_threshold = get_combat_bonus('execute_threshold')
  if execute_threshold > 0 and get_target_hp_ratio(target) <= execute_threshold then
    multiplier = multiplier * (1 + get_combat_bonus('execute_damage_bonus'))
  end

  if info and info.status then
    local armor_break = info.status.armor_break
    if armor_break and (armor_break.stacks or 0) > 0 and (armor_break.ratio or 0) > 0 then
      multiplier = multiplier * (1 + armor_break.ratio * armor_break.stacks)
    end

    local shock = info.status.shock
    if shock and (shock.bonus or 0) > 0 then
      multiplier = multiplier * (1 + shock.bonus)
    end
  end

  return multiplier
end

local function try_trigger_hunter_first_hit(target)
  if STATE.basic_attack_bond_enabled ~= false then
    BondSystem.notify_basic_attack(create_bond_env(), target)
  end
  BondSystem.try_trigger_hunter_first_hit(create_bond_env(), target)
end

local function build_reward_with_bond_bonus(reward)
  return BondSystem.build_reward_with_bonus(create_bond_env(), reward)
end

local DAMAGE_AREA_DEBUG_EFFECT_ID = 101492
local DAMAGE_AREA_DEBUG_SCALE_BASE = 110
local DAMAGE_AREA_DEBUG_HEIGHT = 8
local DAMAGE_DEBUG_UID_WINDOW = 0.08

local function should_show_damage_area_debug()
  if STATE and STATE.debug_show_damage_area == true then
    return true
  end
  return y3 and y3.game and y3.game.is_debug_mode and y3.game.is_debug_mode() or false
end

local function show_damage_area_indicator(center, radius, duration)
  if not should_show_damage_area_debug() or not center or (tonumber(radius) or 0) <= 0 then
    return
  end
  local scale = math.max(0.6, (tonumber(radius) or 0) / DAMAGE_AREA_DEBUG_SCALE_BASE)
  local forced = tonumber(STATE and STATE.debug_force_projectile_key) or 0
  local key = forced > 0 and math.floor(forced) or 201392033
  pcall(y3.projectile.create, {
    key = key,
    target = center,
    socket = 'origin',
    owner = STATE and STATE.hero or nil,
    angle = 0,
    time = duration or 0.30,
    remove_immediately = true,
  })
end

local function get_damage_debug_time()
  if y3 and y3.game and y3.game.current_game_run_time then
    return tonumber(y3.game.current_game_run_time()) or 0
  end
  return os.clock and os.clock() or 0
end

local function should_emit_damage_debug_uid(uid)
  if not uid or uid == '' then
    return true
  end
  STATE.damage_debug_uid_time = STATE.damage_debug_uid_time or {}
  local now = get_damage_debug_time()
  local last = tonumber(STATE.damage_debug_uid_time[uid]) or -1
  if last >= 0 and (now - last) < DAMAGE_DEBUG_UID_WINDOW then
    return false
  end
  STATE.damage_debug_uid_time[uid] = now
  return true
end

local function get_target_point(unit)
  if not unit or not unit.get_point then
    return nil
  end
  local ok, point = pcall(function()
    return unit:get_point()
  end)
  if ok then
    return point
  end
  return nil
end

local function resolve_debug_point(anchor)
  if not anchor then
    return nil
  end
  if anchor.get_x and anchor.get_y then
    return anchor
  end
  if anchor.get_point then
    local ok, point = pcall(function()
      return anchor:get_point()
    end)
    if ok then
      return point
    end
  end
  return nil
end

local function show_damage_line_indicator(origin, impact, width, duration)
  if not should_show_damage_area_debug() then
    return
  end
  local origin_point = resolve_debug_point(origin)
  local impact_point = resolve_debug_point(impact)
  local line_width = math.max(50, tonumber(width) or 120)
  if not origin_point or not impact_point then
    show_damage_area_indicator(impact_point or origin_point, line_width, duration or 0.18)
    return
  end

  local distance = origin_point.get_distance_with and origin_point:get_distance_with(impact_point) or 0
  if distance <= 0 then
    show_damage_area_indicator(impact_point, line_width, duration or 0.18)
    return
  end
  local angle = origin_point.get_angle_with and origin_point:get_angle_with(impact_point) or 0
  local marker_step = math.max(130, math.min(320, line_width * 1.7))
  local marker_count = math.max(2, math.min(8, math.floor(distance / marker_step) + 1))

  for index = 0, marker_count, 1 do
    local travel = distance * (index / marker_count)
    local marker = nil
    if y3 and y3.point and y3.point.get_point_offset_vector then
      marker = y3.point.get_point_offset_vector(origin_point, angle, travel)
    end
    if not marker and y3 and y3.point and y3.point.create and origin_point.get_x and origin_point.get_y then
      local ox = origin_point:get_x()
      local oy = origin_point:get_y()
      local oz = origin_point.get_z and origin_point:get_z() or 0
      marker = y3.point.create(ox + math.cos(angle) * travel, oy + math.sin(angle) * travel, oz)
    end
    show_damage_area_indicator(marker, line_width, duration or 0.18)
  end
end

emit_damage_debug_visual = function(visual, fallback_target)
  if not visual or not visual.debug_kind then
    return
  end
  local debug_uid = tostring(visual.debug_uid or '')
  if visual.debug_kind == 'area' then
    local center = resolve_debug_point(visual.debug_center) or (fallback_target and get_target_point(fallback_target) or nil)
    local radius = math.max(50, tonumber(visual.debug_radius) or 70)
    local area_uid = debug_uid ~= '' and ('area:' .. debug_uid) or nil
    if should_emit_damage_debug_uid(area_uid) then
      show_damage_area_indicator(center, radius, tonumber(visual.debug_duration) or 0.20)
    end
  elseif visual.debug_kind == 'line' then
    local line_uid = debug_uid ~= '' and ('line:' .. debug_uid) or nil
    if should_emit_damage_debug_uid(line_uid) then
      show_damage_line_indicator(
        visual.debug_line_origin,
        visual.debug_line_impact,
        tonumber(visual.debug_line_width) or 120,
        tonumber(visual.debug_duration) or 0.20
      )
    end
  end
end

local function show_damage_debug_indicator(target, visual)
  local hit_radius = tonumber(visual and visual.debug_hit_radius)
  if not hit_radius or hit_radius <= 0 then
    hit_radius = (visual and visual.debug_kind) and 70 or (tonumber(visual and visual.debug_radius) or 70)
  end
  show_damage_area_indicator(get_target_point(target), hit_radius, 0.24)
  emit_damage_debug_visual(visual, target)
end

function RuntimeEntry.emit_skill_hit_feedback(target, final_damage, hp_before)
  if not target then
    return
  end
  local now = get_damage_debug_time()
  STATE.skill_hit_feedback = STATE.skill_hit_feedback or {
    combo = 0,
    combo_window_end = 0,
    next_prompt_time = 0,
    next_heavy_fx_time = 0,
  }
  local stat = STATE.skill_hit_feedback
  if now <= (stat.combo_window_end or 0) then
    stat.combo = (stat.combo or 0) + 1
  else
    stat.combo = 1
  end
  stat.combo_window_end = now + 0.45

  local killed = (tonumber(hp_before) or 0) > 0 and (tonumber(final_damage) or 0) >= (tonumber(hp_before) or 0)
  local heavy = (tonumber(final_damage) or 0) >= math.max(120, (tonumber(hp_before) or 0) * 0.35)
  if heavy and now >= (stat.next_heavy_fx_time or 0) then
    local hit_point = get_target_point(target)
    if hit_point then
      local forced = tonumber(STATE and STATE.debug_force_projectile_key) or 0
      local key = forced > 0 and math.floor(forced) or 201392033
      pcall(y3.projectile.create, {
        key = key,
        target = hit_point,
        socket = 'origin',
        owner = STATE and STATE.hero or nil,
        angle = 0,
        time = 0.08,
        remove_immediately = true,
      })
    end
    stat.next_heavy_fx_time = now + 0.12
  end

  if now < (stat.next_prompt_time or 0) then
    return
  end
  if killed then
    if BattleEventPrompts and BattleEventPrompts.push_battle_event then
      BattleEventPrompts.push_battle_event('斩杀!', 'good', 0.45)
    end
    stat.next_prompt_time = now + 0.28
    return
  end
  if (stat.combo or 0) >= 8 and ((stat.combo or 0) % 4 == 0) then
    if BattleEventPrompts and BattleEventPrompts.push_battle_event then
      BattleEventPrompts.push_battle_event(string.format('连击 x%d', stat.combo), 'normal', 0.45)
    end
    stat.next_prompt_time = now + 0.28
  end
end


local SKILL_DAMAGE_REENTRANT_GUARD_LIMIT = 96

deal_skill_damage = function(target, amount, damage, visual)
  local call_depth = (STATE.__skill_damage_call_depth or 0) + 1
  STATE.__skill_damage_call_depth = call_depth
  if call_depth > SKILL_DAMAGE_REENTRANT_GUARD_LIMIT then
    STATE.__skill_damage_guard_drop = (STATE.__skill_damage_guard_drop or 0) + 1
    STATE.__skill_damage_call_depth = call_depth - 1
    return
  end

  local ok, err = pcall(function()
    if not STATE.hero or not STATE.hero:is_exist() or not RuntimeEntry.can_receive_skill_damage(target) then
      return
    end

    local hit_effect_enabled = CONFIG.damage_hit_effect_enabled ~= false and not is_hit_effect_hidden()
    local damage_meta = resolve_damage_meta(damage)
    local target_multiplier = get_damage_bonus_multiplier(target, {
      is_skill = true,
    })
    local final_damage = hero_attr_system.compute_damage(STATE.hero, amount, damage_meta, {
      damage_kind = 'skill',
      target_multiplier = target_multiplier,
    })
    if final_damage <= 0 then
      return
    end
    show_damage_debug_indicator(target, visual)

    local hp_before = target.get_hp and target:get_hp() or 0
    reserve_formula_damage(target, final_damage, {
      source = 'skill',
      damage_meta = damage_meta,
    })
    STATE.hero:damage({
      target = target,
      damage = final_damage,
      type = damage_meta.damage_type or '法术',
      text_type = resolve_runtime_text_type(resolve_damage_text_type(damage_meta.damage_form, visual)),
      text_track = visual and visual.text_track or 934269508,
      particle = hit_effect_enabled and visual and visual.particle or nil,
      socket = hit_effect_enabled and visual and visual.socket or '',
      pos_socket = hit_effect_enabled and visual and visual.pos_socket or '',
      common_attack = false,
      no_miss = true,
    })
    RuntimeEntry.emit_skill_hit_feedback(target, final_damage, hp_before)

    if battle_auto_acceptance_system and battle_auto_acceptance_system.record_damage then
      local scope = visual and visual.metric_scope or nil
      local key = visual and visual.metric_key or nil
      if (not scope or scope == '') and type(damage) == 'table' then
        scope = 'attack_skill'
        key = tostring(damage.id or damage.name or damage.damage_label or 'unknown')
      elseif (not scope or scope == '') and type(damage) == 'string' then
        scope = 'damage_type'
        key = damage
      end
      battle_auto_acceptance_system.record_damage({
        scope = scope or 'unknown',
        key = key or 'unknown',
        hit = 1,
        damage = final_damage,
      })
    end

    if not (visual and visual.skip_hunter_first_hit) then
      try_trigger_hunter_first_hit(target)
    end
  end)

  STATE.__skill_damage_call_depth = call_depth - 1
  if not ok then
    error(err)
  end
end

local td_damage_api = SkillDamageTemplates.create({
  y3 = y3,
  deal_skill_damage = function(target, amount, damage_meta, visual)
    deal_skill_damage(target, amount, damage_meta, visual)
  end,
  emit_damage_debug = function(visual)
    emit_damage_debug_visual(visual, nil)
  end,
  get_enemies_in_range = get_enemies_in_range,
  is_active_enemy = is_active_enemy,
})

sample_skills_system = SampleSkillsSystem.create({
  STATE = STATE,
  y3 = y3,
  message = message,
  hero_attr_system = hero_attr_system,
  skill_damage_api = td_damage_api,
  get_enemies_in_range = get_enemies_in_range,
  is_active_enemy = is_active_enemy,
})

heal_hero = function(amount)
  if amount <= 0 or not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  local before = STATE.hero:get_hp()
  STATE.hero:add_hp(amount)
  if STATE.hero:get_hp() > before then
    message(string.format('急救生效，英雄生命恢复至 %.0f。', STATE.hero:get_hp()))
  end
end

award_rewards = function(reward, source_text, silent)
  local final_reward = reward_system.build_reward_with_treasure_bonus(reward)
  if not final_reward then
    return
  end

  if final_reward.gold and final_reward.gold > 0 then
    STATE.resources.gold = STATE.resources.gold + final_reward.gold
  end

  if final_reward.wood and final_reward.wood > 0 then
    STATE.resources.wood = STATE.resources.wood + final_reward.wood
  end

  if final_reward.exp and final_reward.exp > 0 then
    progression_system.grant_hero_exp(final_reward.exp)
  end

  if silent then
    return
  end
end

local function update_passive_resources(dt)
  local rules = get_resource_rules()
  local gold_per_sec = math.max(
    0,
    (rules.gold_per_sec or 0)
    + get_bond_runtime_bonus('gold_per_sec_bonus')
    + reward_system.get_treasure_passive_income('gold')
  )
  local wood_per_sec = math.max(
    0,
    (rules.wood_per_sec or 0)
    + get_bond_runtime_bonus('wood_per_sec_bonus')
    + reward_system.get_treasure_passive_income('wood')
  )
  if (gold_per_sec <= 0 and wood_per_sec <= 0) or not STATE.resources then
    return
  end

  local interval = math.max(0.05, CONFIG.debug_time_scale or 1.0)
  STATE.resource_income_elapsed = (STATE.resource_income_elapsed or 0) + dt

  while STATE.resource_income_elapsed >= interval do
    STATE.resource_income_elapsed = STATE.resource_income_elapsed - interval
    STATE.resources.gold = STATE.resources.gold + gold_per_sec
    STATE.resources.wood = STATE.resources.wood + wood_per_sec
  end
end

local function handle_bond_enemy_kill(info)
  BondSystem.handle_enemy_kill(create_bond_env(), info)
  if auto_active_effects_system then
    auto_active_effects_system.handle_enemy_kill(info)
  end
  if STATE.hero_form_skills_system then
    STATE.hero_form_skills_system.handle_enemy_kill(info)
  end
end

local function handle_bond_hero_pre_hurt(data)
  if data and STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() then
    local source = data.source_unit
    if source and source == STATE.hero then
      local damage_instance = data.damage_instance
      if damage_instance and damage_instance.set_damage then
        pcall(function()
          damage_instance:set_damage(0)
        end)
      end
      if STATE and STATE.debug_self_damage_guard == true then
        message('[DEBUG] 已拦截主角自伤。')
      end
      return
    end
  end
  BondSystem.notify_hero_pre_hurt(create_bond_env(), data)
end

local function get_current_wave()
  return battlefield_system.get_current_wave()
end

local function get_boss_name(wave)
  return battlefield_system.get_boss_name(wave)
end

local function show_runtime_status()
  if STATE.session_phase ~= 'battle' then
    local stage_name = STATE.current_stage_def and
        (STATE.current_stage_def.display_label or STATE.current_stage_def.display_name) or '未选择'
    local mode_name = STATE.current_mode_def and STATE.current_mode_def.display_name or '标准模式'
    message(string.format('当前处于局外选关阶段：%s %s。', stage_name, mode_name))
    return
  end

  local wave = get_current_wave()
  local wave_text = wave and wave.name or '未开始'
  local boss_text = '无'
  if STATE.active_wave then
    if STATE.active_wave.boss_spawned then
      boss_text = get_boss_name(STATE.active_wave.wave) .. ' 已登场'
    else
      local remain = math.max(0, STATE.active_wave.wave.boss_spawn_sec - STATE.active_wave.elapsed)
      boss_text = string.format('Boss倒计时 %.1f', remain)
    end
  end

  local challenge_count = 0
  for _ in pairs(STATE.active_challenges) do
    challenge_count = challenge_count + 1
  end

  local challenge_charge_text = ''
  if STATE.challenge_charge_map then
    local parts = {}
    for _, challenge_id in ipairs({ 'gold_trial', 'wood_trial', 'exp_trial' }) do
      local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
      if def then
        parts[#parts + 1] = string.format(
          '%s %d/%d',
          tostring(def.hotkey or challenge_id),
          tonumber(STATE.challenge_charge_map[challenge_id]) or 0,
          CONFIG.challenge_rules.max_charges or 0
        )
      end
    end
    challenge_charge_text = table.concat(parts, ' ')
  else
    challenge_charge_text = string.format('%d/%d', STATE.challenge_charges, CONFIG.challenge_rules.max_charges)
  end

  message(string.format(
    '状态：%s，%s，英雄 %s，敌人数 %d，金币 %d，木材 %d，挑战次数 %s，进行中挑战 %d，待领奖励 %d。',
    wave_text,
    boss_text,
    progression_system.get_hero_progress_text(),
    STATE.total_enemy_alive,
    STATE.resources.gold,
    STATE.resources.wood,
    challenge_charge_text,
    challenge_count,
    reward_system.get_reward_queue_count()
  ))
end

local function trigger_td_skills_on_hit(data)
  if STATE.game_finished or not data.is_normal_hit or data.source_unit ~= STATE.hero then
    return
  end

  local skill = STATE.skill_runtime
  local target = data.target_unit
  if not is_active_enemy(target) then
    return
  end
  local chain_center = get_unit_point_snapshot(target) or target
  local basic_attack_def = ATTACK_SKILL_DEFS.basic_attack or {
    damage_type = '物理',
    damage_form = 'weapon',
    element = 'none',
    damage_label = '兵刃伤害',
  }
  local basic_attack_vfx = AttackSkillObjects.vfx_by_id.basic_attack or {}
  local basic_chain_particle = basic_attack_vfx.chain_particle
      or basic_attack_vfx.impact_particle
  if CONFIG.damage_hit_effect_enabled == false or is_hit_effect_hidden() then
    basic_chain_particle = nil
  end

  if skill.normal_attack_bonus_ratio > 0 then
    td_damage_api.single(target, data.damage * skill.normal_attack_bonus_ratio, '物理', {
      text_type = 'physics',
    })
  end

  if skill.splash_ratio > 0 then
    td_damage_api.area(target, skill.splash_radius, data.damage * skill.splash_ratio, '物理', {
      except_unit = target,
      visual = {
        text_type = 'physics',
      },
    })
  end

  if skill.chain_bounces > 0 and skill.chain_chance > 0 and math.random() <= skill.chain_chance then
    td_damage_api.chain(
      get_enemies_in_range(chain_center, skill.chain_radius, target, skill.chain_bounces),
      data.damage * skill.chain_ratio,
      basic_attack_def,
      {
        visual = function()
          return {
            particle = basic_chain_particle,
          }
        end,
      }
    )
  end

  local bond_chain_bounces = math.max(0, round_number(
    get_bond_runtime_bonus('chain_bounces') + get_hero_attr_value('弹射次数')
  ))
  local bond_chain_ratio = 0.30 + math.max(0,
    normalize_ratio(get_bond_runtime_bonus('chain_ratio'))
    + get_hero_attr_ratio('弹射伤害')
  )
  if bond_chain_bounces > 0 and bond_chain_ratio > 0 then
    td_damage_api.chain(
      get_enemies_in_range(
        chain_center,
        math.max(skill.chain_radius or 0, 420),
        target,
        bond_chain_bounces
      ),
      data.damage * bond_chain_ratio,
      basic_attack_def,
      {
        visual = function()
          return {
            particle = basic_chain_particle,
            skip_hunter_first_hit = true,
          }
        end,
      }
    )
  end

  if skill.execute_threshold > 0 and target:is_exist() and target:get_hp() > 0 then
    local max_hp = get_unit_max_hp(target)
    if max_hp > 0 and target:get_hp() / max_hp <= skill.execute_threshold then
      target:kill_by(STATE.hero)
    end
  end
end

local function handle_challenge_success(instance)
  if not instance or not instance.def or instance.def.id ~= 'treasure_trial' then
    return false
  end

  award_rewards(instance.def.reward, instance.def.name .. ' 成功', false)
  message('宝物功能已下线，本次不再发放宝物奖励。')
  return true
end

local function handle_battle_finished(result)
  if audio_system and audio_system.handle_battle_finished then
    audio_system.handle_battle_finished(result)
  end
  if battlefield_system and battlefield_system.cleanup_battle_units then
    battlefield_system.cleanup_battle_units()
  end
  set_battle_hud_visible(false)
  reset_battle_state()
  STATE.session_phase = 'outgame'
  STATE.game_finished = true
  STATE.last_battle_result = result
  if outgame_system then
    outgame_system.enter_outgame(result)
  end
end

battlefield_system = BattlefieldSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  design_seconds = design_seconds,
  random_point_in_area = random_point_in_area,
  hero_attr_system = hero_attr_system,
  set_attr_pack = set_attr_pack,
  add_attr_pack = add_attr_pack,
  get_player = get_player,
  get_enemy_player = get_enemy_player,
  get_hero_level = progression_system.get_hero_level,
  award_rewards = function(reward, source_text, silent)
    return award_rewards(reward, source_text, silent)
  end,
  build_reward_with_bond_bonus = function(reward)
    return build_reward_with_bond_bonus(reward)
  end,
  handle_bond_enemy_kill = function(info)
    return handle_bond_enemy_kill(info)
  end,
  heal_hero = function(amount)
    return heal_hero(amount)
  end,
  play_enemy_death_sound = function(unit, info, death_point)
    local is_boss = info and info.kind == 'boss'
    local played = audio_system and audio_system.play_enemy_death and
        audio_system.play_enemy_death(unit, is_boss, death_point) or nil
    if played then
      return played
    end
    if not death_point or not y3 or not y3.sound then
      return nil
    end

    local player = get_player()
    if not player then
      return nil
    end

    local function resolve_audio_key(raw_id)
      if raw_id == nil then
        return nil
      end
      local number_id = tonumber(raw_id)
      if number_id then
        return number_id
      end
      if y3 and y3.game and y3.game.str_to_audio_key then
        local ok, key = pcall(y3.game.str_to_audio_key, tostring(raw_id))
        if ok and key then
          return key
        end
      end
      return nil
    end

    local function play_3d_with_candidates(candidates, options)
      for _, candidate in ipairs(candidates or {}) do
        local key = resolve_audio_key(candidate)
        if key then
          local ok, sound = pcall(y3.sound.play_3d, player, key, death_point, options)
          if ok and sound then
            if options and options.volume and sound.set_volume then
              pcall(sound.set_volume, sound, player, options.volume)
            end
            return sound
          end
        end
      end
      return nil
    end

    local heavy_sound = play_3d_with_candidates({ '134257420', '126040', '125775' }, {
      ensure = true,
      height = 45,
      volume = is_boss and 100 or 92,
    })
    play_3d_with_candidates({ '134257799', '126054', '126042' }, {
      height = 65,
      volume = is_boss and 94 or 82,
    })
    return heavy_sound
  end,
  on_hero_damage = function(data)
    return trigger_td_skills_on_hit(data)
  end,
  apply_formula_damage_override = function(data)
    return apply_formula_damage_override(data)
  end,
  on_hero_before_hurt = function(data)
    return handle_bond_hero_pre_hurt(data)
  end,
  on_wave_started = function(wave_index)
    if audio_system and audio_system.handle_wave_started then
      audio_system.handle_wave_started(wave_index)
    end
    return reward_system.handle_wave_started(wave_index)
  end,
  on_mainline_task_wave_started = function(wave_index)
    return mainline_task_system.handle_wave_started(wave_index)
  end,
  on_mainline_task_enemy_killed = function(info)
    return mainline_task_system.handle_enemy_killed(info)
  end,
  on_mainline_task_wave_cleared = function()
    return mainline_task_system.handle_wave_cleared()
  end,
  on_mainline_task_cleared = function(task)
    return mainline_task_system.handle_task_cleared(task)
  end,
  on_boss_spawned = function(boss_info)
    if audio_system and audio_system.handle_boss_spawned then
      audio_system.handle_boss_spawned(boss_info)
    end
    return reward_system.handle_boss_spawned(boss_info)
  end,
  on_boss_warning = function(wave, remain)
    if audio_system and audio_system.handle_boss_warning then
      return audio_system.handle_boss_warning(wave, remain)
    end
    return nil
  end,
  on_challenge_started = function(instance)
    if audio_system and audio_system.handle_challenge_started then
      audio_system.handle_challenge_started(instance)
    end
    return reward_system.handle_challenge_started(instance)
  end,
  on_challenge_finished = function(instance, is_success)
    if audio_system and audio_system.handle_challenge_finished then
      audio_system.handle_challenge_finished(instance, is_success)
    end
    if mainline_task_system and mainline_task_system.handle_challenge_finished then
      mainline_task_system.handle_challenge_finished(instance, is_success)
    end
    return reward_system.handle_challenge_finished(instance, is_success)
  end,
  on_hero_be_hurt = function()
    if audio_system and audio_system.handle_hero_be_hurt then
      audio_system.handle_hero_be_hurt()
    end
    return reward_system.handle_hero_be_hurt()
  end,
  on_hero_attr_changed = snapshot_hero_attrs,
  handle_challenge_success = function(instance)
    return handle_challenge_success(instance)
  end,
  on_finish_game = function(result)
    return handle_battle_finished(result)
  end,
})

local function get_attack_skill(skill_id)
  return attack_skills_system.get_attack_skill(skill_id)
end

local function get_empty_attack_skill_slot()
  return attack_skills_system.get_empty_attack_skill_slot()
end

local function get_unlocked_attack_skill_count()
  return attack_skills_system.get_unlocked_attack_skill_count()
end

local function build_attack_skill_slot_text(slot)
  return attack_skills_system.build_attack_skill_slot_text(slot)
end

local function apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)
  if not reward_system or not reward_system.apply_treasure_bonus_to_attack_skill then
    return nil
  end
  return reward_system.apply_treasure_bonus_to_attack_skill(skill_id, skill, bonus, direction)
end

show_attack_skill_loadout = function()
  return attack_skills_system.show_attack_skill_loadout()
end

local function unlock_attack_skill(skill_id)
  if CONFIG.attack_skill_deprecated and skill_id ~= 'basic_attack' then
    return nil, nil, false
  end
  local skill, slot, is_new = attack_skills_system.unlock_attack_skill(skill_id)
  if is_new and STATE.treasure_runtime and STATE.treasure_runtime.applied then
    apply_treasure_bonus_to_attack_skill(
      skill_id,
      skill,
      STATE.treasure_runtime.applied.attack_skill or {},
      1
    )
  end
  if is_new and STATE.mark_runtime and STATE.mark_runtime.applied then
    apply_treasure_bonus_to_attack_skill(
      skill_id,
      skill,
      STATE.mark_runtime.applied.attack_skill or {},
      1
    )
  end
  return skill, slot, is_new
end

local function update_attack_skills(dt)
  return attack_skills_system.update_attack_skills(dt)
end
attack_skills_system = AttackSkillsSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  attack_skill_slot_count = ATTACK_SKILL_SLOT_COUNT,
  round_number = round_number,
  message = message,
  hero_attr_system = hero_attr_system,
  ATTACK_SKILL_DEFS = ATTACK_SKILL_DEFS,
  ATTACK_SKILL_VFX = AttackSkillObjects.vfx_by_id,
  get_player = get_player,
  get_hero_point = get_hero_point,
  get_bond_runtime_bonus = get_bond_runtime_bonus,
  is_active_enemy = is_active_enemy,
  create_attack_skill_instance = create_attack_skill_instance,
  deal_skill_damage = deal_skill_damage,
  emit_damage_debug = function(visual)
    emit_damage_debug_visual(visual, nil)
  end,
  get_damage_bonus_multiplier = get_damage_bonus_multiplier,
  reserve_formula_damage = reserve_formula_damage,
  get_enemies_in_range = get_enemies_in_range,
  try_trigger_hunter_first_hit = try_trigger_hunter_first_hit,
  notify_bond_attack_skill_cast = function(skill, target)
    if battle_auto_acceptance_system and battle_auto_acceptance_system.record_event and skill then
      battle_auto_acceptance_system.record_event({
        scope = 'attack_skill',
        key = tostring(skill.id or skill.name or 'unknown'),
        cast = 1,
      })
    end
    return BondSystem.notify_attack_skill_cast(create_bond_env(), skill, target)
  end,
  notify_auto_active_basic_attack = function(target)
    if auto_active_effects_system then
      auto_active_effects_system.handle_basic_attack_cast(target)
    end
    if STATE.hero_form_skills_system then
      STATE.hero_form_skills_system.handle_basic_attack_cast(target)
    end
  end,
  notify_auto_active_skill_cast = function(skill, target)
    if auto_active_effects_system then
      auto_active_effects_system.handle_attack_skill_cast(skill, target)
    end
    if STATE.hero_form_skills_system then
      STATE.hero_form_skills_system.handle_attack_skill_cast(skill, target)
    end
  end,
  play_basic_attack_sound = function(source_unit)
    return audio_system and audio_system.play_basic_attack and audio_system.play_basic_attack(source_unit) or nil
  end,
  play_attack_skill_sound = function(skill, source_anchor, stage)
    return audio_system and audio_system.play_attack_skill and
        audio_system.play_attack_skill(skill, source_anchor, stage) or nil
  end,
})

auto_active_effects_system = AutoActiveEffectsSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  attack_skill_slot_count = ATTACK_SKILL_SLOT_COUNT,
  hero_attr_system = hero_attr_system,
  str_to_modifier_key = function(name)
    return y3.game.str_to_modifier_key(name)
  end,
  ATTACK_SKILL_VFX = AttackSkillObjects.vfx_by_id,
  get_player = get_player,
  has_bond_route_tag = function(tag)
    return BondSystem.has_route_tag(STATE, tag)
  end,
  is_debug_effect_mounted = function(effect_id)
    return STATE.effect_debug_runtime
        and STATE.effect_debug_runtime.mounted_effect_ids
        and STATE.effect_debug_runtime.mounted_effect_ids[effect_id] == true
        or false
  end,
  is_active_enemy = is_active_enemy,
  get_enemies_in_range = get_enemies_in_range,
  deal_skill_damage = deal_skill_damage,
  heal_hero = function(amount)
    return heal_hero(amount)
  end,
})

effect_debug_system = EffectDebugSystem.create({
  STATE = STATE,
  message = message,
  get_modifier_name_by_key = function(modifier_key)
    if not modifier_key or modifier_key == 0 then
      return nil
    end
    return y3.buff.get_name_by_key(modifier_key)
  end,
  get_effect_defs = function()
    return auto_active_effects_system.get_effect_defs()
  end,
  get_effect_runtime_snapshot = function(effect_id)
    return auto_active_effects_system.get_effect_runtime_snapshot(effect_id)
  end,
  clear_effect_runtime = function(effect_id)
    return auto_active_effects_system.clear_effect_runtime(effect_id)
  end,
})

bond_set_effects_system = BondSetEffectsSystem.create({
  auto_active_effects_system = auto_active_effects_system,
  effect_debug_system = effect_debug_system,
})
bond_set_effects_system.register_global_apis()

STATE.hero_form_skills_system = require('runtime.hero_form_skills').create({
  STATE = STATE,
  y3 = y3,
  message = message,
  round_number = round_number,
  hero_attr_system = hero_attr_system,
  is_active_enemy = is_active_enemy,
  get_enemies_in_range = get_enemies_in_range,
  get_enemy_runtime_info = get_enemy_runtime_info,
  is_boss_runtime_enemy = is_boss_runtime_enemy,
  is_elite_runtime_enemy = is_elite_runtime_enemy,
  deal_skill_damage = deal_skill_damage,
  heal_hero = function(amount)
    return heal_hero(amount)
  end,
  play_skill_sound = function(skill)
    return audio_system and audio_system.play_attack_skill and audio_system.play_attack_skill(skill, STATE.hero) or nil
  end,
})

local function get_pending_round_choice_kind()
  if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
    return 'gear'
  end
  if attr_choice_system and attr_choice_system.get_pending_choice_kind then
    local attr_kind = attr_choice_system.get_pending_choice_kind()
    if attr_kind then
      return attr_kind
    end
  end
  if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice and STATE.bond_runtime.current_choices then
    return 'bond'
  end
  local evolution_runtime = STATE.evolution_runtime or STATE.mark_runtime
  if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
    return 'evolution'
  end
  return nil
end

local function get_pending_round_choice_label(kind)
  if kind == 'bond' then
    return 'F 战术抽卡'
  end
  if kind == 'gear' then
    return '成长武器词条'
  end
  if kind == 'attr' then
    return '属性四选一'
  end
  if kind == 'evolution' or kind == 'mark' then
    return '猎手专精'
  end
  return '当前选择'
end

local get_runtime_overview_model
overview_model_system = OverviewModelSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  round_number = round_number,
  hero_attr_system = hero_attr_system,
  get_current_wave = get_current_wave,
  get_boss_name = get_boss_name,
  get_pending_round_choice_kind = get_pending_round_choice_kind,
  get_hero_progress_text = progression_system.get_hero_progress_text,
  get_reward_queue_count = reward_system.get_reward_queue_count,
  get_reward_queue = reward_system.get_reward_queue,
  get_mark_runtime = reward_system.get_evolution_runtime,
  get_treasure_runtime = reward_system.get_treasure_runtime,
  get_treasure_quality_label = reward_system.get_treasure_quality_label,
  get_treasure_active_count = reward_system.get_treasure_active_count,
  get_mark_active_count = reward_system.get_evolution_active_count,
  build_treasure_slot_text = reward_system.build_treasure_slot_text,
  build_mark_slot_text = reward_system.build_evolution_slot_text,
  get_bond_runtime_bonus = get_bond_runtime_bonus,
  get_treasure_reward_ratio = reward_system.get_treasure_reward_ratio,
  get_treasure_passive_income = reward_system.get_treasure_passive_income,
  attack_skill_slot_count = ATTACK_SKILL_SLOT_COUNT,
  build_attack_skill_slot_text = function(slot)
    return attack_skills_system.build_attack_skill_slot_text(slot)
  end,
  build_bond_slot_text = function(slot)
    return BondSystem.build_slot_text(STATE, slot)
  end,
  build_bond_choice_preview_text = function(index, choice)
    return BondSystem.build_choice_preview_text(index, choice)
  end,
  build_bond_progress_lines = function(max_lines)
    return BondSystem.build_progress_lines(STATE, max_lines)
  end,
})

get_runtime_overview_model = function()
  return overview_model_system.get_runtime_overview_model()
end

local function show_pending_round_choice(kind)
  local current_kind = kind or get_pending_round_choice_kind()
  STATE.choice_panel_hidden = false
  if current_kind == 'bond' then
    BondSystem.try_draw(create_bond_env())
    return
  end
  if current_kind == 'gear' then
    return
  end
  if current_kind == 'attr' then
    return runtime_hud_system and runtime_hud_system.refresh_hud and runtime_hud_system.refresh_hud() or nil
  end
  if current_kind == 'evolution' or current_kind == 'mark' then
    show_mark_choices()
    return
  end
  if current_kind == 'treasure' then
    message('宝物功能已下线。')
    STATE.choice_panel_hidden = false
    return
  end
end

ensure_round_choice_available = function(allowed_kind)
  local kind = get_pending_round_choice_kind()
  if not kind or kind == allowed_kind then
    return true
  end

  message('请先完成当前' .. get_pending_round_choice_label(kind) .. '。')
  show_pending_round_choice(kind)
  return false
end

local function apply_bond_choice(index)
  BondSystem.apply_choice(create_bond_env(), index)
  STATE.choice_panel_hidden = false
  try_open_queued_treasure_round()
end

local function apply_round_choice(index)
  local kind = get_pending_round_choice_kind()

  if kind == 'gear' then
    if GearUpgrades.apply_affix_choice({
          STATE = STATE,
          CONFIG = CONFIG,
          message = message,
        }, index) then
      if STATE.hero and sync_gear_runtime_effects then
        sync_gear_runtime_effects(STATE, STATE.hero, CONFIG.gear_upgrade_config)
      end
      STATE.choice_panel_hidden = false
      try_open_queued_treasure_round()
      return true
    end
    return false
  end

  if kind == 'attr' then
    local ok = attr_choice_system and attr_choice_system.apply_choice and attr_choice_system.apply_choice(index) or false
    if ok then
      STATE.choice_panel_hidden = false
      try_open_queued_treasure_round()
    end
    return ok
  end

  if kind == 'bond' then
    apply_bond_choice(index)
    return true
  end

  if kind == 'evolution' or kind == 'mark' then
    reward_system.apply_evolution_choice(index)
    STATE.choice_panel_hidden = false
    return true
  end

  if kind == 'treasure' then
    message('宝物功能已下线。')
    return false
  end

  return false
end

local function refresh_current_choice()
  STATE.choice_panel_hidden = false
  local kind = get_pending_round_choice_kind()

  if kind == 'gear' then
    return GearUpgrades.refresh_affix_choices({
      STATE = STATE,
      CONFIG = CONFIG,
      message = message,
    })
  end

  if kind == 'attr' then
    message('属性四选一不支持刷新。')
    return false
  end

  if kind == 'bond' then
    return BondSystem.refresh_choice(create_bond_env())
  end

  if kind == 'evolution' or kind == 'mark' then
    message('当前猎手专精不支持刷新。')
    return false
  end

  if kind == 'treasure' then
    message('宝物功能已下线。')
    return false
  end

  return false
end

local function try_bond_draw()
  STATE.choice_panel_hidden = false
  if not ensure_round_choice_available('bond') then
    return
  end
  if not STATE.resources or (STATE.resources.wood or 0) < (BondDrawConfig.draw_cost or 100) then
    if runtime_hud_system and runtime_hud_system.show_center_tip then
      runtime_hud_system.show_center_tip('木头不足，无法抽卡！')
    end
  end
  BondSystem.try_draw(create_bond_env())
end

local function finish_game(is_win, reason)
  return battlefield_system.finish_game(is_win, reason)
end


debug_actions_system = DebugActionsSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  debug_message = debug_message,
  attack_skill_slot_count = ATTACK_SKILL_SLOT_COUNT,
  is_battle_active = function()
    return is_battle_active and is_battle_active() or false
  end,
  get_hero_max_level = progression_system.get_hero_max_level,
  sync_hero_progression = progression_system.sync_hero_progression,
  ATTACK_SKILL_BLUEPRINTS = ATTACK_SKILL_BLUEPRINTS,
  unlock_attack_skill = unlock_attack_skill,
  show_attack_skill_loadout = show_attack_skill_loadout,
  try_bond_draw = try_bond_draw,
  force_spawn_boss = function()
    return battlefield_system.force_spawn_boss()
  end,
  execute_enemy = function(unit)
    return battlefield_system.execute_enemy(unit)
  end,
  grant_bond_card = function(card_id)
    return BondSystem.debug_grant_card(create_bond_env(), card_id)
  end,
  grant_treasure = function(treasure_id, replace_slot)
    return reward_system.debug_grant_treasure(treasure_id, replace_slot)
  end,
  dump_temporary_treasures = function()
    return reward_system.debug_dump_temporary_treasures()
  end,
  effect_debug_system = effect_debug_system,
  force_trigger_effect = function(effect_id)
    return auto_active_effects_system.force_trigger_effect(effect_id)
  end,
  open_effect_debug_panel_ui = function()
    if not gm_bond_effects_system then
      return
    end
    local gm_ui = gm_bond_effects_system.ensure_board and gm_bond_effects_system.ensure_board() or nil
    if gm_ui and gm_ui.visible ~= true then
      gm_bond_effects_system.toggle_board()
    else
      gm_bond_effects_system.refresh_board()
    end
  end,
  sample_skill_system = sample_skills_system,
})

debug_tools_system = DebugToolsSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  make_point = make_point,
  develop_command = require 'y3.develop.command',
  get_player = get_player,
  get_hero_point = get_hero_point,
  get_current_wave = get_current_wave,
  get_boss_name = get_boss_name,
  get_hero_level = progression_system.get_hero_level,
  get_active_challenge_count = function()
    return battlefield_system.get_active_challenge_count()
  end,
  show_runtime_status = show_runtime_status,
  debug_add_test_resources = function()
    return debug_actions_system.debug_add_test_resources()
  end,
  debug_grant_levels = function(level_count)
    return debug_actions_system.debug_grant_levels(level_count)
  end,
  debug_unlock_all_attack_skills = function()
    return debug_actions_system.debug_unlock_all_attack_skills()
  end,
  debug_trigger_bond_draw = function()
    return debug_actions_system.debug_trigger_bond_draw()
  end,
  debug_refill_challenge_charges = function()
    return debug_actions_system.debug_refill_challenge_charges()
  end,
  debug_force_spawn_boss = function()
    return debug_actions_system.debug_force_spawn_boss()
  end,
  debug_kill_all_active_enemies = function()
    return debug_actions_system.debug_kill_all_active_enemies()
  end,
  debug_open_attr_overview = function()
    show_runtime_attr_dialog()
  end,
  debug_show_attr_tip_panel = function()
    show_runtime_attr_dialog()
  end,
  debug_grant_bond_card = function(card_id)
    return debug_actions_system.debug_grant_bond_card(card_id)
  end,
  debug_grant_treasure = function(treasure_id, replace_slot)
    return debug_actions_system.debug_grant_treasure(treasure_id, replace_slot)
  end,
  debug_print_temporary_treasures = function()
    return debug_actions_system.debug_print_temporary_treasures()
  end,
  effect_debug_system = effect_debug_system,
  debug_open_effect_debug_panel = function()
    return debug_actions_system.debug_open_effect_debug_panel()
  end,
  debug_select_effect = function(effect_id)
    return debug_actions_system.debug_select_effect(effect_id)
  end,
  debug_mount_effect = function(effect_id)
    return debug_actions_system.debug_mount_effect(effect_id)
  end,
  debug_unmount_effect = function(effect_id)
    return debug_actions_system.debug_unmount_effect(effect_id)
  end,
  debug_clear_mounted_effects = function()
    return debug_actions_system.debug_clear_mounted_effects()
  end,
  debug_trigger_effect = function(effect_id)
    return debug_actions_system.debug_trigger_effect(effect_id)
  end,
  debug_start_effect_observe = function(effect_id)
    return debug_actions_system.debug_start_effect_observe(effect_id)
  end,
  debug_print_effect_logs = function()
    return debug_actions_system.debug_print_effect_logs()
  end,
  debug_list_sample_skills = function()
    return debug_actions_system.debug_list_sample_skills()
  end,
  debug_cast_sample_skill = function(sample_id)
    return debug_actions_system.debug_cast_sample_skill(sample_id)
  end,
  debug_cast_next_sample_skill = function()
    return debug_actions_system.debug_cast_next_sample_skill()
  end,
  debug_print_sample_framework_telemetry = function(sample_id)
    return debug_actions_system.debug_print_sample_framework_telemetry(sample_id)
  end,
  debug_print_sample_framework_report = function()
    return debug_actions_system.debug_print_sample_framework_report()
  end,
  debug_run_framework_tier_suite = function()
    return debug_actions_system.debug_run_framework_tier_suite()
  end,
  debug_print_framework_tier_report = function()
    return debug_actions_system.debug_print_framework_tier_report()
  end,
  debug_set_global_projectile_override = function(projectile_key)
    return debug_actions_system.debug_set_global_projectile_override(projectile_key)
  end,
  debug_clear_global_projectile_override = function()
    return debug_actions_system.debug_clear_global_projectile_override()
  end,
  debug_toggle_global_projectile_override = function(projectile_key)
    return debug_actions_system.debug_toggle_global_projectile_override(projectile_key)
  end,
  debug_get_global_projectile_override = function()
    return debug_actions_system.debug_get_global_projectile_override()
  end,
  sample_skill_system = sample_skills_system,
})

function RuntimeEntry.start_wave(index)
  return battlefield_system.start_wave(index)
end

function RuntimeEntry.finish_challenge(instance, is_success)
  return battlefield_system.finish_challenge(instance, is_success)
end

function RuntimeEntry.push_battle_event(text, style, duration)
  return BattleEventPrompts.push_battle_event(text, style, duration)
end

function RuntimeEntry.push_message_prompt(text, icon, opts)
  if not STATE.message_prompt_system or not STATE.message_prompt_system.push_list then
    return nil
  end
  return STATE.message_prompt_system.push_list(text, icon, opts)
end

function RuntimeEntry.push_message_board(text, priority, opts)
  if not STATE.message_prompt_system or not STATE.message_prompt_system.push_board then
    return nil
  end
  return STATE.message_prompt_system.push_board(text, priority, opts)
end

function RuntimeEntry.push_message_marquee(text, priority, opts)
  if not STATE.message_prompt_system or not STATE.message_prompt_system.push_marquee then
    return nil
  end
  return STATE.message_prompt_system.push_marquee(text, priority, opts)
end

local function try_start_challenge(challenge_id)
  if challenge_id == 'treasure_trial' then
    message('宝物挑战已下线。')
    return false
  end
  if not ensure_round_choice_available(nil) then
    return
  end
  return battlefield_system.try_start_challenge(challenge_id)
end

local function has_pending_treasure_choice()
  return reward_system.has_pending_treasure_choice()
end

local function has_pending_evolution_choice()
  local runtime = reward_system.get_evolution_runtime()
  return runtime
      and runtime.awaiting_choice == true
      and runtime.current_choices
      and #runtime.current_choices > 0
end

local function try_evolution_entry()
  if has_pending_evolution_choice() then
    STATE.choice_panel_hidden = false
    show_pending_round_choice('evolution')
    return true
  end

  try_open_queued_treasure_round()
  if not ensure_round_choice_available('evolution') then
    return false
  end
  if has_pending_evolution_choice() then
    STATE.choice_panel_hidden = false
    show_pending_round_choice('evolution')
    return true
  end

  message('当前没有待领取的猎手专精选择。')
  return false
end

local function try_treasure_entry()
  message('宝物功能已下线。')
  return false
end

local function use_attr_diamond()
  if not ensure_round_choice_available('attr') then
    return false
  end
  local ok = attr_choice_system and attr_choice_system.use_diamond and attr_choice_system.use_diamond() or false
  if ok then
    STATE.choice_panel_hidden = false
    show_pending_round_choice('attr')
  end
  return ok
end

local function open_bond_card_album()
  if runtime_ui_helpers and runtime_ui_helpers.show_bond_swallow_panel then
    local panel = runtime_ui_helpers.show_bond_swallow_panel()
    if panel then
      return true
    end
  end
  BondSystem.show_bond_progress(create_bond_env())
  return false
end

local function open_runtime_save_panel()
  STATE.choice_panel_hidden = true
  if runtime_ui_helpers and runtime_ui_helpers.destroy_choice_panel then
    runtime_ui_helpers.destroy_choice_panel()
  end
  if runtime_ui_helpers and runtime_ui_helpers.refresh_bond_swallow_panel then
    STATE.bond_swallow_panel_visible = false
    runtime_ui_helpers.refresh_bond_swallow_panel()
  end
  return outgame_system and outgame_system.open_save_panel and outgame_system.open_save_panel() or false
end

runtime_hud_system = RuntimeHudSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  attack_skill_slot_count = ATTACK_SKILL_SLOT_COUNT,
  get_player = get_player,
  hero_attr_system = hero_attr_system,
  message = message,
  try_bond_draw = try_bond_draw,
  show_bond_progress = function()
    return open_bond_card_album()
  end,
  try_evolution_entry = try_evolution_entry,
  try_treasure_entry = try_treasure_entry,
  try_start_challenge = try_start_challenge,
  open_save_panel = function()
    return open_runtime_save_panel()
  end,
  toggle_gm_panel = function()
    if not gm_bond_effects_system then
      return
    end
    gm_bond_effects_system.ensure_board()
    gm_bond_effects_system.toggle_board()
  end,
  try_upgrade_growth_weapon = BattleEventPrompts.try_upgrade_growth_weapon,
  use_attr_diamond = use_attr_diamond,
  get_attr_choice_runtime = function()
    return attr_choice_system and attr_choice_system.ensure_runtime and attr_choice_system.ensure_runtime() or nil
  end,
  apply_attr_choice = function(index)
    return attr_choice_system and attr_choice_system.apply_choice and attr_choice_system.apply_choice(index) or false
  end,
  show_runtime_status = show_runtime_status,
  build_runtime_attr_dialog_chunks = build_runtime_attr_dialog_chunks,
  build_growth_weapon_tip_payload = function()
    return GearUpgrades.build_tip_payload(STATE, 'weapon', CONFIG.gear_upgrade_config, y3.item)
  end,
  build_bond_slot_tip_payload = function(slot)
    return BondSystem.build_slot_tip_payload(STATE, slot)
  end,
  bond_draw_cost = BondDrawConfig.draw_cost or 100,
  get_bond_slot_icon = function(slot)
    return BondSystem.get_slot_icon(STATE, slot)
  end,
  get_bottom_status_effect_entries = function(max_slots)
    return get_bottom_status_effect_entries(max_slots)
  end,
  play_ui_click = function()
    return audio_system and audio_system.play_ui_click and audio_system.play_ui_click() or nil
  end,
})
choice_panel_system = nil

STATE.attr_tips_panel_system = require('runtime.attr_tips_panel').create({
  STATE = STATE,
  y3 = y3,
  get_player = get_player,
  hero_attr_system = hero_attr_system,
})
if STATE.attr_tips_panel_system and STATE.attr_tips_panel_system.init then
  STATE.attr_tips_panel_system.init()
end

runtime_ui_helpers = RuntimeUIHelpers.create({
  STATE = STATE,
  y3 = y3,
  get_player = get_player,
  get_pending_round_choice_kind = get_pending_round_choice_kind,
  refresh_current_choice = refresh_current_choice,
  apply_round_choice = apply_round_choice,
  defer_choice_panel = function()
    STATE.choice_panel_hidden = true
  end,
  get_growth_weapon_item_key = function()
    local slot_cfg = CONFIG.gear_upgrade_config
        and CONFIG.gear_upgrade_config.slots
        and CONFIG.gear_upgrade_config.slots.weapon
        or nil
    return slot_cfg and slot_cfg.item_key or nil
  end,
  build_treasure_slot_text = function(slot)
    return reward_system.build_treasure_slot_text(slot)
  end,
  get_treasure_quality_label = function(quality)
    return reward_system.get_treasure_quality_label(quality)
  end,
  get_treasure_def = function(treasure_id)
    return reward_system.get_treasure_def(treasure_id)
  end,
  get_evolution_quality_label = function(quality)
    return reward_system.get_evolution_quality_label(quality)
  end,
  get_runtime_hud_system = function()
    return runtime_hud_system
  end,
  get_runtime_overview_model = function()
    return get_runtime_overview_model and get_runtime_overview_model() or nil
  end,
  build_bond_swallow_panel_model = function(state, selected_root_index)
    return BondSystem.build_bond_swallow_panel_model(state, selected_root_index)
  end,
})

gm_bond_effects_system = GmBondEffectsSystem.create({
  STATE = STATE,
  y3 = y3,
  message = message,
  develop_command = require 'y3.develop.command',
  get_player = get_player,
  is_battle_active = function()
    return STATE.session_phase == 'battle' and STATE.game_finished ~= true
  end,
  grant_modifier_card_effect = function(card_ref)
    return BondSystem.debug_grant_modifier_card(create_bond_env(), card_ref)
  end,
  activate_modifier_bond_effect = function(bond_name, grant_missing_cards)
    return BondSystem.debug_activate_modifier_bond(create_bond_env(), bond_name, grant_missing_cards)
  end,
  activate_single_modifier_bond_effect = function(bond_name, grant_missing_cards)
    return BondSystem.debug_activate_single_modifier_bond(create_bond_env(), bond_name, grant_missing_cards)
  end,
  clear_active_modifier_bond_effects = function()
    return BondSystem.debug_clear_active_modifier_bonds(create_bond_env())
  end,
  set_force_special_effects_100 = function(enabled)
    BondModifierEffects.set_force_special_effects_100(enabled)
  end,
  is_force_special_effects_100 = function()
    return BondModifierEffects.is_force_special_effects_100()
  end,
  run_bond_self_test = function()
    return BondEffectsTestFramework.run({
      message = message,
    })
  end,
  list_sample_skills = function()
    if sample_skills_system and sample_skills_system.list_samples then
      return sample_skills_system.list_samples()
    end
    return {}
  end,
  cast_sample_skill = function(sample_id)
    if sample_skills_system and sample_skills_system.cast_sample then
      return sample_skills_system.cast_sample(sample_id)
    end
    return false, 'sample 技能系统未初始化。'
  end,
  cast_next_sample_skill = function()
    if sample_skills_system and sample_skills_system.cast_next_sample then
      return sample_skills_system.cast_next_sample()
    end
    return false, 'sample 技能系统未初始化。'
  end,
  get_sample_skill_defs = function()
    if sample_skills_system and sample_skills_system.get_sample_defs then
      return sample_skills_system.get_sample_defs()
    end
    return {}
  end,
  cast_basic_attack_ability = function()
    if attack_skills_system and attack_skills_system.debug_cast_basic_attack_once then
      return attack_skills_system.debug_cast_basic_attack_once()
    end
    return false, '普攻能力系统未初始化。'
  end,
  set_n0_activation_mode = function(mode)
    if battle_auto_acceptance_system and battle_auto_acceptance_system.set_activation_mode then
      battle_auto_acceptance_system.set_activation_mode(mode)
      return true
    end
    return false
  end,
  set_n0_single_bond_name = function(bond_name)
    if battle_auto_acceptance_system and battle_auto_acceptance_system.set_single_bond_name then
      battle_auto_acceptance_system.set_single_bond_name(bond_name)
      return true
    end
    return false
  end,
  restart_n0_auto_acceptance = function()
    if battle_auto_acceptance_system and battle_auto_acceptance_system.restart_current_run then
      return battle_auto_acceptance_system.restart_current_run() == true
    end
    return false
  end,
  debug_set_global_projectile_override = function(projectile_key)
    if debug_actions_system and debug_actions_system.debug_set_global_projectile_override then
      return debug_actions_system.debug_set_global_projectile_override(projectile_key)
    end
  end,
  debug_clear_global_projectile_override = function()
    if debug_actions_system and debug_actions_system.debug_clear_global_projectile_override then
      return debug_actions_system.debug_clear_global_projectile_override()
    end
  end,
  debug_toggle_global_projectile_override = function(projectile_key)
    if debug_actions_system and debug_actions_system.debug_toggle_global_projectile_override then
      return debug_actions_system.debug_toggle_global_projectile_override(projectile_key)
    end
  end,
  debug_get_global_projectile_override = function()
    if debug_actions_system and debug_actions_system.debug_get_global_projectile_override then
      return debug_actions_system.debug_get_global_projectile_override()
    end
    return nil
  end,
  set_basic_attack_enabled = function(enabled)
    STATE.basic_attack_enabled = enabled == true
    return true
  end,
  get_basic_attack_enabled = function()
    return STATE.basic_attack_enabled ~= false
  end,
  get_game_time = function()
    if y3 and y3.game and y3.game.current_game_run_time then
      return tonumber(y3.game.current_game_run_time()) or 0
    end
    return 0
  end,
})

battle_auto_acceptance_system = BattleAutoAcceptanceSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  auto_start_in_n0 = true,
  is_battle_active = function()
    return STATE.session_phase == 'battle' and STATE.game_finished ~= true
  end,
  get_enemy_player = get_enemy_player,
  has_unit_data = function(unit_id)
    return battlefield_system and battlefield_system.has_unit_data and battlefield_system.has_unit_data(unit_id) or false
  end,
  activate_modifier_bond_effect = function(bond_name, grant_missing_cards)
    return BondSystem.debug_activate_modifier_bond(create_bond_env(), bond_name, grant_missing_cards)
  end,
  activate_single_modifier_bond_effect = function(bond_name, grant_missing_cards)
    return BondSystem.debug_activate_single_modifier_bond(create_bond_env(), bond_name, grant_missing_cards)
  end,
  clear_active_modifier_bond_effects = function()
    return BondSystem.debug_clear_active_modifier_bonds(create_bond_env())
  end,
  set_force_special_effects_100 = function(enabled)
    BondModifierEffects.set_force_special_effects_100(enabled)
  end,
  run_bond_self_test = function()
    return BondEffectsTestFramework.run({
      message = message,
    })
  end,
  get_game_time = function()
    if y3 and y3.game and y3.game.current_game_run_time then
      return tonumber(y3.game.current_game_run_time()) or 0
    end
    return 0
  end,
})

local function resolve_quality_frame_image(quality)
  if QualityImageTable and QualityImageTable.get_frame_image then
    local image = QualityImageTable.get_frame_image(quality)
    if image then
      return image
    end
  end

  local image_table = quality_image_table or QUALITY_IMAGE_TABLE
  if type(image_table) ~= 'table' then
    return nil
  end
  local key = tostring(quality or 'common')
  local lower_key = string.lower(key)
  local normalized_key = ({
    n = 'N',
    r = 'R',
    sr = 'SR',
    ssr = 'SSR',
    ur = 'UR',
    common = 'N',
    excellent = 'R',
    rare = 'SR',
    epic = 'SSR',
    legendary = 'UR',
    ['普通'] = 'N',
    ['优秀'] = 'R',
    ['稀有'] = 'SR',
    ['史诗'] = 'SSR',
    ['传说'] = 'UR',
  })[lower_key] or ({
    ['普通'] = 'N',
    ['优秀'] = 'R',
    ['稀有'] = 'SR',
    ['史诗'] = 'SSR',
    ['传说'] = 'UR',
  })[key]
  local cn_key = ({
    common = '普通',
    excellent = '优秀',
    rare = '稀有',
    epic = '史诗',
    legendary = '传说',
  })[lower_key]
  return image_table[key]
      or image_table[lower_key]
      or (normalized_key and image_table[normalized_key] or nil)
      or (normalized_key and image_table[string.lower(normalized_key)] or nil)
      or (cn_key and image_table[cn_key] or nil)
      or (lower_key == 'excellent' and (image_table.rare or image_table.SR or image_table.sr) or nil)
      or (lower_key == 'legendary' and (image_table.epic or image_table.UR or image_table.ur) or nil)
      or image_table.common
      or image_table.N
      or image_table.n
      or image_table['普通']
end

local function set_ui_visible(ui, visible)
  if ui and (not ui.is_removed or not ui:is_removed()) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

local function set_ui_image(ui, image)
  if ui and (not ui.is_removed or not ui:is_removed()) and ui.set_image and image and image ~= 0 then
    ui:set_image(image)
  end
end

local function apply_bond_choice_quality_frames()
  local bond_runtime = STATE.bond_runtime
  local choices = bond_runtime and bond_runtime.current_choices or nil
  if not choices or #choices == 0 or STATE.choice_panel_hidden == true then
    return
  end
  local player = get_player()
  if not player then
    return
  end
  local panel_name = 'BondChoice4'
  local panel_index = '4'
  for index = 1, 4 do
    local path = string.format(
      '%s.bond_choice_%s.cards_row.card_%d.icon_frame_%d',
      panel_name,
      panel_index,
      index,
      index
    )
    local ok, frame = pcall(y3.ui.get_ui, player, path)
    if ok and frame then
      local choice = choices[index]
      local image = choice and resolve_quality_frame_image(choice.quality) or nil
      set_ui_visible(frame, image ~= nil)
      set_ui_image(frame, image)
    end
  end
end

local function resolve_choice_panel_card(scroll, index)
  if not scroll then
    return nil
  end
  local names
  if index == 1 then
    names = { 'Card1', 'Card_1' }
  elseif index == 2 then
    names = { 'Card2', 'Card_2' }
  elseif index == 3 then
    names = { 'Card3', 'Card_3' }
  else
    names = { 'Card4', 'Card_4' }
  end
  for _, name in ipairs(names) do
    local card = nil
    if scroll and scroll.get_child then
      local ok, child = pcall(scroll.get_child, scroll, name)
      if ok then
        card = child
      end
    end
    if card then
      return card
    end
  end
  return nil
end

local function resolve_ui_child(parent, child_name)
  if not parent or not child_name or not parent.get_child then
    return nil
  end
  local ok, child = pcall(parent.get_child, parent, child_name)
  if ok then
    return child
  end
  return nil
end

local function ensure_choice_list_choice_panel()
  local player = get_player()
  if not player then
    return nil, nil, nil
  end
  local ok_root, root = pcall(y3.ui.get_ui, player, 'Choice_Panel')
  if not ok_root or not root then
    return nil, nil, nil
  end
  local ok_scroll, scroll = pcall(y3.ui.get_ui, player, 'Choice_Panel.ChoiceList.scroll_view')
  if not ok_scroll or not scroll then
    return nil, nil, nil
  end
  return root, scroll, player
end

local choice_click_bound = setmetatable({}, { __mode = 'k' })
local function bind_choice_click_target(target, index)
  if not target or not target.add_fast_event then
    return
  end
  if choice_click_bound[target] then
    return
  end
  choice_click_bound[target] = true
  if target.set_intercepts_operations then
    target:set_intercepts_operations(true)
  end
  target:add_fast_event('左键-点击', function()
    apply_round_choice(index)
  end)
end

local function build_choice_list_cards()
  local kind = get_pending_round_choice_kind()
  local choices = nil
  if kind == 'gear' then
    choices = STATE.gear_state and STATE.gear_state.current_choices or nil
  elseif kind == 'attr' then
    choices = STATE.attr_choice_runtime and STATE.attr_choice_runtime.current_choices or nil
  elseif kind == 'bond' then
    choices = STATE.bond_runtime and STATE.bond_runtime.current_choices or nil
  elseif kind == 'evolution' or kind == 'mark' then
    local evolution_runtime = STATE.evolution_runtime or STATE.mark_runtime
    choices = evolution_runtime and evolution_runtime.current_choices or nil
  end

  local root, scroll, player = ensure_choice_list_choice_panel()
  if not root or not scroll then
    return
  end

  local is_visible = choices and #choices > 0 and STATE.choice_panel_hidden ~= true
  set_ui_visible(root, is_visible)

  local old_choice_panels = { 'BondChoice2', 'BondChoice3', 'BondChoice4', 'ChoiceList' }
  if player then
    for _, panel_name in ipairs(old_choice_panels) do
      local ok_old, old_panel = pcall(y3.ui.get_ui, player, panel_name)
      if ok_old and old_panel then
        set_ui_visible(old_panel, false)
      end
    end
  end

  for index = 1, 4 do
    local card = resolve_choice_panel_card(scroll, index)
    local choice = choices and choices[index] or nil
    set_ui_visible(card, is_visible and choice ~= nil)

    if card and is_visible and choice then
      local title = resolve_ui_child(card, 'title')
      if title and title.set_text then
        title:set_text(tostring(choice.pretty_display_name or choice.display_name or choice.title_text or choice.name or '候选'))
      end

      local subtitle = resolve_ui_child(card, 'sub_title')
      if subtitle and subtitle.set_text then
        subtitle:set_text(tostring(choice.bond_root_name or choice.bond_name or choice.tag or choice.quality or kind or '候选'))
      end

      local desc = resolve_ui_child(card, 'desc')
      if desc and desc.set_text then
        desc:set_text(tostring(choice.desc_text or choice.summary or choice.effect_body_text or ''))
      end

      local icon = resolve_ui_child(card, 'image_2_1')
      if icon and icon.set_image then
        icon:set_image(choice.ui_icon or choice.icon or 999)
      end

      local click_image = resolve_ui_child(card, 'image_2')
      bind_choice_click_target(click_image or card, index)
    end
  end

  if root.set_z_order then
    root:set_z_order(9600)
  end
end
runtime_ui_helpers.__raw_refresh_choice_panel = runtime_ui_helpers.refresh_choice_panel
runtime_ui_helpers.refresh_choice_panel = function(...)
  -- 选择面板统一走 ChoiceList 动态卡片链路，不再依赖旧 BondChoice2/3/4 渲染。
  build_choice_list_cards()
  return nil
end

cannon_skill_134258724_system = CannonSkill134258724System.create({
  STATE = STATE,
  y3 = y3,
  hero_attr_system = hero_attr_system,
  get_enemies_in_range = get_enemies_in_range,
  deal_skill_damage = deal_skill_damage,
  emit_damage_debug = function(visual)
    emit_damage_debug_visual(visual, nil)
  end,
})

runtime_ui_helpers.install_panel_systems()

runtime_ui_helpers.__raw_set_battle_hud_visible = runtime_ui_helpers.set_battle_hud_visible
set_battle_hud_visible = function(visible)
  if visible == true and STATE.archive_panel_visible == true then
    local result = runtime_ui_helpers.__raw_set_battle_hud_visible(false)
    enforce_runtime_ui_phase(false)
    return result
  end
  local result = runtime_ui_helpers.__raw_set_battle_hud_visible(visible)
  enforce_runtime_ui_phase(visible == true)
  if runtime_ui_helpers and runtime_ui_helpers.refresh_bond_swallow_panel then
    runtime_ui_helpers.refresh_bond_swallow_panel()
  end
  return result
end

RuntimeEntry._session_bundle = require('runtime.boot_session_setup').create({
  RuntimeEntry = RuntimeEntry,
  HeroSelectionRangeSystem = HeroSelectionRangeSystem,
  BootSession = BootSession,
  OutgameSystem = OutgameSystem,
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  hero_attr_system = hero_attr_system,
  make_point = make_point,
  get_resource_rules = get_resource_rules,
  create_bond_runtime = create_bond_runtime,
  create_battle_event_feed_runtime = create_battle_event_feed_runtime,
  create_effect_debug_runtime = create_effect_debug_runtime,
  reward_system = reward_system,
  create_skill_runtime = create_skill_runtime,
  create_attack_skill_state = create_attack_skill_state,
  ATTACK_SKILL_BLUEPRINTS = ATTACK_SKILL_BLUEPRINTS,
  ATTACK_SKILL_DEFS = ATTACK_SKILL_DEFS,
  runtime_ui_helpers = runtime_ui_helpers,
  battlefield_system = battlefield_system,
  progression_system = progression_system,
  GearUpgrades = GearUpgrades,
  get_player = get_player,
  get_enemy_player = get_enemy_player,
  get_outgame_system = function()
    return outgame_system
  end,
  unlock_attack_skill = unlock_attack_skill,
  show_attack_skill_loadout = show_attack_skill_loadout,
  setup_basic_attack_ability = setup_basic_attack_ability,
  set_battle_hud_visible = function(visible)
    return set_battle_hud_visible(visible)
  end,
  audio_system = audio_system,
})

hero_selection_range_system = RuntimeEntry._session_bundle.hero_selection_range_system
session_state_system = RuntimeEntry._session_bundle.session_state_system
outgame_system = RuntimeEntry._session_bundle.outgame_system
is_battle_active = RuntimeEntry._session_bundle.is_battle_active
reset_battle_state = RuntimeEntry._session_bundle.reset_battle_state
reset_session_state = RuntimeEntry._session_bundle.reset_session_state

RuntimeEntry._runtime_bundle = require('runtime.boot_runtime_setup').create({
  RuntimeEntry = RuntimeEntry,
  BootInput = BootInput,
  BootEvents = BootEvents,
  BootLoops = BootLoops,
  BootHeroTujian = BootHeroTujian,
  BootDevCommands = BootDevCommands,
  BootBootstrapSequence = BootBootstrapSequence,
  BattleEventPrompts = BattleEventPrompts,
  STATE = STATE,
  y3 = y3,
  message = message,
  progression_system = progression_system,
  reward_system = reward_system,
  attr_choice_system = attr_choice_system,
  runtime_ui_helpers = runtime_ui_helpers,
  mainline_task_system = mainline_task_system,
  debug_actions_system = debug_actions_system,
  debug_tools_system = debug_tools_system,
  gm_bond_effects_system = gm_bond_effects_system,
  audio_system = audio_system,
  hero_attr_system = hero_attr_system,
  battle_auto_acceptance_system = battle_auto_acceptance_system,
  battlefield_system = battlefield_system,
  hero_selection_range_system = hero_selection_range_system,
  outgame_system = outgame_system,
  get_player = get_player,
  is_battle_active = function()
    return is_battle_active()
  end,
  try_bond_draw = try_bond_draw,
  open_bond_card_album = open_bond_card_album,
  show_runtime_attr_dialog = show_runtime_attr_dialog,
  try_start_challenge = try_start_challenge,
  try_evolution_entry = try_evolution_entry,
  try_treasure_entry = try_treasure_entry,
  apply_round_choice = apply_round_choice,
  show_runtime_status = show_runtime_status,
  open_runtime_save_panel = open_runtime_save_panel,
  use_attr_diamond = use_attr_diamond,
  show_debug_hotkey_help = show_debug_hotkey_help,
  update_passive_resources = update_passive_resources,
  update_bond_effects = update_bond_effects,
  update_auto_active_effects = update_auto_active_effects,
  update_effect_debug = update_effect_debug,
  update_enemy_statuses = update_enemy_statuses,
  update_attack_skills = update_attack_skills,
  is_active_enemy = is_active_enemy,
  get_enemies_in_range = get_enemies_in_range,
  deal_skill_damage = deal_skill_damage,
  emit_damage_debug_visual = emit_damage_debug_visual,
  set_battle_hud_visible = set_battle_hud_visible,
  ensure_helper_signals = ensure_helper_signals,
  reset_session_state = function()
    return reset_session_state()
  end,
  cannon_skill_134258724_system = cannon_skill_134258724_system,
})

input_events_system = RuntimeEntry._runtime_bundle.input_events_system
hero_tujian_panel_system = RuntimeEntry._runtime_bundle.hero_tujian_panel_system
runtime_loops_system = RuntimeEntry._runtime_bundle.runtime_loops_system
register_dev_commands = RuntimeEntry._runtime_bundle.register_dev_commands
RuntimeEntry.register_runtime_events = RuntimeEntry._runtime_bundle.register_runtime_events
RuntimeEntry.start_runtime_loops = RuntimeEntry._runtime_bundle.start_runtime_loops
RuntimeEntry.run_bootstrap_sequence = RuntimeEntry._runtime_bundle.run_bootstrap_sequence

function RuntimeEntry.bootstrap()
  if not RuntimeEntry.validate_config() then
    return
  end

  RuntimeEntry.run_bootstrap_sequence()
end

return RuntimeEntry

local CONFIG = require 'entry_config'
local BondSystem = require 'runtime.bonds'
local AttackSkillObjects = require 'entry_objects.attack_skills'
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
local AttackUpgradeSystem = require 'runtime.attack_upgrades'
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
local AudioSystem = require 'runtime.audio'
local HeroSelectionRangeSystem = require 'runtime.hero_selection_range'
local HeroAttrSystem = require 'runtime.hero_attr_system'
local HeroAttrDefs = require 'runtime.hero_attr_defs'
local HeroAttrPanel = require 'runtime.hero_attr_panel'
local BootCore = require 'runtime.boot_core'
local RuntimeEntry = {}
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
attack_upgrade_system = nil
attack_skills_system = nil
auto_active_effects_system = nil
battle_auto_acceptance_system = nil
cannon_skill_134258724_system = nil
bond_set_effects_system = nil
effect_debug_system = nil
reward_system = nil
attr_choice_system = nil
audio_system = nil
hero_selection_range_system = nil
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
    tip_title = tostring(title or '魔法效果'),
    tip_text = table.concat(lines, '\n'),
  }
end

local function get_bottom_status_effect_entries(max_slots)
  local entries = {}
  local limit = math.max(0, tonumber(max_slots) or 5)
  if limit == 0
      or not auto_active_effects_system
      or not auto_active_effects_system.get_effect_defs
      or not auto_active_effects_system.get_effect_runtime_snapshot then
    return entries
  end

  for _, effect_def in ipairs(auto_active_effects_system.get_effect_defs() or {}) do
    if #entries >= limit then
      break
    end
    local snapshot = auto_active_effects_system.get_effect_runtime_snapshot(effect_def.id)
    local entry = build_bottom_status_effect_entry(effect_def, snapshot)
    if entry then
      entries[#entries + 1] = entry
    end
  end

  return entries
end

local function resolve_damage_meta(damage)
  if type(damage) == 'table' then
    return {
      damage_type = damage.damage_type or '法术',
      damage_form = damage.damage_form or (damage.damage_type == '物理' and 'weapon' or 'spell'),
      element = damage.element or 'none',
      damage_label = damage.damage_label or (damage.damage_type == '物理' and '兵刃伤害' or '术法伤害'),
    }
  end

  local legacy_damage_type = damage or '法术'
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

local STATE = boot_core.create_initial_state()

local function get_player()
  return y3.player(CONFIG.player_id)
end

local function get_enemy_player()
  return y3.player(CONFIG.enemy_player_id)
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
    'BondChoice2',
    'BondChoice3',
    'BondChoice4',
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

audio_system = AudioSystem.create({
  STATE = STATE,
  y3 = y3,
  get_player = get_player,
  trace = function() end,
})

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

local function register_dev_commands()
  debug_tools_system.register_dev_commands()
  if gm_bond_effects_system and gm_bond_effects_system.register_dev_commands then
    gm_bond_effects_system.register_dev_commands()
  end
end

function ReservedRuntimeApi.has_unit_data(unit_id)
  return battlefield_system.has_unit_data(unit_id)
end

local function is_active_enemy(unit)
  return battlefield_system.is_active_enemy(unit)
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

local BOND_AUDIO_ELEMENT = {
  ['龙骑士'] = 'fire',
  ['枪炮师'] = 'earth',
  ['寒冰法师'] = 'water',
  ['冰霜法师'] = 'water',
  ['雷电法王'] = 'wood',
  ['火法师'] = 'fire',
  ['骷髅法师'] = 'wood',
  ['猎人'] = 'wind',
  ['狂战士'] = 'metal',
  ['剑魂'] = 'metal',
  ['剑宗'] = 'metal',
  ['魔剑士'] = 'thunder',
  ['战斗法师'] = 'thunder',
  ['战法法师'] = 'thunder',
  ['游侠'] = 'wind',
  ['风暴萨满'] = 'wind',
  ['神射手'] = 'metal',
}

local function play_bond_sound(bond_name, stage, anchor)
  if not audio_system or not audio_system.play_attack_skill then
    return nil
  end
  local state = STATE
  state.bond_audio_gate = state.bond_audio_gate or {}
  local gate_key = string.format('%s:%s', tostring(bond_name or 'bond'), tostring(stage or 'cast'))
  local now = os.clock and os.clock() or 0
  local next_time = tonumber(state.bond_audio_gate[gate_key]) or 0
  if next_time > now then
    return nil
  end
  state.bond_audio_gate[gate_key] = now + 0.10

  local skill_stub = {
    id = 'bond_' .. tostring(bond_name or 'generic'),
    element = BOND_AUDIO_ELEMENT[bond_name] or 'none',
    damage_form = 'spell',
  }
  return audio_system.play_attack_skill(skill_stub, anchor or STATE.hero, stage or 'cast')
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
    reserve_formula_damage = reserve_formula_damage,
    basic_attack_damage_type = ATTACK_SKILL_DEFS.basic_attack.damage_type,
    get_player = get_player,
    play_bond_sound = play_bond_sound,
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
  BondSystem.notify_basic_attack(create_bond_env(), target)
  BondSystem.try_trigger_hunter_first_hit(create_bond_env(), target)
end

local function build_reward_with_bond_bonus(reward)
  return BondSystem.build_reward_with_bonus(create_bond_env(), reward)
end

local DAMAGE_AREA_DEBUG_EFFECT_ID = 101492
local DAMAGE_AREA_DEBUG_SCALE_BASE = 110
local DAMAGE_AREA_DEBUG_HEIGHT = 8

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
  pcall(y3.particle.create, {
    type = DAMAGE_AREA_DEBUG_EFFECT_ID,
    target = center,
    scale = scale,
    time = duration or 0.30,
    height = DAMAGE_AREA_DEBUG_HEIGHT,
    immediate = true,
  })
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


deal_skill_damage = function(target, amount, damage, visual)
  if not STATE.hero or not STATE.hero:is_exist() or not is_active_enemy(target) then
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
  show_damage_area_indicator(get_target_point(target), tonumber(visual and visual.debug_radius) or 70, 0.24)

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
end

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
    for _, challenge_id in ipairs({ 'gold_trial', 'wood_trial', 'exp_trial', 'treasure_trial' }) do
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
    element = 'metal',
    damage_label = '金行剑罡',
  }
  local basic_attack_vfx = AttackSkillObjects.vfx_by_id.basic_attack or {}
  local basic_chain_particle = basic_attack_vfx.chain_particle
      or basic_attack_vfx.impact_particle
  if CONFIG.damage_hit_effect_enabled == false or is_hit_effect_hidden() then
    basic_chain_particle = nil
  end

  if skill.normal_attack_bonus_ratio > 0 then
    deal_skill_damage(target, data.damage * skill.normal_attack_bonus_ratio, '物理', {
      text_type = 'physics',
    })
  end

  if skill.splash_ratio > 0 then
    for _, unit in ipairs(get_enemies_in_range(target, skill.splash_radius, target)) do
      deal_skill_damage(unit, data.damage * skill.splash_ratio, '物理', {
        text_type = 'physics',
      })
    end
  end

  if skill.chain_bounces > 0 and skill.chain_chance > 0 and math.random() <= skill.chain_chance then
    local bounced = 0
    for _, unit in ipairs(get_enemies_in_range(chain_center, skill.chain_radius, target, skill.chain_bounces)) do
      deal_skill_damage(unit, data.damage * skill.chain_ratio, basic_attack_def, {
        particle = basic_chain_particle,
      })
      bounced = bounced + 1
      if bounced >= skill.chain_bounces then
        break
      end
    end
  end

  local bond_chain_bounces = math.max(0, round_number(
    get_bond_runtime_bonus('chain_bounces') + get_hero_attr_value('弹射次数')
  ))
  local bond_chain_ratio = 0.30 + math.max(0,
    normalize_ratio(get_bond_runtime_bonus('chain_ratio'))
    + get_hero_attr_ratio('弹射伤害')
  )
  if bond_chain_bounces > 0 and bond_chain_ratio > 0 then
    local bounced = 0
    for _, unit in ipairs(get_enemies_in_range(
      chain_center,
      math.max(skill.chain_radius or 0, 420),
      target,
      bond_chain_bounces
    )) do
      deal_skill_damage(unit, data.damage * bond_chain_ratio, basic_attack_def, {
        particle = basic_chain_particle,
        skip_hunter_first_hit = true,
      })
      bounced = bounced + 1
      if bounced >= bond_chain_bounces then
        break
      end
    end
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
  reward_system.queue_treasure_round(instance.def.id, instance.def.name)
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
  play_enemy_death_sound = function(unit, info)
    return audio_system and audio_system.play_enemy_death and
        audio_system.play_enemy_death(unit, info and info.kind == 'boss') or nil
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

local function get_upgrade_pick_count(upgrade_key)
  return attack_skills_system.get_upgrade_pick_count(upgrade_key)
end

local function record_upgrade_pick(upgrade_key)
  return attack_skills_system.record_upgrade_pick(upgrade_key)
end

local function build_attack_skill_slot_text(slot)
  return attack_skills_system.build_attack_skill_slot_text(slot)
end

show_attack_skill_loadout = function()
  return attack_skills_system.show_attack_skill_loadout()
end

local function unlock_attack_skill(skill_id)
  local skill, slot, is_new = attack_skills_system.unlock_attack_skill(skill_id)
  if is_new and STATE.treasure_runtime and STATE.treasure_runtime.applied then
    reward_system.apply_treasure_bonus_to_attack_skill(
      skill_id,
      skill,
      STATE.treasure_runtime.applied.attack_skill or {},
      1
    )
  end
  if is_new and STATE.mark_runtime and STATE.mark_runtime.applied then
    reward_system.apply_treasure_bonus_to_attack_skill(
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

attack_upgrade_system = AttackUpgradeSystem.create({
  STATE = STATE,
  message = message,
  ATTACK_SKILL_DEFS = ATTACK_SKILL_DEFS,
  ATTACK_SKILL_BLUEPRINTS = ATTACK_SKILL_BLUEPRINTS,
  get_attack_skill = get_attack_skill,
  get_empty_attack_skill_slot = get_empty_attack_skill_slot,
  get_unlocked_attack_skill_count = get_unlocked_attack_skill_count,
  get_upgrade_pick_count = get_upgrade_pick_count,
  record_upgrade_pick = record_upgrade_pick,
  unlock_attack_skill = unlock_attack_skill,
  sync_basic_attack_ability = sync_basic_attack_ability,
  build_attack_skill_slot_text = build_attack_skill_slot_text,
  collect_bond_route_tags = function()
    return BondSystem.collect_route_tags(STATE)
  end,
  has_active_treasure = function(treasure_id)
    return STATE.treasure_runtime
        and STATE.treasure_runtime.active_by_id
        and STATE.treasure_runtime.active_by_id[treasure_id] ~= nil
  end,
})

local function get_pending_round_choice_kind()
  if STATE.awaiting_upgrade and STATE.current_upgrade_choices then
    return 'upgrade'
  end
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
  if STATE.treasure_runtime then
    if STATE.treasure_runtime.awaiting_choice and STATE.treasure_runtime.current_choices then
      return 'treasure'
    end
    if STATE.treasure_runtime.awaiting_replace and STATE.treasure_runtime.pending_replace_choice then
      return 'treasure'
    end
  end
  return nil
end

local function get_pending_round_choice_label(kind)
  if kind == 'upgrade' then
    return 'G 技能强化'
  end
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
  if kind == 'treasure' then
    return '宝物选择'
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
  if current_kind == 'upgrade' then
    return show_upgrade_choices()
  end
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
    show_treasure_choices()
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

local function show_upgrade_choices()
  if not ensure_round_choice_available('upgrade') then
    return false
  end
  if attack_upgrade_system and attack_upgrade_system.show_upgrade_choices then
    return attack_upgrade_system.show_upgrade_choices()
  end
  return false
end

local function apply_upgrade(index)
  local result = attack_upgrade_system.apply_upgrade(index)
  STATE.choice_panel_hidden = false
  reward_system.sync_mark_effects()
  reward_system.sync_treasure_effects()
  try_open_queued_treasure_round()
  return result
end

local function apply_bond_choice(index)
  BondSystem.apply_choice(create_bond_env(), index)
  STATE.choice_panel_hidden = false
  try_open_queued_treasure_round()
end

local function apply_round_choice(index)
  local kind = get_pending_round_choice_kind()

  if kind == 'upgrade' then
    apply_upgrade(index)
    return true
  end

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
    reward_system.apply_treasure_choice(index)
    STATE.choice_panel_hidden = false
    return true
  end

  return false
end

local function refresh_current_choice()
  STATE.choice_panel_hidden = false
  local kind = get_pending_round_choice_kind()

  if kind == 'upgrade' then
    return attack_upgrade_system and attack_upgrade_system.refresh_upgrade_choices
        and attack_upgrade_system.refresh_upgrade_choices()
        or false
  end

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

  if kind == 'treasure' and STATE.treasure_runtime and STATE.treasure_runtime.awaiting_replace then
    message('当前已选中新的宝物，请先指定要替换的宝物位。')
    return false
  end

  if kind == 'treasure' and STATE.treasure_runtime and STATE.treasure_runtime.awaiting_choice then
    return reward_system.refresh_treasure_choices()
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
  show_upgrade_choices = show_upgrade_choices,
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
  debug_open_upgrade_panel = function()
    return debug_actions_system.debug_open_upgrade_panel()
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
  if has_pending_treasure_choice() then
    STATE.choice_panel_hidden = false
    show_pending_round_choice('treasure')
    return true
  end

  try_open_queued_treasure_round()
  if not ensure_round_choice_available('treasure') then
    return false
  end
  if has_pending_treasure_choice() then
    STATE.choice_panel_hidden = false
    show_pending_round_choice('treasure')
    return true
  end

  message('当前没有待领取的宝物三选一。')
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
  show_upgrade_choices = show_upgrade_choices,
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
  local panel_name = #choices <= 2 and 'BondChoice2' or (#choices >= 4 and 'BondChoice4' or 'BondChoice3')
  local panel_index = #choices <= 2 and '2' or (#choices >= 4 and '4' or '3')
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

local raw_refresh_choice_panel = runtime_ui_helpers.refresh_choice_panel
runtime_ui_helpers.refresh_choice_panel = function(...)
  local result = raw_refresh_choice_panel(...)
  apply_bond_choice_quality_frames()
  return result
end

cannon_skill_134258724_system = CannonSkill134258724System.create({
  STATE = STATE,
  y3 = y3,
  hero_attr_system = hero_attr_system,
  get_enemies_in_range = get_enemies_in_range,
  deal_skill_damage = deal_skill_damage,
})

runtime_ui_helpers.install_panel_systems()

local raw_set_battle_hud_visible = runtime_ui_helpers.set_battle_hud_visible
set_battle_hud_visible = function(visible)
  if visible == true and STATE.archive_panel_visible == true then
    local result = raw_set_battle_hud_visible(false)
    enforce_runtime_ui_phase(false)
    return result
  end
  local result = raw_set_battle_hud_visible(visible)
  enforce_runtime_ui_phase(visible == true)
  if runtime_ui_helpers and runtime_ui_helpers.refresh_bond_swallow_panel then
    runtime_ui_helpers.refresh_bond_swallow_panel()
  end
  return result
end

local function create_hero()
  return battlefield_system.create_hero(ATTACK_SKILL_DEFS.basic_attack.base_range or 250)
end

local function validate_config()
  return battlefield_system.validate_config()
end

hero_selection_range_system = HeroSelectionRangeSystem.create({
  STATE = STATE,
  y3 = y3,
  is_battle_active = function()
    return STATE.session_phase == 'battle' and STATE.game_finished ~= true
  end,
  get_current_basic_attack_range = function()
    return attack_skills_system and attack_skills_system.get_current_basic_attack_range and
        attack_skills_system.get_current_basic_attack_range() or 0
  end,
})

session_state_system = BootSession.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  hero_attr_system = hero_attr_system,
  make_point = make_point,
  get_resource_rules = get_resource_rules,
  create_bond_runtime = create_bond_runtime,
  create_battle_event_feed_runtime = create_battle_event_feed_runtime,
  create_effect_debug_runtime = create_effect_debug_runtime,
  create_mark_runtime = reward_system.create_evolution_runtime,
  create_treasure_runtime = reward_system.create_treasure_runtime,
  create_skill_runtime = create_skill_runtime,
  create_attack_skill_state = create_attack_skill_state,
  ATTACK_SKILL_BLUEPRINTS = ATTACK_SKILL_BLUEPRINTS,
  destroy_choice_panel = runtime_ui_helpers.destroy_choice_panel,
  battlefield_system = battlefield_system,
  get_player = get_player,
  get_enemy_player = get_enemy_player,
  create_hero = create_hero,
  initialize_hero_progression = progression_system.initialize_hero_progression,
  ensure_gear_runtime = function(state, config)
    return GearUpgrades.ensure_runtime(state, config)
  end,
  sync_gear_items_to_hero = function(state, hero, config)
    return GearUpgrades.sync_items_to_hero(state, hero, config)
  end,
  sync_gear_runtime_effects = function(state, hero, config)
    return GearUpgrades.sync_runtime_bonuses(state, hero, config, hero_attr_system)
  end,
  unlock_attack_skill = unlock_attack_skill,
  show_attack_skill_loadout = show_attack_skill_loadout,
  setup_basic_attack_ability = setup_basic_attack_ability,
  ensure_runtime_hud = runtime_ui_helpers.ensure_runtime_hud,
  set_battle_hud_visible = function(visible)
    return set_battle_hud_visible(visible)
  end,
  refresh_runtime_hud = runtime_ui_helpers.refresh_runtime_hud,
  enter_battle_audio = function()
    return audio_system and audio_system.enter_battle and audio_system.enter_battle() or nil
  end,
  disable_local_attack_preview = function()
    return hero_selection_range_system
        and hero_selection_range_system.disable_local_preview
        and hero_selection_range_system.disable_local_preview()
        or false
  end,
  get_outgame_system = function()
    return outgame_system
  end,
  start_wave = function(index)
    return RuntimeEntry.start_wave(index)
  end,
})

is_battle_active = function()
  return session_state_system.is_battle_active()
end

reset_battle_state = function()
  return session_state_system.reset_battle_state()
end

reset_session_state = function()
  return session_state_system.reset_session_state()
end

outgame_system = OutgameSystem.create({
  STATE = STATE,
  CONFIG = CONFIG,
  y3 = y3,
  message = message,
  round_number = round_number,
  get_player = get_player,
  stage_runtime = {
    get_current_stage_text = function()
      if STATE.current_stage_def and (STATE.current_stage_def.display_label or STATE.current_stage_def.display_name) then
        return STATE.current_stage_def.display_label or STATE.current_stage_def.display_name
      end
      return '第1关'
    end,
    start_selected_stage = function(stage_id, mode_id)
      return session_state_system.start_selected_stage(stage_id, mode_id)
    end,
  },
  play_ui_click = function()
    return audio_system and audio_system.play_ui_click and audio_system.play_ui_click() or nil
  end,
  ensure_music_loop = function()
    return audio_system and audio_system.ensure_music_loop and audio_system.ensure_music_loop() or nil
  end,
  set_battle_hud_visible = function(visible)
    return set_battle_hud_visible(visible)
  end,
})

input_events_system = BootInput.create({
  STATE = STATE,
  y3 = y3,
  message = message,
  is_battle_active = function()
    return is_battle_active()
  end,
  get_hero_max_level = progression_system.get_hero_max_level,
  sync_hero_progress_from_engine = progression_system.sync_hero_progress_from_engine,
  try_queue_mark_node_for_level = reward_system.try_queue_evolution_node_for_level,
  grant_attr_diamond = function(count, level)
    return attr_choice_system and attr_choice_system.grant_diamond and attr_choice_system.grant_diamond(count, level) or
        nil
  end,
  show_upgrade_choices = show_upgrade_choices,
  try_bond_draw = try_bond_draw,
  show_bond_progress = function()
    return open_bond_card_album()
  end,
  show_runtime_attr_overview = function()
    show_runtime_attr_dialog()
  end,
  show_runtime_attr_tip_panel = function()
    runtime_ui_helpers.show_runtime_attr_tip_panel(8)
  end,
  show_runtime_attr_dialog = show_runtime_attr_dialog,
  refresh_runtime_overview = runtime_ui_helpers.refresh_runtime_overview,
  start_current_task_challenge = function()
    return mainline_task_system and mainline_task_system.start_current_task_challenge and
        mainline_task_system.start_current_task_challenge() or nil
  end,
  try_start_challenge = try_start_challenge,
  try_evolution_entry = try_evolution_entry,
  try_treasure_entry = try_treasure_entry,
  apply_round_choice = apply_round_choice,
  show_runtime_status = show_runtime_status,
  toggle_talk_input = runtime_ui_helpers.toggle_talk_input,
  toggle_inventory_panel = runtime_ui_helpers.toggle_inventory_panel,
  open_save_panel = function()
    return open_runtime_save_panel()
  end,
  try_upgrade_growth_weapon = BattleEventPrompts.try_upgrade_growth_weapon,
  use_attr_diamond = use_attr_diamond,
  show_debug_hotkey_help = show_debug_hotkey_help,
  debug_actions_system = debug_actions_system,
  debug_tools_system = debug_tools_system,
  gm_bond_effects_system = gm_bond_effects_system,
})

hero_tujian_panel_system = BootHeroTujian.create({
  STATE = STATE,
  y3 = y3,
  get_player = get_player,
  message = message,
  get_audio_system = function()
    return audio_system
  end,
  get_outgame_system = function()
    return outgame_system
  end,
})

local function register_runtime_events()
  BootEvents.register({
    input_events_system = input_events_system,
    hero_selection_range_system = hero_selection_range_system,
  })
end

runtime_loops_system = BootLoops.create({
  STATE = STATE,
  y3 = y3,
  hero_attr_system = hero_attr_system,
  is_battle_active = function()
    return is_battle_active()
  end,
  update_passive_resources = update_passive_resources,
  battlefield_system = battlefield_system,
  update_bond_effects = update_bond_effects,
  update_auto_active_effects = update_auto_active_effects,
  update_effect_debug = update_effect_debug,
  update_enemy_statuses = update_enemy_statuses,
  update_attack_skills = update_attack_skills,
  update_temporary_treasures = reward_system.update_temporary_treasures,
  update_mainline_task = function(dt)
    return mainline_task_system and mainline_task_system.update and mainline_task_system.update(dt) or nil
  end,
  update_battle_auto_acceptance = function(dt)
    if battle_auto_acceptance_system and battle_auto_acceptance_system.update then
      return battle_auto_acceptance_system.update(dt)
    end
    return nil
  end,
  ensure_runtime_hud = runtime_ui_helpers.ensure_runtime_hud,
  ensure_choice_panel = runtime_ui_helpers.ensure_choice_panel,
  set_battle_hud_visible = set_battle_hud_visible,
  refresh_runtime_hud = runtime_ui_helpers.refresh_runtime_hud,
  refresh_choice_panel = runtime_ui_helpers.refresh_choice_panel,
  refresh_runtime_overview = runtime_ui_helpers.refresh_runtime_overview,
  refresh_inventory_panel = runtime_ui_helpers.refresh_inventory_panel,
  outgame_system = outgame_system,
  gm_bond_effects_system = gm_bond_effects_system,
  is_active_enemy = is_active_enemy,
  get_enemies_in_range = get_enemies_in_range,
  deal_skill_damage = deal_skill_damage,
  hero_tujian_panel_system = hero_tujian_panel_system,
})

local function start_runtime_loops()
  return runtime_loops_system.start_runtime_loops()
end

function RuntimeEntry.bootstrap()
  if not validate_config() then
    return
  end

  ensure_helper_signals()
  reset_session_state()
  register_runtime_events()
  cannon_skill_134258724_system.register()
  register_dev_commands()
  start_runtime_loops()
  if gm_bond_effects_system and gm_bond_effects_system.ensure_board then
    gm_bond_effects_system.ensure_board()
    gm_bond_effects_system.refresh_board()
  end
  outgame_system.load_profile()
  outgame_system.enter_outgame()
end

return RuntimeEntry

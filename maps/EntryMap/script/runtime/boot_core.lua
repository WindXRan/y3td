local M = {}

local SHARED_RUNTIME_FIELDS = {
  split_count = 0,
  split_ratio = 0,
  boss_bonus_ratio = 0,
  armor_break_ratio = 0,
  armor_break_duration = 0,
  armor_break_max_stacks = 0,
  secondary_targets = 0,
  burst_radius = 0,
  burst_ratio = 0,
  ignite_duration = 0,
  ignite_tick_ratio = 0,
  ignite_spread_radius = 0,
  frost_control_bonus = 0,
  shatter_bonus = 0,
  shard_count = 0,
  shard_ratio = 0,
  shock_duration = 0,
  shock_bonus = 0,
  field_radius = 0,
  field_ratio = 0,
  apply_generic_armor_break = false,
  apply_generic_ignite = false,
  apply_generic_shock = false,
  apply_generic_control = false,
  generic_status_duration = 0,
  terminal_burst_radius = 0,
  terminal_burst_ratio = 0,
  followup_count = 0,
  followup_ratio = 0,
  split_seek_count = 0,
  split_seek_ratio = 0,
  split_seek_radius = 0,
  split_seek_depth = 0,
  kill_seek_count = 0,
  kill_seek_ratio = 0,
  kill_seek_radius = 0,
  echo_count = 0,
  echo_ratio = 0,
  return_pass_enabled = false,
  return_pass_ratio = 0.75,
  sweep_enabled = false,
  field_track_target = false,
  persistent_field_duration = 0,
  persistent_field_ratio = 0,
  persistent_field_control = false,
  persistent_field_ignite = false,
  pull_strength = 0,
}

local function copy_fields(template)
  local result = {}
  for k, v in pairs(template) do
    result[k] = v
  end
  return result
end

--- 技能修正值对象：封装 chain / splash / artillery / medbot / evolution 等
local SkillRuntime = {}
SkillRuntime.__index = SkillRuntime

function SkillRuntime.create()
  local data = copy_fields(SHARED_RUNTIME_FIELDS)
  data.normal_attack_bonus_ratio = 0
  data.splash_ratio = 0
  data.splash_radius = 220
  data.chain_chance = 0
  data.chain_bounces = 0
  data.chain_ratio = 0
  data.chain_radius = 420
  data.execute_threshold = 0
  data.medbot_every = 0
  data.medbot_heal = 0
  data.medbot_kills = 0
  data.artillery_interval = 0
  data.artillery_ratio = 0
  data.artillery_base = 0
  data.artillery_radius = 0
  data.artillery_cd = 0
  data.bonus_gold_on_kill = 0

  return setmetatable({
    -- 通用读写
    get = function(_, key) return data[key] end,
    set = function(_, key, value) data[key] = value end,

    --- 链式攻击属性（攻击技能系统高频读取）
    get_chain = function()
      return data.chain_bounces, data.chain_chance, data.chain_ratio, data.chain_radius
    end,

    --- 溅射属性
    get_splash = function()
      return data.splash_ratio, data.splash_radius
    end,

    --- 医疗机器人：敌人击杀计数，达到阈值触发回血
    --- @param kills_increment number 本次击杀数
    --- @return number|nil 触发的治疗量，未触发返回 nil
    try_medbot_heal = function(_, kills_increment)
      if data.medbot_every <= 0 or data.medbot_heal <= 0 then return nil end
      data.medbot_kills = data.medbot_kills + (kills_increment or 1)
      if data.medbot_kills >= data.medbot_every then
        data.medbot_kills = data.medbot_kills - data.medbot_every
        return data.medbot_heal
      end
      return nil
    end,

    --- 炮击冷却推进
    advance_artillery_cd = function(_, amount)
      data.artillery_cd = (data.artillery_cd or 0) + (amount or 0)
    end,
    --- 炮击就绪判断
    is_artillery_ready = function()
      return data.artillery_interval > 0 and data.artillery_radius > 0
          and data.artillery_ratio > 0 and data.artillery_cd >= data.artillery_interval
    end,
    --- 消耗炮击
    consume_artillery = function()
      data.artillery_cd = 0
      return data.artillery_base, data.artillery_ratio, data.artillery_radius
    end,

    --- 击杀金币奖励
    get_bonus_gold_on_kill = function() return data.bonus_gold_on_kill end,

    --- 应用进化/羁绊加成
    --- @param bonuses table { damage_ratio, repeat_count, range_bonus, cooldown_reduction, ... }
    apply_evolution_bonus = function(_, bonuses)
      for key, value in pairs(bonuses) do
        if data[key] ~= nil and type(value) == 'number' then
          if key == 'repeat_count' then
            data[key] = math.max(1, (data[key] or 1) + value)
          else
            data[key] = math.max(0, (data[key] or 0) + value)
          end
        end
      end
    end,

    --- 导出为纯表（用于保存/传递）
    to_table = function() return data end,
  }, SkillRuntime)
end

--- 技能实例工厂
function M.create_attack_skill_instance(skill_id, slot)
  local def = M.ATTACK_SKILL_DEFS[skill_id]
  local blueprint = M.ATTACK_SKILL_BLUEPRINTS.by_id and M.ATTACK_SKILL_BLUEPRINTS.by_id[skill_id] or nil
  local blueprint_base = blueprint and blueprint.base or {}
  local instance = copy_fields(SHARED_RUNTIME_FIELDS)
  instance.id = def.id
  instance.name = def.name
  instance.slot = slot or def.default_slot or 0
  instance.summary = def.summary
  instance.archetype = def.archetype or (blueprint and blueprint.archetype) or nil
  instance.category = def.category or nil
  instance.cast_family = def.cast_family or nil
  instance.presentation_family = def.presentation_family or nil
  instance.eca_reference = def.eca_reference or nil
  instance.ui_icon = def.ui_icon or (blueprint and (blueprint.ui_icon or blueprint.icon)) or nil
  instance.icon = def.icon or def.ui_icon or (blueprint and (blueprint.icon or blueprint.ui_icon)) or nil
  instance.evolution_name = def.evolution_name or (blueprint and blueprint.evolution and blueprint.evolution.name) or nil
  instance.evolution_summary = def.evolution_summary or (blueprint and blueprint.evolution and blueprint.evolution.summary) or nil
  instance.damage_type = def.damage_type
  instance.damage_form = def.damage_form
  instance.element = def.element
  instance.damage_label = def.damage_label
  instance.level = 1
  instance.unlocked = true
  instance.damage_ratio = def.base_damage_ratio or 0
  instance.base_cooldown = def.base_cooldown or 0
  instance.cooldown_reduction = 0
  instance.cooldown_remaining = 0
  instance.cast_range = def.base_range or 0
  instance.range_bonus = 0
  instance.attack_speed_bonus = 0
  instance.pierce = def.base_pierce or 0
  instance.pierce_width = def.base_pierce_width or 90
  instance.base_duration = def.base_duration or blueprint_base.duration or 0
  instance.base_radius = def.base_radius or blueprint_base.radius or 0
  instance.base_bounce = def.base_bounce or blueprint_base.bounce or 0
  instance.repeat_count = def.base_repeat_count or 1
  instance.explosion_ratio = def.base_explosion_ratio or 0
  instance.explosion_radius = def.base_explosion_radius or 0
  instance.extra_targets = def.base_extra_targets or 0
  instance.control_lock_time = def.base_control_lock_time or 0
  instance.knockback_distance = def.base_knockback_distance or 0
  instance.knockback_speed = def.base_knockback_speed or 900
  return instance
end

--- 技能状态对象：管理技能槽位
local SkillState = {}
SkillState.__index = SkillState

function SkillState.create()
  local basic_attack = M.create_attack_skill_instance('basic_attack', 1)
  local data = {
    slots = { [1] = basic_attack },
    by_id = { basic_attack = basic_attack },
    new_skill_feed = {},
  }

  return setmetatable({
    get_slot = function(_, n) return data.slots[n] end,
    set_slot = function(_, n, skill) data.slots[n] = skill end,
    get_skill = function(_, id) return data.by_id[id] end,
    add_skill = function(_, skill) data.by_id[skill.id] = skill end,
    get_all_slots = function() return data.slots end,
    get_all_skills = function() return data.by_id end,
    add_new_skill_feed = function(_, skill) data.new_skill_feed[#data.new_skill_feed + 1] = skill end,
    to_table = function() return data end,
  }, SkillState)
end

--- 创建初始 STATE
function M.create_initial_state()
  return {
    hero = nil,
    hero_common_attack = nil,
    hero_spawn_point = nil,
    defense_point = nil,
    all_enemies = nil,
    total_enemy_alive = 0,
    total_kills = 0,
    current_wave_index = 0,
    started_wave_count = 0,
    active_wave = nil,
    active_challenges = nil,
    resources = nil,
    resource_income_elapsed = 0,
    battle_event_feed = nil,
    effect_debug_runtime = nil,
    evolution_runtime = nil,
    auto_active_effects = nil,
    enemy_info_map = nil,
    hero_progress = nil,
    skill_runtime = nil,
    attack_skill_state = nil,
    reward_queue = nil,
    challenge_charges = 0,
    challenge_recover_elapsed = 0,
    defeated_boss_waves = nil,
    basic_attack_ability_bound = false,
    basic_attack_ability_warned = false,
    debug_ctrl_down_count = 0,
    runtime_elapsed = 0,
    runtime_hud = nil,
    choice_panel = nil,
    choice_panel_hidden = false,
    runtime_overview = nil,
    runtime_overview_mode = 'build',
    runtime_attr_tab_panel = nil,
    runtime_attr_tab_selected = 'summary',
    hero_attr_runtime = nil,
    attr_choice_runtime = nil,
    gm_ui = nil,
    session_phase = 'outgame',
    outgame_profile = nil,
    selected_stage_id = nil,
    selected_mode_id = nil,
    current_stage_def = nil,
    current_mode_def = nil,
    last_battle_result = nil,
    outgame_ui = nil,
    outgame_profile_save_enabled = false,
    outgame_profile_save_warned = false,
    game_finished = false,
  }
end

function M.create(args)
  local AttackSkillObjects = assert(args and args.AttackSkillObjects, 'AttackSkillObjects is required')
  M.ATTACK_SKILL_DEFS = AttackSkillObjects.defs_by_id
  M.ATTACK_SKILL_BLUEPRINTS = AttackSkillObjects.blueprints
  local ATTACK_SKILL_SLOT_COUNT = 5

  return {
    ATTACK_SKILL_DEFS = M.ATTACK_SKILL_DEFS,
    ATTACK_SKILL_BLUEPRINTS = M.ATTACK_SKILL_BLUEPRINTS,
    ATTACK_SKILL_SLOT_COUNT = ATTACK_SKILL_SLOT_COUNT,
    SkillRuntime = SkillRuntime,
    SkillState = SkillState,
    create_attack_skill_instance = M.create_attack_skill_instance,
    create_initial_state = M.create_initial_state,
  }
end

return M

local M = {}
local y3 = y3
local CONFIG = require 'config.entry_config'
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers

local env
local STATE = env and env.STATE or _G.STATE
  local round_number = BootHelpers.round_number
  local message = env and env.message or _G.message
  local hero_attr_system = env and env.hero_attr_system or _G.hero_attr_system

  local function on_hero_level_up(level)
    local acs = _G.attr_choice_system
    if acs and acs.grant_diamond then acs.grant_diamond(1, level) end
    local rs = _G.reward_system
    if rs and rs.try_queue_evolution_node_for_level then rs.try_queue_evolution_node_for_level(level) end
  end

  local function get_hero_progression_rules()
    return CONFIG.hero_progression or {}
  end

  local function get_resource_rules()
    return CONFIG.resource_rules or {}
  end

  local function get_hero_max_level()
    local level_table = CONFIG.hero_level_progression
    if level_table and type(level_table.max_level) == 'number' and level_table.max_level > 0 then
      return math.max(1, level_table.max_level)
    end
    local rules = get_hero_progression_rules()
    return math.max(1, rules.max_level or 60)
  end

  local function get_engine_exp_cap_level()
    local rules = get_hero_progression_rules()
    return math.max(1, rules.engine_exp_cap_level or 15)
  end

  local function get_post_cap_exp_required(level)
    local rules = get_hero_progression_rules()
    local base = rules.post_cap_exp_base or 260
    local step = rules.post_cap_exp_step or 40
    local offset = math.max(0, level - get_engine_exp_cap_level())
    return math.max(1, base + step * offset)
  end

  local function get_hero_level()
    if STATE.hero_progress then
      return STATE.hero_progress.level or 1
    end
    if STATE.hero and STATE.hero:is_exist() then
      return STATE.hero:get_level()
    end
    return 1
  end

  local function get_hero_next_level_exp(level)
    local level_table = CONFIG.hero_level_progression
    local level_row = level_table and level_table.by_level and level_table.by_level[level] or nil
    if level_row and level_row.exp_to_next ~= nil then
      return math.max(0, level_row.exp_to_next)
    end

    if level >= get_hero_max_level() then
      return 0
    end

    if STATE.hero and STATE.hero:is_exist()
      and level < get_engine_exp_cap_level()
      and STATE.hero:get_level() == level then
      local required = round_number(y3.helper.tonumber(STATE.hero:get_upgrade_exp()) or 0)
      if required > 0 then
        return required
      end
    end

    if level < get_engine_exp_cap_level() then
      return math.max(1, 60 + (level - 1) * 20)
    end

    return get_post_cap_exp_required(level)
  end

  local function sync_hero_progression()
    local progress = STATE.hero_progress
    if not progress then
      return
    end

    progress.level = math.max(1, math.min(progress.level or 1, get_hero_max_level()))
    progress.exp = math.max(0, progress.exp or 0)
    progress.exp_to_next = get_hero_next_level_exp(progress.level)

    if STATE.hero and STATE.hero:is_exist() then
      STATE.hero:set_level(progress.level)
      STATE.hero:set_exp(0)
      STATE.hero:set_ability_point(0)
    end
  end

  local function initialize_hero_progression()
    STATE.hero_progress = {
      level = 1,
      exp = 0,
      exp_to_next = 0,
      total_exp = 0,
      applied_growth_level = 1,
    }
    sync_hero_progression()
  end

  local function get_level_growth_pack(level_count)
    local rules = get_hero_progression_rules()
    local count = math.max(0, tonumber(level_count) or 0)
    if count <= 0 then
      return nil
    end

    local attack_growth = (tonumber(rules.hero_level_attack_growth) or 0) * count

    return {
      ['攻击'] = attack_growth,
      ['生命'] = (tonumber(rules.hero_level_hp_growth) or 0) * count,
    }
  end

  local function apply_attr_pack_to_hero(hero, attr_pack)
    for attr_name, value in pairs(attr_pack) do
      if value ~= 0 then
        if hero_attr_system and hero_attr_system.add_attr then
          hero_attr_system.add_attr(hero, attr_name, value)
        elseif hero.add_attr then
          hero:add_attr(attr_name, value)
        end
      end
    end
    if hero_attr_system and hero_attr_system.rebuild_derived_attrs then
      hero_attr_system.rebuild_derived_attrs(hero)
    end
  end

  local function apply_hero_level_growth(target_level)
    local progress = STATE.hero_progress
    if not progress or not STATE.hero or not STATE.hero:is_exist() then
      return false
    end

    local applied_level = math.max(1, tonumber(progress.applied_growth_level) or 1)
    local new_level = math.max(applied_level, tonumber(target_level) or applied_level)
    local level_count = new_level - applied_level
    local growth_pack = get_level_growth_pack(level_count)
    if not growth_pack then
      progress.applied_growth_level = new_level
      return false
    end

    apply_attr_pack_to_hero(STATE.hero, growth_pack)

    local hp_growth = tonumber(growth_pack['生命']) or 0
    if hp_growth > 0 and STATE.hero.add_hp then
      STATE.hero:add_hp(hp_growth)
    end
    progress.last_growth_pack = growth_pack
    progress.last_growth_from_level = applied_level + 1
    progress.last_growth_to_level = new_level
    progress.applied_growth_level = new_level
    return true
  end

  local function sync_hero_progress_from_engine()
    if not STATE.hero_progress or not STATE.hero or not STATE.hero:is_exist() then
      return
    end

    local progress = STATE.hero_progress
    local engine_cap_level = get_engine_exp_cap_level()
    local current_level = math.max(1, math.min(tonumber(progress.level) or 1, get_hero_max_level()))
    local engine_level = math.max(1, math.min(tonumber(STATE.hero:get_level()) or 1, engine_cap_level))

    if engine_cap_level <= 1 or current_level >= engine_cap_level or engine_level < current_level then
      progress.level = current_level
      progress.exp = math.max(0, tonumber(progress.exp) or 0)
      progress.exp_to_next = get_hero_next_level_exp(progress.level)
      STATE.hero:set_exp(0)
      STATE.hero:set_ability_point(0)
      return
    end

    progress.level = engine_level
    progress.exp = math.max(0, round_number(y3.helper.tonumber(STATE.hero:get_exp()) or 0))
    progress.exp_to_next = get_hero_next_level_exp(progress.level)
    apply_hero_level_growth(progress.level)
  end

  local function get_hero_progress_text()
    local progress = STATE.hero_progress
    if not progress then
      return string.format('Lv%d', get_hero_level())
    end

    if progress.exp_to_next and progress.exp_to_next > 0 then
      return string.format('Lv%d %d/%d', progress.level, progress.exp, progress.exp_to_next)
    end

    return string.format('Lv%d MAX', progress.level)
  end

  local function grant_hero_exp(amount)
    if amount == nil or amount <= 0 or not STATE.hero_progress then
      return 0
    end

    local progress = STATE.hero_progress
    local remaining = math.max(0, round_number(amount))
    local granted = remaining

    if remaining <= 0 then
      return 0
    end

    progress.total_exp = (progress.total_exp or 0) + remaining

    if STATE.hero and STATE.hero:is_exist()
      and progress.level < get_engine_exp_cap_level()
      and STATE.hero:get_level() < get_engine_exp_cap_level() then
      STATE.hero:add_exp(remaining)
      sync_hero_progress_from_engine()
      return granted
    end

    while remaining > 0 and progress.level < get_hero_max_level() do
      local exp_to_next = progress.exp_to_next or 0
      if exp_to_next <= 0 then
        sync_hero_progression()
        exp_to_next = progress.exp_to_next or 0
        if exp_to_next <= 0 then
          break
        end
      end

      local need = exp_to_next - progress.exp
      if remaining < need then
        progress.exp = progress.exp + remaining
        remaining = 0
      else
        remaining = remaining - need
        progress.level = progress.level + 1
        progress.exp = 0
        sync_hero_progression()
        apply_hero_level_growth(progress.level)
        if progress.level % 5 == 0 then
          on_hero_level_up(progress.level)
        end
      end
    end

    if progress.level >= get_hero_max_level() then
      progress.exp = 0
      progress.exp_to_next = 0
      if STATE.hero and STATE.hero:is_exist() then
        STATE.hero:set_exp(0)
        STATE.hero:set_ability_point(0)
      end
    end

    return granted
  end

  local api = {
    get_hero_progression_rules = get_hero_progression_rules,
    get_resource_rules = get_resource_rules,
    get_hero_max_level = get_hero_max_level,
    get_engine_exp_cap_level = get_engine_exp_cap_level,
    get_post_cap_exp_required = get_post_cap_exp_required,
    get_hero_level = get_hero_level,
    get_hero_next_level_exp = get_hero_next_level_exp,
    sync_hero_progression = sync_hero_progression,
    initialize_hero_progression = initialize_hero_progression,
    sync_hero_progress_from_engine = sync_hero_progress_from_engine,
    get_hero_progress_text = get_hero_progress_text,
    grant_hero_exp = grant_hero_exp,
    apply_hero_level_growth = apply_hero_level_growth,
  }
  _G.progression_system = api
  _G.SYSTEM = _G.SYSTEM or {}
  _G.SYSTEM.progression = api

return api

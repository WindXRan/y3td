local PresentationProfiles = require 'data.object_tables.attack_skill_presentation_profiles'
local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG or {}
  local y3 = env.y3
  local round_number = env.round_number
  local message = env.message
  local ATTACK_SKILL_DEFS = env.ATTACK_SKILL_DEFS
  local ATTACK_SKILL_BLUEPRINTS = env.ATTACK_SKILL_BLUEPRINTS or { by_id = {} }
  local ATTACK_SKILL_VFX = env.ATTACK_SKILL_VFX
  local hero_attr_system = env.hero_attr_system
  local get_player = env.get_player
  local get_hero_point = env.get_hero_point
  local get_bond_runtime_bonus = env.get_bond_runtime_bonus
  local is_active_enemy = env.is_active_enemy
  local create_attack_skill_instance = env.create_attack_skill_instance
  local deal_skill_damage = env.deal_skill_damage
  local get_damage_bonus_multiplier = env.get_damage_bonus_multiplier
  local get_enemies_in_range = env.get_enemies_in_range
  local try_trigger_hunter_first_hit = env.try_trigger_hunter_first_hit
  local notify_bond_attack_skill_cast = env.notify_bond_attack_skill_cast
  local notify_auto_active_basic_attack = env.notify_auto_active_basic_attack
  local notify_auto_active_skill_cast = env.notify_auto_active_skill_cast
  local play_basic_attack_sound = env.play_basic_attack_sound
  local play_attack_skill_sound = env.play_attack_skill_sound
  local ATTACK_STATUS_MODIFIER_KEYS = RuntimeEditorIds.modifier.attack_status or {}
  local VISUAL_ANIMATION_SPEED = 0.5

  local function scale_visual_duration(seconds)
    return math.max(0.05, (seconds or 0.30) / VISUAL_ANIMATION_SPEED)
  end

  local function apply_visual_animation_speed(target)
    if not target or not target.set_animation_speed then
      return
    end
    pcall(function()
      target:set_animation_speed(VISUAL_ANIMATION_SPEED)
    end)
  end

  local function get_hero_attr(name, fallback_name)
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name) or STATE.hero:get_attr(name)
    value = y3.helper.tonumber(value) or 0
    if value > 0 or not fallback_name then
      return value
    end
    local fallback = hero_attr_system and hero_attr_system.get_attr(STATE.hero, fallback_name) or STATE.hero:get_attr(fallback_name)
    return y3.helper.tonumber(fallback) or 0
  end

  local function normalize_ratio(value)
    local number = y3.helper.tonumber(value) or 0
    if math.abs(number) > 1 then
      return number / 100
    end
    return number
  end

  local function get_hero_attr_ratio(name, fallback_name)
    return normalize_ratio(get_hero_attr(name, fallback_name))
  end

  local function get_basic_attack_multishot_bonus()
    local count = math.max(0, round_number(
      get_bond_runtime_bonus('multishot_count') + get_hero_attr('多重数量')
    ))
    if count <= 0 then
      return 0, 0
    end

    local ratio = math.max(0,
      normalize_ratio(get_bond_runtime_bonus('multishot_ratio'))
      + get_hero_attr_ratio('多重伤害')
    )
    return count, ratio
  end

  local function get_basic_attack_runtime_chain_stats()
    local skill_runtime = STATE.skill_runtime or {}
    local count = math.max(0, round_number(skill_runtime.chain_bounces or 0))
    local chance = math.max(0, normalize_ratio(skill_runtime.chain_chance or 0))
    local ratio = math.max(0, normalize_ratio(skill_runtime.chain_ratio or 0))
    return count, chance, ratio
  end

  local function get_basic_attack_bonus_chain_stats()
    local count = math.max(0, round_number(
      get_bond_runtime_bonus('chain_bounces') + get_hero_attr('弹射次数')
    ))
    if count <= 0 then
      return 0, 0
    end

    local ratio = 0.30 + math.max(0,
      normalize_ratio(get_bond_runtime_bonus('chain_ratio'))
      + get_hero_attr_ratio('弹射伤害')
    )
    return count, ratio
  end

  local function get_basic_attack_skill()
    if not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
      return nil
    end
    return STATE.attack_skill_state.by_id.basic_attack
  end

  local function get_global_skill_bonus(field)
    local state_bonus = STATE.skill_runtime and STATE.skill_runtime[field] or 0
    return state_bonus + get_bond_runtime_bonus(field)
  end

  local function get_effective_skill_value(skill, field)
    return math.max(0, (skill and skill[field] or 0) + get_global_skill_bonus(field))
  end

  local function remember_basic_attack_range(range)
    local number = y3.helper.tonumber(range) or 0
    if number > 0 then
      STATE.last_valid_basic_attack_range = number
      return number
    end
    return 0
  end
  
  local function get_current_basic_attack_range()
    if not STATE.hero or not STATE.hero:is_exist() then
      return math.max(1, round_number(
        STATE.last_valid_basic_attack_range
          or ATTACK_SKILL_DEFS.basic_attack.base_range
          or 0
      ))
    end

    local range = remember_basic_attack_range(
      hero_attr_system and hero_attr_system.get_attr(STATE.hero, '攻击范围') or STATE.hero:get_attr('攻击范围')
    )
    if range <= 0 then
      range = remember_basic_attack_range(
        hero_attr_system and hero_attr_system.get_attr(STATE.hero, 'attack_range') or STATE.hero:get_attr('attack_range')
      )
    end
    if range <= 0 then
      range = STATE.last_valid_basic_attack_range
        or ATTACK_SKILL_DEFS.basic_attack.base_range
        or 0
    end
    return math.max(1, round_number(range))
  end
  
  local function get_basic_attack_animation_names()
    if STATE.basic_attack_animation_names then
      return STATE.basic_attack_animation_names
    end

    local names = {}
    if STATE.hero and STATE.hero:is_exist() then
      local hero_key = STATE.hero:get_key()
      local editor_unit = hero_key and y3.object.unit[hero_key] or nil
      local animation_items = editor_unit
        and editor_unit.data
        and editor_unit.data.simple_common_atk
        and editor_unit.data.simple_common_atk.ability_animations
        and editor_unit.data.simple_common_atk.ability_animations.items
        or nil
      if type(animation_items) == 'table' then
        for _, name in ipairs(animation_items) do
          if type(name) == 'string' and name ~= '' then
            names[#names + 1] = name
          end
        end
      end
    end

    if #names == 0 then
      names[1] = 'attack1'
    end

    STATE.basic_attack_animation_names = names
    return names
  end

  local function play_basic_attack_animation()
    if not STATE.hero or not STATE.hero:is_exist() then
      return
    end

    local names = get_basic_attack_animation_names()
    if #names == 0 then
      return
    end

    STATE.basic_attack_animation_index = (STATE.basic_attack_animation_index or 0) + 1
    local index = ((STATE.basic_attack_animation_index - 1) % #names) + 1
    local animation_name = names[index]
    if animation_name and animation_name ~= '' then
      STATE.hero:play_animation(animation_name, 1.0, nil, nil, false, true)
    end
  end

  local function build_basic_attack_ability_description(skill)
    if not skill then
      return '当前普攻技能。'
    end
  
    local lines = {
      string.format('当前普攻：造成 %.0f%% 攻击的物理伤害。', (skill.damage_ratio or 0) * 100),
      string.format('当前射程：%d。', get_current_basic_attack_range()),
    }

    local multishot_count, multishot_ratio = get_basic_attack_multishot_bonus()
    local runtime_chain_count, runtime_chain_chance, runtime_chain_ratio = get_basic_attack_runtime_chain_stats()
    local bonus_chain_count, bonus_chain_ratio = get_basic_attack_bonus_chain_stats()
  
    if STATE.skill_runtime and STATE.skill_runtime.normal_attack_bonus_ratio > 0 then
      lines[#lines + 1] = string.format(
        '额外追伤：%.0f%% 攻击。',
        STATE.skill_runtime.normal_attack_bonus_ratio * 100
      )
    end
  
    if STATE.skill_runtime and STATE.skill_runtime.splash_ratio > 0 then
      lines[#lines + 1] = string.format(
        '溅射：%.0f%% 攻击，半径 %d。',
        STATE.skill_runtime.splash_ratio * 100,
        round_number(STATE.skill_runtime.splash_radius)
      )
    end
  
    if runtime_chain_count > 0 and runtime_chain_chance > 0 and runtime_chain_ratio > 0 then
      lines[#lines + 1] = string.format(
        '弹射：%.0f%% 概率弹射 %d 个目标，造成 %.0f%% %s伤害。',
        runtime_chain_chance * 100,
        runtime_chain_count,
        runtime_chain_ratio * 100,
        skill.damage_label or '额外'
      )
    end

    if multishot_count > 0 and multishot_ratio > 0 then
      lines[#lines + 1] = string.format(
        '多重：额外命中 %d 个目标，造成 %.0f%% 伤害。',
        multishot_count,
        multishot_ratio * 100
      )
    end

    if get_effective_skill_value(skill, 'explosion_ratio') > 0 and get_effective_skill_value(skill, 'explosion_radius') > 0 then
      lines[#lines + 1] = string.format(
        '剑爆：命中后炸裂，对半径 %d 范围造成 %.0f%% 伤害。',
        round_number(get_effective_skill_value(skill, 'explosion_radius')),
        get_effective_skill_value(skill, 'explosion_ratio') * 100
      )
    end

    if bonus_chain_count > 0 and bonus_chain_ratio > 0 then
      lines[#lines + 1] = string.format(
        '月刃：命中后额外弹射 %d 个目标，造成 %.0f%% 伤害。',
        bonus_chain_count,
        bonus_chain_ratio * 100
      )
    end
  
    if STATE.skill_runtime and STATE.skill_runtime.execute_threshold > 0 then
      lines[#lines + 1] = string.format(
        '处决：目标生命低于 %.0f%% 时立即击杀。',
        STATE.skill_runtime.execute_threshold * 100
      )
    end

    if get_effective_skill_value(skill, 'split_count') > 0 then
      lines[#lines + 1] = string.format(
        '分裂：额外命中 %d 个目标，造成 %.0f%% 伤害。',
        round_number(get_effective_skill_value(skill, 'split_count')),
        get_effective_skill_value(skill, 'split_ratio') * 100
      )
    end

    if get_effective_skill_value(skill, 'armor_break_ratio') > 0 then
      lines[#lines + 1] = string.format(
        '破甲：命中附加 %.0f%% 破甲，持续 %.1f 秒。',
        get_effective_skill_value(skill, 'armor_break_ratio') * 100,
        get_effective_skill_value(skill, 'armor_break_duration')
      )
    end
  
    return table.concat(lines, '\n')
  end
  
  local function sync_basic_attack_ability()
    if not STATE.hero or not STATE.hero:is_exist() then
      return nil
    end
  
    local ability = STATE.hero_common_attack
    if not ability or not ability:is_exist() then
      ability = STATE.hero:get_common_attack()
      STATE.hero_common_attack = ability
    end
  
    if not ability or not ability:is_exist() then
      if not STATE.basic_attack_ability_warned then
        STATE.basic_attack_ability_warned = true
        message('警告：未找到英雄普攻技能对象，无法通过 Ability API 同步普攻参数。')
      end
      return nil
    end
  
    local skill = get_basic_attack_skill()
    ability:set_range(get_current_basic_attack_range())
  
    if skill then
      ability:set_name(skill.name)
      ability:set_description(build_basic_attack_ability_description(skill))
    end
  
    return ability
  end
  
  local function bind_basic_attack_ability_events(ability)
    if not ability or not ability:is_exist() or STATE.basic_attack_ability_bound then
      return
    end
  
    ability:event('施法-出手', function(_, data)
      if STATE.game_finished or data.unit ~= STATE.hero then
        return
      end
      sync_basic_attack_ability()
    end)
  
    STATE.basic_attack_ability_bound = true
  end
  
  local function setup_basic_attack_ability()
    local ability = sync_basic_attack_ability()
    if not ability then
      return
    end
    bind_basic_attack_ability_events(ability)
  end

  local function get_attack_skill(skill_id)
    return STATE.attack_skill_state and STATE.attack_skill_state.by_id[skill_id] or nil
  end
  
  local function get_attack_skill_slot(slot)
    return STATE.attack_skill_state and STATE.attack_skill_state.slots[slot] or nil
  end
  
  local function get_empty_attack_skill_slot()
    if not STATE.attack_skill_state then
      return nil
    end
    for slot = 1, 4, 1 do
      if not STATE.attack_skill_state.slots[slot] then
        return slot
      end
    end
    return nil
  end
  
  local function get_unlocked_attack_skill_count()
    if not STATE.attack_skill_state then
      return 0
    end
  
    local count = 0
    for slot = 1, 4, 1 do
      if STATE.attack_skill_state.slots[slot] then
        count = count + 1
      end
    end
    return count
  end
  
  local function get_upgrade_pick_count(upgrade_key)
    if not STATE.attack_skill_state then
      return 0
    end
    return STATE.attack_skill_state.upgrade_counts[upgrade_key] or 0
  end
  
  local function record_upgrade_pick(upgrade_key)
    if not STATE.attack_skill_state then
      return
    end
    STATE.attack_skill_state.upgrade_counts[upgrade_key] = get_upgrade_pick_count(upgrade_key) + 1
  end
  
  local function get_skill_current_cooldown(skill)
    if not skill or skill.base_cooldown <= 0 then
      return 0
    end
    return math.max(0.4, skill.base_cooldown * (1 - skill.cooldown_reduction))
  end
  
  local function get_basic_attack_interval(skill)
    if not skill then
      return 0.6
    end
    local effective_base_interval = math.max(0.15, (skill.base_cooldown or 1.7) * (1 - math.max(0, skill.cooldown_reduction or 0)))
  
    if STATE.hero and STATE.hero:is_exist() then
      local interval_offset = y3.helper.tonumber(get_hero_attr('攻击间隔')) or 0
      if interval_offset >= 0.3 then
        return math.max(0.15, interval_offset)
      end
  
      local attack_speed = math.max(20, get_hero_attr('攻击速度') + (skill.attack_speed_bonus or 0))
      return math.max(0.15, effective_base_interval * 100 / attack_speed + interval_offset)
    end
  
    return effective_base_interval
  end
  
  local function build_attack_skill_slot_text(slot)
    local skill = get_attack_skill_slot(slot)
    if not skill then
      return string.format('%d号位 空', slot)
    end
  
    local parts = {
      string.format('%d号位 %s Lv%d', slot, skill.name, skill.level),
      string.format('%.0f%%攻击', skill.damage_ratio * 100),
    }
  
    if skill.id == 'basic_attack' then
      parts[#parts + 1] = string.format('间隔 %.2fs', get_basic_attack_interval(skill))
    elseif skill.base_cooldown > 0 then
      parts[#parts + 1] = string.format('CD %.1fs', get_skill_current_cooldown(skill))
    end
    if skill.pierce and skill.pierce > 0 and skill.id ~= 'basic_attack' then
      parts[#parts + 1] = '穿透+' .. tostring(skill.pierce)
    end
    if skill.extra_targets and skill.extra_targets > 0 then
      parts[#parts + 1] = '扩散+' .. tostring(skill.extra_targets)
    end
    if skill.repeat_count and skill.repeat_count > 1 then
      parts[#parts + 1] = '连发x' .. tostring(skill.repeat_count)
    end
    if skill.split_seek_count and skill.split_seek_count > 0 then
      parts[#parts + 1] = '分化x' .. tostring(skill.split_seek_count)
    end
    if skill.kill_seek_count and skill.kill_seek_count > 0 then
      parts[#parts + 1] = '追命x' .. tostring(skill.kill_seek_count)
    end
  
    return table.concat(parts, ' | ')
  end
  
  local function show_attack_skill_loadout()
    message('攻击技能栏：')
    for slot = 1, 4, 1 do
      message(build_attack_skill_slot_text(slot))
    end
  end
  
  local function unlock_attack_skill(skill_id)
    local existing = get_attack_skill(skill_id)
    if existing then
      return existing, existing.slot, false
    end
  
    local empty_slot = get_empty_attack_skill_slot()
    if not empty_slot then
      return nil
    end
  
    local skill = create_attack_skill_instance(skill_id, empty_slot)
    STATE.attack_skill_state.slots[empty_slot] = skill
    STATE.attack_skill_state.by_id[skill_id] = skill
    STATE.attack_skill_state.new_skill_feed[skill_id] = 2
    return skill, empty_slot, true
  end
  
  local function get_skill_damage(skill, ratio_override)
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    local attack_value = get_hero_attr('攻击结算值', '攻击')
    return attack_value * (ratio_override or skill.damage_ratio or 0)
  end
  
  local function clone_point(point)
    if not point then
      return nil
    end
    return point:move()
  end
  
  local function get_unit_point_snapshot(unit)
    if not unit or not unit:is_exist() then
      return nil
    end
    return clone_point(unit:get_point())
  end

  local function is_unit_alive_now(unit)
    if not unit or not unit.is_exist or not unit:is_exist() then
      return false
    end
    if unit.is_alive then
      return unit:is_alive()
    end
    return (unit.get_hp and unit:get_hp() or 0) > 0
  end
  
  local function get_enemies_on_line(origin_point, impact_point, max_distance, line_width, max_hits, except_unit)
    local result = {}
    if not origin_point or not impact_point or max_hits <= 0 then
      return result
    end
  
    local ox = origin_point:get_x()
    local oy = origin_point:get_y()
    local tx = impact_point:get_x()
    local ty = impact_point:get_y()
    local dir_x = tx - ox
    local dir_y = ty - oy
    local length = origin_point:get_distance_with(impact_point)
    if length < 1 then
      return result
    end
  
    local reach = math.max(length, max_distance or length)
    local width = math.max(40, line_width or 95)
    local start_projection = math.max(0, length - width)
    local segment_length = reach - start_projection
    if segment_length <= 0 then
      return result
    end

    local direction = origin_point:get_angle_with(impact_point)
    local segment_center = y3.point.get_point_offset_vector(
      origin_point,
      direction,
      start_projection + segment_length / 2
    )
    local line_shape = y3.shape.create_rectangle_shape(width * 2, segment_length, direction)
    local candidates = {}
    local picked = y3.selector.create()
      :is_enemy(get_player())
      :in_shape(segment_center, line_shape)
      :pick()
  
    for _, unit in ipairs(picked) do
      if unit ~= except_unit and is_active_enemy(unit) then
        local point = unit:get_point()
        candidates[#candidates + 1] = {
          unit = unit,
          projection = ((point:get_x() - ox) * dir_x + (point:get_y() - oy) * dir_y) / length,
        }
      end
    end
  
    table.sort(candidates, function(a, b)
      return a.projection < b.projection
    end)
  
    for index = 1, math.min(max_hits, #candidates), 1 do
      result[#result + 1] = candidates[index].unit
    end
  
    return result
  end
  
  local function resume_enemy_path(unit)
    if is_active_enemy(unit) and STATE.defense_point then
      unit:attack_move(STATE.defense_point)
    end
  end

  local function get_enemy_status_bucket(unit)
    local info = STATE.enemy_info_map and STATE.enemy_info_map[unit] or nil
    if not info then
      return nil
    end
    info.status = info.status or {}
    return info.status
  end

  local function apply_enemy_status(unit, status_id, values)
    local bucket = get_enemy_status_bucket(unit)
    if not bucket then
      return nil
    end
    bucket[status_id] = bucket[status_id] or {}
    for key, value in pairs(values or {}) do
      bucket[status_id][key] = value
    end
    return bucket[status_id]
  end

  local function try_add_status_modifier(unit, modifier_key, duration)
    if not modifier_key or modifier_key == 0 or (duration or 0) <= 0 then
      return nil
    end
    if not unit or not unit.is_exist or not unit:is_exist() or not unit.add_buff then
      return nil
    end
    local ok, buff = pcall(unit.add_buff, unit, {
      key = modifier_key,
      source = STATE.hero,
      time = duration,
    })
    if ok then
      return buff
    end
    return nil
  end

  local function get_enemy_status(unit, status_id)
    local bucket = get_enemy_status_bucket(unit)
    return bucket and bucket[status_id] or nil
  end
  
  local function update_enemy_statuses(dt)
    if not STATE.enemy_info_map or not STATE.hero or not STATE.hero:is_exist() then
      return
    end

    for unit, info in pairs(STATE.enemy_info_map) do
      if info and info.status then
        local ignite = info.status.ignite
        if ignite then
          ignite.remaining = math.max(0, (ignite.remaining or 0) - dt)
          ignite.tick_cd = (ignite.tick_cd or 1) - dt
          if ignite.remaining <= 0 then
            info.status.ignite = nil
          elseif ignite.tick_cd <= 0 and is_active_enemy(unit) then
            ignite.tick_cd = 1
            deal_skill_damage(unit, get_hero_attr('攻击结算值', '攻击') * (ignite.tick_ratio or 0), '物理', {
              text_type = 'physics',
            })
          end
        end

        for _, status_id in ipairs({ 'armor_break', 'shock' }) do
          local entry = info.status[status_id]
          if entry then
            entry.remaining = math.max(0, (entry.remaining or 0) - dt)
            if entry.remaining <= 0 then
              info.status[status_id] = nil
            end
          end
        end
      end
    end
  end
  
  local function play_particle_on_unit(unit, effect_key, scale, time, socket)
    if not effect_key or not unit or not unit:is_exist() then
      return nil
    end
  
    local ok, particle = pcall(y3.particle.create, {
      type = effect_key,
      target = unit,
      socket = socket or 'origin',
      scale = scale or 1.0,
      time = scale_visual_duration(time),
      immediate = true,
    })
    if ok and particle then
      apply_visual_animation_speed(particle)
      return particle
    end
    return nil
  end
  
  local function play_particle_on_point(point, effect_key, scale, time, height)
    if not effect_key or not point then
      return nil
    end
  
    local ok, particle = pcall(y3.particle.create, {
      type = effect_key,
      target = point,
      scale = scale or 1.0,
      time = scale_visual_duration(time),
      height = height or 0,
      immediate = true,
    })
    if ok and particle then
      apply_visual_animation_speed(particle)
      return particle
    end
    return nil
  end

  local function get_skill_vfx(skill)
    return ATTACK_SKILL_VFX[skill and skill.id or ''] or {}
  end

  local function get_skill_presentation_family(skill)
    if not skill then
      return 'default'
    end
    if skill.presentation_family and skill.presentation_family ~= '' then
      return skill.presentation_family
    end
    local def = ATTACK_SKILL_DEFS[skill.id]
    if def and def.presentation_family and def.presentation_family ~= '' then
      return def.presentation_family
    end
    return 'default'
  end

  local function get_skill_stage_profile(skill, stage)
    local family = get_skill_presentation_family(skill)
    local profile = PresentationProfiles.by_id[family] or PresentationProfiles.by_id.default or {}
    return profile[stage] or {}
  end

  local function resolve_skill_stage_particle(skill, stage)
    local vfx = get_skill_vfx(skill)
    local profile = get_skill_stage_profile(skill, stage)
    local effect_key
    local scale
    local time

    if stage == 'cast' then
      effect_key, scale, time = vfx.cast_particle, vfx.cast_scale, vfx.cast_time
    elseif stage == 'impact' then
      effect_key, scale, time = vfx.impact_particle, vfx.impact_scale, vfx.impact_time
    elseif stage == 'burst' or stage == 'terminal' then
      effect_key = vfx.explosion_particle or vfx.impact_particle
      scale = vfx.explosion_scale or vfx.impact_scale
      time = vfx.explosion_time or vfx.impact_time
    elseif stage == 'charge' then
      effect_key = vfx.charge_particle or vfx.cast_particle or vfx.chain_particle
      scale = vfx.charge_scale or vfx.cast_scale or vfx.chain_scale
      time = vfx.charge_time or vfx.cast_time or vfx.chain_time
    elseif stage == 'chain' then
      effect_key = vfx.chain_particle or vfx.impact_particle or vfx.explosion_particle
      scale = vfx.chain_scale or vfx.impact_scale or vfx.explosion_scale
      time = vfx.chain_time or vfx.impact_time or vfx.explosion_time
    elseif stage == 'sustain' or stage == 'tick' then
      effect_key = vfx.chain_particle or vfx.charge_particle or vfx.impact_particle or vfx.cast_particle
      scale = vfx.chain_scale or vfx.charge_scale or vfx.impact_scale or vfx.cast_scale or 1.0
      time = vfx.chain_time or vfx.charge_time or vfx.impact_time or vfx.cast_time or 0.30
      scale = math.max(0.42, scale * 0.84)
      time = math.min(0.24, time)
    end

    if effect_key and profile.min_scale then
      scale = math.max(profile.min_scale, scale or 0)
    end
    if effect_key and profile.min_time then
      time = math.max(profile.min_time, time or 0)
    end

    return effect_key, scale, time, profile.height, profile.socket
  end

  local function play_skill_particle_on_unit(skill, unit, stage, socket)
    local effect_key, scale, time, _, profile_socket = resolve_skill_stage_particle(skill, stage)
    return play_particle_on_unit(unit, effect_key, scale, time, socket or profile_socket)
  end

  local function play_skill_particle_on_point(skill, point, stage, height)
    local effect_key, scale, time, profile_height = resolve_skill_stage_particle(skill, stage)
    return play_particle_on_point(point, effect_key, scale, time, height ~= nil and height or profile_height)
  end

  local function play_skill_audio(skill, stage, anchor)
    if not play_attack_skill_sound then
      return nil
    end
    return play_attack_skill_sound(skill, anchor or STATE.hero, stage)
  end

  local function get_projectile_launch_angle(target)
    if not STATE.hero or not STATE.hero:is_exist() or not target or not target:is_exist() then
      return nil
    end
    local source_point = STATE.hero:get_point()
    local target_point = target:get_point()
    if not source_point or not target_point or not source_point.get_angle_with then
      return nil
    end
    return source_point:get_angle_with(target_point)
  end

  local PROJECTILE_FLIGHT_HEIGHT = 100

  local function launch_projectile_to_target(vfx, target, on_finish, ability)
    local impact_point = get_unit_point_snapshot(target)
    local launch_angle = get_projectile_launch_angle(target)
    if not vfx or not vfx.projectile_key or not STATE.hero or not STATE.hero:is_exist() then
      if on_finish then
        on_finish(impact_point, false)
      end
      return false
    end
  
    local ok_create, projectile = pcall(y3.projectile.create, {
      key = vfx.projectile_key,
      target = STATE.hero,
      socket = 'origin',
      owner = STATE.hero,
      ability = ability,
      angle = launch_angle,
      time = vfx.projectile_time or 3.0,
      remove_immediately = true,
    })
    if not ok_create or not projectile then
      if on_finish then
        on_finish(impact_point, false)
      end
      return false
    end

    pcall(function()
      projectile:set_height(PROJECTILE_FLIGHT_HEIGHT)
    end)
    apply_visual_animation_speed(projectile)

    if launch_angle ~= nil then
      pcall(function()
        projectile:set_facing(launch_angle)
      end)
    end
  
    local resolved = false
  
    local function finish(did_hit, final_point)
      if resolved then
        return
      end
      resolved = true
      local resolved_point = final_point or impact_point
      if projectile and projectile:is_exist() then
        resolved_point = final_point or clone_point(projectile:get_point()) or resolved_point
        projectile:remove()
      end
      if on_finish then
        on_finish(resolved_point, did_hit == true)
      end
    end
  
    local ok_move = pcall(function()
      projectile:mover_target({
        target = target,
        speed = tonumber(vfx and vfx.projectile_speed) or 1000,
        target_distance = vfx.target_distance or 60,
        height = PROJECTILE_FLIGHT_HEIGHT,
        init_angle = launch_angle,
        rotate_time = 0.0,
        face_angle = true,
        miss_when_target_destroy = false,
        on_finish = function()
          finish(target and target:is_exist() or false)
        end,
        on_break = function()
          finish(false, clone_point(projectile and projectile:is_exist() and projectile:get_point() or nil) or impact_point)
        end,
        on_miss = function()
          finish(false, clone_point(projectile and projectile:is_exist() and projectile:get_point() or nil) or impact_point)
        end,
      })
    end)
  
    if not ok_move then
      if resolved then
        return false
      end
      finish(false, clone_point(projectile and projectile:is_exist() and projectile:get_point() or nil) or impact_point)
      return false
    end

    return true
  end

  local function launch_projectile_from_point_to_target(vfx, source_point, target, on_finish, ability)
    local origin_point = clone_point(source_point) or source_point
    local impact_point = get_unit_point_snapshot(target)
    if not origin_point then
      if on_finish then
        on_finish(impact_point, false)
      end
      return false
    end
    if not vfx or not vfx.projectile_key or not STATE.hero or not STATE.hero:is_exist() then
      if on_finish then
        on_finish(impact_point, false)
      end
      return false
    end

    local launch_angle = nil
    if origin_point.get_angle_with and target and target.is_exist and target:is_exist() then
      launch_angle = origin_point:get_angle_with(target:get_point())
    end

    local ok_create, projectile = pcall(y3.projectile.create, {
      key = vfx.projectile_key,
      target = origin_point,
      owner = STATE.hero,
      ability = ability,
      angle = launch_angle,
      height = PROJECTILE_FLIGHT_HEIGHT,
      time = vfx.projectile_time or 3.0,
      remove_immediately = true,
    })
    if not ok_create or not projectile then
      if on_finish then
        on_finish(impact_point, false)
      end
      return false
    end

    pcall(function()
      projectile:set_height(PROJECTILE_FLIGHT_HEIGHT)
    end)
    apply_visual_animation_speed(projectile)

    if launch_angle ~= nil then
      pcall(function()
        projectile:set_facing(launch_angle)
      end)
    end

    local resolved = false

    local function finish(did_hit, final_point)
      if resolved then
        return
      end
      resolved = true
      local resolved_point = final_point or impact_point
      if projectile and projectile:is_exist() then
        resolved_point = final_point or clone_point(projectile:get_point()) or resolved_point
        projectile:remove()
      end
      if on_finish then
        on_finish(resolved_point, did_hit == true)
      end
    end

    local ok_move = pcall(function()
      projectile:mover_target({
        target = target,
        speed = tonumber(vfx and vfx.projectile_speed) or 1000,
        target_distance = vfx.target_distance or 60,
        height = PROJECTILE_FLIGHT_HEIGHT,
        init_angle = launch_angle,
        rotate_time = 0.0,
        face_angle = true,
        miss_when_target_destroy = false,
        on_finish = function()
          finish(target and target:is_exist() or false)
        end,
        on_break = function()
          finish(false, clone_point(projectile and projectile:is_exist() and projectile:get_point() or nil) or impact_point)
        end,
        on_miss = function()
          finish(false, clone_point(projectile and projectile:is_exist() and projectile:get_point() or nil) or impact_point)
        end,
      })
    end)

    if not ok_move then
      if resolved then
        return false
      end
      finish(false, clone_point(projectile and projectile:is_exist() and projectile:get_point() or nil) or impact_point)
      return false
    end

    return true
  end

  local function launch_local_projectile(vfx, point, on_finish, ability)
    local fallback_point = clone_point(point) or point or get_hero_point()
    if not vfx or not vfx.projectile_key or not STATE.hero or not STATE.hero:is_exist() then
      if on_finish then
        on_finish(fallback_point, false)
      end
      return false
    end

    local ok_create, projectile = pcall(y3.projectile.create, {
      key = vfx.projectile_key,
      target = STATE.hero,
      socket = 'origin',
      owner = STATE.hero,
      ability = ability,
      time = vfx.projectile_time or 0.25,
      remove_immediately = true,
    })
    if not ok_create or not projectile then
      if on_finish then
        on_finish(fallback_point, false)
      end
      return false
    end

    pcall(function()
      projectile:set_height(PROJECTILE_FLIGHT_HEIGHT)
    end)
    apply_visual_animation_speed(projectile)

    local function finish(did_hit)
      local resolved_point = fallback_point
      if projectile and projectile.is_exist and projectile:is_exist() then
        resolved_point = clone_point(projectile:get_point()) or resolved_point
        projectile:remove()
      end
      if on_finish then
        on_finish(resolved_point, did_hit == true)
      end
    end

    if not y3 or not y3.ltimer or not y3.ltimer.wait then
      finish(true)
      return true
    end

    y3.ltimer.wait(math.max(0.08, vfx.projectile_time or 0.25), function()
      finish(true)
    end)

    return true
  end

  local function run_skill_target_projectile(skill, target, on_resolve, opts)
    local vfx = ATTACK_SKILL_VFX[skill and skill.id or ''] or {}
    local fallback_point = get_unit_point_snapshot(target) or get_hero_point()
    if not vfx.projectile_key then
      if on_resolve then
        on_resolve(fallback_point, false, vfx)
      end
      return false
    end

    return launch_projectile_to_target(vfx, target, function(impact_point, did_hit)
      if did_hit ~= true and not (opts and opts.allow_fallback == true) then
        return
      end
      if on_resolve then
        on_resolve(impact_point or fallback_point, did_hit == true, vfx)
      end
    end, opts and opts.ability or nil)
  end

  local function run_skill_local_projectile(skill, point, on_resolve, opts)
    local vfx = ATTACK_SKILL_VFX[skill and skill.id or ''] or {}
    local fallback_point = clone_point(point) or point or get_hero_point()
    if not vfx.projectile_key then
      if on_resolve then
        on_resolve(fallback_point, false, vfx)
      end
      return false
    end

    return launch_local_projectile(vfx, fallback_point, function(impact_point, did_hit)
      if did_hit ~= true and not (opts and opts.allow_fallback == true) then
        return
      end
      if on_resolve then
        on_resolve(impact_point or fallback_point, did_hit == true, vfx)
      end
    end, opts and opts.ability or nil)
  end
  
  local function pick_skill_target(skill)
    if not STATE.hero or not STATE.hero:is_exist() then
      return nil
    end
  
    local range
    if skill and skill.id == 'basic_attack' then
      range = get_current_basic_attack_range()
    else
      range = math.max(1, (skill.cast_range or 0) + (skill.range_bonus or 0), skill.base_radius or 0)
    end
    local picked = y3.selector.create()
      :is_enemy(get_player())
      :in_range(STATE.hero:get_point(), range)
      :sort_type('由近到远')
      :pick()
  
    for _, unit in ipairs(picked) do
      if is_active_enemy(unit) then
        return unit
      end
    end
  
    return nil
  end

  local function get_basic_attack_bonus_multiplier(skill, target)
    local multiplier = 1
    if target and is_active_enemy(target) then
      multiplier = multiplier * get_damage_bonus_multiplier(target, {
        is_basic_attack = true,
      })
      local info = STATE.enemy_info_map and STATE.enemy_info_map[target] or nil
      if info and (info.is_elite == true or info.kind == 'boss' or info.is_boss == true) then
        multiplier = multiplier * (1 + get_effective_skill_value(skill, 'boss_bonus_ratio'))
      end
    end
    return multiplier
  end

  local function deal_basic_attack_damage(skill, target, amount, options)
    if not STATE.hero or not STATE.hero:is_exist() or not target or not is_active_enemy(target) then
      return
    end

    local hit_effect_enabled = CONFIG.damage_hit_effect_enabled ~= false
    local damage_meta = skill or ATTACK_SKILL_DEFS.basic_attack or {}
    local damage_form = damage_meta.damage_form or damage_meta.damage_type
    local element = damage_meta.element
    if ATTACK_SKILL_DEFS.basic_attack then
      damage_form = damage_form or ATTACK_SKILL_DEFS.basic_attack.damage_form or ATTACK_SKILL_DEFS.basic_attack.damage_type
      element = element or ATTACK_SKILL_DEFS.basic_attack.element
    end

    local hero_damage_multiplier = 1
    if hero_attr_system and hero_attr_system.get_damage_multiplier then
      hero_damage_multiplier = hero_attr_system.get_damage_multiplier(
        STATE.hero,
        damage_form or 'weapon',
        'normal_attack',
        element
      ) or 1
    end
    STATE.hero:damage({
      target = target,
      damage = round_number((amount or 0) * hero_damage_multiplier * get_basic_attack_bonus_multiplier(skill, target)),
      type = skill.damage_type,
      ability = hit_effect_enabled
        and STATE.hero_common_attack
        and STATE.hero_common_attack:is_exist()
        and STATE.hero_common_attack
        or nil,
      text_type = options and options.text_type or 'physics',
      text_track = options and options.text_track or 934269508,
      particle = hit_effect_enabled and options and options.particle or nil,
      socket = hit_effect_enabled and options and options.socket or '',
      pos_socket = hit_effect_enabled and options and options.pos_socket or '',
      common_attack = hit_effect_enabled and options and options.common_attack == true or false,
      no_miss = true,
    })
  end

  local function apply_armor_break_on_hit(target)
    local skill = get_basic_attack_skill()
    local ratio = get_effective_skill_value(skill, 'armor_break_ratio')
    local duration = get_effective_skill_value(skill, 'armor_break_duration')
    local max_stacks = math.max(1, round_number(get_effective_skill_value(skill, 'armor_break_max_stacks')))
    if ratio <= 0 or duration <= 0 or not is_active_enemy(target) then
      return
    end

    local status = get_enemy_status(target, 'armor_break') or { stacks = 0 }
    status.stacks = math.min(max_stacks, (status.stacks or 0) + 1)
    status.remaining = duration
    status.ratio = ratio
    apply_enemy_status(target, 'armor_break', status)
    try_add_status_modifier(target, ATTACK_STATUS_MODIFIER_KEYS.armor_break, duration)
  end

  local function get_basic_attack_secondary_search_radius()
    return math.max(260, get_current_basic_attack_range() * 0.45)
  end

  local function get_secondary_hit_center(unit)
    if not unit or not unit:is_exist() then
      return nil
    end
    return get_unit_point_snapshot(unit) or unit:get_point()
  end

  local function deal_basic_attack_secondary_damage(skill, unit, amount, options)
    if not unit or not is_active_enemy(unit) then
      return false
    end

    local hit_center = get_secondary_hit_center(unit)
    if hit_center then
      play_skill_particle_on_point(skill, hit_center, options and options.stage or 'chain', options and options.height or 16)
    end
    if options and options.audio_stage then
      play_skill_audio(skill, options.audio_stage, unit or hit_center)
    end

    if options and options.use_skill_damage == true then
      deal_skill_damage(unit, amount, options.damage_meta or skill, {
        text_type = options.text_type or 'physics',
        particle = options.particle,
        skip_hunter_first_hit = options.skip_hunter_first_hit == true,
      })
      return true
    end

    deal_basic_attack_damage(skill, unit, amount, {
      text_type = options and options.text_type or 'physics',
      particle = options and options.particle or nil,
      common_attack = false,
    })
    if not (options and options.apply_armor_break == false) then
      apply_armor_break_on_hit(unit)
    end
    return true
  end

  local function get_skill_archetype(skill)
    if not skill then
      return ''
    end
    if skill.archetype and skill.archetype ~= '' then
      return skill.archetype
    end
    local blueprint = ATTACK_SKILL_BLUEPRINTS.by_id and ATTACK_SKILL_BLUEPRINTS.by_id[skill.id] or nil
    return blueprint and blueprint.archetype or ''
  end

  local function get_skill_cast_family(skill)
    if not skill then
      return ''
    end
    if skill.cast_family and skill.cast_family ~= '' then
      return skill.cast_family
    end
    local def = ATTACK_SKILL_DEFS[skill.id]
    if def and def.cast_family and def.cast_family ~= '' then
      return def.cast_family
    end
    return ''
  end

  local function get_skill_radius(skill)
    return math.max(0, skill and skill.base_radius or 0)
  end

  local function get_skill_duration(skill)
    return math.max(0, skill and skill.base_duration or 0)
  end

  local function get_skill_bounce(skill)
    return math.max(0, round_number(skill and skill.base_bounce or 0))
  end

  local function apply_hold_control(unit, duration)
    if duration <= 0 or not unit or not is_active_enemy(unit) then
      return
    end
    unit:stop()
    unit:add_state('禁止移动')
    unit:add_state('禁止转向')
    y3.ltimer.wait(duration, function()
      if not unit or not unit:is_exist() then
        return
      end
      unit:remove_state('禁止移动')
      unit:remove_state('禁止转向')
      resume_enemy_path(unit)
    end)
  end

  local function pull_unit_towards_point(unit, center, strength)
    if strength <= 0 or not unit or not center or not is_active_enemy(unit) then
      return
    end

    local unit_point = get_unit_point_snapshot(unit)
    if not unit_point then
      return
    end

    local remaining_distance = unit_point:get_distance_with(center)
    local pull_distance = math.min(math.max(30, strength), math.max(0, remaining_distance - 40))
    if pull_distance <= 0 then
      return
    end

    pcall(function()
      unit:mover_line({
        angle = unit_point:get_angle_with(center),
        distance = pull_distance,
        speed = math.max(600, strength * 6),
        terrain_block = false,
        on_finish = function()
          if is_active_enemy(unit) then
            resume_enemy_path(unit)
          end
        end,
        on_break = function()
          if is_active_enemy(unit) then
            resume_enemy_path(unit)
          end
        end,
      })
    end)
  end

  local function apply_simple_ignite(unit, duration, tick_ratio)
    if duration <= 0 or tick_ratio <= 0 or not unit or not is_active_enemy(unit) then
      return
    end
    apply_enemy_status(unit, 'ignite', {
      remaining = duration,
      tick_cd = 1,
      tick_ratio = tick_ratio,
    })
    try_add_status_modifier(unit, ATTACK_STATUS_MODIFIER_KEYS.ignite, duration)
  end

  local function deal_area_skill_damage(center, radius, skill, amount, options)
    if not center or radius <= 0 then
      return {}
    end
    local hit_units = {}
    for _, unit in ipairs(get_enemies_in_range(center, radius)) do
      hit_units[#hit_units + 1] = unit
      deal_skill_damage(unit, amount, skill, options)
    end
    return hit_units
  end

  local function apply_generic_skill_statuses(skill, unit)
    if not skill or not unit or not is_active_enemy(unit) then
      return
    end

    if skill.apply_generic_armor_break and (skill.armor_break_ratio or 0) > 0 then
      local status = get_enemy_status(unit, 'armor_break') or { stacks = 0 }
      status.stacks = math.min(
        math.max(1, round_number(skill.armor_break_max_stacks or 1)),
        (status.stacks or 0) + 1
      )
      status.remaining = math.max(status.remaining or 0, skill.armor_break_duration or skill.generic_status_duration or 0)
      status.ratio = math.max(status.ratio or 0, skill.armor_break_ratio or 0)
      apply_enemy_status(unit, 'armor_break', status)
      try_add_status_modifier(unit, ATTACK_STATUS_MODIFIER_KEYS.armor_break, status.remaining)
    end

    if skill.apply_generic_ignite and (skill.ignite_duration or 0) > 0 and (skill.ignite_tick_ratio or 0) > 0 then
      apply_simple_ignite(unit, skill.ignite_duration, skill.ignite_tick_ratio)
    end

    if skill.apply_generic_shock and (skill.shock_duration or 0) > 0 then
      apply_enemy_status(unit, 'shock', {
        remaining = skill.shock_duration,
        bonus = skill.shock_bonus or 0,
      })
      try_add_status_modifier(unit, ATTACK_STATUS_MODIFIER_KEYS.shock, skill.shock_duration)
    end

    if skill.apply_generic_control and (skill.control_lock_time or 0) > 0 then
      apply_hold_control(unit, skill.control_lock_time)
    end
  end

  local function trigger_skill_terminal_burst(skill, center)
    local radius = math.max(0, skill and skill.terminal_burst_radius or 0)
    local ratio = math.max(0, skill and skill.terminal_burst_ratio or 0)
    if not center or radius <= 0 or ratio <= 0 then
      return
    end
    play_skill_particle_on_point(skill, center, 'terminal', 0)
    play_skill_audio(skill, 'burst', center)
    for _, unit in ipairs(deal_area_skill_damage(center, radius, skill, get_skill_damage(skill) * ratio)) do
      apply_generic_skill_statuses(skill, unit)
    end
  end

  local function trigger_skill_followup_hits(skill, center, except_unit)
    local count = math.max(0, round_number(skill and skill.followup_count or 0))
    local ratio = math.max(0, skill and skill.followup_ratio or 0)
    local vfx = ATTACK_SKILL_VFX[skill and skill.id or ''] or {}
    if not center or count <= 0 or ratio <= 0 then
      return
    end
    local hit_count = 0
    for _, unit in ipairs(get_enemies_in_range(center, math.max(220, get_skill_radius(skill) or 0, 320), except_unit, count)) do
      if hit_count == 0 then
        play_skill_audio(skill, 'chain', unit)
      end
      deal_skill_damage(unit, get_skill_damage(skill) * ratio, skill, {
        particle = vfx.chain_particle or vfx.impact_particle,
      })
      apply_generic_skill_statuses(skill, unit)
      hit_count = hit_count + 1
      if hit_count >= count then
        break
      end
    end
  end

  local function spawn_persistent_field(skill, center, opts)
    local duration = math.max(0, opts and opts.duration or skill and skill.persistent_field_duration or 0)
    local ratio = math.max(0, opts and opts.ratio or skill and skill.persistent_field_ratio or 0)
    local radius = math.max(120, opts and opts.radius or get_skill_radius(skill))
    if not center or duration <= 0 or ratio <= 0 then
      return
    end

    local tick_interval = 0.50
    local tick_count = math.max(1, round_number(duration / tick_interval))
    local tick_damage = get_skill_damage(skill) * ratio
    y3.ltimer.loop_count(tick_interval, tick_count, function()
      if STATE.game_finished then
        return
      end
      play_skill_particle_on_point(skill, center, 'sustain', 0)
      play_skill_audio(skill, 'tick', center)
      local hit_units = deal_area_skill_damage(center, radius, skill, tick_damage)
      for _, unit in ipairs(hit_units) do
        if (opts and opts.control) or skill.persistent_field_control then
          apply_hold_control(unit, 0.30)
        end
        if (opts and opts.ignite) or skill.persistent_field_ignite then
          apply_simple_ignite(unit, 3, math.max(0.05, ratio * 0.25))
        end
        apply_generic_skill_statuses(skill, unit)
      end
    end)
  end

  local function cast_blueprint_line_skill(skill, target, opts)
    local vfx = ATTACK_SKILL_VFX[skill.id] or {}
    local damage = get_skill_damage(skill)
    local origin_point = get_hero_point()
    play_skill_particle_on_unit(skill, STATE.hero, 'cast')

    launch_projectile_to_target(vfx, target, function(impact_point, did_hit)
      if did_hit ~= true then
        return
      end
      local center = impact_point or get_unit_point_snapshot(target)
      if center then
        play_skill_particle_on_point(skill, center, 'impact', 18)
      end
      if is_active_enemy(target) then
        play_skill_audio(skill, 'impact', target)
        deal_skill_damage(target, damage, skill, {
          particle = vfx.impact_particle,
        })
        apply_generic_skill_statuses(skill, target)
      end
      if origin_point and center then
        for _, unit in ipairs(get_enemies_on_line(
          origin_point,
          center,
          math.max(1, (skill.cast_range or 0) + (skill.range_bonus or 0)),
          skill.pierce_width or 110,
          math.max(0, skill.pierce or 0),
          target
        )) do
          play_skill_audio(skill, 'chain', unit)
          deal_skill_damage(unit, damage, skill, {
            particle = vfx.chain_particle or vfx.impact_particle,
          })
          apply_generic_skill_statuses(skill, unit)
        end
        if (opts and opts.return_pass) or skill.return_pass_enabled then
          for _, unit in ipairs(get_enemies_on_line(
            center,
            origin_point,
            math.max(1, (skill.cast_range or 0) + (skill.range_bonus or 0)),
            skill.pierce_width or 110,
            math.max(1, math.max(0, skill.pierce or 0) + 1),
            nil
          )) do
            deal_skill_damage(unit, damage * (opts and opts.return_ratio or skill.return_pass_ratio or 0.75), skill, {
              particle = vfx.chain_particle or vfx.impact_particle,
            })
            apply_generic_skill_statuses(skill, unit)
          end
        end
        trigger_skill_followup_hits(skill, center, target)
        trigger_skill_terminal_burst(skill, center)
      end
    end)
  end

  local function cast_blueprint_beam_skill(skill, target)
    play_skill_particle_on_unit(skill, STATE.hero, 'cast')
    run_skill_target_projectile(skill, target, function(impact_point)
      local duration = math.max(0.6, get_skill_duration(skill))
      local tick_interval = 0.30
      local tick_count = math.max(2, round_number(duration / tick_interval))
      local tick_damage = get_skill_damage(skill) / tick_count
      local locked_point = impact_point or get_unit_point_snapshot(target)
      y3.ltimer.loop_count(tick_interval, tick_count, function(_, current)
        if STATE.game_finished or not STATE.hero or not STATE.hero:is_exist() then
          return
        end
        local end_point = get_unit_point_snapshot(target) or locked_point
        local start_point = get_hero_point()
        if not start_point or not end_point then
          return
        end
        play_skill_particle_on_point(skill, end_point, 'sustain', 12)
        play_skill_audio(skill, 'tick', end_point)
        for _, unit in ipairs(get_enemies_on_line(
          start_point,
          end_point,
          math.max(1, (skill.cast_range or 0) + (skill.range_bonus or 0)),
          skill.sweep_enabled and 180 or 120,
          99,
          nil
        )) do
          deal_skill_damage(unit, tick_damage, skill)
          apply_generic_skill_statuses(skill, unit)
        end
        if skill.sweep_enabled then
          trigger_skill_followup_hits(skill, end_point, nil)
        end
        if current == tick_count then
          trigger_skill_terminal_burst(skill, end_point)
        end
      end)
    end, {
      allow_fallback = true,
    })
  end

  local function cast_blueprint_nova_skill(skill)
    local center = get_hero_point()
    local radius = math.max(120, get_skill_radius(skill))
    local hold_duration = math.max(0.25, get_skill_duration(skill))
    if not center then
      return
    end
    play_skill_particle_on_unit(skill, STATE.hero, 'cast')
    run_skill_local_projectile(skill, center, function(burst_center)
      if not burst_center then
        return
      end
      play_skill_particle_on_point(skill, burst_center, 'burst', 0)
      play_skill_audio(skill, 'burst', burst_center)
      for _, unit in ipairs(deal_area_skill_damage(burst_center, radius, skill, get_skill_damage(skill))) do
        apply_hold_control(unit, hold_duration)
        apply_generic_skill_statuses(skill, unit)
      end

      if skill.echo_count and skill.echo_count > 0 and (skill.echo_ratio or 0) > 0 then
        for echo_index = 1, math.max(1, round_number(skill.echo_count)), 1 do
          y3.ltimer.wait(0.20 * echo_index, function()
            if STATE.game_finished or not burst_center then
              return
            end
            play_skill_particle_on_point(skill, burst_center, 'sustain', 0)
            play_skill_audio(skill, 'tick', burst_center)
            for _, unit in ipairs(deal_area_skill_damage(burst_center, radius, skill, get_skill_damage(skill) * skill.echo_ratio)) do
              apply_hold_control(unit, math.max(0.15, hold_duration * 0.5))
              apply_generic_skill_statuses(skill, unit)
            end
          end)
        end
      end

      trigger_skill_followup_hits(skill, burst_center, nil)
      trigger_skill_terminal_burst(skill, burst_center)
      spawn_persistent_field(skill, burst_center)
    end, {
      allow_fallback = true,
    })
  end

  local function cast_blueprint_chain_skill(skill, target)
    play_skill_particle_on_unit(skill, STATE.hero, 'cast')
    run_skill_target_projectile(skill, target, function(impact_point, _, vfx)
      local damage = get_skill_damage(skill)
      local remaining = math.max(1, get_skill_bounce(skill))
      local current_target = target
      local current_center = impact_point or get_unit_point_snapshot(target)
      local hit_map = {}
      local visited = {}
      while current_target and remaining > 0 do
        hit_map[current_target] = true
        visited[#visited + 1] = current_target
        if current_center then
          play_skill_particle_on_point(skill, current_center, 'chain', 0)
        end
        play_skill_audio(skill, 'chain', current_target or current_center)
        deal_skill_damage(current_target, damage, skill, {
          particle = vfx.chain_particle or vfx.impact_particle,
        })
        apply_generic_skill_statuses(skill, current_target)
        apply_enemy_status(current_target, 'shock', {
          remaining = 1.0,
          bonus = 0.10,
        })
        try_add_status_modifier(current_target, ATTACK_STATUS_MODIFIER_KEYS.shock, 1.0)
        remaining = remaining - 1
        if remaining <= 0 then
          break
        end
        local next_target = nil
        for _, unit in ipairs(get_enemies_in_range(
          current_center or current_target,
          math.max(320, 420 + (skill.range_bonus or 0))
        )) do
          if not hit_map[unit] then
            next_target = unit
            break
          end
        end
        current_target = next_target
        current_center = next_target and get_unit_point_snapshot(next_target) or nil
      end

      if skill.return_pass_enabled and #visited >= 2 then
        for index = #visited - 1, 1, -1 do
          local unit = visited[index]
          if unit and is_active_enemy(unit) then
            play_skill_particle_on_point(skill, unit:get_point(), 'chain', 0)
            play_skill_audio(skill, 'chain', unit)
            deal_skill_damage(unit, damage * (skill.return_pass_ratio or 0.65), skill, {
              particle = vfx.chain_particle or vfx.impact_particle,
            })
            apply_generic_skill_statuses(skill, unit)
          end
        end
      end

      trigger_skill_terminal_burst(skill, current_center or impact_point or get_unit_point_snapshot(target))
    end, {
      allow_fallback = true,
    })
  end

  local function cast_blueprint_area_burst_skill(skill, target, delay)
    local radius = math.max(140, get_skill_radius(skill))
    play_skill_particle_on_unit(skill, STATE.hero, 'cast')
    run_skill_target_projectile(skill, target, function(center)
      local function detonate()
        if not center then
          return
        end
        play_skill_particle_on_point(skill, center, 'impact', 0)
        play_skill_particle_on_point(skill, center, 'burst', 0)
        play_skill_audio(skill, 'burst', center)
        local hit_units = deal_area_skill_damage(center, radius, skill, get_skill_damage(skill))
        for _, unit in ipairs(hit_units) do
          apply_generic_skill_statuses(skill, unit)
        end
        if skill.echo_count and skill.echo_count > 0 and (skill.echo_ratio or 0) > 0 then
          for echo_index = 1, math.max(1, round_number(skill.echo_count)), 1 do
            y3.ltimer.wait(0.22 * echo_index, function()
              if STATE.game_finished or not center then
                return
              end
              play_skill_particle_on_point(skill, center, 'sustain', 0)
              play_skill_audio(skill, 'tick', center)
              local echo_hits = deal_area_skill_damage(center, radius, skill, get_skill_damage(skill) * skill.echo_ratio)
              for _, unit in ipairs(echo_hits) do
                apply_generic_skill_statuses(skill, unit)
              end
            end)
          end
        end
        trigger_skill_followup_hits(skill, center, target)
        trigger_skill_terminal_burst(skill, center)
        spawn_persistent_field(skill, center)
      end
      if delay and delay > 0 then
        if center then
          play_skill_particle_on_point(skill, center, 'charge', 120)
          play_skill_audio(skill, 'charge', center)
        end
        y3.ltimer.wait(delay, function()
          if STATE.game_finished then
            return
          end
          detonate()
        end)
      else
        detonate()
      end
    end, {
      allow_fallback = true,
    })
  end

  local function cast_blueprint_field_skill(skill, target, opts)
    local radius = math.max(120, get_skill_radius(skill))
    local duration = math.max(1.2, get_skill_duration(skill))
    local tick_interval = 0.50
    local tick_count = math.max(2, round_number(duration / tick_interval))
    local tick_damage = get_skill_damage(skill) * 0.50
    play_skill_particle_on_unit(skill, STATE.hero, 'cast')
    run_skill_target_projectile(skill, target, function(start_center)
      local hero_point = get_hero_point()
      local angle = hero_point and start_center and hero_point:get_angle_with(start_center) or 0
      local move_step = math.max(40, ((skill.cast_range or 240) / math.max(1, tick_count)) * 0.55)
      play_skill_particle_on_point(skill, start_center, 'charge', 0)
      play_skill_audio(skill, 'charge', start_center)

      y3.ltimer.loop_count(tick_interval, tick_count, function(_, current)
        if STATE.game_finished then
          return
        end
        local center = start_center
        if skill.field_track_target and target and target:is_exist() then
          center = get_unit_point_snapshot(target) or center
        elseif opts and opts.moving and center then
          center = y3.point.get_point_offset_vector(start_center, angle, move_step * (current - 1))
        end
        if not center then
          return
        end
        play_skill_particle_on_point(skill, center, 'sustain', 0)
        play_skill_audio(skill, 'tick', center)
        local hit_units = deal_area_skill_damage(center, radius, skill, tick_damage)
        for _, unit in ipairs(hit_units) do
          if opts and opts.control then
            apply_hold_control(unit, math.min(0.35, duration))
          end
          if opts and opts.ignite then
            apply_simple_ignite(unit, 3, 0.08)
          end
          if (skill.pull_strength or 0) > 0 then
            pull_unit_towards_point(unit, center, skill.pull_strength)
          end
          apply_generic_skill_statuses(skill, unit)
        end
        if current == tick_count then
          trigger_skill_terminal_burst(skill, center)
        end
      end)
    end, {
      allow_fallback = true,
    })
  end

  local function cast_blueprint_seal_skill(skill, target)
    local radius = math.max(120, get_skill_radius(skill))
    local delay = math.max(0.2, get_skill_duration(skill) * 0.4)
    play_skill_particle_on_unit(skill, STATE.hero, 'cast')
    run_skill_target_projectile(skill, target, function(center)
      if center then
        play_skill_particle_on_point(skill, center, 'charge', 120)
        play_skill_audio(skill, 'charge', center)
        for _, unit in ipairs(get_enemies_in_range(center, radius)) do
          apply_hold_control(unit, delay)
        end
      end
      y3.ltimer.wait(delay, function()
        if STATE.game_finished or not center then
          return
        end
        play_skill_particle_on_point(skill, center, 'impact', 0)
        play_skill_particle_on_point(skill, center, 'burst', 0)
        play_skill_audio(skill, 'burst', center)
        local hit_units = deal_area_skill_damage(center, radius, skill, get_skill_damage(skill))
        for _, unit in ipairs(hit_units) do
          apply_generic_skill_statuses(skill, unit)
        end
        if skill.echo_count and skill.echo_count > 0 and (skill.echo_ratio or 0) > 0 then
          for echo_index = 1, math.max(1, round_number(skill.echo_count)), 1 do
            y3.ltimer.wait(0.25 * echo_index, function()
              if STATE.game_finished or not center then
                return
              end
              play_skill_particle_on_point(skill, center, 'sustain', 0)
              play_skill_audio(skill, 'tick', center)
              local echo_hits = deal_area_skill_damage(center, radius, skill, get_skill_damage(skill) * skill.echo_ratio)
              for _, unit in ipairs(echo_hits) do
                apply_generic_skill_statuses(skill, unit)
              end
            end)
          end
        end
        trigger_skill_followup_hits(skill, center, target)
        spawn_persistent_field(skill, center, {
          control = true,
        })
      end)
    end, {
      allow_fallback = true,
    })
  end

  local function cast_blueprint_seeking_swords(skill, target)
    local vfx = ATTACK_SKILL_VFX[skill.id] or {}
    local base_damage = get_skill_damage(skill)
    local sword_count = math.max(1, get_skill_bounce(skill))
    local initial_radius = math.max(320, 420 + (skill.range_bonus or 0))
    local split_count = math.max(0, round_number(skill.split_seek_count or 0))
    local split_ratio = math.max(0, skill.split_seek_ratio or 0)
    local split_radius = math.max(220, skill.split_seek_radius or 280)
    local split_depth = math.max(0, round_number(skill.split_seek_depth or 0))
    local kill_count = math.max(0, round_number(skill.kill_seek_count or 0))
    local kill_ratio = math.max(0, skill.kill_seek_ratio or 0)
    local kill_radius = math.max(split_radius, skill.kill_seek_radius or math.max(420, 460 + (skill.range_bonus or 0) * 0.35))
    local chain_state = {
      spawned = 0,
      max_spawned = math.max(18, sword_count * 4 + split_count * 6 + kill_count * 12),
    }

    local function reserve_sword_launch()
      if chain_state.spawned >= chain_state.max_spawned then
        return false
      end
      chain_state.spawned = chain_state.spawned + 1
      return true
    end

    local function build_seek_targets(center, radius, except_unit, count)
      local result = {}
      if not center or count <= 0 then
        return result
      end
      for _, unit in ipairs(get_enemies_in_range(center, radius)) do
        if unit ~= except_unit and is_active_enemy(unit) then
          result[#result + 1] = unit
          if #result >= count then
            break
          end
        end
      end
      return result
    end

    local launch_seek_sword

    local function queue_seek_burst(center, except_unit, count, ratio, child_split_depth, radius, delay_step)
      local launch_center = clone_point(center) or center
      if not launch_center or count <= 0 or ratio <= 0 then
        return
      end

      local launched = 0
      local did_queue = false
      for _, unit in ipairs(build_seek_targets(launch_center, radius, except_unit, count)) do
        if not reserve_sword_launch() then
          break
        end
        did_queue = true
        launched = launched + 1
        local victim = unit
        local delay = (launched - 1) * (delay_step or 0.05)
        y3.ltimer.wait(delay, function()
          if STATE.game_finished or not victim or not is_active_enemy(victim) then
            return
          end
          launch_seek_sword(victim, launch_center, base_damage * ratio, child_split_depth)
        end)
      end

      if did_queue then
        play_skill_particle_on_point(skill, launch_center, 'chain', 10)
        play_skill_audio(skill, 'chain', launch_center)
      end
    end

    launch_seek_sword = function(victim, origin_point, amount, remaining_split_depth)
      if not victim or not victim:is_exist() then
        return
      end

      local function on_hit(impact_point, did_hit)
        if did_hit ~= true then
          return
        end
        if impact_point then
          play_skill_particle_on_point(skill, impact_point, 'impact', 12)
        end
        if not is_active_enemy(victim) then
          return
        end

        local was_alive = is_unit_alive_now(victim)
        play_skill_audio(skill, 'impact', victim)
        deal_skill_damage(victim, amount, skill, {
          particle = vfx.impact_particle,
        })
        apply_generic_skill_statuses(skill, victim)

        local burst_center = impact_point or get_unit_point_snapshot(victim)
        if burst_center and split_count > 0 and split_ratio > 0 and remaining_split_depth > 0 then
          queue_seek_burst(
            burst_center,
            victim,
            split_count,
            split_ratio,
            math.max(0, remaining_split_depth - 1),
            split_radius,
            0.04
          )
        end
        if burst_center and kill_count > 0 and kill_ratio > 0 and was_alive and not is_unit_alive_now(victim) then
          queue_seek_burst(
            burst_center,
            victim,
            kill_count,
            kill_ratio,
            math.max(0, remaining_split_depth - 1),
            kill_radius,
            0.02
          )
        end
        trigger_skill_followup_hits(skill, burst_center or victim:get_point(), victim)
      end

      if origin_point then
        launch_projectile_from_point_to_target(vfx, origin_point, victim, on_hit)
        return
      end
      launch_projectile_to_target(vfx, victim, on_hit)
    end

    local targets = { target }
    local center = get_unit_point_snapshot(target)
    for _, unit in ipairs(build_seek_targets(center or target, initial_radius, target, sword_count - 1)) do
      targets[#targets + 1] = unit
      if #targets >= sword_count then
        break
      end
    end

    play_skill_particle_on_unit(skill, STATE.hero, 'cast')
    for index, victim in ipairs(targets) do
      if not reserve_sword_launch() then
        break
      end
      y3.ltimer.wait((index - 1) * 0.08, function()
        if STATE.game_finished or not victim or not is_active_enemy(victim) then
          return
        end
        launch_seek_sword(victim, nil, base_damage, split_depth)
      end)
    end
  end

  local function cast_basic_attack_skill(skill, target)
    local vfx = ATTACK_SKILL_VFX.basic_attack
    local damage = get_skill_damage(skill)
    local multishot_count, multishot_ratio = get_basic_attack_multishot_bonus()
    local split_count = math.max(0, round_number(get_effective_skill_value(skill, 'split_count')))
    local split_ratio = get_effective_skill_value(skill, 'split_ratio')
    local hero_point = get_hero_point()
    play_skill_particle_on_unit(skill, STATE.hero, 'cast')
    play_basic_attack_animation()
    if play_basic_attack_sound then
      play_basic_attack_sound(STATE.hero)
    end
    if notify_auto_active_basic_attack then
      notify_auto_active_basic_attack(target)
    end
    if hero_point and target and target:is_exist() and not STATE.hero:has_state('禁止转向') then
      STATE.hero:set_facing(hero_point:get_angle_with(target:get_point()), 0.08)
    end

    launch_projectile_to_target(vfx, target, function(impact_point, did_hit)
      if STATE.game_finished or not STATE.hero or not STATE.hero:is_exist() then
        return
      end
      if did_hit ~= true then
        return
      end

      local impact_center = impact_point or get_unit_point_snapshot(target)
      local splash_center = impact_center or target
      local secondary_search_radius = get_basic_attack_secondary_search_radius()
      local extra_hit_particle = vfx.chain_particle or vfx.impact_particle
      local basic_attack_def = ATTACK_SKILL_DEFS.basic_attack or skill
      local runtime = STATE.skill_runtime or {}
      local runtime_chain_count, runtime_chain_chance, runtime_chain_ratio = get_basic_attack_runtime_chain_stats()
      local bonus_chain_count, bonus_chain_ratio = get_basic_attack_bonus_chain_stats()
      local explosion_ratio = math.max(0, get_effective_skill_value(skill, 'explosion_ratio'))
      local explosion_radius = math.max(0, get_effective_skill_value(skill, 'explosion_radius'))

      if impact_center then
        play_skill_particle_on_point(skill, impact_center, 'impact', 18)
      end
      play_skill_audio(skill, 'impact', target or impact_center)

      if is_active_enemy(target) then
        deal_basic_attack_damage(skill, target, damage, {
          common_attack = false,
        })
        if (runtime.normal_attack_bonus_ratio or 0) > 0 then
          deal_skill_damage(target, damage * runtime.normal_attack_bonus_ratio, '物理', {
            text_type = 'physics',
          })
        end
        try_trigger_hunter_first_hit(target)
        apply_armor_break_on_hit(target)
      end

      if explosion_ratio > 0 and explosion_radius > 0 then
        local splash_units = get_enemies_in_range(splash_center, explosion_radius, target)
        if #splash_units > 0 then
          if impact_center then
            play_skill_particle_on_point(skill, impact_center, 'burst', 18)
          end
          play_skill_audio(skill, 'burst', impact_center or splash_center)
          for _, unit in ipairs(splash_units) do
            deal_basic_attack_secondary_damage(skill, unit, damage * explosion_ratio, {
              particle = extra_hit_particle,
              stage = 'chain',
            })
          end
        end
      end

      if multishot_count > 0 and multishot_ratio > 0 then
        local hit_count = 0
        for _, unit in ipairs(get_enemies_in_range(
          splash_center,
          secondary_search_radius,
          target,
          multishot_count
        )) do
          if deal_basic_attack_secondary_damage(skill, unit, damage * multishot_ratio, {
            text_type = 'physics',
            particle = extra_hit_particle,
            audio_stage = hit_count == 0 and 'chain' or nil,
          }) then
            hit_count = hit_count + 1
          end
          if hit_count >= multishot_count then
            break
          end
        end
      end

      if split_count > 0 and split_ratio > 0 then
        local split_hits = 0
        for _, unit in ipairs(get_enemies_in_range(
          splash_center,
          secondary_search_radius,
          target,
          split_count
        )) do
          if deal_basic_attack_secondary_damage(skill, unit, damage * split_ratio, {
            particle = extra_hit_particle,
            audio_stage = split_hits == 0 and 'chain' or nil,
          }) then
            split_hits = split_hits + 1
          end
          if split_hits >= split_count then
            break
          end
        end
      end

      if (runtime.splash_ratio or 0) > 0 and (runtime.splash_radius or 0) > 0 then
        local bonus_splash_units = get_enemies_in_range(splash_center, runtime.splash_radius, target)
        if #bonus_splash_units > 0 then
          if impact_center then
            play_skill_particle_on_point(skill, impact_center, 'burst', 18)
          end
          play_skill_audio(skill, 'burst', impact_center or splash_center)
          for _, unit in ipairs(bonus_splash_units) do
            deal_basic_attack_secondary_damage(skill, unit, damage * runtime.splash_ratio, {
              use_skill_damage = true,
              damage_meta = '物理',
              text_type = 'physics',
              particle = extra_hit_particle,
              stage = 'chain',
            })
          end
        end
      end

      if runtime_chain_count > 0 and runtime_chain_ratio > 0 and runtime_chain_chance > 0 and math.random() <= runtime_chain_chance then
        local bounced = 0
        for _, unit in ipairs(get_enemies_in_range(splash_center, runtime.chain_radius or 420, target, runtime_chain_count)) do
          if deal_basic_attack_secondary_damage(skill, unit, damage * runtime_chain_ratio, {
            use_skill_damage = true,
            damage_meta = basic_attack_def,
            text_type = 'physics',
            particle = extra_hit_particle,
            audio_stage = bounced == 0 and 'chain' or nil,
          }) then
            bounced = bounced + 1
          end
          if bounced >= runtime_chain_count then
            break
          end
        end
      end

      if bonus_chain_count > 0 and bonus_chain_ratio > 0 then
        local bounced = 0
        for _, unit in ipairs(get_enemies_in_range(
          splash_center,
          math.max(runtime.chain_radius or 0, 420),
          target,
          bonus_chain_count
        )) do
          if deal_basic_attack_secondary_damage(skill, unit, damage * bonus_chain_ratio, {
            use_skill_damage = true,
            damage_meta = basic_attack_def,
            text_type = 'physics',
            particle = extra_hit_particle,
            audio_stage = bounced == 0 and 'chain' or nil,
            skip_hunter_first_hit = true,
          }) then
            bounced = bounced + 1
          end
          if bounced >= bonus_chain_count then
            break
          end
        end
      end
    end, STATE.hero_common_attack and STATE.hero_common_attack:is_exist() and STATE.hero_common_attack or nil)
  end
  
  local function cast_attack_skill_once(skill, target)
    local cast_family = get_skill_cast_family(skill)
    if cast_family == 'basic_projectile' then
      cast_basic_attack_skill(skill, target)
      return
    end
  
    if notify_bond_attack_skill_cast then
      notify_bond_attack_skill_cast(skill, target)
    end
    if notify_auto_active_skill_cast then
      notify_auto_active_skill_cast(skill, target)
    end
  
    if cast_family == 'line_pierce' then
      cast_blueprint_line_skill(skill, target)
      return
    end
    if cast_family == 'beam' then
      cast_blueprint_beam_skill(skill, target)
      return
    end
    if cast_family == 'nova' then
      cast_blueprint_nova_skill(skill)
      return
    end
    if cast_family == 'chain' then
      cast_blueprint_chain_skill(skill, target)
      return
    end
    if cast_family == 'area_burst' then
      cast_blueprint_area_burst_skill(skill, target, 0)
      return
    end
    if cast_family == 'moving_field' then
      cast_blueprint_field_skill(skill, target, { moving = true })
      return
    end
    if cast_family == 'control_field' then
      cast_blueprint_field_skill(skill, target, { control = true })
      return
    end
    if cast_family == 'delayed_area_burst' then
      cast_blueprint_area_burst_skill(skill, target, (ATTACK_SKILL_VFX[skill.id] and ATTACK_SKILL_VFX[skill.id].strike_delay) or 0.45)
      return
    end
    if cast_family == 'persistent_field' then
      cast_blueprint_field_skill(skill, target, {})
      return
    end
    if cast_family == 'line_return' then
      cast_blueprint_line_skill(skill, target, {
        return_pass = true,
        return_ratio = 0.80,
      })
      return
    end
    if cast_family == 'ignite_field' then
      cast_blueprint_field_skill(skill, target, {
        ignite = true,
      })
      return
    end
    if cast_family == 'seal_burst' then
      cast_blueprint_seal_skill(skill, target)
      return
    end
    if cast_family == 'seeking_swords' then
      cast_blueprint_seeking_swords(skill, target)
      return
    end

    local archetype = get_skill_archetype(skill)
    if archetype == '点面兼顾爆炸' then
      cast_blueprint_area_burst_skill(skill, target, 0.12)
      return
    end
  end
  
  local function try_cast_attack_skill(skill)
    if not skill or skill.id == 'basic_attack' then
      return
    end
  
    local first_target = pick_skill_target(skill)
    if not first_target then
      return
    end

    play_skill_audio(skill, 'cast', STATE.hero)
  
    local cast_times = math.max(1, skill.repeat_count or 1)
    local skill_echo_chance = math.max(0, get_bond_runtime_bonus('skill_echo_chance') or 0)
    if skill_echo_chance > 0 and math.random() <= math.min(1, skill_echo_chance) then
      cast_times = cast_times + 1
    end
    for cast_index = 1, cast_times, 1 do
      local target = cast_index == 1 and first_target or pick_skill_target(skill)
      if not target then
        break
      end
      cast_attack_skill_once(skill, target)
    end
  
    skill.cooldown_remaining = get_skill_current_cooldown(skill)
  end
  
  local function update_basic_attack(dt)
    local skill = get_basic_attack_skill()
    if not skill or not STATE.hero or not STATE.hero:is_exist() then
      return
    end
  
    skill.cooldown_remaining = math.max(0, (skill.cooldown_remaining or 0) - dt)
    if skill.cooldown_remaining > 0 then
      return
    end
  
    local target = pick_skill_target(skill)
    if not target then
      return
    end
  
    cast_attack_skill_once(skill, target)
    skill.cooldown_remaining = get_basic_attack_interval(skill)
  end
  
  local function update_attack_skills(dt)
    if not STATE.attack_skill_state or not STATE.hero or not STATE.hero:is_exist() then
      return
    end
  
    update_basic_attack(dt)
  
    for slot = 1, 4, 1 do
      local skill = STATE.attack_skill_state.slots[slot]
      if skill and skill.id ~= 'basic_attack' then
        skill.cooldown_remaining = math.max(0, (skill.cooldown_remaining or 0) - dt)
        if skill.cooldown_remaining <= 0 then
          try_cast_attack_skill(skill)
        end
      end
    end
  end

  return {
    get_basic_attack_skill = get_basic_attack_skill,
    get_current_basic_attack_range = get_current_basic_attack_range,
    sync_basic_attack_ability = sync_basic_attack_ability,
    setup_basic_attack_ability = setup_basic_attack_ability,
    get_attack_skill = get_attack_skill,
    get_attack_skill_slot = get_attack_skill_slot,
    get_empty_attack_skill_slot = get_empty_attack_skill_slot,
    get_unlocked_attack_skill_count = get_unlocked_attack_skill_count,
    get_upgrade_pick_count = get_upgrade_pick_count,
    record_upgrade_pick = record_upgrade_pick,
    build_attack_skill_slot_text = build_attack_skill_slot_text,
    show_attack_skill_loadout = show_attack_skill_loadout,
    unlock_attack_skill = unlock_attack_skill,
    update_enemy_statuses = update_enemy_statuses,
    update_attack_skills = update_attack_skills,
  }
end

return M

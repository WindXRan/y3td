local CONFIG = require 'entry_config'
local develop_command = require 'y3.develop.command'
local M = {}

local function create_skill_runtime()
  return {
    normal_attack_bonus_ratio = 0,
    splash_ratio = 0,
    splash_radius = 220,
    chain_chance = 0,
    chain_bounces = 0,
    chain_ratio = 0,
    chain_radius = 420,
    execute_threshold = 0,
    medbot_every = 0,
    medbot_heal = 0,
    medbot_kills = 0,
    artillery_interval = 0,
    artillery_ratio = 0,
    artillery_base = 0,
    artillery_radius = 0,
    artillery_cd = 0,
    bonus_gold_on_kill = 0,
  }
end

local ATTACK_SKILL_DEFS = {
  basic_attack = {
    id = 'basic_attack',
    name = '普攻',
    default_slot = 1,
    summary = '发射 1 支箭矢，造成 100% 攻击的物理伤害。',
    damage_type = '物理',
    base_damage_ratio = 1.0,
    base_cooldown = 1.7,
    base_range = 700,
  },
  arcane_arrow = {
    id = 'arcane_arrow',
    name = '奥术箭',
    summary = '射出 1 支奥术箭，造成能量魔法伤害。',
    damage_type = '法术',
    base_damage_ratio = 0.8,
    base_cooldown = 2.0,
    base_range = 900,
    base_pierce = 1,
  },
  flame_arrow = {
    id = 'flame_arrow',
    name = '爆炎箭',
    summary = '射出 1 支爆炎箭，命中后爆炸造成火系物理伤害。',
    damage_type = '物理',
    base_damage_ratio = 2.2,
    base_cooldown = 6.2,
    base_range = 900,
    base_explosion_ratio = 1.8,
    base_explosion_radius = 220,
  },
  frost_arrow = {
    id = 'frost_arrow',
    name = '寒冰箭',
    summary = '射出 1 支寒冰箭，造成冰系魔法伤害。',
    damage_type = '法术',
    base_damage_ratio = 1.7,
    base_cooldown = 4.8,
    base_range = 920,
    base_pierce = 0,
  },
  thunder = {
    id = 'thunder',
    name = '天雷',
    summary = '召唤 1 道天雷打击目标，造成电系魔法伤害。',
    damage_type = '法术',
    base_damage_ratio = 2.0,
    base_cooldown = 5.5,
    base_range = 950,
    base_extra_targets = 0,
  },
}

local ATTACK_SKILL_VFX = {
  basic_attack = {
    projectile_key = 134257292,
    projectile_speed = 1100,
    projectile_time = 2.2,
    target_distance = 55,
    impact_particle = 102820,
    impact_scale = 0.60,
    impact_time = 0.18,
  },
  arcane_arrow = {
    projectile_key = 134222874,
    projectile_speed = 1200,
    projectile_time = 2.5,
    target_distance = 70,
    cast_particle = 102820,
    cast_scale = 0.75,
    cast_time = 0.20,
    impact_particle = 102820,
    impact_scale = 0.95,
    impact_time = 0.30,
  },
  flame_arrow = {
    projectile_key = 134218466,
    projectile_speed = 980,
    projectile_time = 3.0,
    target_distance = 75,
    cast_particle = 102521,
    cast_scale = 0.85,
    cast_time = 0.20,
    impact_particle = 102702,
    impact_scale = 1.10,
    impact_time = 0.35,
    explosion_particle = 102705,
    explosion_scale = 1.20,
    explosion_time = 0.45,
  },
  frost_arrow = {
    projectile_key = 134236870,
    projectile_speed = 920,
    projectile_time = 3.0,
    target_distance = 70,
    cast_particle = 102750,
    cast_scale = 0.80,
    cast_time = 0.20,
    impact_particle = 102754,
    impact_scale = 1.00,
    impact_time = 0.35,
  },
  thunder = {
    charge_particle = 102740,
    charge_scale = 0.85,
    charge_time = 0.16,
    impact_particle = 102731,
    impact_scale = 1.20,
    impact_time = 0.40,
    chain_particle = 102740,
    chain_scale = 0.85,
    chain_time = 0.25,
    strike_delay = 0.12,
  },
}

local function create_attack_skill_instance(skill_id, slot)
  local def = ATTACK_SKILL_DEFS[skill_id]
  return {
    id = def.id,
    name = def.name,
    slot = slot or def.default_slot or 0,
    summary = def.summary,
    damage_type = def.damage_type,
    level = 1,
    unlocked = true,
    damage_ratio = def.base_damage_ratio or 0,
    base_cooldown = def.base_cooldown or 0,
    cooldown_reduction = 0,
    cooldown_remaining = 0,
    cast_range = def.base_range or 0,
    range_bonus = 0,
    attack_speed_bonus = 0,
    pierce = def.base_pierce or 0,
    repeat_count = def.base_repeat_count or 1,
    explosion_ratio = def.base_explosion_ratio or 0,
    explosion_radius = def.base_explosion_radius or 0,
    extra_targets = def.base_extra_targets or 0,
  }
end

local function create_attack_skill_state()
  local basic_attack = create_attack_skill_instance('basic_attack', 1)
  return {
    slots = {
      [1] = basic_attack,
      [2] = nil,
      [3] = nil,
      [4] = nil,
    },
    by_id = {
      basic_attack = basic_attack,
    },
    upgrade_counts = {},
  }
end

local STATE = {
  hero = nil,
  hero_common_attack = nil,
  hero_spawn_point = nil,
  defense_point = nil,
  all_enemies = nil,
  total_enemy_alive = 0,
  current_wave_index = 0,
  started_wave_count = 0,
  active_wave = nil,
  active_challenges = nil,
  resources = nil,
  skill_points = 0,
  hero_progress = nil,
  awaiting_upgrade = false,
  current_upgrade_choices = nil,
  skill_runtime = nil,
  attack_skill_state = nil,
  challenge_charges = 0,
  challenge_recover_elapsed = 0,
  bond_draw_count = 0,
  defeated_boss_waves = nil,
  basic_attack_ability_bound = false,
  basic_attack_ability_warned = false,
  game_finished = false,
}

local function get_player()
  return y3.player(CONFIG.player_id)
end

local function get_enemy_player()
  return y3.player(CONFIG.enemy_player_id)
end

local function message(text)
  print(text)
  get_player():display_message(text)
end

local function make_point(data)
  return y3.point.create(data.x, data.y, data.z or 0)
end

local function round_number(value)
  return math.floor((value or 0) + 0.5)
end

local function get_basic_attack_skill()
  if not STATE.attack_skill_state or not STATE.attack_skill_state.by_id then
    return nil
  end
  return STATE.attack_skill_state.by_id.basic_attack
end

local function get_current_basic_attack_range()
  if not STATE.hero or not STATE.hero:is_exist() then
    return ATTACK_SKILL_DEFS.basic_attack.base_range or 0
  end
  return math.max(1, round_number(STATE.hero:get_attr('attack_range')))
end

local function build_basic_attack_ability_description(skill)
  if not skill then
    return '当前普攻技能。'
  end

  local lines = {
    string.format('当前普攻：造成 %.0f%% 攻击的物理伤害。', (skill.damage_ratio or 0) * 100),
    string.format('当前射程：%d。', get_current_basic_attack_range()),
  }

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

  if STATE.skill_runtime and STATE.skill_runtime.chain_bounces > 0 and STATE.skill_runtime.chain_chance > 0 then
    lines[#lines + 1] = string.format(
      '弹射：%.0f%% 概率弹射 %d 个目标，造成 %.0f%% 法术伤害。',
      STATE.skill_runtime.chain_chance * 100,
      STATE.skill_runtime.chain_bounces,
      STATE.skill_runtime.chain_ratio * 100
    )
  end

  if STATE.skill_runtime and STATE.skill_runtime.execute_threshold > 0 then
    lines[#lines + 1] = string.format(
      '处决：目标生命低于 %.0f%% 时立即击杀。',
      STATE.skill_runtime.execute_threshold * 100
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

local function get_hero_progression_rules()
  return CONFIG.hero_progression or {}
end

local function get_hero_max_level()
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
  if level >= get_hero_max_level() then
    return 0
  end

  if STATE.hero and STATE.hero:is_exist() and level < get_engine_exp_cap_level() and STATE.hero:get_level() == level then
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
  }
  sync_hero_progression()
end

local function sync_hero_progress_from_engine()
  if not STATE.hero_progress or not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  STATE.hero_progress.level = math.max(1, math.min(STATE.hero:get_level(), get_engine_exp_cap_level()))
  STATE.hero_progress.exp = math.max(0, round_number(y3.helper.tonumber(STATE.hero:get_exp()) or 0))
  STATE.hero_progress.exp_to_next = get_hero_next_level_exp(STATE.hero_progress.level)
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

  if STATE.hero and STATE.hero:is_exist() and progress.level < get_engine_exp_cap_level() and STATE.hero:get_level() < get_engine_exp_cap_level() then
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
      STATE.skill_points = STATE.skill_points + 1
      message(string.format('英雄升级至 %d，获得 1 点技能点。按 G 打开强化选择。', progress.level))
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

local function show_runtime_status_legacy()
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

  message(string.format(
    '状态：%s，%s，英雄 %s，敌人数 %d，金币 %d，木材 %d，技能点 %d，挑战次数 %d/%d，进行中挑战 %d。',
    wave_text,
    boss_text,
    get_hero_progress_text(),
    STATE.total_enemy_alive,
    STATE.resources.gold,
    STATE.resources.wood,
    STATE.skill_points,
    STATE.challenge_charges,
    CONFIG.challenge_rules.max_charges,
    challenge_count
  ))
  show_attack_skill_loadout()
end

local function point_to_table(point)
  return {
    x = round_number(point:get_x()),
    y = round_number(point:get_y()),
    z = round_number(point:get_z()),
  }
end

local function format_point(point)
  if not point then
    return '(nil)'
  end
  return string.format('(%d, %d, %d)', round_number(point:get_x()), round_number(point:get_y()), round_number(point:get_z()))
end

local function design_seconds(seconds)
  if CONFIG.debug_time_scale <= 0 then
    return seconds
  end
  return seconds / CONFIG.debug_time_scale
end

local function get_area(area_id)
  return CONFIG.areas[area_id]
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

local function get_area_size(area_id)
  local area = get_area(area_id)
  if not area then
    return nil, nil
  end
  return area.x_max - area.x_min, area.y_max - area.y_min
end

local function get_hero_point()
  if not STATE.hero or not STATE.hero:is_exist() then
    return nil
  end
  return STATE.hero:get_point()
end

local function update_point_config(point_key, point)
  local value = point_to_table(point)
  CONFIG.points[point_key] = value
  if point_key == 'hero_spawn' then
    STATE.hero_spawn_point = make_point(value)
  elseif point_key == 'defense_point' then
    STATE.defense_point = make_point(value)
  end
  return value
end

local function recenter_area(area_id, center_point, width, height, offset_x, offset_y)
  local area = get_area(area_id)
  if not area then
    return nil
  end

  local current_width, current_height = get_area_size(area_id)
  width = width or current_width or 200
  height = height or current_height or 200
  offset_x = offset_x or 0
  offset_y = offset_y or 0

  local cx = center_point:get_x() + offset_x
  local cy = center_point:get_y() + offset_y
  local half_w = width / 2
  local half_h = height / 2

  area.x_min = round_number(cx - half_w)
  area.x_max = round_number(cx + half_w)
  area.y_min = round_number(cy - half_h)
  area.y_max = round_number(cy + half_h)
  area.z = round_number(center_point:get_z())
  return area
end

local function dump_calibration_file()
  local lines = {
    '-- 游戏内校准导出',
    'return {',
    '  points = {',
  }

  for key, point in pairs(CONFIG.points) do
    lines[#lines + 1] = string.format(
      '    %s = { x = %d, y = %d, z = %d },',
      key,
      round_number(point.x),
      round_number(point.y),
      round_number(point.z or 0)
    )
  end

  lines[#lines + 1] = '  },'
  lines[#lines + 1] = '  areas = {'

  for key, area in pairs(CONFIG.areas) do
    lines[#lines + 1] = string.format(
      '    %s = { x_min = %d, x_max = %d, y_min = %d, y_max = %d, z = %d },',
      key,
      round_number(area.x_min),
      round_number(area.x_max),
      round_number(area.y_min),
      round_number(area.y_max),
      round_number(area.z or 0)
    )
  end

  lines[#lines + 1] = '  },'
  lines[#lines + 1] = '}'

  y3.fs.save('.log/entry_calibration.lua', table.concat(lines, '\n'))
  message('已导出当前 points/areas 到 script/.log/entry_calibration.lua')
end

local function show_calibration_help()
  message('校准指令：.epos / .eset hero / .eset defense / .earea 区域名 [宽] [高] [偏移X] [偏移Y] / .eblink hero|defense / .edump')
end

local function register_dev_commands()
  if STATE.dev_commands_registered then
    return
  end
  STATE.dev_commands_registered = true

  develop_command.register('EPOS', {
    desc = '打印英雄、防线与主要刷新区域坐标。',
    onCommand = function()
      local hero_point = get_hero_point()
      message('英雄当前位置：' .. format_point(hero_point))
      message('英雄出生点：' .. format_point(STATE.hero_spawn_point))
      message('防线点：' .. format_point(STATE.defense_point))
      for _, area_id in ipairs({
        'main_spawn_wave_1',
        'main_spawn_wave_3',
        'main_spawn_wave_5',
        'challenge_spawn_top',
        'challenge_spawn_mid',
        'challenge_spawn_bottom',
      }) do
        local area = get_area(area_id)
        if area then
          message(string.format(
            '%s: x[%d,%d] y[%d,%d]',
            area_id,
            round_number(area.x_min),
            round_number(area.x_max),
            round_number(area.y_min),
            round_number(area.y_max)
          ))
        end
      end
    end,
  })

  develop_command.register('ESET', {
    desc = '把 hero/defense 记录到当前英雄位置。',
    onCommand = function(target)
      local hero_point = get_hero_point()
      if not hero_point then
        message('当前没有可用英雄，无法记录坐标。')
        return
      end

      target = (target or ''):lower()
      if target == 'hero' then
        local value = update_point_config('hero_spawn', hero_point)
        message(string.format('已记录 hero_spawn = (%d, %d, %d)', value.x, value.y, value.z))
        return
      end
      if target == 'defense' then
        local value = update_point_config('defense_point', hero_point)
        message(string.format('已记录 defense_point = (%d, %d, %d)', value.x, value.y, value.z))
        return
      end

      show_calibration_help()
    end,
  })

  develop_command.register('EAREA', {
    desc = '以当前英雄位置为中心重设某个刷新区域。',
    onCommand = function(area_id, width, height, offset_x, offset_y)
      local hero_point = get_hero_point()
      if not hero_point then
        message('当前没有可用英雄，无法设置区域。')
        return
      end
      if not area_id or area_id == '' then
        show_calibration_help()
        return
      end
      if not get_area(area_id) then
        message('未知区域：' .. tostring(area_id))
        return
      end

      local area = recenter_area(
        area_id,
        hero_point,
        tonumber(width),
        tonumber(height),
        tonumber(offset_x),
        tonumber(offset_y)
      )
      if area then
        message(string.format(
          '已重设 %s: x[%d,%d] y[%d,%d]',
          area_id,
          round_number(area.x_min),
          round_number(area.x_max),
          round_number(area.y_min),
          round_number(area.y_max)
        ))
      end
    end,
  })

  develop_command.register('EBLINK', {
    desc = '把英雄传送到 hero_spawn 或 defense_point。',
    onCommand = function(target)
      if not STATE.hero or not STATE.hero:is_exist() then
        message('当前没有可用英雄，无法传送。')
        return
      end

      target = (target or ''):lower()
      if target == 'hero' then
        STATE.hero:blink(STATE.hero_spawn_point)
        message('英雄已传送到 hero_spawn。')
        return
      end
      if target == 'defense' then
        STATE.hero:blink(STATE.defense_point)
        message('英雄已传送到 defense_point。')
        return
      end

      show_calibration_help()
    end,
  })

  develop_command.register('EDUMP', {
    desc = '导出当前校准后的 points/areas 到日志文件。',
    onCommand = function()
      dump_calibration_file()
    end,
  })
end

local function has_unit_data(unit_id)
  return unit_id ~= nil and y3.object.unit[unit_id] and y3.object.unit[unit_id].data ~= nil
end

local function is_active_enemy(unit)
  return unit
    and unit:is_exist()
    and STATE.all_enemies
    and unit:is_in_group(STATE.all_enemies)
end

local function get_enemies_in_range(center, radius, except_unit)
  local result = {}
  local picked = y3.selector.create()
    :is_enemy(get_player())
    :in_range(center, radius)
    :sort_type('由近到远')
    :pick()

  for _, unit in ipairs(picked) do
    if unit ~= except_unit and is_active_enemy(unit) then
      result[#result + 1] = unit
    end
  end

  return result
end

local function resolve_damage_text_type(damage_type, visual)
  if visual and visual.text_type then
    return visual.text_type
  end

  if damage_type == ATTACK_SKILL_DEFS.basic_attack.damage_type
    or damage_type == ATTACK_SKILL_DEFS.flame_arrow.damage_type then
    return 'physics'
  end

  return 'magic'
end

local function deal_skill_damage(target, amount, damage_type, visual)
  if not STATE.hero or not STATE.hero:is_exist() or not is_active_enemy(target) then
    return
  end

  local final_damage = math.floor(amount or 0)
  if final_damage <= 0 then
    return
  end

  STATE.hero:damage({
    target = target,
    damage = final_damage,
    type = damage_type or '法术',
    text_type = resolve_damage_text_type(damage_type, visual),
    text_track = visual and visual.text_track or 934269508,
    particle = visual and visual.particle or nil,
    socket = visual and visual.socket or '',
    pos_socket = visual and visual.pos_socket or '',
    common_attack = false,
    no_miss = true,
  })
end

local function heal_hero(amount)
  if amount <= 0 or not STATE.hero or not STATE.hero:is_exist() then
    return
  end

  local before = STATE.hero:get_hp()
  STATE.hero:add_hp(amount)
  if STATE.hero:get_hp() > before then
    message(string.format('急救生效，英雄生命恢复至 %.0f。', STATE.hero:get_hp()))
  end
end

local function award_rewards(reward, source_text, silent)
  if not reward then
    return
  end

  if reward.gold and reward.gold > 0 then
    STATE.resources.gold = STATE.resources.gold + reward.gold
  end

  if reward.wood and reward.wood > 0 then
    STATE.resources.wood = STATE.resources.wood + reward.wood
  end

  if reward.exp and reward.exp > 0 then
    grant_hero_exp(reward.exp)
  end

  if silent then
    return
  end

  local parts = {}
  if reward.gold and reward.gold > 0 then
    parts[#parts + 1] = ('金币 +' .. tostring(reward.gold))
  end
  if reward.wood and reward.wood > 0 then
    parts[#parts + 1] = ('木材 +' .. tostring(reward.wood))
  end
  if reward.exp and reward.exp > 0 then
    parts[#parts + 1] = ('经验 +' .. tostring(reward.exp))
  end
  if reward.special then
    parts[#parts + 1] = tostring(reward.special)
  end

  if #parts > 0 then
    message(string.format('%s：%s', source_text or '获得奖励', table.concat(parts, '，')))
  end
end

local function get_current_wave()
  return CONFIG.waves[STATE.current_wave_index]
end

local function get_boss_name(wave)
  return string.format('第%d波Boss', wave.index)
end

local function show_runtime_status()
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

  message(string.format(
    '状态：%s，%s，英雄 %s，敌人数 %d，金币 %d，木材 %d，技能点 %d，挑战次数 %d/%d，进行中挑战 %d。',
    wave_text,
    boss_text,
    get_hero_progress_text(),
    STATE.total_enemy_alive,
    STATE.resources.gold,
    STATE.resources.wood,
    STATE.skill_points,
    STATE.challenge_charges,
    CONFIG.challenge_rules.max_charges,
    challenge_count
  ))
  show_attack_skill_loadout()
end

local UPGRADE_POOL = {
  {
    key = 'attack_1',
    name = '力量打击',
    desc = '物理攻击 +18。',
    apply = function(state)
      state.hero:add_attr('物理攻击', 18)
    end,
  },
  {
    key = 'attack_2',
    name = '重击训练',
    desc = '物理攻击 +28。',
    apply = function(state)
      state.hero:add_attr('物理攻击', 28)
    end,
  },
  {
    key = 'attack_speed_1',
    name = '高速连射',
    desc = '攻击速度 +35%。',
    apply = function(state)
      state.hero:add_attr('攻击速度', 35)
    end,
  },
  {
    key = 'crit_chance',
    name = '致命专注',
    desc = '暴击率 +10%。',
    apply = function(state)
      state.hero:add_attr('暴击率', 10)
    end,
  },
  {
    key = 'hp_max',
    name = '生命强化',
    desc = '最大生命 +180，并回复 180 生命。',
    apply = function(state)
      state.hero:add_attr('最大生命', 180)
      state.hero:add_hp(180)
    end,
  },
  {
    key = 'regen',
    name = '呼吸法',
    desc = '生命恢复 +4。',
    apply = function(state)
      state.hero:add_attr('生命恢复', 4)
    end,
  },
  {
    key = 'lifesteal',
    name = '战斗续航',
    desc = '物理吸血 +6%。',
    apply = function(state)
      state.hero:add_attr('物理吸血', 6)
    end,
  },
  {
    key = 'splash_shell',
    name = '爆裂弹头',
    desc = '普攻会对目标周围造成 35% 溅射伤害。',
    apply = function(state)
      state.skill_runtime.splash_ratio = state.skill_runtime.splash_ratio + 0.35
      state.skill_runtime.splash_radius = math.max(state.skill_runtime.splash_radius, 220)
      sync_basic_attack_ability()
    end,
  },
  {
    key = 'chain_arc',
    name = '连锁电弧',
    desc = '普攻有 25% 概率弹射 2 个目标，造成 45% 法术伤害。',
    apply = function(state)
      state.skill_runtime.chain_chance = state.skill_runtime.chain_chance + 0.25
      state.skill_runtime.chain_bounces = math.max(state.skill_runtime.chain_bounces, 2)
      state.skill_runtime.chain_ratio = math.max(state.skill_runtime.chain_ratio, 0.45)
      state.skill_runtime.chain_radius = math.max(state.skill_runtime.chain_radius, 420)
      sync_basic_attack_ability()
    end,
  },
  {
    key = 'execute_protocol',
    name = '处决协议',
    desc = '敌人生命低于 12% 时，普攻命中后会立即处决。',
    apply = function(state)
      state.skill_runtime.execute_threshold = math.max(state.skill_runtime.execute_threshold, 0.12)
      sync_basic_attack_ability()
    end,
  },
  {
    key = 'med_drone',
    name = '急救无人机',
    desc = '每击杀 18 个敌人，自动为英雄回复 80 生命。',
    apply = function(state)
      state.skill_runtime.medbot_every = 18
      state.skill_runtime.medbot_heal = state.skill_runtime.medbot_heal + 80
    end,
  },
  {
    key = 'damage_bonus',
    name = '杀意高涨',
    desc = '伤害加成 +8%。',
    apply = function(state)
      state.hero:add_attr('伤害加成', 8)
    end,
  },
  {
    key = 'attack_range',
    name = '警戒扩展',
    desc = '攻击范围 +120。',
    apply = function(state)
      state.hero:add_attr('攻击范围', 120)
      sync_basic_attack_ability()
    end,
  },
  {
    key = 'orbital_barrage',
    name = '轨道轰炸',
    desc = '每 6 秒对随机敌群降下轰炸，造成范围法术伤害。',
    apply = function(state)
      state.skill_runtime.artillery_interval = 6
      state.skill_runtime.artillery_base = state.skill_runtime.artillery_base + 40
      state.skill_runtime.artillery_ratio = state.skill_runtime.artillery_ratio + 0.9
      state.skill_runtime.artillery_radius = math.max(state.skill_runtime.artillery_radius, 240)
      state.skill_runtime.artillery_cd = 0
    end,
  },
  {
    key = 'bounty_radar',
    name = '赏金雷达',
    desc = '每次击杀额外获得 2 金币。',
    apply = function(state)
      state.skill_runtime.bonus_gold_on_kill = state.skill_runtime.bonus_gold_on_kill + 2
    end,
  },
}

local function trigger_td_skills_on_hit(data)
  if STATE.game_finished or not data.is_normal_hit or data.source_unit ~= STATE.hero then
    return
  end

  local skill = STATE.skill_runtime
  local target = data.target_unit
  if not is_active_enemy(target) then
    return
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
    for _, unit in ipairs(get_enemies_in_range(target, skill.chain_radius, target)) do
      deal_skill_damage(unit, data.damage * skill.chain_ratio, '法术', {
        text_type = 'magic',
        particle = ATTACK_SKILL_VFX.thunder.chain_particle,
      })
      bounced = bounced + 1
      if bounced >= skill.chain_bounces then
        break
      end
    end
  end

  if skill.execute_threshold > 0 and target:is_exist() and target:get_hp() > 0 then
    local max_hp = target:get_attr('最大生命')
    if max_hp > 0 and target:get_hp() / max_hp <= skill.execute_threshold then
      target:kill_by(STATE.hero)
    end
  end
end

local function pick_upgrade_choices(count)
  local pool = {}
  for _, upgrade in ipairs(UPGRADE_POOL) do
    pool[#pool + 1] = upgrade
  end

  local choices = {}
  local total = math.min(count, #pool)
  for _ = 1, total, 1 do
    local index = math.random(1, #pool)
    choices[#choices + 1] = pool[index]
    table.remove(pool, index)
  end

  return choices
end

local function show_upgrade_choices()
  if STATE.game_finished then
    return
  end

  if STATE.awaiting_upgrade and STATE.current_upgrade_choices then
    message('继续当前 G 三选一：')
  else
    if STATE.skill_points <= 0 then
      message('技能点不足。')
      return
    end

    STATE.skill_points = STATE.skill_points - 1
    STATE.awaiting_upgrade = true
    STATE.current_upgrade_choices = pick_upgrade_choices(3)
    message('攻击技能强化 3 选 1：按 1 / 2 / 3 选择。')
  end

  for index, upgrade in ipairs(STATE.current_upgrade_choices) do
    message(string.format('%d. %s %s', index, upgrade.name, upgrade.desc))
  end
end

local function apply_upgrade(index)
  if not STATE.awaiting_upgrade then
    return
  end

  local upgrade = STATE.current_upgrade_choices and STATE.current_upgrade_choices[index]
  if not upgrade then
    return
  end

  upgrade.apply(STATE)
  STATE.awaiting_upgrade = false
  STATE.current_upgrade_choices = nil
  message('已选择强化：' .. upgrade.name)
end

-- 第二版攻击技能运行时：保留前面的原型代码不动，在这里后置接管 G 三选一与技能槽逻辑。
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

  if STATE.hero and STATE.hero:is_exist() then
    local interval = y3.helper.tonumber(STATE.hero.handle:api_get_unit_attack_interval()) or 0
    if interval > 0 then
      return math.max(0.15, interval)
    end

    local attack_speed = math.max(20, STATE.hero:get_attr('攻击速度'))
    local base_interval = math.max(0.15, skill.base_cooldown or 1.7)
    return math.max(0.15, base_interval * 100 / attack_speed)
  end

  return math.max(0.15, get_skill_current_cooldown(skill))
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
  return skill, empty_slot, true
end

local function get_skill_damage(skill, ratio_override)
  if not STATE.hero or not STATE.hero:is_exist() then
    return 0
  end
  return STATE.hero:get_attr('物理攻击') * (ratio_override or skill.damage_ratio or 0)
end

local function clone_point(point)
  if not point then
    return nil
  end
  return y3.point.create(point:get_x(), point:get_y(), point:get_z())
end

local function get_unit_point_snapshot(unit)
  if not unit or not unit:is_exist() then
    return nil
  end
  return clone_point(unit:get_point())
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
    time = time or 0.30,
    immediate = true,
  })
  if ok then
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
    time = time or 0.30,
    height = height or 0,
    immediate = true,
  })
  if ok then
    return particle
  end
  return nil
end

local function launch_projectile_to_target(vfx, target, on_finish)
  local impact_point = get_unit_point_snapshot(target)
  if not vfx or not vfx.projectile_key or not STATE.hero or not STATE.hero:is_exist() then
    if on_finish then
      on_finish(impact_point)
    end
    return false
  end

  local ok_create, projectile = pcall(y3.projectile.create, {
    key = vfx.projectile_key,
    target = STATE.hero,
    socket = 'origin',
    owner = STATE.hero,
    time = vfx.projectile_time or 3.0,
    remove_immediately = true,
  })
  if not ok_create or not projectile then
    if on_finish then
      on_finish(impact_point)
    end
    return false
  end

  local resolved = false

  local function finish()
    if resolved then
      return
    end
    resolved = true
    local final_point = impact_point
    if projectile and projectile:is_exist() then
      final_point = clone_point(projectile:get_point()) or final_point
      projectile:remove()
    end
    if on_finish then
      on_finish(final_point)
    end
  end

  local ok_move = pcall(function()
    projectile:mover_target({
      target = target,
      speed = vfx.projectile_speed or 1000,
      target_distance = vfx.target_distance or 60,
      on_finish = finish,
      on_break = function()
        if resolved then
          return
        end
        resolved = true
        if projectile and projectile:is_exist() then
          projectile:remove()
        end
        if on_finish then
          on_finish(impact_point)
        end
      end,
    })
  end)

  if not ok_move then
    if resolved then
      return false
    end
    resolved = true
    if projectile and projectile:is_exist() then
      projectile:remove()
    end
    if on_finish then
      on_finish(impact_point)
    end
    return false
  end

  return true
end

local function pick_skill_target(skill)
  if not STATE.hero or not STATE.hero:is_exist() then
    return nil
  end

  local range
  if skill and skill.id == 'basic_attack' then
    range = get_current_basic_attack_range()
  else
    range = math.max(1, (skill.cast_range or 0) + (skill.range_bonus or 0))
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

local function cast_arcane_arrow(skill, target)
  local vfx = ATTACK_SKILL_VFX.arcane_arrow
  local damage = get_skill_damage(skill)
  local remaining_hits = 1 + math.max(0, skill.pierce or 0)
  play_particle_on_unit(STATE.hero, vfx.cast_particle, vfx.cast_scale, vfx.cast_time)

  launch_projectile_to_target(vfx, target, function(impact_point)
    local center = impact_point or get_unit_point_snapshot(target)
    if center then
      play_particle_on_point(center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 20)
    end

    if is_active_enemy(target) then
      deal_skill_damage(target, damage, skill.damage_type)
      remaining_hits = remaining_hits - 1
    end

    if remaining_hits <= 0 then
      return
    end

    for _, unit in ipairs(get_enemies_in_range(center or target, 320, target)) do
      deal_skill_damage(unit, damage, skill.damage_type, {
        particle = vfx.impact_particle,
      })
      remaining_hits = remaining_hits - 1
      if remaining_hits <= 0 then
        break
      end
    end
  end)
end

local function cast_flame_arrow(skill, target)
  local vfx = ATTACK_SKILL_VFX.flame_arrow
  local explosion_damage = get_skill_damage(skill, skill.explosion_ratio)
  play_particle_on_unit(STATE.hero, vfx.cast_particle, vfx.cast_scale, vfx.cast_time)

  launch_projectile_to_target(vfx, target, function(impact_point)
    local center = impact_point or get_unit_point_snapshot(target)
    if center then
      play_particle_on_point(center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 20)
    end

    if is_active_enemy(target) then
      deal_skill_damage(target, get_skill_damage(skill), skill.damage_type)
    end

    if skill.explosion_ratio <= 0 or skill.explosion_radius <= 0 then
      return
    end

    if center then
      play_particle_on_point(center, vfx.explosion_particle, vfx.explosion_scale, vfx.explosion_time, 10)
    end

    for _, unit in ipairs(get_enemies_in_range(center or target, skill.explosion_radius)) do
      deal_skill_damage(unit, explosion_damage, skill.damage_type, {
        particle = vfx.explosion_particle,
      })
    end
  end)
end

local function cast_frost_arrow(skill, target)
  local vfx = ATTACK_SKILL_VFX.frost_arrow
  local damage = get_skill_damage(skill)
  local remaining_hits = 1 + math.max(0, skill.pierce or 0)
  play_particle_on_unit(STATE.hero, vfx.cast_particle, vfx.cast_scale, vfx.cast_time)

  launch_projectile_to_target(vfx, target, function(impact_point)
    local center = impact_point or get_unit_point_snapshot(target)
    if center then
      play_particle_on_point(center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 20)
    end

    if is_active_enemy(target) then
      deal_skill_damage(target, damage, skill.damage_type)
      remaining_hits = remaining_hits - 1
    end

    if remaining_hits <= 0 then
      return
    end

    for _, unit in ipairs(get_enemies_in_range(center or target, 280, target)) do
      deal_skill_damage(unit, damage, skill.damage_type, {
        particle = vfx.impact_particle,
      })
      remaining_hits = remaining_hits - 1
      if remaining_hits <= 0 then
        break
      end
    end
  end)
end

local function cast_thunder(skill, target)
  local vfx = ATTACK_SKILL_VFX.thunder
  local damage = get_skill_damage(skill)
  local locked_point = get_unit_point_snapshot(target)
  if locked_point then
    play_particle_on_point(locked_point, vfx.charge_particle, vfx.charge_scale, vfx.charge_time, 200)
  end

  y3.ltimer.wait(vfx.strike_delay or 0.12, function()
    if STATE.game_finished then
      return
    end

    local strike_center = get_unit_point_snapshot(target) or locked_point
    if not strike_center then
      return
    end

    play_particle_on_point(strike_center, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 0)

    if is_active_enemy(target) then
      deal_skill_damage(target, damage, skill.damage_type, {
        particle = vfx.impact_particle,
      })
    end

    local extra_targets = math.max(0, skill.extra_targets or 0)
    if extra_targets <= 0 then
      return
    end

    local hit_count = 0
    for _, unit in ipairs(get_enemies_in_range(strike_center, 420, target)) do
      play_particle_on_point(unit:get_point(), vfx.chain_particle, vfx.chain_scale, vfx.chain_time, 0)
      deal_skill_damage(unit, damage, skill.damage_type, {
        particle = vfx.chain_particle,
      })
      hit_count = hit_count + 1
      if hit_count >= extra_targets then
        break
      end
    end
  end)
end

local function cast_attack_skill_once(skill, target)
  if skill.id == 'basic_attack' then
    local vfx = ATTACK_SKILL_VFX.basic_attack
    local damage = get_skill_damage(skill)
    local hero_point = get_hero_point()
    if hero_point and target and target:is_exist() and not STATE.hero:has_state('禁止转向') then
      STATE.hero:set_facing(hero_point:get_angle_with(target:get_point()), 0.08)
    end

    launch_projectile_to_target(vfx, target, function(impact_point)
      if STATE.game_finished or not STATE.hero or not STATE.hero:is_exist() then
        return
      end

      if impact_point and vfx.impact_particle then
        play_particle_on_point(impact_point, vfx.impact_particle, vfx.impact_scale, vfx.impact_time, 18)
      end

      if is_active_enemy(target) then
        STATE.hero:damage({
          target = target,
          damage = round_number(damage),
          type = skill.damage_type,
          ability = STATE.hero_common_attack and STATE.hero_common_attack:is_exist() and STATE.hero_common_attack or nil,
          text_type = 'physics',
          text_track = 934269508,
          common_attack = true,
          no_miss = true,
        })
      end
    end)
    return
  end

  if skill.id == 'arcane_arrow' then
    cast_arcane_arrow(skill, target)
    return
  end
  if skill.id == 'flame_arrow' then
    cast_flame_arrow(skill, target)
    return
  end
  if skill.id == 'frost_arrow' then
    cast_frost_arrow(skill, target)
    return
  end
  if skill.id == 'thunder' then
    cast_thunder(skill, target)
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

  local cast_times = math.max(1, skill.repeat_count or 1)
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

local ATTACK_UPGRADE_DEFS = {
  {
    key = 'unlock_arcane_arrow',
    tag = '新技能',
    skill_id = 'arcane_arrow',
    name = '奥术箭',
    desc = '装配到空余攻击技能位，冷却 2.0 秒，造成 80% 攻击的能量魔法伤害。',
    weight = 10,
    can_offer = function()
      return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('arcane_arrow')
    end,
    apply = function()
      local skill, slot, is_new = unlock_attack_skill('arcane_arrow')
      if skill and is_new then
        message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
      end
    end,
  },
  {
    key = 'unlock_flame_arrow',
    tag = '新技能',
    skill_id = 'flame_arrow',
    name = '爆炎箭',
    desc = '装配到空余攻击技能位，冷却 6.2 秒，命中并爆炸造成火系物理伤害。',
    weight = 10,
    can_offer = function()
      return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('flame_arrow')
    end,
    apply = function()
      local skill, slot, is_new = unlock_attack_skill('flame_arrow')
      if skill and is_new then
        message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
      end
    end,
  },
  {
    key = 'unlock_frost_arrow',
    tag = '新技能',
    skill_id = 'frost_arrow',
    name = '寒冰箭',
    desc = '装配到空余攻击技能位，冷却 4.8 秒，造成冰系魔法伤害。',
    weight = 10,
    can_offer = function()
      return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('frost_arrow')
    end,
    apply = function()
      local skill, slot, is_new = unlock_attack_skill('frost_arrow')
      if skill and is_new then
        message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
      end
    end,
  },
  {
    key = 'unlock_thunder',
    tag = '新技能',
    skill_id = 'thunder',
    name = '天雷',
    desc = '装配到空余攻击技能位，冷却 5.5 秒，召唤天雷打击目标。',
    weight = 10,
    can_offer = function()
      return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('thunder')
    end,
    apply = function()
      local skill, slot, is_new = unlock_attack_skill('thunder')
      if skill and is_new then
        message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
      end
    end,
  },
  {
    key = 'basic_attack_damage',
    tag = '普攻',
    skill_id = 'basic_attack',
    level_delta = 1,
    name = '强化箭矢',
    desc = '普攻伤害 +20%。',
    weight = 8,
    max_picks = 6,
    can_offer = function()
      return get_attack_skill('basic_attack') ~= nil
    end,
    apply = function(state)
      local skill = get_attack_skill('basic_attack')
      skill.damage_ratio = skill.damage_ratio + 0.20
      state.skill_runtime.normal_attack_bonus_ratio = state.skill_runtime.normal_attack_bonus_ratio + 0.20
      sync_basic_attack_ability()
    end,
  },
  {
    key = 'basic_attack_speed',
    tag = '普攻',
    skill_id = 'basic_attack',
    level_delta = 1,
    name = '迅捷拉弦',
    desc = '攻击速度 +15%。',
    weight = 6,
    max_picks = 4,
    can_offer = function()
      return get_attack_skill('basic_attack') ~= nil
    end,
    apply = function(state)
      local skill = get_attack_skill('basic_attack')
      skill.attack_speed_bonus = skill.attack_speed_bonus + 15
      state.hero:add_attr('攻击速度', 15)
      sync_basic_attack_ability()
    end,
  },
  {
    key = 'basic_attack_range',
    tag = '普攻',
    skill_id = 'basic_attack',
    level_delta = 1,
    name = '猎手视界',
    desc = '攻击范围 +80。',
    weight = 4,
    max_picks = 3,
    can_offer = function()
      return get_attack_skill('basic_attack') ~= nil
    end,
    apply = function(state)
      local skill = get_attack_skill('basic_attack')
      skill.range_bonus = skill.range_bonus + 80
      state.hero:add_attr('攻击范围', 80)
      sync_basic_attack_ability()
    end,
  },
  {
    key = 'arcane_damage',
    tag = '奥术箭',
    skill_id = 'arcane_arrow',
    level_delta = 1,
    name = '箭矢增幅',
    desc = '奥术箭伤害 +25%。',
    weight = 6,
    max_picks = 5,
    can_offer = function()
      return get_attack_skill('arcane_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('arcane_arrow')
      skill.damage_ratio = skill.damage_ratio + 0.25
    end,
  },
  {
    key = 'arcane_cdr',
    tag = '奥术箭',
    skill_id = 'arcane_arrow',
    level_delta = 1,
    name = '急速抽箭',
    desc = '奥术箭冷却缩减 12%。',
    weight = 4,
    max_picks = 4,
    can_offer = function()
      return get_attack_skill('arcane_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('arcane_arrow')
      skill.cooldown_reduction = math.min(0.60, skill.cooldown_reduction + 0.12)
    end,
  },
  {
    key = 'arcane_pierce',
    tag = '奥术箭',
    skill_id = 'arcane_arrow',
    level_delta = 1,
    name = '贯通延伸',
    desc = '奥术箭额外穿透 +1。',
    weight = 3,
    max_picks = 2,
    can_offer = function()
      return get_attack_skill('arcane_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('arcane_arrow')
      skill.pierce = skill.pierce + 1
    end,
  },
  {
    key = 'flame_damage',
    tag = '爆炎箭',
    skill_id = 'flame_arrow',
    level_delta = 1,
    name = '火箭增幅',
    desc = '爆炎箭命中与爆炸伤害 +20%。',
    weight = 6,
    max_picks = 5,
    can_offer = function()
      return get_attack_skill('flame_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('flame_arrow')
      skill.damage_ratio = skill.damage_ratio + 0.20
      skill.explosion_ratio = skill.explosion_ratio + 0.20
    end,
  },
  {
    key = 'flame_radius',
    tag = '爆炎箭',
    skill_id = 'flame_arrow',
    level_delta = 1,
    name = '爆炸扩散',
    desc = '爆炎箭爆炸范围 +60。',
    weight = 4,
    max_picks = 3,
    can_offer = function()
      return get_attack_skill('flame_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('flame_arrow')
      skill.explosion_radius = skill.explosion_radius + 60
    end,
  },
  {
    key = 'flame_repeat',
    tag = '爆炎箭',
    skill_id = 'flame_arrow',
    level_delta = 1,
    name = '连珠火箭',
    desc = '爆炎箭额外释放 1 次。',
    weight = 3,
    max_picks = 2,
    can_offer = function()
      return get_attack_skill('flame_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('flame_arrow')
      skill.repeat_count = skill.repeat_count + 1
    end,
  },
  {
    key = 'frost_damage',
    tag = '寒冰箭',
    skill_id = 'frost_arrow',
    level_delta = 1,
    name = '冰箭增幅',
    desc = '寒冰箭伤害 +25%。',
    weight = 6,
    max_picks = 5,
    can_offer = function()
      return get_attack_skill('frost_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('frost_arrow')
      skill.damage_ratio = skill.damage_ratio + 0.25
    end,
  },
  {
    key = 'frost_cdr',
    tag = '寒冰箭',
    skill_id = 'frost_arrow',
    level_delta = 1,
    name = '冰箭连发',
    desc = '寒冰箭冷却缩减 10%。',
    weight = 4,
    max_picks = 4,
    can_offer = function()
      return get_attack_skill('frost_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('frost_arrow')
      skill.cooldown_reduction = math.min(0.55, skill.cooldown_reduction + 0.10)
    end,
  },
  {
    key = 'frost_pierce',
    tag = '寒冰箭',
    skill_id = 'frost_arrow',
    level_delta = 1,
    name = '冰箭贯穿',
    desc = '寒冰箭额外穿透 +1。',
    weight = 3,
    max_picks = 2,
    can_offer = function()
      return get_attack_skill('frost_arrow') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('frost_arrow')
      skill.pierce = skill.pierce + 1
    end,
  },
  {
    key = 'thunder_damage',
    tag = '天雷',
    skill_id = 'thunder',
    level_delta = 1,
    name = '雷击增幅',
    desc = '天雷伤害 +25%。',
    weight = 6,
    max_picks = 5,
    can_offer = function()
      return get_attack_skill('thunder') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('thunder')
      skill.damage_ratio = skill.damage_ratio + 0.25
    end,
  },
  {
    key = 'thunder_chain',
    tag = '天雷',
    skill_id = 'thunder',
    level_delta = 1,
    name = '连续雷击',
    desc = '天雷额外打击 1 个附近目标。',
    weight = 4,
    max_picks = 3,
    can_offer = function()
      return get_attack_skill('thunder') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('thunder')
      skill.extra_targets = skill.extra_targets + 1
    end,
  },
  {
    key = 'thunder_cdr',
    tag = '天雷',
    skill_id = 'thunder',
    level_delta = 1,
    name = '高压导体',
    desc = '天雷冷却缩减 10%。',
    weight = 4,
    max_picks = 4,
    can_offer = function()
      return get_attack_skill('thunder') ~= nil
    end,
    apply = function()
      local skill = get_attack_skill('thunder')
      skill.cooldown_reduction = math.min(0.55, skill.cooldown_reduction + 0.10)
    end,
  },
}

local function is_unlock_upgrade(upgrade)
  return upgrade and type(upgrade.key) == 'string' and string.sub(upgrade.key, 1, 7) == 'unlock_'
end

local function pick_weighted_upgrade(pool)
  if #pool == 0 then
    return nil
  end

  local total_weight = 0
  for _, upgrade in ipairs(pool) do
    total_weight = total_weight + (upgrade.weight or 1)
  end

  local roll = math.random() * total_weight
  local cumulative = 0
  local picked_index = #pool
  for index, upgrade in ipairs(pool) do
    cumulative = cumulative + (upgrade.weight or 1)
    if roll <= cumulative then
      picked_index = index
      break
    end
  end

  local picked = pool[picked_index]
  table.remove(pool, picked_index)
  return picked
end

local function build_upgrade_pool()
  local regular_pool = {}
  local unlock_pool = {}
  for _, upgrade in ipairs(ATTACK_UPGRADE_DEFS) do
    local max_picks = upgrade.max_picks
    if (not max_picks or get_upgrade_pick_count(upgrade.key) < max_picks)
      and (not upgrade.can_offer or upgrade.can_offer(STATE)) then
      if is_unlock_upgrade(upgrade) then
        unlock_pool[#unlock_pool + 1] = upgrade
      else
        regular_pool[#regular_pool + 1] = upgrade
      end
    end
  end
  return regular_pool, unlock_pool
end

local function pick_upgrade_choices(count)
  local regular_pool, unlock_pool = build_upgrade_pool()
  local choices = {}
  local unlocked_skill_count = get_unlocked_attack_skill_count()
  local guaranteed_unlock_count = 0

  if get_empty_attack_skill_slot() ~= nil and #unlock_pool > 0 then
    if unlocked_skill_count <= 1 then
      guaranteed_unlock_count = math.min(2, count, #unlock_pool)
    else
      guaranteed_unlock_count = math.min(1, count, #unlock_pool)
    end
  end

  for _ = 1, guaranteed_unlock_count, 1 do
    local picked = pick_weighted_upgrade(unlock_pool)
    if picked then
      choices[#choices + 1] = picked
    end
  end

  while #choices < count and (#regular_pool > 0 or #unlock_pool > 0) do
    local picked = pick_weighted_upgrade(regular_pool)
    if not picked then
      picked = pick_weighted_upgrade(unlock_pool)
    end
    if not picked then
      break
    end
    choices[#choices + 1] = picked
  end

  return choices
end

local function show_upgrade_choices()
  if STATE.game_finished then
    return
  end

  if STATE.awaiting_upgrade and STATE.current_upgrade_choices then
    message('继续当前 G 三选一。')
  else
    if STATE.skill_points <= 0 then
      message('技能点不足。')
      return
    end

    local choices = pick_upgrade_choices(3)
    if #choices == 0 then
      message('当前没有可用的攻击技能强化选项。')
      return
    end

    STATE.skill_points = STATE.skill_points - 1
    STATE.awaiting_upgrade = true
    STATE.current_upgrade_choices = choices
    message('攻击技能强化 3 选 1：按 1 / 2 / 3 选择。')
  end

  for index, upgrade in ipairs(STATE.current_upgrade_choices) do
    message(string.format('%d. [%s] %s %s', index, upgrade.tag or '强化', upgrade.name, upgrade.desc))
  end
end

local function apply_upgrade(index)
  if not STATE.awaiting_upgrade then
    return
  end

  local upgrade = STATE.current_upgrade_choices and STATE.current_upgrade_choices[index]
  if not upgrade then
    return
  end

  if upgrade.level_delta and upgrade.skill_id then
    local skill = get_attack_skill(upgrade.skill_id)
    if skill then
      skill.level = skill.level + upgrade.level_delta
    end
  end

  upgrade.apply(STATE)
  record_upgrade_pick(upgrade.key)
  STATE.awaiting_upgrade = false
  STATE.current_upgrade_choices = nil
  message('已选择强化：' .. upgrade.name)

  if upgrade.skill_id == 'basic_attack' then
    sync_basic_attack_ability()
  end

  if upgrade.skill_id and get_attack_skill(upgrade.skill_id) then
    local skill = get_attack_skill(upgrade.skill_id)
    message('技能更新：' .. build_attack_skill_slot_text(skill.slot))
  end
end

local function try_bond_draw()
  local cost_wood = 100
  if STATE.awaiting_upgrade then
    message('请先完成当前 G 三选一。')
    return
  end
  if STATE.resources.wood < cost_wood then
    message('木材不足，无法进行羁绊抽卡。')
    return
  end

  STATE.resources.wood = STATE.resources.wood - cost_wood
  STATE.bond_draw_count = STATE.bond_draw_count + 1

  if STATE.bond_draw_count <= 7 then
    message(string.format('已进行第 %d 次羁绊抽卡。F 系统当前先用文本占位，后续接正式羁绊候选。', STATE.bond_draw_count))
  else
    message(string.format('已进行第 %d 次羁绊抽卡。当前按占位逻辑视为触发一次“替换/吞噬”决策。', STATE.bond_draw_count))
  end
end

local function show_status_legacy()
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

  message(string.format(
    '状态：%s，%s，敌人数 %d，金币 %d，木材 %d，技能点 %d，挑战次数 %d/%d，进行中挑战 %d。',
    wave_text,
    boss_text,
    STATE.total_enemy_alive,
    STATE.resources.gold,
    STATE.resources.wood,
    STATE.skill_points,
    STATE.challenge_charges,
    CONFIG.challenge_rules.max_charges,
    challenge_count
  ))
  show_attack_skill_loadout()
end

local function evaluate_unlock(rule)
  if not rule then
    return true
  end

  if rule.type == 'wave_started' then
    return STATE.started_wave_count >= rule.value
  end
  if rule.type == 'bond_draw_count' then
    return STATE.bond_draw_count >= rule.value
  end
  if rule.type == 'hero_level' then
    return get_hero_level() >= rule.value
  end
  if rule.type == 'boss_kill_wave' then
    return STATE.defeated_boss_waves[rule.value] == true
  end

  return false
end

local function finish_game(is_win, reason)
  if STATE.game_finished then
    return
  end

  STATE.game_finished = true
  message((is_win and '游戏胜利！' or '游戏失败！') .. (reason and (' ' .. reason) or ''))
  message(string.format(
    '结算：波次 %d/%d，金币 %d，木材 %d，英雄剩余生命 %.0f。',
    STATE.current_wave_index,
    #CONFIG.waves,
    STATE.resources.gold,
    STATE.resources.wood,
    STATE.hero and STATE.hero:is_exist() and STATE.hero:get_hp() or 0
  ))
end

local function create_enemy_info(unit, info)
  info.unit = unit
  info.alive = true
  info.owner = info.owner or nil

  STATE.all_enemies:add_unit(unit)
  STATE.total_enemy_alive = STATE.total_enemy_alive + 1

  if info.owner then
    info.owner.alive_count = (info.owner.alive_count or 0) + 1
  end

  function info.remove_runtime(grant_death_rewards)
    if not info.alive then
      return false
    end

    info.alive = false
    if STATE.all_enemies and unit then
      STATE.all_enemies:remove_unit(unit)
    end
    if STATE.total_enemy_alive > 0 then
      STATE.total_enemy_alive = STATE.total_enemy_alive - 1
    end
    if info.owner and info.owner.alive_count and info.owner.alive_count > 0 then
      info.owner.alive_count = info.owner.alive_count - 1
    end
    if info.owner and info.owner.infos then
      info.owner.dead_count = (info.owner.dead_count or 0) + 1
    end

    if grant_death_rewards then
      if info.kind == 'main' then
        award_rewards(info.reward, nil, true)
        if STATE.skill_runtime.medbot_every > 0 and STATE.skill_runtime.medbot_heal > 0 then
          STATE.skill_runtime.medbot_kills = STATE.skill_runtime.medbot_kills + 1
          if STATE.skill_runtime.medbot_kills >= STATE.skill_runtime.medbot_every then
            STATE.skill_runtime.medbot_kills = STATE.skill_runtime.medbot_kills - STATE.skill_runtime.medbot_every
            heal_hero(STATE.skill_runtime.medbot_heal)
          end
        end
      elseif info.kind == 'boss' then
        award_rewards(info.reward, get_boss_name(info.wave), false)
      end
    end

    return true
  end

  unit:event('单位-死亡', function(_, data)
    if not info.remove_runtime(true) then
      return
    end

    if info.kind == 'boss' then
      STATE.defeated_boss_waves[info.wave.index] = true
      if info.wave.index >= #CONFIG.waves then
        finish_game(true, '击败最终 Boss。')
      else
        local next_wave = CONFIG.waves[info.wave.index + 1]
        message(string.format('%s 被击败，立即切换到 %s。', get_boss_name(info.wave), next_wave.name))
        STATE.active_wave = nil
        STATE.current_wave_index = next_wave.index
        M.start_wave(next_wave.index)
      end
    elseif info.kind == 'challenge' then
      local instance = info.owner
      if instance and instance.active and instance.alive_count <= 0 and instance.all_batches_spawned then
        M.finish_challenge(instance, true)
      end
    end

    if info.kind == 'main' and STATE.skill_runtime.bonus_gold_on_kill > 0 then
      STATE.resources.gold = STATE.resources.gold + STATE.skill_runtime.bonus_gold_on_kill
    end
  end)

  return info
end

local function spawn_enemy(unit_id, area_id, facing, info)
  local spawn_point = random_point_in_area(area_id)
  local unit = y3.unit.create_unit(get_enemy_player(), unit_id, spawn_point, facing or 180.0)
  unit:set_reward_exp(0)
  unit:attack_move(STATE.defense_point)
  return create_enemy_info(unit, info)
end

local function get_spawn_interval(wave, elapsed, boss_spawned)
  if boss_spawned then
    return wave.post_boss_interval_sec
  end

  local current = wave.spawn_segments[1]
  for _, segment_data in ipairs(wave.spawn_segments) do
    if elapsed >= segment_data.start_sec then
      current = segment_data
    end
  end
  return current.interval_sec
end

local function can_spawn_main_batch(runner)
  if not runner or not runner.active then
    return false
  end
  if runner.wave.max_alive and runner.alive_count >= runner.wave.max_alive then
    return false
  end
  if STATE.total_enemy_alive >= CONFIG.total_enemy_soft_cap then
    return false
  end
  return true
end

local function spawn_main_batch(runner)
  if not can_spawn_main_batch(runner) then
    return
  end

  local wave = runner.wave
  local batch_count = math.random(wave.batch_min, wave.batch_max)
  local soft_cap_left = CONFIG.total_enemy_soft_cap - STATE.total_enemy_alive
  local wave_cap_left = wave.max_alive - runner.alive_count
  batch_count = math.min(batch_count, soft_cap_left, wave_cap_left)

  for _ = 1, batch_count, 1 do
    spawn_enemy(wave.main_unit_id, wave.spawn_area_id, 180.0, {
      kind = 'main',
      owner = runner,
      wave = wave,
      reward = wave.main_kill_reward,
    })
  end
end

local function spawn_boss(runner)
  if not runner or runner.boss_spawned or STATE.game_finished then
    return
  end

  runner.boss_spawned = true
  message(string.format('%s 登场。', get_boss_name(runner.wave)))

  runner.boss_info = spawn_enemy(runner.wave.boss_unit_id, runner.wave.boss_spawn_area_id, 180.0, {
    kind = 'boss',
    owner = runner,
    wave = runner.wave,
    reward = runner.wave.boss_kill_reward,
  })
end

function M.start_wave(index)
  local wave = CONFIG.waves[index]
  if not wave or STATE.game_finished then
    return
  end

  STATE.current_wave_index = index
  STATE.started_wave_count = math.max(STATE.started_wave_count, index)
  STATE.active_wave = {
    wave = wave,
    elapsed = 0,
    active = true,
    boss_spawned = false,
    boss_info = nil,
    alive_count = 0,
    next_spawn_sec = 0,
  }

  message(string.format('%s 开始。Boss 将在 %.0f 秒后加入战场。', wave.name, design_seconds(wave.boss_spawn_sec)))
end

local function cleanup_challenge_units(instance)
  for _, info in ipairs(instance.infos) do
    if info.alive and info.unit and info.unit:is_exist() then
      info.remove_runtime(false)
      info.unit:remove()
    end
  end
end

function M.finish_challenge(instance, is_success)
  if not instance or not instance.active then
    return
  end

  instance.active = false
  STATE.active_challenges[instance.id] = nil

  if is_success then
    award_rewards(instance.def.reward, instance.def.name .. ' 成功', false)
  else
    cleanup_challenge_units(instance)
    message(instance.def.name .. ' 失败。')
  end
end

local function spawn_challenge_batch(instance, batch_index, batch)
  if instance.spawned_batches[batch_index] then
    return
  end
  instance.spawned_batches[batch_index] = true

  if instance.def.id == 'treasure_trial' then
    if batch_index == 1 then
      local boss_info = spawn_enemy(instance.def.boss_unit_id, instance.def.spawn_area_id, 180.0, {
        kind = 'challenge',
        owner = instance,
        reward = nil,
      })
      instance.infos[#instance.infos + 1] = boss_info
      for _ = 1, batch.count - 1, 1 do
        local info = spawn_enemy(instance.def.guard_unit_id, instance.def.spawn_area_id, 180.0, {
          kind = 'challenge',
          owner = instance,
          reward = nil,
        })
        instance.infos[#instance.infos + 1] = info
      end
    else
      for _ = 1, batch.count, 1 do
        local info = spawn_enemy(instance.def.guard_unit_id, instance.def.spawn_area_id, 180.0, {
          kind = 'challenge',
          owner = instance,
          reward = nil,
        })
        instance.infos[#instance.infos + 1] = info
      end
    end
  else
    for _ = 1, batch.count, 1 do
      local info = spawn_enemy(instance.def.unit_id, instance.def.spawn_area_id, 180.0, {
        kind = 'challenge',
        owner = instance,
        reward = nil,
      })
      instance.infos[#instance.infos + 1] = info
    end
  end

  if batch_index >= #instance.def.batches then
    instance.all_batches_spawned = true
  end
end

local function try_start_challenge(challenge_id)
  if STATE.game_finished then
    return
  end
  if STATE.awaiting_upgrade then
    message('请先完成当前 G 三选一。')
    return
  end

  local def = CONFIG.challenges[challenge_id]
  if not def then
    return
  end

  if STATE.active_challenges[challenge_id] then
    message(def.name .. ' 进行中。')
    return
  end

  if not evaluate_unlock(def.unlock_rule) then
    message(def.unlock_rule.text or '该挑战尚未解锁。')
    return
  end

  if STATE.challenge_charges < def.cost_charge then
    message('挑战次数不足。')
    return
  end

  local recharge_was_full = STATE.challenge_charges >= CONFIG.challenge_rules.max_charges
  STATE.challenge_charges = STATE.challenge_charges - def.cost_charge
  if recharge_was_full then
    STATE.challenge_recover_elapsed = 0
  end

  local instance = {
    id = def.id,
    def = def,
    elapsed = 0,
    active = true,
    alive_count = 0,
    dead_count = 0,
    infos = {},
    spawned_batches = {},
    all_batches_spawned = false,
  }
  STATE.active_challenges[challenge_id] = instance

  message(string.format('%s 开始，持续 %.0f 秒。', def.name, design_seconds(def.duration_sec)))
end

local function update_wave(dt)
  local runner = STATE.active_wave
  if not runner or not runner.active or STATE.game_finished then
    return
  end

  runner.elapsed = runner.elapsed + dt

  while runner.next_spawn_sec <= runner.elapsed do
    if can_spawn_main_batch(runner) then
      spawn_main_batch(runner)
    end

    local interval = get_spawn_interval(runner.wave, runner.elapsed, runner.boss_spawned)
    interval = math.max(interval, 0.2)
    runner.next_spawn_sec = runner.next_spawn_sec + interval
  end

  if not runner.boss_spawned and runner.elapsed >= runner.wave.boss_spawn_sec then
    spawn_boss(runner)
  end
end

local function update_challenges(dt)
  local instances = {}
  for _, instance in pairs(STATE.active_challenges) do
    instances[#instances + 1] = instance
  end

  for _, instance in ipairs(instances) do
    if instance.active then
      instance.elapsed = instance.elapsed + dt

      for batch_index, batch in ipairs(instance.def.batches) do
        if not instance.spawned_batches[batch_index] and instance.elapsed >= batch.time_sec then
          spawn_challenge_batch(instance, batch_index, batch)
        end
      end

      if instance.active and instance.all_batches_spawned and instance.alive_count <= 0 then
        M.finish_challenge(instance, true)
      elseif instance.active and instance.elapsed >= instance.def.duration_sec then
        M.finish_challenge(instance, false)
      end
    end
  end
end

local function update_challenge_charges(dt)
  if STATE.challenge_charges >= CONFIG.challenge_rules.max_charges then
    STATE.challenge_recover_elapsed = 0
    return
  end

  STATE.challenge_recover_elapsed = STATE.challenge_recover_elapsed + dt
  while STATE.challenge_charges < CONFIG.challenge_rules.max_charges
    and STATE.challenge_recover_elapsed >= CONFIG.challenge_rules.recover_sec do
    STATE.challenge_recover_elapsed = STATE.challenge_recover_elapsed - CONFIG.challenge_rules.recover_sec
    STATE.challenge_charges = STATE.challenge_charges + 1
    message(string.format('挑战次数 +1，当前 %d/%d。', STATE.challenge_charges, CONFIG.challenge_rules.max_charges))
  end
end

local function create_hero()
  local hero = get_player():create_unit(CONFIG.unit_ids.hero, STATE.hero_spawn_point, 0)
  get_player():select_unit(hero)

  hero:set_name('守关英雄')
  set_attr_pack(hero, CONFIG.hero_init_stats)
  hero:set_attr('attack_range', ATTACK_SKILL_DEFS.basic_attack.base_range or 250)
  hero:add_state('禁止普攻')

  hero:add_state('禁止移动')
  hero:add_state('禁止转向')
  hero:set_turning_speed(0)
  hero:stop()

  if CONFIG.debug_time_scale < 1 then
    add_attr_pack(hero, CONFIG.debug_hero_bonus_stats)
  end

  hero:set_hp(hero:get_attr('hp_max'))
  STATE.hero_common_attack = hero:get_common_attack()

  hero:event('单位-死亡', function()
    finish_game(false, '英雄倒下。')
  end)

  hero:event('单位-造成伤害后', function(_, data)
    trigger_td_skills_on_hit(data)
  end)

  return hero
end

local function validate_config()
  local missing = {}
  local checked = {}

  local function check_unit(name, unit_id)
    if unit_id == nil then
      missing[#missing + 1] = string.format('%s: 未配置', name)
      return
    end
    if checked[unit_id] then
      return
    end
    checked[unit_id] = true
    if not has_unit_data(unit_id) then
      missing[#missing + 1] = string.format('%s: %d', name, unit_id)
    end
  end

  check_unit('hero', CONFIG.unit_ids.hero)
  for id, wave in ipairs(CONFIG.waves) do
    check_unit('wave[' .. tostring(id) .. '].main_unit_id', wave.main_unit_id)
    check_unit('wave[' .. tostring(id) .. '].boss_unit_id', wave.boss_unit_id)
  end
  for key, challenge in pairs(CONFIG.challenges) do
    if challenge.unit_id then
      check_unit('challenge.' .. key .. '.unit_id', challenge.unit_id)
    end
    if challenge.boss_unit_id then
      check_unit('challenge.' .. key .. '.boss_unit_id', challenge.boss_unit_id)
    end
    if challenge.guard_unit_id then
      check_unit('challenge.' .. key .. '.guard_unit_id', challenge.guard_unit_id)
    end
  end

  if #missing == 0 then
    return true
  end

  message('主循环骨架未启动：以下单位物编 ID 不存在，请先替换 entry_config.lua 中的配置。')
  for _, line in ipairs(missing) do
    message(line)
  end
  return false
end

local function register_runtime_events()
  if STATE.events_registered then
    return
  end
  STATE.events_registered = true

  y3.game:event('单位-升级', function(_, data)
    if STATE.game_finished or data.unit ~= STATE.hero or not STATE.hero_progress then
      return
    end

    local engine_level = math.min(STATE.hero:get_level(), get_hero_max_level())
    if engine_level <= STATE.hero_progress.level then
      sync_hero_progress_from_engine()
      STATE.hero:set_ability_point(0)
      return
    end

    STATE.hero_progress.level = engine_level
    sync_hero_progress_from_engine()
    STATE.skill_points = STATE.skill_points + 1
    message(string.format('英雄升级至 %d，获得 1 点技能点。按 G 打开强化选择。', STATE.hero_progress.level))
  end)

  y3.game:event('键盘-按下', 'G', function()
    show_upgrade_choices()
  end)
  y3.game:event('键盘-按下', 'F', function()
    try_bond_draw()
  end)
  y3.game:event('键盘-按下', 'Q', function()
    try_start_challenge('gold_trial')
  end)
  y3.game:event('键盘-按下', 'W', function()
    try_start_challenge('wood_trial')
  end)
  y3.game:event('键盘-按下', 'E', function()
    try_start_challenge('exp_trial')
  end)
  y3.game:event('键盘-按下', 'R', function()
    try_start_challenge('treasure_trial')
  end)

  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_1'], function()
    apply_upgrade(1)
  end)
  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_2'], function()
    apply_upgrade(2)
  end)
  y3.game:event('键盘-按下', y3.const.KeyboardKey['KEY_3'], function()
    apply_upgrade(3)
  end)
  y3.game:event('键盘-按下', 'SPACE', function()
    show_runtime_status()
  end)
end

local function start_runtime_loops()
  y3.ltimer.loop(0.25, function(timer)
    if STATE.game_finished then
      timer:remove()
      return
    end

    update_wave(0.25)
    update_challenges(0.25)
    update_challenge_charges(0.25)
    update_attack_skills(0.25)
  end)

  y3.ltimer.loop(1, function(timer)
    if STATE.game_finished then
      timer:remove()
      return
    end

    local skill = STATE.skill_runtime
    if skill.artillery_interval <= 0 or skill.artillery_radius <= 0 or skill.artillery_ratio <= 0 then
      return
    end

    skill.artillery_cd = skill.artillery_cd + 1
    if skill.artillery_cd < skill.artillery_interval then
      return
    end
    skill.artillery_cd = 0

    local anchor = STATE.all_enemies:get_random()
    if not is_active_enemy(anchor) then
      return
    end

    local damage = skill.artillery_base + STATE.hero:get_attr('物理攻击') * skill.artillery_ratio
    for _, unit in ipairs(get_enemies_in_range(anchor, skill.artillery_radius)) do
      deal_skill_damage(unit, damage, '法术')
    end
  end)
end

local function reset_state()
  STATE.hero = nil
  STATE.hero_spawn_point = make_point(CONFIG.points.hero_spawn)
  STATE.defense_point = make_point(CONFIG.points.defense_point)
  STATE.all_enemies = y3.unit_group.create()
  STATE.total_enemy_alive = 0
  STATE.current_wave_index = 0
  STATE.started_wave_count = 0
  STATE.active_wave = nil
  STATE.active_challenges = {}
  STATE.resources = { gold = 0, wood = 0 }
  STATE.skill_points = 0
  STATE.hero_progress = nil
  STATE.awaiting_upgrade = false
  STATE.current_upgrade_choices = nil
  STATE.skill_runtime = create_skill_runtime()
  STATE.attack_skill_state = create_attack_skill_state()
  STATE.hero_common_attack = nil
  STATE.challenge_charges = CONFIG.challenge_rules.initial_charges
  STATE.challenge_recover_elapsed = 0
  STATE.bond_draw_count = 0
  STATE.defeated_boss_waves = {}
  STATE.basic_attack_ability_bound = false
  STATE.basic_attack_ability_warned = false
  STATE.game_finished = false
  STATE.events_registered = STATE.events_registered or false
  STATE.dev_commands_registered = STATE.dev_commands_registered or false
end

function M.bootstrap()
  if not validate_config() then
    return
  end

  reset_state()

  get_player():set_hostility(get_enemy_player(), true)
  get_enemy_player():set_hostility(get_player(), true)
  STATE.hero = create_hero()
  initialize_hero_progression()
  setup_basic_attack_ability()
  register_runtime_events()
  register_dev_commands()
  start_runtime_loops()
  message('初始攻击技能已装配：1 号位 普攻 Lv1；2-4 号位可通过 G 三选一逐步解锁。')
  show_attack_skill_loadout()

  message('主循环骨架已启动：G 技能三选一，F 羁绊占位抽卡，Q/W/E/R 临时触发四类挑战，Space 查看状态。')
  message('开发模式坐标校准：.epos / .eset hero / .eset defense / .earea main_spawn_wave_1 280 360 / .edump')
  message(string.format(
    '当前临时物编：英雄=%s，1-5波主怪=%s/%s/%s/%s/%s。',
    CONFIG.temp_unit_labels.hero,
    CONFIG.temp_unit_labels.wave_1_main,
    CONFIG.temp_unit_labels.wave_2_main,
    CONFIG.temp_unit_labels.wave_3_main,
    CONFIG.temp_unit_labels.wave_4_main,
    CONFIG.temp_unit_labels.wave_5_main
  ))
  if CONFIG.debug_time_scale < 1 then
    message(string.format('当前为调试模式，时间缩放为 %.1f 倍，便于快速验证波次与挑战流程。', CONFIG.debug_time_scale))
  end

  y3.ltimer.wait(1, function()
    M.start_wave(1)
  end)
end

return M

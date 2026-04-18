local M = {}

function M.create(env)
  local STATE = env.STATE
  local message = env.message
  local ATTACK_SKILL_DEFS = env.ATTACK_SKILL_DEFS or {}
  local ATTACK_SKILL_BLUEPRINTS = env.ATTACK_SKILL_BLUEPRINTS or { list = {} }
  local get_attack_skill = env.get_attack_skill
  local get_empty_attack_skill_slot = env.get_empty_attack_skill_slot
  local get_unlocked_attack_skill_count = env.get_unlocked_attack_skill_count
  local get_upgrade_pick_count = env.get_upgrade_pick_count
  local record_upgrade_pick = env.record_upgrade_pick
  local unlock_attack_skill = env.unlock_attack_skill
  local sync_basic_attack_ability = env.sync_basic_attack_ability
  local build_attack_skill_slot_text = env.build_attack_skill_slot_text
  local has_active_treasure = env.has_active_treasure
  local collect_bond_route_tags = env.collect_bond_route_tags
  local UPGRADE_FREE_REFRESH_COUNT = 3

  local function get_refresh_cost(paid_count)
    if (paid_count or 0) <= 0 then
      return 40
    end
    if paid_count == 1 then
      return 80
    end
    return 100
  end

  local function ensure_upgrade_round()
    if not STATE.current_upgrade_round then
      STATE.current_upgrade_round = {
        free_refresh_left = UPGRADE_FREE_REFRESH_COUNT,
        refresh_paid_count = 0,
      }
    end
    return STATE.current_upgrade_round
  end

  local function unlock_upgrade(def)
    def.tag = '新技能'
    def.weight = def.weight or 10
    def.max_picks = def.max_picks or 1
    def.route_tags = def.route_tags or {}
    return def
  end

  local function skill_upgrade(def)
    def.level_delta = def.level_delta or 1
    def.weight = def.weight or 5
    def.route_tags = def.route_tags or {}
    def.can_offer = def.can_offer or function()
      return get_attack_skill(def.skill_id) ~= nil
    end
    return def
  end

  local BLUEPRINT_BUCKET_ORDER = {
    'common',
    'excellent',
    'rare',
  }

  local QUALITY_BY_BUCKET = {
    common = 'common',
    excellent = 'rare',
    rare = 'epic',
    legendary = 'epic',
  }

  local WEIGHT_BY_BUCKET = {
    common = 6,
    excellent = 5,
    rare = 4,
    legendary = 3,
  }

  local ROUTE_TAG_BY_BUCKET = {
    common = 'foundation',
    excellent = 'branch',
    rare = 'advanced',
    legendary = 'legend',
  }

  local function has_text(text, pattern)
    return string.find(tostring(text or ''), pattern, 1, true) ~= nil
  end

  local function parse_first_percent(text)
    local value = tostring(text or ''):match('([%d%.]+)%%')
    return value and ((tonumber(value) or 0) / 100) or 0
  end

  local function parse_first_seconds(text)
    local value = tostring(text or ''):match('([%d%.]+)%s*秒')
    return value and (tonumber(value) or 0) or 0
  end

  local function parse_first_integer(text)
    local value = tostring(text or ''):match('(%d+)')
    return value and (tonumber(value) or 0) or 0
  end

  local function get_base_skill_def(skill_id)
    return ATTACK_SKILL_DEFS[skill_id] or {}
  end

  local function add_skill_damage_ratio(skill, skill_id, ratio_gain)
    local base = get_base_skill_def(skill_id).base_damage_ratio or skill.damage_ratio or 0
    skill.damage_ratio = (skill.damage_ratio or 0) + math.max(0, base * (ratio_gain or 0))
  end

  local function add_skill_cooldown_cut(skill, ratio_cut)
    skill.cooldown_reduction = math.min(0.80, (skill.cooldown_reduction or 0) + math.max(0, ratio_cut or 0))
  end

  local function add_skill_cast_range(skill, skill_id, ratio_gain)
    local base = get_base_skill_def(skill_id).base_range or skill.cast_range or 0
    skill.range_bonus = (skill.range_bonus or 0) + math.max(0, base * (ratio_gain or 0))
  end

  local function add_skill_radius(skill, skill_id, ratio_gain)
    local base = get_base_skill_def(skill_id).base_radius or skill.base_radius or 0
    if base > 0 then
      skill.base_radius = (skill.base_radius or 0) + math.max(0, base * (ratio_gain or 0))
      return
    end
    add_skill_cast_range(skill, skill_id, ratio_gain)
  end

  local function add_skill_duration(skill, seconds)
    skill.base_duration = (skill.base_duration or 0) + math.max(0, seconds or 0)
  end

  local function add_skill_bounce(skill, count)
    skill.base_bounce = math.max(0, (skill.base_bounce or 0) + math.max(0, count or 0))
  end

  local function add_skill_pierce(skill, count)
    skill.pierce = math.max(0, (skill.pierce or 0) + math.max(0, count or 0))
  end

  local function add_skill_followup(skill, count, ratio)
    skill.followup_count = (skill.followup_count or 0) + math.max(0, count or 0)
    skill.followup_ratio = math.max(skill.followup_ratio or 0, ratio or 0)
  end

  local function add_skill_echo(skill, count, ratio)
    skill.echo_count = (skill.echo_count or 0) + math.max(0, count or 0)
    skill.echo_ratio = math.max(skill.echo_ratio or 0, ratio or 0)
  end

  local function add_skill_terminal_burst(skill, skill_id, burst_ratio, radius_scale)
    local def = get_base_skill_def(skill_id)
    local base_radius = def.base_radius or skill.base_radius or 0
    local base_range = def.base_range or skill.cast_range or 0
    local radius = math.max(
      160,
      base_radius > 0 and base_radius * math.max(0.45, radius_scale or 0.70)
        or math.max(160, base_range * 0.18)
    )
    skill.terminal_burst_radius = math.max(skill.terminal_burst_radius or 0, radius)
    skill.terminal_burst_ratio = math.max(skill.terminal_burst_ratio or 0, burst_ratio or 0)
  end

  local function add_skill_persistent_field(skill, skill_id, duration, ratio, opts)
    if (skill.base_radius or 0) <= 0 then
      local base_radius = get_base_skill_def(skill_id).base_radius or 0
      skill.base_radius = math.max(skill.base_radius or 0, base_radius > 0 and base_radius or 180)
    end
    skill.persistent_field_duration = math.max(skill.persistent_field_duration or 0, duration or 0)
    skill.persistent_field_ratio = math.max(skill.persistent_field_ratio or 0, ratio or 0)
    if opts and opts.control then
      skill.persistent_field_control = true
    end
    if opts and opts.ignite then
      skill.persistent_field_ignite = true
    end
  end

  local function add_generic_armor_break(skill, ratio, duration, max_stacks)
    skill.apply_generic_armor_break = true
    skill.armor_break_ratio = math.max(skill.armor_break_ratio or 0, ratio or 0)
    skill.armor_break_duration = math.max(skill.armor_break_duration or 0, duration or 0)
    skill.armor_break_max_stacks = math.max(skill.armor_break_max_stacks or 0, max_stacks or 1)
  end

  local function add_generic_ignite(skill, duration, tick_ratio)
    skill.apply_generic_ignite = true
    skill.ignite_duration = math.max(skill.ignite_duration or 0, duration or 0)
    skill.ignite_tick_ratio = math.max(skill.ignite_tick_ratio or 0, tick_ratio or 0)
  end

  local function add_generic_shock(skill, duration, bonus)
    skill.apply_generic_shock = true
    skill.shock_duration = math.max(skill.shock_duration or 0, duration or 0)
    skill.shock_bonus = math.max(skill.shock_bonus or 0, bonus or 0)
  end

  local function add_generic_control(skill, duration)
    skill.apply_generic_control = true
    skill.control_lock_time = math.max(skill.control_lock_time or 0, duration or 0)
  end

  local function add_pull_strength(skill, amount)
    skill.pull_strength = (skill.pull_strength or 0) + math.max(0, amount or 0)
  end

  local function add_boss_bonus(skill, ratio)
    skill.boss_bonus_ratio = (skill.boss_bonus_ratio or 0) + math.max(0, ratio or 0)
  end

  local function add_repeat_with_ratio(skill, repeat_delta, per_cast_ratio)
    skill.repeat_count = math.max(1, (skill.repeat_count or 1) + math.max(0, repeat_delta or 0))
    if per_cast_ratio and per_cast_ratio > 0 and per_cast_ratio < 1 then
      skill.damage_ratio = (skill.damage_ratio or 0) * per_cast_ratio
    end
  end

  local function apply_blueprint_function_card(blueprint, skill, card)
    local summary = card.summary or ''
    local seconds = parse_first_seconds(summary)
    local percent = parse_first_percent(summary)
    local count = parse_first_integer(summary)

    if has_text(summary, '燃烧') or has_text(summary, '灼光') then
      add_generic_ignite(skill, seconds > 0 and seconds or 4, 0.08)
      return
    end
    if has_text(summary, '回斩伤害') then
      skill.return_pass_enabled = true
      skill.return_pass_ratio = math.max(skill.return_pass_ratio or 0.80, 0.80 + percent)
      if has_text(summary, '穿透') then
        add_skill_pierce(skill, math.max(1, count))
      end
      return
    end
    if has_text(summary, '穿透') then
      add_skill_pierce(skill, math.max(1, count))
      return
    end
    if has_text(summary, '飞剑数量') or has_text(summary, '弹射次数') then
      add_skill_bounce(skill, math.max(1, count))
      return
    end
    if has_text(summary, '拉扯力度') or has_text(summary, '聚怪力度') then
      add_pull_strength(skill, percent > 0 and 140 * percent + 80 or 140)
      return
    end
    if has_text(summary, '击飞') then
      add_generic_control(skill, seconds > 0 and seconds or 0.8)
      return
    end
    if has_text(summary, '减速效果') then
      add_generic_control(skill, 0.30)
      return
    end
    if seconds > 0 then
      add_skill_duration(skill, seconds)
    end
  end

  local function apply_blueprint_state_card(blueprint, skill, card)
    local summary = card.summary or ''
    local seconds = parse_first_seconds(summary)
    local percent = parse_first_percent(summary)

    if has_text(summary, '感电') then
      add_generic_shock(skill, seconds > 0 and seconds or 4, percent > 0 and percent or 0.18)
      return
    end
    if has_text(summary, '燃烧') or has_text(summary, '灼光') or has_text(summary, '焚地') then
      add_generic_ignite(skill, seconds > 0 and seconds or 4, math.max(0.08, percent * 0.40))
      if has_text(summary, '焚地') then
        add_skill_persistent_field(skill, blueprint.id, seconds > 0 and seconds or 4, 0.18, { ignite = true })
      end
      return
    end
    if has_text(summary, '禁足') or has_text(summary, '束缚') or has_text(summary, '冻结') or has_text(summary, '减速') then
      add_generic_control(skill, seconds > 0 and seconds or 0.40)
      return
    end

    add_generic_armor_break(skill, percent > 0 and percent or 0.18, seconds > 0 and seconds or 4, 1)
    if has_text(summary, '扩散') then
      add_skill_followup(skill, 1, 0.35)
    end
  end

  local function apply_blueprint_count_card(blueprint, skill, card)
    local summary = card.summary or ''
    local percent = parse_first_percent(summary)
    local per_cast_ratio = percent > 0 and percent or 0.65
    if string.find(summary, '-', 1, true) ~= nil and percent > 0 then
      per_cast_ratio = math.max(0.55, 1 - percent)
    end

    if has_text(summary, '回响') or has_text(summary, '余震') or has_text(summary, '小型法环') or has_text(summary, '小型法印') then
      add_skill_echo(skill, 1, per_cast_ratio)
      return
    end

    add_repeat_with_ratio(skill, 1, per_cast_ratio)
  end

  local function apply_blueprint_form_card(blueprint, skill, card)
    local summary = card.summary or ''
    local count = math.max(1, parse_first_integer(summary))

    if has_text(summary, '横扫') then
      skill.sweep_enabled = true
      return
    end
    if has_text(summary, '回斩') then
      skill.return_pass_enabled = true
      skill.return_pass_ratio = math.max(skill.return_pass_ratio or 0.80, 1.00)
      return
    end
    if has_text(summary, '雷爆') or has_text(summary, '爆燃') then
      add_skill_terminal_burst(skill, blueprint.id, 0.80, 0.75)
      return
    end
    if has_text(summary, '分叉') then
      add_skill_followup(skill, 2, 0.45)
      return
    end
    if has_text(summary, '冰棱') or has_text(summary, '碎片') or has_text(summary, '火星') then
      add_skill_followup(skill, math.min(6, count), 0.35)
      return
    end
    if has_text(summary, '电弧') or has_text(summary, '符链') then
      add_skill_followup(skill, math.min(3, count), 0.50)
      return
    end
    if has_text(summary, '岩刺') or has_text(summary, '高频') or has_text(summary, '切割') then
      add_skill_persistent_field(skill, blueprint.id, 2.0, 0.25, {})
    end
  end

  local function apply_blueprint_elite_card(skill, card)
    local summary = card.summary or ''
    local seconds = parse_first_seconds(summary)
    local percent = parse_first_percent(summary)

    add_boss_bonus(skill, percent > 0 and percent or 0.80)
    if has_text(summary, '追加 1 段') or has_text(summary, '额外承受') then
      add_skill_followup(skill, 1, math.max(0.70, percent > 0 and percent or 0.80))
    end
    if has_text(summary, '击飞') then
      add_generic_control(skill, seconds > 0 and seconds or 0.6)
    end
  end

  local function apply_blueprint_trigger_card(blueprint, skill, card)
    local summary = card.summary or ''

    if has_text(summary, '回弹') or has_text(summary, '回流') then
      skill.return_pass_enabled = true
      skill.return_pass_ratio = math.max(skill.return_pass_ratio or 0.70, 0.70)
      return
    end
    if has_text(summary, '乱流') then
      add_skill_persistent_field(skill, blueprint.id, 1.8, 0.25, {})
      return
    end
    if has_text(summary, '火圈') then
      add_skill_persistent_field(skill, blueprint.id, 1.8, 0.25, { ignite = true })
      return
    end

    if has_text(summary, '补斩')
      or has_text(summary, '再延伸')
      or has_text(summary, '再追发')
      or has_text(summary, '追命')
      or has_text(summary, '回扫')
      or has_text(summary, '额外降下') then
      add_skill_followup(skill, 1, 0.60)
    end
    if has_text(summary, '爆炸')
      or has_text(summary, '冰爆')
      or has_text(summary, '回爆')
      or has_text(summary, '余震')
      or has_text(summary, '爆发') then
      add_skill_echo(skill, 1, 0.60)
      add_skill_terminal_burst(skill, blueprint.id, 0.60, 0.60)
    end
  end

  local function apply_blueprint_legendary_card(blueprint, skill, card)
    local summary = card.summary or ''
    local def = get_base_skill_def(blueprint.id)

    add_skill_damage_ratio(skill, blueprint.id, 0.85)

    if has_text(summary, '持续时间 +100%') or has_text(summary, '持续时间+100%') then
      add_skill_duration(skill, def.base_duration or skill.base_duration or 0)
    elseif (def.base_duration or 0) > 0 and (has_text(summary, '持续') or has_text(summary, '禁域') or has_text(summary, '冰界') or has_text(summary, '莲台')) then
      add_skill_duration(skill, math.max(1.5, (def.base_duration or skill.base_duration or 0) * 0.5))
    end

    if (def.base_radius or 0) > 0 and (
      has_text(summary, '范围')
      or has_text(summary, '冰界')
      or has_text(summary, '禁域')
      or has_text(summary, '莲台')
      or has_text(summary, '火浪')
      or has_text(summary, '裂界')
    ) then
      add_skill_radius(skill, blueprint.id, 0.35)
    end

    if (def.base_bounce or 0) > 0 then
      add_skill_bounce(skill, 2)
    end

    if has_text(summary, '追踪') then
      skill.field_track_target = true
      add_pull_strength(skill, 80)
    end
    if has_text(summary, '束缚')
      or has_text(summary, '压制')
      or has_text(summary, '冻结')
      or has_text(summary, '禁域')
      or has_text(summary, '冰界') then
      add_skill_persistent_field(skill, blueprint.id, has_text(summary, '冰界') and 4 or 3.5, 0.35, { control = true })
    end
    if has_text(summary, '火浪')
      or has_text(summary, '焚世')
      or has_text(summary, '莲台')
      or has_text(summary, '劫火') then
      add_skill_persistent_field(skill, blueprint.id, 3.0, 0.35, { ignite = true })
    end
    if has_text(summary, '回斩') or has_text(summary, '往返') or has_text(summary, '轮斩') then
      skill.return_pass_enabled = true
      skill.return_pass_ratio = math.max(skill.return_pass_ratio or 0.80, 1.00)
      add_skill_followup(skill, 1, 0.50)
    end
    if has_text(summary, '切割') or has_text(summary, '残影') or has_text(summary, '岩浪') then
      add_skill_echo(skill, 1, 0.70)
      add_skill_persistent_field(skill, blueprint.id, 2.2, 0.30, {})
    end
    if has_text(summary, '终点')
      or has_text(summary, '重斩')
      or blueprint.archetype == '直线贯穿清怪'
      or blueprint.archetype == '长线穿透爆发' then
      add_skill_terminal_burst(skill, blueprint.id, 1.10, 0.80)
    end
    if has_text(summary, '雷劫') or has_text(summary, '雷击') then
      add_generic_shock(skill, 4, 0.20)
      skill.return_pass_enabled = true
    end
    if blueprint.archetype == '追击飞剑攒射' then
      add_skill_followup(skill, 2, 0.55)
    end
    if has_text(summary, '聚怪') or has_text(summary, '黄风') or has_text(summary, '风庭') then
      add_pull_strength(skill, 120)
    end
  end

  local function build_blueprint_card_apply(blueprint, card)
    return function()
      local skill = get_attack_skill(blueprint.id)
      if not skill then
        return
      end

      local summary = card.summary or ''
      if card.lane == 'damage' then
        add_skill_damage_ratio(skill, blueprint.id, parse_first_percent(summary) > 0 and parse_first_percent(summary) or 0.60)
        return
      end
      if card.lane == 'frequency' then
        add_skill_cooldown_cut(skill, parse_first_percent(summary) > 0 and parse_first_percent(summary) or 0.18)
        return
      end
      if card.lane == 'range' then
        if (get_base_skill_def(blueprint.id).base_radius or 0) > 0 then
          add_skill_radius(skill, blueprint.id, parse_first_percent(summary) > 0 and parse_first_percent(summary) or 0.60)
        else
          add_skill_cast_range(skill, blueprint.id, parse_first_percent(summary) > 0 and parse_first_percent(summary) or 0.60)
        end
        return
      end
      if card.lane == 'function' then
        apply_blueprint_function_card(blueprint, skill, card)
        return
      end
      if card.lane == 'count' then
        apply_blueprint_count_card(blueprint, skill, card)
        return
      end
      if card.lane == 'form' then
        apply_blueprint_form_card(blueprint, skill, card)
        return
      end
      if card.lane == 'state' then
        apply_blueprint_state_card(blueprint, skill, card)
        return
      end
      if card.lane == 'elite' then
        apply_blueprint_elite_card(skill, card)
        return
      end
      if card.lane == 'trigger' then
        apply_blueprint_trigger_card(blueprint, skill, card)
        return
      end
    end
  end

  local function build_blueprint_regular_upgrades()
    local upgrades = {}

    for _, blueprint in ipairs(ATTACK_SKILL_BLUEPRINTS.list or {}) do
      if not ATTACK_SKILL_DEFS[blueprint.id] then
        goto continue_blueprint
      end

      for _, bucket in ipairs(BLUEPRINT_BUCKET_ORDER) do
        for _, card in ipairs((blueprint.cards and blueprint.cards[bucket]) or {}) do
          upgrades[#upgrades + 1] = skill_upgrade({
            key = 'bp_' .. tostring(card.id),
            skill_id = blueprint.id,
            name = card.name,
            desc = card.summary,
            ui_icon = (ATTACK_SKILL_DEFS[blueprint.id] and ATTACK_SKILL_DEFS[blueprint.id].ui_icon) or blueprint.ui_icon or blueprint.icon,
            quality = QUALITY_BY_BUCKET[bucket] or 'common',
            weight = WEIGHT_BY_BUCKET[bucket] or 4,
            max_picks = 1,
            route_tags = {
              blueprint.id,
              blueprint.element or 'element',
              card.lane or bucket,
              ROUTE_TAG_BY_BUCKET[bucket] or bucket,
            },
            apply = build_blueprint_card_apply(blueprint, card),
          })
        end
      end

      ::continue_blueprint::
    end

    return upgrades
  end

  local function build_blueprint_unlock_upgrades()
    local upgrades = {}

    for _, blueprint in ipairs(ATTACK_SKILL_BLUEPRINTS.list or {}) do
      if not ATTACK_SKILL_DEFS[blueprint.id] then
        goto continue
      end

      upgrades[#upgrades + 1] = unlock_upgrade({
        key = 'unlock_' .. blueprint.id,
        skill_id = blueprint.id,
        name = blueprint.name,
        ui_icon = (ATTACK_SKILL_DEFS[blueprint.id] and ATTACK_SKILL_DEFS[blueprint.id].ui_icon) or blueprint.ui_icon or blueprint.icon,
        desc = string.format(
          '装配到空余攻击技能位。定位：%s。终局：%s。',
          blueprint.archetype or '攻击技能',
          blueprint.evolution and blueprint.evolution.name or '未命名终局'
        ),
        quality = 'rare',
        route_tags = { blueprint.id, blueprint.element or 'element' },
        can_offer = function()
          return get_empty_attack_skill_slot() ~= nil and not get_attack_skill(blueprint.id)
        end,
        apply = function()
          local skill, slot, is_new = unlock_attack_skill(blueprint.id)
          if skill and is_new then
            message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
          end
        end,
      })

      ::continue::
    end

    return upgrades
  end

  local ATTACK_UPGRADE_DEFS = {
    skill_upgrade({
      key = 'basic_attack_damage',
      skill_id = 'basic_attack',
      name = '凝锋',
      desc = '普攻伤害 +15%。',
      max_picks = 4,
      route_tags = { 'basic_attack' },
      apply = function()
        local skill = get_attack_skill('basic_attack')
        skill.damage_ratio = skill.damage_ratio + 0.15
        sync_basic_attack_ability()
      end,
    }),
    skill_upgrade({
      key = 'basic_rapid_edge',
      skill_id = 'basic_attack',
      name = '御剑回环',
      desc = '普攻间隔缩短 8%。',
      max_picks = 4,
      route_tags = { 'basic_attack', 'tempo' },
      apply = function()
        local skill = get_attack_skill('basic_attack')
        skill.cooldown_reduction = math.min(0.55, (skill.cooldown_reduction or 0) + 0.08)
        sync_basic_attack_ability()
      end,
    }),
    skill_upgrade({
      key = 'basic_splitshot',
      skill_id = 'basic_attack',
      name = '分光剑影',
      desc = '普攻额外分裂 1 个目标，分裂伤害 +15%。',
      max_picks = 3,
      route_tags = { 'basic_attack', 'barrage', 'clear' },
      apply = function()
        local skill = get_attack_skill('basic_attack')
        skill.split_count = skill.split_count + 1
        skill.split_ratio = skill.split_ratio + 0.15
        sync_basic_attack_ability()
      end,
    }),
    skill_upgrade({
      key = 'basic_hunter_mark',
      skill_id = 'basic_attack',
      name = '猎王刻印',
      desc = '对精英与 Boss 额外伤害 +15%，攻击范围 +60。',
      max_picks = 3,
      route_tags = { 'basic_attack', 'hunter', 'boss' },
      apply = function()
        local skill = get_attack_skill('basic_attack')
        skill.boss_bonus_ratio = skill.boss_bonus_ratio + 0.15
        skill.range_bonus = skill.range_bonus + 60
        STATE.hero:add_attr('攻击范围', 60)
        sync_basic_attack_ability()
      end,
    }),
    skill_upgrade({
      key = 'basic_sunder',
      skill_id = 'basic_attack',
      name = '裂甲飞锋',
      desc = '普攻附加破甲，持续时间 +1 秒，叠层上限 +1。',
      max_picks = 3,
      route_tags = { 'basic_attack', 'armor_break', 'boss' },
      apply = function()
        local skill = get_attack_skill('basic_attack')
        skill.armor_break_ratio = skill.armor_break_ratio + 0.04
        skill.armor_break_duration = skill.armor_break_duration + 1
        skill.armor_break_max_stacks = skill.armor_break_max_stacks + 1
        sync_basic_attack_ability()
      end,
    }),
  }

  for _, upgrade in ipairs(build_blueprint_unlock_upgrades()) do
    ATTACK_UPGRADE_DEFS[#ATTACK_UPGRADE_DEFS + 1] = upgrade
  end
  for _, upgrade in ipairs(build_blueprint_regular_upgrades()) do
    ATTACK_UPGRADE_DEFS[#ATTACK_UPGRADE_DEFS + 1] = upgrade
  end

  local function is_unlock_upgrade(upgrade)
    return upgrade and type(upgrade.key) == 'string' and string.sub(upgrade.key, 1, 7) == 'unlock_'
  end

  local function get_upgrade_balance_wave_index()
    return math.max(1, STATE.current_wave_index or 0, STATE.started_wave_count or 0)
  end

  local function get_unlock_offer_chance(unlocked_skill_count)
    local wave_index = get_upgrade_balance_wave_index()
    if unlocked_skill_count <= 1 then
      if wave_index <= 1 then
        return 0.75
      end
      if wave_index == 2 then
        return 0.65
      end
      return 0.50
    end
    if unlocked_skill_count == 2 then
      if wave_index <= 1 then
        return 0.55
      end
      if wave_index == 2 then
        return 0.45
      end
      return 0.35
    end
    if unlocked_skill_count == 3 then
      if wave_index <= 2 then
        return 0.30
      end
      if wave_index <= 4 then
        return 0.22
      end
      return 0.15
    end
    return 0
  end

  local function get_skill_regular_upgrade_pick_count(skill_id)
    if not skill_id then
      return 0
    end

    local total = 0
    for _, upgrade in ipairs(ATTACK_UPGRADE_DEFS) do
      if upgrade.skill_id == skill_id and not is_unlock_upgrade(upgrade) then
        total = total + get_upgrade_pick_count(upgrade.key)
      end
    end
    return total
  end

  local function build_upgrade_route_tags()
    local tags = {}

    if STATE.attack_skill_state and STATE.attack_skill_state.by_id then
      for skill_id in pairs(STATE.attack_skill_state.by_id) do
        tags[skill_id] = true
      end
    else
      tags.basic_attack = true
      for _, blueprint in ipairs(ATTACK_SKILL_BLUEPRINTS.list or {}) do
        local skill_id = blueprint.id
        if get_attack_skill(skill_id) then
          tags[skill_id] = true
        end
      end
    end

    if collect_bond_route_tags then
      for tag in pairs(collect_bond_route_tags() or {}) do
        tags[tag] = true
      end
    end

    return tags
  end

  local function get_route_match_factor(route_tags, build_tags)
    local match_count = 0

    for _, tag in ipairs(route_tags or {}) do
      if build_tags[tag] then
        match_count = match_count + 1
      end
    end

    if match_count <= 0 then
      return 1.0
    end
    if match_count == 1 then
      return 1.30
    end
    if match_count == 2 then
      return 1.50
    end
    return 1.65
  end

  local function get_regular_upgrade_weight(upgrade, build_tags)
    local base_weight = upgrade.weight or 1
    local factor = 1.0

    local skill_id = upgrade.skill_id
    local wave_index = get_upgrade_balance_wave_index()
    local picked_count = get_skill_regular_upgrade_pick_count(skill_id)

    if picked_count > 0 then
      factor = factor * 1.20
    else
      factor = factor * 0.90
    end

    if STATE.attack_skill_state and STATE.attack_skill_state.last_picked_skill_id == skill_id then
      factor = factor * 1.20
    end

    local feed_rounds = STATE.attack_skill_state
      and STATE.attack_skill_state.new_skill_feed
      and STATE.attack_skill_state.new_skill_feed[skill_id]
      or 0
    if feed_rounds > 0 then
      factor = factor * 1.50
    end

    factor = factor * get_route_match_factor(upgrade.route_tags, build_tags)

    if skill_id == 'basic_attack' and wave_index <= 2 then
      factor = factor * 1.15
    end

    return base_weight * math.min(factor, 2.5)
  end

  local function get_upgrade_effective_weight(upgrade, build_tags)
    if is_unlock_upgrade(upgrade) then
      return (upgrade.weight or 1) * get_route_match_factor(upgrade.route_tags, build_tags)
    end
    return get_regular_upgrade_weight(upgrade, build_tags)
  end

  local function count_distinct_skill_ids(pool)
    local seen = {}
    local count = 0
    for _, upgrade in ipairs(pool) do
      local skill_id = upgrade.skill_id
      if skill_id and not seen[skill_id] then
        seen[skill_id] = true
        count = count + 1
      end
    end
    return count
  end

  local function decay_new_skill_feed_rounds()
    if not STATE.attack_skill_state or not STATE.attack_skill_state.new_skill_feed then
      return
    end

    for skill_id, rounds in pairs(STATE.attack_skill_state.new_skill_feed) do
      local next_rounds = rounds - 1
      if next_rounds > 0 then
        STATE.attack_skill_state.new_skill_feed[skill_id] = next_rounds
      else
        STATE.attack_skill_state.new_skill_feed[skill_id] = nil
      end
    end
  end

  local function pick_weighted_upgrade(pool, avoid_skill_id)
    if #pool == 0 then
      return nil
    end

    local build_tags = build_upgrade_route_tags()
    local total_weight = 0
    local candidates = {}
    for index, upgrade in ipairs(pool) do
      if not avoid_skill_id or upgrade.skill_id ~= avoid_skill_id then
        local weight = math.max(0.01, get_upgrade_effective_weight(upgrade, build_tags))
        total_weight = total_weight + weight
        candidates[#candidates + 1] = {
          index = index,
          weight = weight,
        }
      end
    end

    if #candidates == 0 then
      return pick_weighted_upgrade(pool, nil)
    end

    local roll = math.random() * total_weight
    local cumulative = 0
    local picked_index = candidates[#candidates].index
    for _, candidate in ipairs(candidates) do
      cumulative = cumulative + candidate.weight
      if roll <= cumulative then
        picked_index = candidate.index
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
    local has_unlock_available = get_empty_attack_skill_slot() ~= nil and #unlock_pool > 0
    local unlock_added = false

    if has_unlock_available then
      local force_unlock = STATE.attack_skill_state
        and (STATE.attack_skill_state.unlock_offer_fail_streak or 0) >= 3
      local should_offer_unlock = force_unlock
        or math.random() <= get_unlock_offer_chance(unlocked_skill_count)
      if should_offer_unlock then
        local picked = pick_weighted_upgrade(unlock_pool)
        if picked then
          choices[#choices + 1] = picked
          unlock_added = true
        end
      end
    end

    local regular_skill_ids = {}
    while #choices < count and #regular_pool > 0 do
      local avoid_skill_id = nil
      if #regular_skill_ids == 1 and count_distinct_skill_ids(regular_pool) > 1 then
        avoid_skill_id = regular_skill_ids[1]
      end

      local picked = pick_weighted_upgrade(regular_pool, avoid_skill_id)
      if not picked then
        break
      end
      choices[#choices + 1] = picked
      regular_skill_ids[#regular_skill_ids + 1] = picked.skill_id
    end

    if #choices < count and not unlock_added and has_unlock_available then
      local picked = pick_weighted_upgrade(unlock_pool)
      if picked then
        choices[#choices + 1] = picked
        unlock_added = true
      end
    end

    while #choices < count and #regular_pool > 0 do
      local picked = pick_weighted_upgrade(regular_pool)
      if not picked then
        break
      end
      choices[#choices + 1] = picked
    end

    if STATE.attack_skill_state and #choices > 0 then
      if has_unlock_available then
        if unlock_added then
          STATE.attack_skill_state.unlock_offer_fail_streak = 0
        else
          STATE.attack_skill_state.unlock_offer_fail_streak =
            (STATE.attack_skill_state.unlock_offer_fail_streak or 0) + 1
        end
      else
        STATE.attack_skill_state.unlock_offer_fail_streak = 0
      end

      decay_new_skill_feed_rounds()
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
      STATE.current_upgrade_round = {
        free_refresh_left = UPGRADE_FREE_REFRESH_COUNT,
        refresh_paid_count = 0,
      }
      message('攻击技能强化 3 选 1：按 1 / 2 / 3 选择。')
    end

    for index, upgrade in ipairs(STATE.current_upgrade_choices) do
      message(string.format('%d. [%s] %s %s', index, upgrade.tag or '强化', upgrade.name, upgrade.desc))
    end
  end

  local function refresh_upgrade_choices()
    if not STATE.awaiting_upgrade or not STATE.current_upgrade_choices then
      return false
    end

    local choices = pick_upgrade_choices(3)
    if #choices == 0 then
      message('当前没有可刷新的攻击技能强化选项。')
      return false
    end

    local round = ensure_upgrade_round()
    if (round.free_refresh_left or 0) > 0 then
      round.free_refresh_left = round.free_refresh_left - 1
      message(string.format('已免费刷新 G 三选一，剩余免费次数 %d。', round.free_refresh_left))
    else
      local cost = get_refresh_cost(round.refresh_paid_count or 0)
      local wood = STATE.resources and STATE.resources.wood or 0
      if wood < cost then
        message(string.format('木材不足，刷新 G 三选一需要 %d 木材。', cost))
        return false
      end
      STATE.resources.wood = wood - cost
      round.refresh_paid_count = (round.refresh_paid_count or 0) + 1
      message(string.format('已消耗 %d 木材刷新 G 三选一。', cost))
    end

    STATE.current_upgrade_choices = choices
    return true
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
    if STATE.attack_skill_state then
      STATE.attack_skill_state.last_picked_skill_id = upgrade.skill_id
    end
    STATE.awaiting_upgrade = false
    STATE.current_upgrade_choices = nil
    STATE.current_upgrade_round = nil
    message('已选择强化：' .. upgrade.name)

    if upgrade.skill_id == 'basic_attack' then
      sync_basic_attack_ability()
    end

    if upgrade.skill_id and get_attack_skill(upgrade.skill_id) then
      local skill = get_attack_skill(upgrade.skill_id)
      message('技能更新：' .. build_attack_skill_slot_text(skill.slot))
    end
  end

  return {
    show_upgrade_choices = show_upgrade_choices,
    refresh_upgrade_choices = refresh_upgrade_choices,
    apply_upgrade = apply_upgrade,
  }
end

return M

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
        desc = string.format('装配到空余攻击技能位。定位：%s。', blueprint.archetype or '攻击技能'),
        route_tags = { blueprint.id },
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
    unlock_upgrade({
      key = 'unlock_arcane_arrow',
      skill_id = 'arcane_arrow',
      name = '奥术箭',
      desc = '装配到空余攻击技能位。',
      route_tags = { 'arcane_arrow', 'element' },
      can_offer = function()
        return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('arcane_arrow')
      end,
      apply = function()
        local skill, slot, is_new = unlock_attack_skill('arcane_arrow')
        if skill and is_new then
          message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
        end
      end,
    }),
    unlock_upgrade({
      key = 'unlock_flame_arrow',
      skill_id = 'flame_arrow',
      name = '爆炎箭',
      desc = '装配到空余攻击技能位。',
      route_tags = { 'flame_arrow', 'element' },
      can_offer = function()
        return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('flame_arrow')
      end,
      apply = function()
        local skill, slot, is_new = unlock_attack_skill('flame_arrow')
        if skill and is_new then
          message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
        end
      end,
    }),
    unlock_upgrade({
      key = 'unlock_frost_arrow',
      skill_id = 'frost_arrow',
      name = '寒冰箭',
      desc = '装配到空余攻击技能位。',
      route_tags = { 'frost_arrow', 'element' },
      can_offer = function()
        return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('frost_arrow')
      end,
      apply = function()
        local skill, slot, is_new = unlock_attack_skill('frost_arrow')
        if skill and is_new then
          message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
        end
      end,
    }),
    unlock_upgrade({
      key = 'unlock_thunder',
      skill_id = 'thunder',
      name = '天雷',
      desc = '装配到空余攻击技能位。',
      route_tags = { 'thunder', 'element' },
      can_offer = function()
        return get_empty_attack_skill_slot() ~= nil and not get_attack_skill('thunder')
      end,
      apply = function()
        local skill, slot, is_new = unlock_attack_skill('thunder')
        if skill and is_new then
          message(string.format('已装配 %d 号位攻击技能：%s。', slot, skill.name))
        end
      end,
    }),
    skill_upgrade({
      key = 'basic_attack_damage',
      skill_id = 'basic_attack',
      name = '强化箭矢',
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
      key = 'basic_splitshot',
      skill_id = 'basic_attack',
      name = '分裂箭矢',
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
      name = '破甲强弩',
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
    skill_upgrade({
      key = 'arcane_damage',
      skill_id = 'arcane_arrow',
      name = '箭矢增幅',
      desc = '奥术箭伤害 +20%。',
      max_picks = 4,
      route_tags = { 'arcane_arrow', 'element' },
      apply = function()
        local skill = get_attack_skill('arcane_arrow')
        skill.damage_ratio = skill.damage_ratio + 0.20
      end,
    }),
    skill_upgrade({
      key = 'arcane_secondary',
      skill_id = 'arcane_arrow',
      name = '次级箭',
      desc = '奥术箭次级目标 +1。',
      max_picks = 3,
      route_tags = { 'arcane_arrow', 'resonance', 'clear' },
      apply = function()
        local skill = get_attack_skill('arcane_arrow')
        skill.secondary_targets = skill.secondary_targets + 1
      end,
    }),
    skill_upgrade({
      key = 'arcane_burst',
      skill_id = 'arcane_arrow',
      name = '爆裂棱镜',
      desc = '奥术箭命中后额外爆裂，半径 +110，倍率 +20%。',
      max_picks = 3,
      route_tags = { 'arcane_arrow', 'resonance', 'burst' },
      apply = function()
        local skill = get_attack_skill('arcane_arrow')
        skill.burst_radius = skill.burst_radius + 110
        skill.burst_ratio = skill.burst_ratio + 0.20
      end,
    }),
    skill_upgrade({
      key = 'arcane_volley',
      skill_id = 'arcane_arrow',
      name = '齐射回路',
      desc = '奥术箭额外释放 1 次，冷却缩减 8%。',
      max_picks = 2,
      route_tags = { 'arcane_arrow', 'tempo', 'element' },
      apply = function()
        local skill = get_attack_skill('arcane_arrow')
        skill.repeat_count = skill.repeat_count + 1
        skill.cooldown_reduction = math.min(0.65, skill.cooldown_reduction + 0.08)
      end,
    }),
    skill_upgrade({
      key = 'flame_damage',
      skill_id = 'flame_arrow',
      name = '火箭增幅',
      desc = '爆炎箭本体与爆炸伤害各 +18%。',
      max_picks = 4,
      route_tags = { 'flame_arrow', 'element' },
      apply = function()
        local skill = get_attack_skill('flame_arrow')
        skill.damage_ratio = skill.damage_ratio + 0.18
        skill.explosion_ratio = skill.explosion_ratio + 0.18
      end,
    }),
    skill_upgrade({
      key = 'flame_ignite',
      skill_id = 'flame_arrow',
      name = '灼热引信',
      desc = '点燃持续时间 +2 秒，每秒伤害 +6% 攻击。',
      max_picks = 3,
      route_tags = { 'flame_arrow', 'burn', 'element' },
      apply = function()
        local skill = get_attack_skill('flame_arrow')
        skill.ignite_duration = skill.ignite_duration + 2
        skill.ignite_tick_ratio = skill.ignite_tick_ratio + 0.06
      end,
    }),
    skill_upgrade({
      key = 'flame_spread',
      skill_id = 'flame_arrow',
      name = '余烬扩散',
      desc = '点燃扩散半径 +140，爆炸半径 +50。',
      max_picks = 3,
      route_tags = { 'flame_arrow', 'burn', 'clear' },
      apply = function()
        local skill = get_attack_skill('flame_arrow')
        skill.ignite_spread_radius = skill.ignite_spread_radius + 140
        skill.explosion_radius = skill.explosion_radius + 50
      end,
    }),
    skill_upgrade({
      key = 'flame_double_blast',
      skill_id = 'flame_arrow',
      name = '火箭爆破',
      desc = '爆炎箭额外释放 1 次，爆炸倍率 +25%。',
      max_picks = 2,
      route_tags = { 'flame_arrow', 'burst', 'boss' },
      apply = function()
        local skill = get_attack_skill('flame_arrow')
        skill.repeat_count = skill.repeat_count + 1
        skill.explosion_ratio = skill.explosion_ratio + 0.25
      end,
    }),
    skill_upgrade({
      key = 'frost_damage',
      skill_id = 'frost_arrow',
      name = '冰箭增幅',
      desc = '寒冰箭伤害 +20%。',
      max_picks = 4,
      route_tags = { 'frost_arrow', 'element' },
      apply = function()
        local skill = get_attack_skill('frost_arrow')
        skill.damage_ratio = skill.damage_ratio + 0.20
      end,
    }),
    skill_upgrade({
      key = 'frost_pierce',
      skill_id = 'frost_arrow',
      name = '贯穿冰箭',
      desc = '寒冰箭穿透 +1。',
      max_picks = 3,
      route_tags = { 'frost_arrow', 'line', 'control' },
      apply = function()
        local skill = get_attack_skill('frost_arrow')
        skill.pierce = skill.pierce + 1
      end,
    }),
    skill_upgrade({
      key = 'frost_shards',
      skill_id = 'frost_arrow',
      name = '三棱冰片',
      desc = '寒冰箭额外裂出 2 枚冰片，冰片伤害 +15%。',
      max_picks = 3,
      route_tags = { 'frost_arrow', 'cold_tide', 'clear' },
      apply = function()
        local skill = get_attack_skill('frost_arrow')
        skill.shard_count = skill.shard_count + 2
        skill.shard_ratio = skill.shard_ratio + 0.15
      end,
    }),
    skill_upgrade({
      key = 'frost_shatter',
      skill_id = 'frost_arrow',
      name = '冰片增伤',
      desc = '对受控目标额外伤害 +15%，控制时间 +0.12 秒。',
      max_picks = 3,
      route_tags = { 'frost_arrow', 'control', 'boss' },
      apply = function()
        local skill = get_attack_skill('frost_arrow')
        skill.shatter_bonus = skill.shatter_bonus + 0.15
        skill.control_lock_time = skill.control_lock_time + 0.12
      end,
    }),
    skill_upgrade({
      key = 'thunder_damage',
      skill_id = 'thunder',
      name = '雷击增幅',
      desc = '天雷伤害 +20%。',
      max_picks = 4,
      route_tags = { 'thunder', 'element' },
      apply = function()
        local skill = get_attack_skill('thunder')
        skill.damage_ratio = skill.damage_ratio + 0.20
      end,
    }),
    skill_upgrade({
      key = 'thunder_chain',
      skill_id = 'thunder',
      name = '连续雷击',
      desc = '天雷额外打击 1 个附近目标。',
      max_picks = 3,
      route_tags = { 'thunder', 'shock', 'clear' },
      apply = function()
        local skill = get_attack_skill('thunder')
        skill.extra_targets = skill.extra_targets + 1
      end,
    }),
    skill_upgrade({
      key = 'thunder_shock',
      skill_id = 'thunder',
      name = '高压导体',
      desc = '感电持续时间 +1.5 秒，对感电目标额外伤害 +10%。',
      max_picks = 3,
      route_tags = { 'thunder', 'shock', 'boss' },
      apply = function()
        local skill = get_attack_skill('thunder')
        skill.shock_duration = skill.shock_duration + 1.5
        skill.shock_bonus = skill.shock_bonus + 0.10
      end,
    }),
    skill_upgrade({
      key = 'thunder_field',
      skill_id = 'thunder',
      name = '磁暴电场',
      desc = '天雷落点生成电场，半径 +120，倍率 +20%。',
      max_picks = 3,
      route_tags = { 'thunder', 'shock', 'clear' },
      apply = function()
        local skill = get_attack_skill('thunder')
        skill.field_radius = skill.field_radius + 120
        skill.field_ratio = skill.field_ratio + 0.20
      end,
    }),
  }

  for _, upgrade in ipairs(build_blueprint_unlock_upgrades()) do
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

    for _, skill_id in ipairs({ 'basic_attack', 'arcane_arrow', 'flame_arrow', 'frost_arrow', 'thunder' }) do
      if get_attack_skill(skill_id) then
        tags[skill_id] = true
      end
    end

    if collect_bond_route_tags then
      for tag in pairs(collect_bond_route_tags() or {}) do
        tags[tag] = true
      end
    end

    for _, treasure_id in ipairs({
      'hunter_badge', 'feather_quiver', 'echo_codex',
      'gale_tailfeather', 'thunder_pin', 'time_rift_hourglass',
    }) do
      if has_active_treasure and has_active_treasure(treasure_id) then
        tags[treasure_id] = true
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

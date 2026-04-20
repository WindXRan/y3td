local HeroAttrDefs = require 'runtime.hero_attr_defs'

local M = {}

local TRACK_FREE = 'free'
local TRACK_PAID = 'paid'
local CURRENT_SEASON_ID = 'season_1'
local LEVEL_EXP = 300
local MAX_MILITARY_ORDER_CHARGES = 4
local DAILY_LOGIN_REWARD = {
  skill_fragments = 12,
  achievement_points = 6,
}
local MILITARY_ORDER_REWARD = {
  exp = 90,
  skill_fragments = 18,
  achievement_points = 10,
}

local SHORT_ATTR_LABELS = {
  ['攻击白字'] = '攻',
  ['生命白字'] = '命',
  ['攻击范围'] = '射程',
  ['护甲白字'] = '甲',
  ['物理暴击'] = '暴击',
  ['物理暴伤'] = '暴伤',
  ['最终伤害'] = '终伤',
  ['最终生命'] = '终命',
  ['最终攻击'] = '终攻',
  ['攻击增幅'] = '攻幅',
  ['生命增幅'] = '命幅',
  ['杀敌金币'] = '金币',
  ['杀敌经验'] = '经验',
}

local PASS_DEFS = {
  season_id = CURRENT_SEASON_ID,
  season_name = '征战之路·初章',
  premium_name = '至尊征战之路',
  level_exp = LEVEL_EXP,
  battle_result_exp = {
    win_base = 180,
    loss_base = 80,
    per_wave = 35,
    clear_bonus = 60,
  },
  levels = {
    { level = 1,  free = { attr = { ['攻击白字'] = 4 } },   paid = { attr = { ['生命白字'] = 80 } } },
    { level = 2,  free = { attr = { ['生命白字'] = 120 } }, paid = { attr = { ['攻击范围'] = 60 } } },
    { level = 3,  free = { attr = { ['护甲白字'] = 2 } },   paid = { attr = { ['物理暴击'] = 2 } } },
    { level = 4,  free = { attr = { ['攻击白字'] = 6 } },   paid = { attr = { ['生命白字'] = 160 } } },
    { level = 5,  free = { attr = { ['攻击范围'] = 80 } },  paid = { attr = { ['最终伤害'] = 1 } } },
    { level = 6,  free = { attr = { ['护甲白字'] = 3 } },   paid = { attr = { ['攻击增幅'] = 2 } } },
    { level = 7,  free = { attr = { ['攻击白字'] = 8 } },   paid = { attr = { ['生命增幅'] = 3 } } },
    { level = 8,  free = { attr = { ['杀敌金币'] = 3 } },   paid = { attr = { ['杀敌经验'] = 4 } } },
    { level = 9,  free = { attr = { ['物理暴击'] = 3 } },   paid = { attr = { ['物理暴伤'] = 6 } } },
    { level = 10, free = { attr = { ['生命白字'] = 220 } }, paid = { attr = { ['最终生命'] = 2 } } },
    { level = 11, free = { attr = { ['攻击白字'] = 10 } },  paid = { attr = { ['攻击范围'] = 100 } } },
    { level = 12, free = { attr = { ['最终伤害'] = 1 } },   paid = { attr = { ['最终攻击'] = 2 } } },
  },
}

local MAX_LEVEL = #PASS_DEFS.levels
local MAX_TOTAL_EXP = math.max(0, (MAX_LEVEL - 1) * PASS_DEFS.level_exp)

local RATIO_ATTRS = {}
for attr_name, def in pairs(HeroAttrDefs.by_name or {}) do
  if def and def.is_ratio == true then
    RATIO_ATTRS[attr_name] = true
  end
end

local function clamp_nonnegative_int(value)
  local number = tonumber(value) or 0
  if number <= 0 then
    return 0
  end
  return math.floor(number)
end

local function clamp_int_with_default(value, default)
  local integer = math.tointeger(value)
  if integer == nil then
    return default
  end
  return integer
end

local function get_day_context()
  local now
  if y3 and y3.game and y3.game.get_current_server_time then
    local ok, result = pcall(y3.game.get_current_server_time, 8)
    if ok and type(result) == 'table' then
      now = result
    end
  end

  if not now then
    local timestamp = os.time()
    local date = os.date('*t', timestamp)
    date.timestamp = timestamp
    date.time_zone_stamp = timestamp
    now = date
  end

  local stamp = tonumber(now.time_zone_stamp) or tonumber(now.timestamp) or 0
  return {
    day_key = string.format(
      '%04d-%02d-%02d',
      tonumber(now.year) or 1970,
      tonumber(now.month) or 1,
      tonumber(now.day) or 1
    ),
    day_serial = math.floor(stamp / 86400),
  }
end

local function copy_claim_map(map)
  local result = {}
  local dirty = false
  if type(map) ~= 'table' then
    if map ~= nil then
      dirty = true
    end
    return result, dirty
  end

  for key, value in pairs(map) do
    local level = tonumber(key)
    if level and PASS_DEFS.levels[level] then
      local normalized_key = tostring(level)
      if value == true then
        result[normalized_key] = true
      elseif value ~= nil and value ~= false then
        result[normalized_key] = true
        dirty = true
      else
        dirty = true
      end
      if normalized_key ~= key then
        dirty = true
      end
    else
      dirty = true
    end
  end

  return result, dirty
end

local function same_boolean_map(left, right)
  left = type(left) == 'table' and left or {}
  right = type(right) == 'table' and right or {}

  for key, value in pairs(left) do
    if value ~= right[key] then
      return false
    end
  end
  for key, value in pairs(right) do
    if value ~= left[key] then
      return false
    end
  end
  return true
end

local function add_attr_pack(target, source)
  for attr_name, value in pairs(source or {}) do
    local numeric = tonumber(value)
    if attr_name ~= nil and attr_name ~= '' and numeric ~= nil and numeric ~= 0 then
      target[attr_name] = (target[attr_name] or 0) + numeric
    end
  end
end

local function count_true_entries(map)
  local count = 0
  for _, value in pairs(map or {}) do
    if value == true then
      count = count + 1
    end
  end
  return count
end

local function build_currency_gain_label(reward)
  local labels = {}
  if (reward.skill_fragments or 0) > 0 then
    labels[#labels + 1] = string.format('技能碎片+%d', reward.skill_fragments)
  end
  if (reward.achievement_points or 0) > 0 then
    labels[#labels + 1] = string.format('成就积分+%d', reward.achievement_points)
  end
  return table.concat(labels, '、')
end

local function get_track_claim_map(bp, track)
  if track == TRACK_PAID then
    return bp.claimed_paid
  end
  return bp.claimed_free
end

local function get_reward_def(level, track)
  local row = PASS_DEFS.levels[level]
  if not row then
    return nil
  end
  if track == TRACK_PAID then
    return row.paid
  end
  return row.free
end

local function format_attr_value(attr_name, value)
  local numeric = tonumber(value) or 0
  if RATIO_ATTRS[attr_name] then
    return string.format('%+d%%', numeric)
  end
  if math.type and math.type(numeric) == 'float' then
    return string.format('%+.1f', numeric)
  end
  return string.format('%+d', numeric)
end

local function build_attr_pack_label(attr_pack, use_short_label)
  local names = {}
  for attr_name in pairs(attr_pack or {}) do
    names[#names + 1] = attr_name
  end
  table.sort(names)

  local fragments = {}
  for _, attr_name in ipairs(names) do
    local label = use_short_label and (SHORT_ATTR_LABELS[attr_name] or attr_name) or attr_name
    fragments[#fragments + 1] = string.format('%s%s', label, format_attr_value(attr_name, attr_pack[attr_name]))
  end

  if #fragments == 0 then
    return '无'
  end
  return table.concat(fragments, ' ')
end

local function build_track_summary(level, track, use_short_label)
  local reward_def = get_reward_def(level, track)
  if not reward_def or type(reward_def.attr) ~= 'table' then
    return '无'
  end
  return build_attr_pack_label(reward_def.attr, use_short_label)
end

local function get_current_level_by_exp(exp)
  if MAX_LEVEL <= 1 then
    return 1
  end
  local level = math.floor((tonumber(exp) or 0) / PASS_DEFS.level_exp) + 1
  if level > MAX_LEVEL then
    return MAX_LEVEL
  end
  if level < 1 then
    return 1
  end
  return level
end

local function get_bp(profile)
  return type(profile) == 'table' and profile.battle_pass or nil
end

local function get_wallet(bp)
  return type(bp) == 'table' and bp.wallet or nil
end

local function get_login_reward(bp)
  return type(bp) == 'table' and bp.login_reward or nil
end

local function get_military_order(bp)
  return type(bp) == 'table' and bp.military_order or nil
end

local function create_default_bp()
  return {
    season_id = PASS_DEFS.season_id,
    exp = 0,
    paid_unlocked = false,
    claimed_free = {},
    claimed_paid = {},
    wallet = {
      skill_fragments = 0,
      achievement_points = 0,
    },
    login_reward = {
      last_claim_day_key = '',
      last_claim_day_serial = -1,
      total_claim_days = 0,
    },
    military_order = {
      charges = 0,
      last_refresh_day_serial = -1,
      completed_count = 0,
    },
  }
end

local function ensure_wallet_defaults(bp)
  local dirty = false
  if type(bp.wallet) ~= 'table' then
    bp.wallet = {}
    dirty = true
  end

  local wallet = bp.wallet
  local skill_fragments = clamp_nonnegative_int(wallet.skill_fragments)
  if wallet.skill_fragments ~= skill_fragments then
    wallet.skill_fragments = skill_fragments
    dirty = true
  end

  local achievement_points = clamp_nonnegative_int(wallet.achievement_points)
  if wallet.achievement_points ~= achievement_points then
    wallet.achievement_points = achievement_points
    dirty = true
  end

  return dirty
end

local function ensure_login_reward_defaults(bp)
  local dirty = false
  if type(bp.login_reward) ~= 'table' then
    bp.login_reward = {}
    dirty = true
  end

  local login_reward = bp.login_reward
  if type(login_reward.last_claim_day_key) ~= 'string' then
    login_reward.last_claim_day_key = ''
    dirty = true
  end

  local last_claim_day_serial = clamp_int_with_default(login_reward.last_claim_day_serial, -1)
  if login_reward.last_claim_day_serial ~= last_claim_day_serial then
    login_reward.last_claim_day_serial = last_claim_day_serial
    dirty = true
  end

  local total_claim_days = clamp_nonnegative_int(login_reward.total_claim_days)
  if login_reward.total_claim_days ~= total_claim_days then
    login_reward.total_claim_days = total_claim_days
    dirty = true
  end

  return dirty
end

local function ensure_military_order_defaults(bp)
  local dirty = false
  if type(bp.military_order) ~= 'table' then
    bp.military_order = {}
    dirty = true
  end

  local military_order = bp.military_order
  local charges = clamp_nonnegative_int(military_order.charges)
  if charges > MAX_MILITARY_ORDER_CHARGES then
    charges = MAX_MILITARY_ORDER_CHARGES
  end
  if military_order.charges ~= charges then
    military_order.charges = charges
    dirty = true
  end

  local last_refresh_day_serial = clamp_int_with_default(military_order.last_refresh_day_serial, -1)
  if military_order.last_refresh_day_serial ~= last_refresh_day_serial then
    military_order.last_refresh_day_serial = last_refresh_day_serial
    dirty = true
  end

  local completed_count = clamp_nonnegative_int(military_order.completed_count)
  if military_order.completed_count ~= completed_count then
    military_order.completed_count = completed_count
    dirty = true
  end

  return dirty
end

local function get_track_status(bp, level, track, current_level)
  local reward_def = get_reward_def(level, track)
  if not reward_def then
    return 'empty'
  end

  local claimed_map = get_track_claim_map(bp, track)
  if claimed_map and claimed_map[tostring(level)] == true then
    return 'claimed'
  end

  if track == TRACK_PAID and bp.paid_unlocked ~= true then
    return 'premium_locked'
  end

  if level <= current_level then
    return 'claimable'
  end

  return 'locked'
end

local function get_status_label(status)
  if status == 'claimed' then
    return '已领'
  end
  if status == 'claimable' then
    return '可领'
  end
  if status == 'premium_locked' then
    return '未开'
  end
  if status == 'empty' then
    return '--'
  end
  return '未达'
end

local function get_cell_color(free_status, paid_status)
  if free_status == 'claimable' or paid_status == 'claimable' then
    return { 255, 220, 122, 255 }
  end
  if free_status == 'claimed' and (paid_status == 'claimed' or paid_status == 'empty' or paid_status == 'premium_locked') then
    return { 116, 212, 156, 255 }
  end
  if paid_status == 'premium_locked' and free_status ~= 'locked' then
    return { 132, 176, 255, 255 }
  end
  if free_status == 'locked' and (paid_status == 'locked' or paid_status == 'premium_locked' or paid_status == 'empty') then
    return { 150, 146, 133, 255 }
  end
  return { 230, 211, 152, 255 }
end

local function count_claimable(bp, current_level)
  local free_count = 0
  local paid_count = 0
  for level = 1, MAX_LEVEL do
    if get_track_status(bp, level, TRACK_FREE, current_level) == 'claimable' then
      free_count = free_count + 1
    end
    if get_track_status(bp, level, TRACK_PAID, current_level) == 'claimable' then
      paid_count = paid_count + 1
    end
  end
  return free_count, paid_count
end

local function append_attack_skill_id(result, seen, skill_id)
  local value_type = type(skill_id)
  if value_type ~= 'string' and value_type ~= 'number' then
    return
  end

  local normalized = tostring(skill_id)
  if normalized == '' or seen[normalized] == true then
    return
  end

  seen[normalized] = true
  result[#result + 1] = normalized
end

local function collect_reward_attack_skill_ids(result, seen, reward_def)
  if type(reward_def) ~= 'table' then
    return
  end

  append_attack_skill_id(result, seen, reward_def.attack_skill_id)
  if type(reward_def.attack_skill_ids) ~= 'table' then
    return
  end

  for _, skill_id in ipairs(reward_def.attack_skill_ids) do
    append_attack_skill_id(result, seen, skill_id)
  end
end

function M.ensure_profile_defaults(profile)
  if type(profile) ~= 'table' then
    return false
  end

  local dirty = false
  if type(profile.battle_pass) ~= 'table' then
    profile.battle_pass = create_default_bp()
    dirty = true
  end

  local bp = profile.battle_pass
  if bp.season_id ~= PASS_DEFS.season_id then
    profile.battle_pass = create_default_bp()
    return true
  end

  local exp = clamp_nonnegative_int(bp.exp)
  if exp > MAX_TOTAL_EXP then
    exp = MAX_TOTAL_EXP
  end
  if bp.exp ~= exp then
    bp.exp = exp
    dirty = true
  end

  if bp.paid_unlocked ~= true and bp.paid_unlocked ~= false then
    bp.paid_unlocked = false
    dirty = true
  end

  local claimed_free, free_dirty = copy_claim_map(bp.claimed_free)
  if free_dirty or not same_boolean_map(claimed_free, bp.claimed_free) then
    bp.claimed_free = claimed_free
    dirty = true
  end

  local claimed_paid, paid_dirty = copy_claim_map(bp.claimed_paid)
  if paid_dirty or not same_boolean_map(claimed_paid, bp.claimed_paid) then
    bp.claimed_paid = claimed_paid
    dirty = true
  end

  if ensure_wallet_defaults(bp) then
    dirty = true
  end

  if ensure_login_reward_defaults(bp) then
    dirty = true
  end

  if ensure_military_order_defaults(bp) then
    dirty = true
  end

  return dirty
end

function M.get_defs()
  return PASS_DEFS
end

function M.get_progress(profile)
  M.ensure_profile_defaults(profile)
  local bp = get_bp(profile) or {}
  local exp = clamp_nonnegative_int(bp.exp)
  local current_level = get_current_level_by_exp(exp)
  local reached_max = current_level >= MAX_LEVEL and exp >= MAX_TOTAL_EXP
  local exp_in_level = reached_max and PASS_DEFS.level_exp or (exp % PASS_DEFS.level_exp)
  local exp_to_next = reached_max and 0 or math.max(0, PASS_DEFS.level_exp - exp_in_level)
  local free_claimable_count, paid_claimable_count = count_claimable(bp, current_level)

  return {
    current_level = current_level,
    max_level = MAX_LEVEL,
    total_exp = exp,
    total_exp_max = MAX_TOTAL_EXP,
    exp_in_level = exp_in_level,
    exp_to_next = exp_to_next,
    level_exp = PASS_DEFS.level_exp,
    reached_max = reached_max,
    paid_unlocked = bp.paid_unlocked == true,
    free_claimable_count = free_claimable_count,
    paid_claimable_count = paid_claimable_count,
    claimable_count = free_claimable_count + paid_claimable_count,
  }
end

function M.get_claimable_count(profile)
  return M.get_progress(profile).claimable_count
end

function M.set_paid_unlocked(profile, unlocked)
  M.ensure_profile_defaults(profile)
  local bp = get_bp(profile)
  local normalized = unlocked == true
  if bp.paid_unlocked == normalized then
    return false
  end
  bp.paid_unlocked = normalized
  return true
end

function M.reset_claims(profile)
  M.ensure_profile_defaults(profile)
  local bp = get_bp(profile)
  local cleared = 0
  for _ in pairs(bp.claimed_free or {}) do
    cleared = cleared + 1
  end
  for _ in pairs(bp.claimed_paid or {}) do
    cleared = cleared + 1
  end
  bp.claimed_free = {}
  bp.claimed_paid = {}
  return cleared
end

function M.add_exp(profile, amount, reason)
  M.ensure_profile_defaults(profile)
  local bp = get_bp(profile)
  local before = M.get_progress(profile)
  local added = clamp_nonnegative_int(amount)
  if added <= 0 or before.reached_max then
    return {
      reason = reason,
      added_exp = 0,
      before_level = before.current_level,
      after_level = before.current_level,
      current_level = before.current_level,
      claimable_count = before.claimable_count,
      remaining_to_next = before.exp_to_next,
      reached_max = before.reached_max,
    }
  end

  local next_exp = bp.exp + added
  if next_exp > MAX_TOTAL_EXP then
    next_exp = MAX_TOTAL_EXP
  end
  local actual_add = next_exp - bp.exp
  bp.exp = next_exp

  local after = M.get_progress(profile)
  return {
    reason = reason,
    added_exp = actual_add,
    before_level = before.current_level,
    after_level = after.current_level,
    current_level = after.current_level,
    level_up_count = math.max(0, after.current_level - before.current_level),
    claimable_count = after.claimable_count,
    remaining_to_next = after.exp_to_next,
    reached_max = after.reached_max,
  }
end

function M.build_battle_result_exp(result)
  local reached_wave = math.max(0, clamp_nonnegative_int(result and result.reached_wave_index or 0))
  local rules = PASS_DEFS.battle_result_exp
  local base = result and result.is_win and rules.win_base or rules.loss_base
  local wave_bonus = reached_wave * rules.per_wave
  local clear_bonus = result and result.is_win and rules.clear_bonus or 0
  return math.max(0, base + wave_bonus + clear_bonus)
end

function M.apply_battle_result(profile, result)
  if type(result) ~= 'table' then
    return nil
  end
  local exp = M.build_battle_result_exp(result)
  local summary = M.add_exp(profile, exp, 'battle_result')
  local bp = get_bp(profile)
  local wallet = get_wallet(bp) or {}
  local military_order = get_military_order(bp) or {}
  summary.stage_id = result.stage_id
  summary.mode_id = result.mode_id
  summary.is_win = result.is_win == true
  summary.reached_wave_index = clamp_nonnegative_int(result.reached_wave_index)
  summary.skill_fragments_gained = 0
  summary.achievement_points_gained = 0
  summary.military_order_consumed = false
  summary.military_order_bonus_exp = 0
  summary.military_order_charges_left = military_order.charges or 0

  if summary.is_win and (military_order.charges or 0) > 0 then
    military_order.charges = math.max(0, (military_order.charges or 0) - 1)
    military_order.completed_count = clamp_nonnegative_int(military_order.completed_count) + 1

    add_attr_pack(wallet, {
      skill_fragments = MILITARY_ORDER_REWARD.skill_fragments,
      achievement_points = MILITARY_ORDER_REWARD.achievement_points,
    })

    local order_summary = M.add_exp(profile, MILITARY_ORDER_REWARD.exp, 'military_order')
    summary.added_exp = (summary.added_exp or 0) + (order_summary.added_exp or 0)
    summary.after_level = order_summary.after_level or summary.after_level
    summary.current_level = order_summary.current_level or summary.current_level
    summary.level_up_count = (summary.level_up_count or 0) + (order_summary.level_up_count or 0)
    summary.claimable_count = order_summary.claimable_count or summary.claimable_count
    summary.remaining_to_next = order_summary.remaining_to_next or summary.remaining_to_next
    summary.reached_max = order_summary.reached_max == true or summary.reached_max == true
    summary.skill_fragments_gained = MILITARY_ORDER_REWARD.skill_fragments
    summary.achievement_points_gained = MILITARY_ORDER_REWARD.achievement_points
    summary.military_order_consumed = true
    summary.military_order_bonus_exp = order_summary.added_exp or 0
    summary.military_order_charges_left = military_order.charges
  end
  return summary
end

function M.refresh_daily_state(profile)
  M.ensure_profile_defaults(profile)

  local bp = get_bp(profile)
  local wallet = get_wallet(bp) or {}
  local login_reward = get_login_reward(bp) or {}
  local military_order = get_military_order(bp) or {}
  local day = get_day_context()

  local summary = {
    dirty = false,
    day_key = day.day_key,
    day_serial = day.day_serial,
    login_claimed = false,
    login_total_days = login_reward.total_claim_days or 0,
    military_orders_added = 0,
    charges_now = military_order.charges or 0,
    wallet_gained = {},
  }

  if login_reward.last_claim_day_serial ~= day.day_serial or login_reward.last_claim_day_key ~= day.day_key then
    login_reward.last_claim_day_serial = day.day_serial
    login_reward.last_claim_day_key = day.day_key
    login_reward.total_claim_days = clamp_nonnegative_int(login_reward.total_claim_days) + 1
    add_attr_pack(wallet, DAILY_LOGIN_REWARD)
    add_attr_pack(summary.wallet_gained, DAILY_LOGIN_REWARD)
    summary.login_claimed = true
    summary.login_total_days = login_reward.total_claim_days
    summary.dirty = true
  end

  local added_orders = 0
  if military_order.last_refresh_day_serial == nil or military_order.last_refresh_day_serial < 0 then
    added_orders = math.min(MAX_MILITARY_ORDER_CHARGES - (military_order.charges or 0), 1)
  elseif day.day_serial > military_order.last_refresh_day_serial then
    added_orders = math.min(
      MAX_MILITARY_ORDER_CHARGES - (military_order.charges or 0),
      day.day_serial - military_order.last_refresh_day_serial
    )
  end

  if added_orders > 0 then
    military_order.charges = (military_order.charges or 0) + added_orders
    summary.military_orders_added = added_orders
    summary.dirty = true
  end
  if military_order.last_refresh_day_serial ~= day.day_serial then
    military_order.last_refresh_day_serial = day.day_serial
    summary.dirty = true
  end

  summary.charges_now = military_order.charges or 0
  return summary
end

function M.build_daily_refresh_message(summary)
  if not summary then
    return nil
  end

  local fragments = {}
  if summary.login_claimed then
    local reward_label = build_currency_gain_label(summary.wallet_gained or {})
    if reward_label ~= '' then
      fragments[#fragments + 1] = string.format('今日登录奖励已发放：%s。', reward_label)
    else
      fragments[#fragments + 1] = '今日登录奖励已发放。'
    end
  end
  if (summary.military_orders_added or 0) > 0 then
    fragments[#fragments + 1] = string.format(
      '军令状补充 %d 张，当前 %d/%d。',
      summary.military_orders_added,
      summary.charges_now or 0,
      MAX_MILITARY_ORDER_CHARGES
    )
  end

  if #fragments == 0 then
    return nil
  end
  return table.concat(fragments, ' ')
end

function M.claim_available(profile)
  M.ensure_profile_defaults(profile)
  local bp = get_bp(profile)
  local progress = M.get_progress(profile)
  local claimed_entries = {}

  for level = 1, progress.current_level do
    local free_def = get_reward_def(level, TRACK_FREE)
    if free_def and bp.claimed_free[tostring(level)] ~= true then
      bp.claimed_free[tostring(level)] = true
      claimed_entries[#claimed_entries + 1] = {
        level = level,
        track = TRACK_FREE,
        label = build_track_summary(level, TRACK_FREE, false),
      }
    end

    local paid_def = get_reward_def(level, TRACK_PAID)
    if bp.paid_unlocked == true and paid_def and bp.claimed_paid[tostring(level)] ~= true then
      bp.claimed_paid[tostring(level)] = true
      claimed_entries[#claimed_entries + 1] = {
        level = level,
        track = TRACK_PAID,
        label = build_track_summary(level, TRACK_PAID, false),
      }
    end
  end

  return {
    claimed_count = #claimed_entries,
    claimed_entries = claimed_entries,
    claimable_count_after = M.get_claimable_count(profile),
  }
end

function M.collect_claimed_bonus_stats(profile)
  M.ensure_profile_defaults(profile)
  local bp = get_bp(profile) or {}
  local result = {}

  for level = 1, MAX_LEVEL do
    local key = tostring(level)
    local free_def = get_reward_def(level, TRACK_FREE)
    if bp.claimed_free and bp.claimed_free[key] == true and free_def and free_def.attr then
      add_attr_pack(result, free_def.attr)
    end

    local paid_def = get_reward_def(level, TRACK_PAID)
    if bp.paid_unlocked == true and bp.claimed_paid and bp.claimed_paid[key] == true and paid_def and paid_def.attr then
      add_attr_pack(result, paid_def.attr)
    end
  end

  return result
end

function M.collect_owned_attack_skill_ids(profile)
  M.ensure_profile_defaults(profile)
  local bp = get_bp(profile) or {}
  local result = {}
  local seen = {}

  if type(bp.owned_attack_skill_ids) == 'table' then
    for _, skill_id in ipairs(bp.owned_attack_skill_ids) do
      append_attack_skill_id(result, seen, skill_id)
    end
  end

  for level = 1, MAX_LEVEL do
    local key = tostring(level)
    if bp.claimed_free and bp.claimed_free[key] == true then
      collect_reward_attack_skill_ids(result, seen, get_reward_def(level, TRACK_FREE))
    end

    if bp.paid_unlocked == true and bp.claimed_paid and bp.claimed_paid[key] == true then
      collect_reward_attack_skill_ids(result, seen, get_reward_def(level, TRACK_PAID))
    end
  end

  return result
end

function M.build_gain_message(summary)
  if not summary then
    return '征战之路已满级，当前不再获得额外经验。'
  end

  local text
  if (summary.added_exp or 0) <= 0 then
    text = '征战之路已满级，当前不再获得额外经验。'
  else
    text = string.format('征战之路经验 +%d，当前 Lv.%d', summary.added_exp, summary.current_level or 1)
    if (summary.level_up_count or 0) > 0 then
      text = string.format('%s，提升了 %d 级', text, summary.level_up_count)
    end
    if summary.reached_max then
      text = text .. '，已达到满级。'
    elseif (summary.claimable_count or 0) > 0 then
      text = string.format('%s，可领取 %d 项奖励。', text, summary.claimable_count)
    else
      text = string.format('%s，距离下一级还差 %d 经验。', text, summary.remaining_to_next or 0)
    end
  end

  local extras = {}
  if summary.military_order_consumed then
    extras[#extras + 1] = string.format(
      '军令状已完成，剩余 %d/%d。',
      summary.military_order_charges_left or 0,
      MAX_MILITARY_ORDER_CHARGES
    )
  end
  local currency_label = build_currency_gain_label({
    skill_fragments = summary.skill_fragments_gained,
    achievement_points = summary.achievement_points_gained,
  })
  if currency_label ~= '' then
    extras[#extras + 1] = string.format('额外获得 %s。', currency_label)
  end
  if #extras > 0 then
    text = string.format('%s %s', text, table.concat(extras, ' '))
  end

  return text
end

function M.build_claim_message(summary)
  if not summary or (summary.claimed_count or 0) <= 0 then
    return '当前暂无可领取的征战之路奖励。'
  end

  if summary.claimed_count <= 3 then
    local labels = {}
    for _, entry in ipairs(summary.claimed_entries or {}) do
      local track_label = entry.track == TRACK_PAID and '付费' or '免费'
      labels[#labels + 1] = string.format('Lv.%02d %s', entry.level, track_label)
    end
    return string.format('已领取 %d 项征战之路奖励：%s。', summary.claimed_count, table.concat(labels, '、'))
  end

  return string.format('已领取 %d 项征战之路奖励，永久成长已生效。', summary.claimed_count)
end

function M.build_ui_model(profile)
  M.ensure_profile_defaults(profile)
  local bp = get_bp(profile) or {}
  local wallet = get_wallet(bp) or {}
  local login_reward = get_login_reward(bp) or {}
  local military_order = get_military_order(bp) or {}
  local progress = M.get_progress(profile)
  local level_items = {}
  local day = get_day_context()

  for level = 1, MAX_LEVEL do
    local free_status = get_track_status(bp, level, TRACK_FREE, progress.current_level)
    local paid_status = get_track_status(bp, level, TRACK_PAID, progress.current_level)
    local free_short_label = build_track_summary(level, TRACK_FREE, true)
    local paid_short_label = build_track_summary(level, TRACK_PAID, true)
    level_items[#level_items + 1] = {
      level = level,
      free_status = free_status,
      paid_status = paid_status,
      free_short_label = free_short_label,
      paid_short_label = paid_short_label,
      free_label = build_track_summary(level, TRACK_FREE, false),
      paid_label = build_track_summary(level, TRACK_PAID, false),
      cell_text = string.format(
        'Lv.%02d\n免 %s %s\n付 %s %s',
        level,
        free_short_label,
        get_status_label(free_status),
        paid_short_label,
        get_status_label(paid_status)
      ),
      cell_color = get_cell_color(free_status, paid_status),
    }
  end

  local premium_status = progress.paid_unlocked and '已激活' or '未激活'
  local login_claimed_today = login_reward.last_claim_day_key == day.day_key
  local claimed_reward_count = count_true_entries(bp.claimed_free) + count_true_entries(bp.claimed_paid)
  local tips = string.format(
    'Lv.%d/%d，免费可领 %d，付费可领 %d。\n常规战斗加经验，激活「%s」后可同步领付费轨道。',
    progress.current_level,
    progress.max_level,
    progress.free_claimable_count,
    progress.paid_claimable_count,
    PASS_DEFS.premium_name
  )

  return {
    season_name = PASS_DEFS.season_name,
    premium_name = PASS_DEFS.premium_name,
    premium_status = premium_status,
    paid_unlocked = progress.paid_unlocked,
    current_level = progress.current_level,
    max_level = progress.max_level,
    total_exp = progress.total_exp,
    total_exp_max = progress.total_exp_max,
    exp_to_next = progress.exp_to_next,
    reached_max = progress.reached_max,
    claimable_count = progress.claimable_count,
    free_claimable_count = progress.free_claimable_count,
    paid_claimable_count = progress.paid_claimable_count,
    claim_button_text = progress.claimable_count > 0
      and string.format('一键领取(%d)', progress.claimable_count)
      or '暂无可领',
    level_items = level_items,
    tips = tips,
    military_order_title = '军令状',
    military_order_subtitle = string.format(
      '军令 %d/%d · 至尊 %s',
      military_order.charges or 0,
      MAX_MILITARY_ORDER_CHARGES,
      premium_status
    ),
    military_order_summary = string.format(
      '每日补 1 张，最多 %d 张；胜利消耗 1 张并额外经验+%d。\n累计完成 %d 张，额外奖励：%s。',
      MAX_MILITARY_ORDER_CHARGES,
      MILITARY_ORDER_REWARD.exp,
      military_order.completed_count or 0,
      build_currency_gain_label(MILITARY_ORDER_REWARD)
    ),
    login_reward_summary = string.format(
      '%s · 累登 %d 天 · 碎片+%d 成就+%d',
      login_claimed_today and '今日已领' or '今日待领',
      login_reward.total_claim_days or 0,
      DAILY_LOGIN_REWARD.skill_fragments or 0,
      DAILY_LOGIN_REWARD.achievement_points or 0
    ),
    save_counter_text = string.format(
      '碎片 %d | 成就 %d | 军令 %d/%d | 切页',
      wallet.skill_fragments or 0,
      wallet.achievement_points or 0,
      military_order.charges or 0,
      MAX_MILITARY_ORDER_CHARGES
    ),
    skill_fragments = wallet.skill_fragments or 0,
    achievement_points = wallet.achievement_points or 0,
    armory_title = '武库',
    armory_subtitle = string.format(
      '已领 %d 项成长，累计登录 %d 天。',
      claimed_reward_count,
      login_reward.total_claim_days or 0
    ),
    shop_title = '灵魂洪炉',
    shop_subtitle = string.format(
      '技能碎片 %d，可用于后续兑换。',
      wallet.skill_fragments or 0
    ),
    achievement_title = '功成名就',
    achievement_subtitle = string.format(
      '成就 %d，登录 %d 天，军令 %d。',
      wallet.achievement_points or 0,
      login_reward.total_claim_days or 0,
      military_order.completed_count or 0
    ),
  }
end

return M

package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local battle_pass = require 'runtime.battle_pass'

local profile = {}
assert(battle_pass.ensure_profile_defaults(profile) == true, 'expected battle pass defaults to initialize')
assert(profile.battle_pass.season_id == 'season_1', 'expected season id default')
assert(profile.battle_pass.exp == 0, 'expected zero initial exp')
assert(battle_pass.get_progress(profile).current_level == 1, 'expected level 1 at zero exp')
assert(battle_pass.get_claimable_count(profile) == 1, 'expected initial free reward to be claimable')

local gain = battle_pass.apply_battle_result(profile, {
  is_win = true,
  reached_wave_index = 5,
})
assert(gain.added_exp == 415, 'expected battle result exp formula to match 180+5*35+60')
assert(gain.current_level == 2, 'expected 415 exp to reach level 2')
assert(battle_pass.get_claimable_count(profile) == 2, 'expected two free rewards to be claimable after level up')

local first_claim = battle_pass.claim_available(profile)
assert(first_claim.claimed_count == 2, 'expected free track level 1 and 2 to be claimed')
local free_bonus = battle_pass.collect_claimed_bonus_stats(profile)
assert(free_bonus['攻击白字'] == 4, 'expected claimed free attack bonus')
assert(free_bonus['生命白字'] == 120, 'expected claimed free hp bonus')

assert(battle_pass.set_paid_unlocked(profile, true) == true, 'expected paid track toggle to change state')
local second_claim = battle_pass.claim_available(profile)
assert(second_claim.claimed_count == 2, 'expected paid level 1 and 2 rewards to be claimable after unlock')
local total_bonus = battle_pass.collect_claimed_bonus_stats(profile)
assert(total_bonus['生命白字'] == 200, 'expected paid hp bonus to merge')
assert(total_bonus['攻击范围'] == 60, 'expected paid range bonus to merge')

local reset_count = battle_pass.reset_claims(profile)
assert(reset_count == 4, 'expected reset to clear all claimed records')
assert(next(battle_pass.collect_claimed_bonus_stats(profile)) == nil, 'expected claimed bonus stats to clear after reset')
assert(type(battle_pass.collect_owned_attack_skill_ids(profile)) == 'table', 'expected owned attack skills API to return a table')
assert(#battle_pass.collect_owned_attack_skill_ids(profile) == 0, 'expected default battle pass to own no attack skills yet')

profile.battle_pass.owned_attack_skill_ids = { 'sword_wave', 'sword_wave', false, 'chain_ball' }
local owned_skill_ids = battle_pass.collect_owned_attack_skill_ids(profile)
assert(#owned_skill_ids == 2, 'expected owned attack skill ids to dedupe invalid entries')
assert(owned_skill_ids[1] == 'sword_wave', 'expected first owned attack skill id to be preserved')
assert(owned_skill_ids[2] == 'chain_ball', 'expected second owned attack skill id to be preserved')

local daily_refresh = battle_pass.refresh_daily_state(profile)
assert(daily_refresh.login_claimed == true, 'expected first daily refresh to auto grant login reward')
assert(daily_refresh.military_orders_added == 1, 'expected first daily refresh to grant one military order')
assert(profile.battle_pass.wallet.skill_fragments == 12, 'expected daily login reward to add skill fragments')
assert(profile.battle_pass.wallet.achievement_points == 6, 'expected daily login reward to add achievement points')

local order_gain = battle_pass.apply_battle_result(profile, {
  is_win = true,
  reached_wave_index = 0,
})
assert(order_gain.military_order_consumed == true, 'expected win to consume one military order when available')
assert(order_gain.skill_fragments_gained == 18, 'expected military order to grant bonus skill fragments')
assert(order_gain.achievement_points_gained == 10, 'expected military order to grant bonus achievement points')
assert(profile.battle_pass.military_order.charges == 0, 'expected military order charge to be consumed')
assert(profile.battle_pass.wallet.skill_fragments == 30, 'expected wallet fragments to include login and military order rewards')
assert(profile.battle_pass.wallet.achievement_points == 16, 'expected wallet achievement points to include login and military order rewards')

print('[OK] battle pass runtime smoke passed')

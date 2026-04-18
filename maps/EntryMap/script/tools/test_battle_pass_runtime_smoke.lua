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

print('[OK] battle pass runtime smoke passed')

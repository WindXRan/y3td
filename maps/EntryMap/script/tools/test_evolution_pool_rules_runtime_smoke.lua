package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local RewardSystem = require 'runtime.rewards'

math.randomseed(12345)

local state = {
  mark_runtime = nil,
  treasure_runtime = nil,
}

local api = RewardSystem.create({
  STATE = state,
  message = function() end,
  round_number = function() return 1 end,
  add_attr_pack = function() end,
  hero_attr_system = {
    add_bonus_attrs = function() end,
    remove_bonus_attrs = function() end,
  },
  sync_basic_attack_ability = function() end,
  heal_hero = function() end,
  collect_bond_route_tags = function() return {} end,
})

local runtime = api.create_mark_runtime()
state.mark_runtime = runtime

local picks = api.debug_pick_mark_choices_for_rule('mark_pool_global', 3)
assert(#picks == 3, 'should return 3 evolution picks')

local ids = {}
local has_high_quality = false
for _, def in ipairs(picks) do
  assert(ids[def.id] == nil, 'same round should not repeat picks')
  ids[def.id] = true
  if def.quality == 'rare' or def.quality == 'epic' then
    has_high_quality = true
  end
end
assert(has_high_quality, 'global rule should guarantee at least one rare or epic pick')

runtime.owned_mark_ids[picks[1].id] = true
local next_picks = api.debug_pick_mark_choices_for_rule('mark_pool_global', 3)
for _, def in ipairs(next_picks) do
  assert(def.id ~= picks[1].id, 'owned evolutions should be excluded')
end

for _, def in pairs(api.MARK_DEFS) do
  if def.quality == 'rare' or def.quality == 'epic' then
    runtime.owned_mark_ids[def.id] = true
  end
end

local fallback_picks = api.debug_pick_mark_choices_for_rule('mark_pool_global', 3)
assert(#fallback_picks == 3, 'fallback picks should still return 3 evolutions when only commons remain')
for _, def in ipairs(fallback_picks) do
  assert(def.quality == 'common', 'fallback picks should use remaining common evolutions when high-quality pool is empty')
end

print('evolution pool rules runtime smoke ok')

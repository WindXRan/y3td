package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local RewardSystem = require 'runtime.progression.rewards'

math.randomseed(12345)

local state = {
  evolution_runtime = nil,
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

local runtime = api.create_evolution_runtime()
state.evolution_runtime = runtime

local picks = api.debug_pick_evolution_choices_for_rule('evolution_pool_global', 2)
assert(#picks == 2, 'should return 2 evolution picks')

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

runtime.owned_evolution_ids[picks[1].id] = true
local next_picks = api.debug_pick_evolution_choices_for_rule('evolution_pool_global', 2)
for _, def in ipairs(next_picks) do
  assert(def.id ~= picks[1].id, 'owned evolutions should be excluded')
end

for _, def in pairs(api.EVOLUTION_DEFS) do
  if def.quality == 'rare' or def.quality == 'epic' then
    runtime.owned_evolution_ids[def.id] = true
  end
end

local fallback_picks = api.debug_pick_evolution_choices_for_rule('evolution_pool_global', 2)
assert(#fallback_picks == 2, 'fallback picks should still return 2 evolutions when only commons remain')
for _, def in ipairs(fallback_picks) do
  assert(def.quality == 'common', 'fallback picks should use remaining common evolutions when high-quality pool is empty')
end

print('evolution pool rules runtime smoke ok')

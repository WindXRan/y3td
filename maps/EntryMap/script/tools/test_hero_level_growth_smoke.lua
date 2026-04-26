package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local Progression = require 'runtime.progression'

local state = {}
local added = {}
local rebuild_count = 0
local hp_added = 0

local hero = {
  level = 1,
}

function hero:is_exist()
  return true
end

function hero:set_level(level)
  self.level = level
end

function hero:get_level()
  return self.level
end

function hero:set_exp(exp)
  self.exp = exp
end

function hero:set_ability_point(value)
  self.ability_point = value
end

function hero:add_hp(value)
  hp_added = hp_added + value
end

state.hero = hero

local system = Progression.create({
  STATE = state,
  CONFIG = {
    hero_progression = {
      max_level = 60,
      engine_exp_cap_level = 1,
      hero_level_attack_growth = 6,
      hero_level_hp_growth = 60,
      hero_level_all_attr_growth = 2,
    },
    hero_level_progression = {
      max_level = 60,
      by_level = {
        [1] = { exp_to_next = 75 },
        [2] = { exp_to_next = 85 },
      },
    },
  },
  y3 = {},
  round_number = function(value)
    return math.floor((tonumber(value) or 0) + 0.5)
  end,
  message = function() end,
  hero_attr_system = {
    add_attr = function(_, attr_name, value)
      added[attr_name] = (added[attr_name] or 0) + value
    end,
    rebuild_derived_attrs = function()
      rebuild_count = rebuild_count + 1
    end,
  },
})

system.initialize_hero_progression()
system.grant_hero_exp(75)

assert(state.hero_progress.level == 2, 'hero should level to 2')
assert(state.hero_progress.applied_growth_level == 2, 'growth should be applied through level 2')
assert(added['攻击'] == 6, 'level growth should add 6 attack')
assert(added['生命'] == 60, 'level growth should add 60 hp')
assert(added['力量'] == 2, 'level growth should add 2 strength')
assert(added['敏捷'] == 2, 'level growth should add 2 agility')
assert(added['智力'] == 2, 'level growth should add 2 intelligence')
assert(hp_added == 60, 'current hp should increase by hp growth')
assert(rebuild_count == 1, 'derived attrs should rebuild once')

print('[OK] hero level growth smoke passed')

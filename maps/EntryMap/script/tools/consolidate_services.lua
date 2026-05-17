-- Consolidate bare globals: add RuntimeEntry._services dual assignments
-- Run from maps/EntryMap/script/

local file = io.open('runtime/boot.lua', 'r')
local content = file:read('*a')
file:close()

local count = 0

local function replace(from, to)
  local n = 0
  content, n = content:gsub(from, to, 1)  -- replace only first occurrence
  count = count + n
  return n
end

-- These are the assignment patterns (not the initial nil declarations)
-- Each has a unique enough context to target the first occurrence safely

-- message function assignment
replace('\nmessage = function%(text%)',
  '\nmessage = function(text); RuntimeEntry._services.message = message')

-- progression_system assignment
local n = content:gsub('(\nprogression_system = ProgressionSystem%.create%(%b{}%))',
  '%1; RuntimeEntry._services.progression_system = progression_system', 1)
count = count + (n > 0 and 1 or 0)

-- attr_choice_system assignment
n = content:gsub('(\nattr_choice_system = AttrChoices%.create%(%b{}%))',
  '%1; RuntimeEntry._services.attr_choice_system = attr_choice_system', 1)
count = count + (n > 0 and 1 or 0)

-- reward_system assignment
n = content:gsub('(\nreward_system = RewardSystem%.create%(%b{}%))',
  '%1; RuntimeEntry._services.reward_system = reward_system', 1)
count = count + (n > 0 and 1 or 0)

-- get_enemies_in_range function
replace('\nget_enemies_in_range = function%(center, radius, except_unit, max_count%)',
  '\nget_enemies_in_range = function(center, radius, except_unit, max_count); RuntimeEntry._services.get_enemies_in_range = get_enemies_in_range')

-- deal_skill_damage function
replace('\ndeal_skill_damage = function%(target, amount, damage, visual%)',
  '\ndeal_skill_damage = function(target, amount, damage, visual); RuntimeEntry._services.deal_skill_damage = deal_skill_damage')

-- skill_framework_system assignment
n = content:gsub('(\nskill_framework_system = SkillFrameworkSystem%.create%(%b{}%))',
  '%1; RuntimeEntry._services.skill_framework_system = skill_framework_system', 1)
count = count + (n > 0 and 1 or 0)

-- sample_skills_system assignment
n = content:gsub('(\nsample_skills_system = SampleSkillsSystem%.create%(%b{}%))',
  '%1; RuntimeEntry._services.sample_skills_system = sample_skills_system', 1)
count = count + (n > 0 and 1 or 0)

-- heal_hero function
replace('\nheal_hero = function%(amount%)',
  '\nheal_hero = function(amount); RuntimeEntry._services.heal_hero = heal_hero')

-- battlefield_system assignment
n = content:gsub('(\nbattlefield_system = BattlefieldSystem%.create%(%b{}%))',
  '%1; RuntimeEntry._services.battlefield_system = battlefield_system', 1)
count = count + (n > 0 and 1 or 0)


-- These may be assigned differently, let's check
-- debug_tools_system, debug_actions_system, gm_bond_effects_system
-- runtime_hud_system, outgame_system, audio_system
-- hero_selection_range_system

file = io.open('runtime/boot.lua', 'w')
file:write(content)
file:close()
print(string.format('Done! %d service assignments updated.', count))

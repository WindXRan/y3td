local M = {}
local y3 = y3
local CONFIG = require 'config.entry_config'
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers

local STATE = _G.STATE or {}

-- Build synthetic env for sub-modules that access ctx.env.X
local env = {}
env.get_player = y3.player.get_main_player
env.get_enemy_player = _G.get_enemy_player or BootHelpers.get_enemy_player
env.award_rewards = _G.award_rewards or function() end

local message = _G.message or function() end
local design_seconds = BootHelpers.design_seconds
local random_point_in_area = _G.AreaUtils and _G.AreaUtils.random_point_in_area or function(area_id) return (STATE.defense_point) end
local hero_attr_system = _G.hero_attr_system or {
  init_hero_attrs = function() end,
  set_attr = function() end,
  add_attr = function() end,
  get_attr = function() return 0 end,
  rebuild_derived_attrs = function() end,
  log_snapshot = function() end,
}
local hero_model = _G.hero_model or {
  apply_hero_model = function() return false end,
  resolve_model_id = function() return nil end,
  apply_evolution_model = function() return false end,
}
local play_enemy_death_sound = _G.play_enemy_death_sound or function() end

local api = {}
local VISUAL_ANIMATION_SPEED = 0.5
local HERO_RUNTIME_FALLBACK_UNIT_ID = tonumber(CONFIG.hero_fallback_unit_id) or 134245850
local ENEMY_RUNTIME_FALLBACK_UNIT_ID = tonumber(CONFIG.fixed_enemy_spawn_unit_id) or 134278989
local ENEMY_BASE_SPEED_FACTORS = {
  main = 0.76,
  boss = 0.82,
}

local ctx = {
  STATE = STATE, CONFIG = CONFIG, y3 = y3, message = message, env = env, api = api,
  design_seconds = design_seconds, random_point_in_area = random_point_in_area,
  hero_attr_system = hero_attr_system, hero_model = hero_model,
  set_attr_pack = (_G.AttrUtils and _G.AttrUtils.set_attr_pack) or function() end,
  add_attr_pack = (_G.AttrUtils and _G.AttrUtils.add_attr_pack) or function() end,
  play_enemy_death_sound = play_enemy_death_sound,
  heal_hero = _G.heal_hero,
  resource_system = require('runtime.resources.resource_system').create(),
  VISUAL_ANIMATION_SPEED = VISUAL_ANIMATION_SPEED,
  HERO_RUNTIME_FALLBACK_UNIT_ID = HERO_RUNTIME_FALLBACK_UNIT_ID,
  ENEMY_RUNTIME_FALLBACK_UNIT_ID = ENEMY_RUNTIME_FALLBACK_UNIT_ID,
  ENEMY_BASE_SPEED_FACTORS = ENEMY_BASE_SPEED_FACTORS,
}

require('runtime.combat.battlefield.utils')(ctx)
require('runtime.combat.battlefield.reactions')(ctx)
require('runtime.combat.battlefield.spawning')(ctx)
require('runtime.combat.battlefield.apis')(ctx)

api.has_unit_data = ctx.has_unit_data
api.is_active_enemy = ctx.is_active_enemy
api.get_enemy_runtime_info = ctx.get_enemy_runtime_info
api.is_boss_runtime_enemy = ctx.is_boss_runtime_enemy
api.is_elite_runtime_enemy = ctx.is_elite_runtime_enemy
api.get_current_wave = ctx.get_current_wave
api.get_boss_name = ctx.get_boss_name

_G.battlefield_system = api
_G.SYSTEM = _G.SYSTEM or {}
_G.SYSTEM.battlefield = api

return api

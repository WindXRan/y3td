local M = {}
local CustomHealthBars = require 'runtime.custom_health_bars'

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local design_seconds = env.design_seconds
  local random_point_in_area = env.random_point_in_area
  local hero_attr_system = env.hero_attr_system
  local hero_model = env.hero_model
  local set_attr_pack = env.set_attr_pack
  local add_attr_pack = env.add_attr_pack
  local play_enemy_death_sound = env.play_enemy_death_sound

  local api = {}
  local VISUAL_ANIMATION_SPEED = 0.5
  local HERO_RUNTIME_FALLBACK_UNIT_ID = tonumber(CONFIG.hero_fallback_unit_id) or 134245850
  local ENEMY_RUNTIME_FALLBACK_UNIT_ID = tonumber(CONFIG.fixed_enemy_spawn_unit_id) or 134278989
  local ENEMY_BASE_SPEED_FACTORS = {
    main = 0.76,
    boss = 0.82,
    challenge = 0.76,
  }

  local ctx = {
    STATE = STATE, CONFIG = CONFIG, y3 = y3, message = message, env = env, api = api,
    design_seconds = design_seconds, random_point_in_area = random_point_in_area,
    hero_attr_system = hero_attr_system, hero_model = hero_model,
    set_attr_pack = set_attr_pack, add_attr_pack = add_attr_pack,
    play_enemy_death_sound = play_enemy_death_sound,
    CustomHealthBars = CustomHealthBars,
    VISUAL_ANIMATION_SPEED = VISUAL_ANIMATION_SPEED,
    HERO_RUNTIME_FALLBACK_UNIT_ID = HERO_RUNTIME_FALLBACK_UNIT_ID,
    ENEMY_RUNTIME_FALLBACK_UNIT_ID = ENEMY_RUNTIME_FALLBACK_UNIT_ID,
    ENEMY_BASE_SPEED_FACTORS = ENEMY_BASE_SPEED_FACTORS,
  }

  require('runtime.battlefield.utils')(ctx)
  require('runtime.battlefield.reactions')(ctx)
  require('runtime.battlefield.spawning')(ctx)
  require('runtime.battlefield.apis')(ctx)

  api.has_unit_data = ctx.has_unit_data
  api.is_active_enemy = ctx.is_active_enemy
  api.get_enemy_runtime_info = ctx.get_enemy_runtime_info
  api.is_boss_runtime_enemy = ctx.is_boss_runtime_enemy
  api.is_elite_runtime_enemy = ctx.is_elite_runtime_enemy
  api.get_current_wave = ctx.get_current_wave
  api.get_boss_name = ctx.get_boss_name
  api.finish_game = ctx.finish_game

  return api
end

return M

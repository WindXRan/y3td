local hero_attr_config = require 'data.object_tables.hero_attr_config'
local hero_level_progression = require 'data.object_tables.hero_level_progression'
local groups = {
  global_rules = {
    debug_time_scale_debug = 0.2,
    debug_time_scale_release = 1.0,
    enemy_player_id = 31,
    enemy_move_speed_scale = 1.0,
    enemy_spawn_batch_scale = 1.5,
    enemy_alive_cap_scale = 1.5,
    player_id = 1,
    total_enemy_soft_cap_scale = 1.5,
    total_enemy_soft_cap = 40,
  },
  flags = {
    debug_apply_hero_bonus_on_spawn = false,
  },
  progression_rules = {
    engine_exp_cap_level = 1,
    max_level = 60,
    post_cap_exp_base = 320,
    post_cap_exp_step = 55,
    hero_level_attack_growth = 6,
    hero_level_hp_growth = 60,
    hero_level_all_attr_growth = 2,
    main_stat_attack_ratio = 0.5,
  },
  resource_rules = {
    gold_per_sec = 2,
    initial_gold = 0,
    initial_wood = 0,
    wood_per_sec = 1,
  },
  challenge_rules = {
    initial_charges = 1,
    max_charges = 3,
    recover_sec = 105,
  },
}
local flags = groups.flags

return {
  global_rules = groups.global_rules or {},
  hero_init_stats = hero_attr_config.hero_init_stats,
  debug_hero_bonus_stats = hero_attr_config.debug_hero_bonus_stats,
  debug_apply_hero_bonus_on_spawn = flags.debug_apply_hero_bonus_on_spawn == true,
  progression_rules = groups.progression_rules or {},
  hero_level_progression = hero_level_progression,
  resource_rules = groups.resource_rules or {},
  challenge_rules = groups.challenge_rules or {},
}

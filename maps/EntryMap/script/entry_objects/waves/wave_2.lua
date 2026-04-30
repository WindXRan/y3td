local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local segment = helpers.segment

return {
      id = 'wave_2',
      index = 2,
      name = 'µÚ2²¨£º¸¯¼×²½±ø',
      main_unit_id = 100007,
      boss_unit_id = 100008,
      spawn_area_id = 'main_spawn_wave_2',
      boss_spawn_area_id = 'boss_spawn_wave_2',
      boss_spawn_sec = scale(240),
      batch_min = 4,
      batch_max = 5,
      max_alive = 14,
      spawn_segments = {
        segment(0, 2.9),
        segment(60, 2.6),
        segment(150, 2.3),
      },
      post_boss_interval_sec = scale(2.3),
      main_kill_reward = { exp = 10, gold = 5, wood = 0 },
      boss_kill_reward = { exp = 100, gold = 75, wood = 14 },
      boss_special = 'ÎÞ',
      theme = 'ÄÍ¾ÃÑ¹³¡',
      boss_timeline_profile_id = 'boss_timeline_wave_2',
      boss_low_hp_profile_id = 'boss_low_hp_wave_2',
    }

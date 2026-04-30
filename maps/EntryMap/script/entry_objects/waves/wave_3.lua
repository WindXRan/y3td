local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local segment = helpers.segment

return {
      id = 'wave_3',
      index = 3,
      name = '第3波：投矛猎手',
      main_unit_id = 100009,
      boss_unit_id = 100010,
      spawn_area_id = 'main_spawn_wave_3',
      boss_spawn_area_id = 'boss_spawn_wave_3',
      boss_spawn_sec = scale(240),
      batch_min = 4,
      batch_max = 5,
      max_alive = 17,
      spawn_segments = {
        segment(0, 2.5),
        segment(60, 2.2),
        segment(150, 2.0),
      },
      post_boss_interval_sec = scale(2.0),
      main_kill_reward = { exp = 12, gold = 6, wood = 1 },
      boss_kill_reward = { exp = 130, gold = 95, wood = 20 },
      boss_special = '无',
      theme = '远程干扰',
      boss_timeline_profile_id = 'boss_timeline_wave_3',
      boss_low_hp_profile_id = 'boss_low_hp_wave_3',
    }

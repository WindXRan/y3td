local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local segment = helpers.segment

return {
      id = 'wave_2',
      index = 2,
      name = '第2波：腐甲步兵',
      main_unit_id = 200010,
      boss_unit_id = 400010,
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
      boss_special = '无',
      theme = '耐久压场',
      boss_timeline_profile_id = 'boss_timeline_wave_2',
      boss_low_hp_profile_id = 'boss_low_hp_wave_2',
    }

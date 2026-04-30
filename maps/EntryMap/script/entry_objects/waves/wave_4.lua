local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local segment = helpers.segment

return {
      id = 'wave_4',
      index = 4,
      name = '第4波：裂爪兽群',
      main_unit_id = 100011,
      boss_unit_id = 100012,
      spawn_area_id = 'main_spawn_wave_4',
      boss_spawn_area_id = 'boss_spawn_wave_4',
      boss_spawn_sec = scale(240),
      batch_min = 5,
      batch_max = 6,
      max_alive = 20,
      spawn_segments = {
        segment(0, 2.2),
        segment(60, 1.95),
        segment(150, 1.75),
      },
      post_boss_interval_sec = scale(1.75),
      main_kill_reward = { exp = 14, gold = 7, wood = 1 },
      boss_kill_reward = { exp = 160, gold = 125, wood = 28 },
      boss_special = '无',
      theme = '高速穿线',
      boss_timeline_profile_id = 'boss_timeline_wave_4',
      boss_low_hp_profile_id = 'boss_low_hp_wave_4',
    }

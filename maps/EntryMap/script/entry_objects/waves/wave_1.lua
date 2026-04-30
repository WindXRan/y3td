local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local segment = helpers.segment

return {
      id = 'wave_1',
      index = 1,
      name = '第1波：饥饿地精',
      main_unit_id = 100005,
      boss_unit_id = 100006,
      spawn_area_id = 'main_spawn_wave_1',
      boss_spawn_area_id = 'boss_spawn_wave_1',
      boss_spawn_sec = scale(240),
      batch_min = 3,
      batch_max = 4,
      max_alive = 10,
      spawn_segments = {
        segment(0, 3.4),
        segment(60, 3.0),
        segment(150, 2.7),
      },
      post_boss_interval_sec = scale(2.7),
      main_attr_overrides = {
        ['最大生命'] = 1,
      },
      main_spawn_hp = 1,
      main_kill_reward = { exp = 8, gold = 4, wood = 0 },
      boss_kill_reward = { exp = 80, gold = 55, wood = 10 },
      boss_special = '无',
      theme = '教学近战',
      boss_timeline_profile_id = 'boss_timeline_wave_1',
      boss_low_hp_profile_id = 'boss_low_hp_wave_1',
    }

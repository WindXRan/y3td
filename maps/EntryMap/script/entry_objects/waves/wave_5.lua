local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local segment = helpers.segment

return {
      id = 'wave_5',
      index = 5,
      name = '第5波：深渊祭仆',
      main_unit_id = 134280101,
      boss_unit_id = 134222661,
      spawn_area_id = 'main_spawn_wave_5',
      boss_spawn_area_id = 'boss_spawn_wave_5',
      boss_spawn_sec = scale(240),
      batch_min = 4,
      batch_max = 5,
      max_alive = 23,
      spawn_segments = {
        segment(0, 1.95),
        segment(60, 1.75),
        segment(150, 1.55),
      },
      post_boss_interval_sec = scale(1.55),
      main_kill_reward = { exp = 16, gold = 8, wood = 2 },
      boss_kill_reward = { exp = 210, gold = 165, wood = 40 },
      boss_special = '胜利结算',
      theme = '终盘高压',
      boss_timeline_profile_id = 'boss_timeline_wave_5',
      boss_low_hp_profile_id = 'boss_low_hp_wave_5',
    }

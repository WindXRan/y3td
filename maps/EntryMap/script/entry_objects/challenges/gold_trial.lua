local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local challenge_batch = helpers.challenge_batch

return {
      id = 'gold_trial',
      name = '金币挑战',
      hotkey = 'Q',
      unlock_rule = { type = 'wave_started', value = 1, text = '第1波开始后解锁' },
      duration_sec = scale(60),
      cost_charge = 1,
      spawn_area_id = 'challenge_spawn_top',
      reward = { gold = 260, wood = 0, exp = 0, special = nil },
      unit_id = 134242543,
      batches = {
        challenge_batch(0, 10),
      },
    }

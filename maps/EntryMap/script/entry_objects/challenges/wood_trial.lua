local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local challenge_batch = helpers.challenge_batch

return {
      id = 'wood_trial',
      name = '木材挑战',
      hotkey = 'W',
      unlock_rule = { type = 'bond_draw_count', value = 1, text = '首次完成1次羁绊抽卡后解锁' },
      duration_sec = scale(60),
      cost_charge = 1,
      spawn_area_id = 'challenge_spawn_bottom',
      reward = { gold = 0, wood = 90, exp = 0, special = nil },
      unit_id = 134224570,
      batches = {
        challenge_batch(0, 8),
      },
    }

local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local challenge_batch = helpers.challenge_batch

return {
  id = 'wood_trial',
  name = '木材挑战',
  hotkey = 'W',
  duration_sec = scale(60),
  cost_charge = 1,
  spawn_area_id = 'challenge_spawn_bottom',
  reward = { gold = 0, wood = 90, exp = 0, special = nil },
  unit_id = 100002,
  batches = {
    challenge_batch(0, 8),
  },
}

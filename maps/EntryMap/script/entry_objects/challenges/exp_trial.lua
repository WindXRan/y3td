local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local challenge_batch = helpers.challenge_batch

return {
  id = 'exp_trial',
  name = 'æ≠—ÈÃÙ’Ω',
  hotkey = 'E',
  duration_sec = scale(60),
  cost_charge = 1,
  spawn_area_id = 'challenge_spawn_mid',
  reward = { gold = 0, wood = 0, exp = 280, special = nil },
  unit_id = 100004,
  batches = {
    challenge_batch(0, 10),
  },
}

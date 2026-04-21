local helpers = require 'entry_objects.config_helpers'
local scale = helpers.scale
local challenge_batch = helpers.challenge_batch

return {
  id = 'treasure_trial',
  name = '宝物挑战',
  hotkey = 'R',
  duration_sec = scale(60),
  cost_charge = 1,
  spawn_area_id = 'challenge_treasure_elite_spawn',
  reward = { gold = 60, wood = 30, exp = 0, special = nil },
  boss_unit_id = 400014,
  guard_unit_id = 200017,
  batches = {
    challenge_batch(0, 5),
  },
}

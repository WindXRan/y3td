local helpers = require 'entry_objects.helpers'

local module_paths = {
  'entry_objects.treasures.hunter_badge',
  'entry_objects.treasures.feather_quiver',
  'entry_objects.treasures.field_bandage',
  'entry_objects.treasures.coin_casket',
  'entry_objects.treasures.echo_codex',
  'entry_objects.treasures.gale_tailfeather',
  'entry_objects.treasures.thunder_pin',
  'entry_objects.treasures.heart_guard_mirror',
  'entry_objects.treasures.harvest_flask',
  'entry_objects.treasures.time_rift_hourglass',
  'entry_objects.treasures.dragonblood_ring',
  'entry_objects.treasures.crown_fragment',
  'entry_objects.treasures.battle_horn',
  'entry_objects.treasures.charged_talisman',
  'entry_objects.treasures.challenge_banner',
  'entry_objects.treasures.emergency_ration',
  'entry_objects.treasures.boss_edict',
}

local list = helpers.load_list(module_paths)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}

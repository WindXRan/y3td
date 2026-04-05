local helpers = require 'entry_objects.helpers'

local list = helpers.load_list({
  'entry_objects.marks.battle_scar_mark',
  'entry_objects.marks.swift_rhythm_mark',
  'entry_objects.marks.hunter_king_mark',
  'entry_objects.marks.chasing_wind_mark',
  'entry_objects.marks.arcane_edge_mark',
  'entry_objects.marks.slayer_mark',
  'entry_objects.marks.storm_mark',
  'entry_objects.marks.war_god_mark',
  'entry_objects.marks.void_mark',
})

return {
  list = list,
  by_id = helpers.list_to_map(list),
}

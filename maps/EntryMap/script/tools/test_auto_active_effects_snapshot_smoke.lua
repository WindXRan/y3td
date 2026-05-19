package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local mod = require 'runtime.effects.auto_active_effects'

local state = {}
local system = mod.create({
  STATE = state,
  y3 = {},
  attack_skill_slot_count = 5,
  ATTACK_SKILL_VFX = {},
})

local effect_defs = system.get_effect_defs()
assert(type(effect_defs) == 'table' and #effect_defs > 0, 'expected at least one auto active effect')

local effect_id = assert(effect_defs[1].id, 'expected first auto active effect id')
state.auto_active_effects = {
  cooldowns = {},
  counters = {},
  last_trigger_result = {},
  last_modifier_apply = {
    [effect_id] = {
      modifier_key = 123,
      success = true,
      reason = 'smoke',
    },
  },
  temp_attr_bonuses = {},
  temp_target_bonuses = {},
  pending_skill_resets = {},
}

local snapshot = system.get_effect_runtime_snapshot(effect_id)
assert(type(snapshot) == 'table', 'expected snapshot table')
assert(type(snapshot.last_modifier_apply) == 'table', 'expected last_modifier_apply table')
assert(snapshot.last_modifier_apply.modifier_key == 123, 'expected copied modifier key')

snapshot.last_modifier_apply.modifier_key = 456
assert(
  state.auto_active_effects.last_modifier_apply[effect_id].modifier_key == 123,
  'expected snapshot modifier table to be cloned'
)

print('auto active effects snapshot smoke ok')

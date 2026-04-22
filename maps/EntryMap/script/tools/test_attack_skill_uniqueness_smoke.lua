package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local RuntimeEditorIds = require 'data.object_tables.runtime_editor_ids'
local Json = require 'y3.tools.json'
local Audio = require 'runtime.audio'

local runtime_audio = Audio.create({
  STATE = {},
})

local unique_skill_ids = {
  'sword_wave',
  'arcane_laser',
  'arcane_ray',
  'frost_nova',
  'chain_lightning',
  'earthquake',
  'tornado',
  'electro_net',
  'meteor',
  'hurricane',
  'fireball',
  'moon_blade',
  'lotus_flame',
  'demon_seal',
  'flying_swords',
}

local seen_impact_particles = {}
local seen_impact_audio_ids = {}

local function read_text_file(path)
  local handle = io.open(path, 'r')
  if not handle then
    return nil
  end
  local content = handle:read('*a')
  handle:close()
  return content
end

local function load_ability_json(skill_id)
  local ability_key = RuntimeEditorIds.ability[skill_id]
  assert(ability_key ~= nil, 'expected editor ability key for ' .. tostring(skill_id))

  local path_patterns = {
    'maps/EntryMap/editor_table/abilityall/%s.json',
    'editor_table/abilityall/%s.json',
    '../editor_table/abilityall/%s.json',
  }

  for _, pattern in ipairs(path_patterns) do
    local content = read_text_file(string.format(pattern, tostring(ability_key)))
    if content and content ~= '' then
      local ok, data = pcall(Json.decode, content)
      assert(ok and type(data) == 'table', 'expected valid ability json for ' .. tostring(skill_id))
      return data
    end
  end

  error('ability json missing for ' .. tostring(skill_id))
end

local function load_projectile_json(skill_id)
  local projectile_key = RuntimeEditorIds.projectile[skill_id]
  assert(projectile_key ~= nil, 'expected editor projectile key for ' .. tostring(skill_id))

  local path_patterns = {
    'maps/EntryMap/editor_table/projectileall/%s.json',
    'editor_table/projectileall/%s.json',
    '../editor_table/projectileall/%s.json',
  }

  for _, pattern in ipairs(path_patterns) do
    local content = read_text_file(string.format(pattern, tostring(projectile_key)))
    if content and content ~= '' then
      local ok, data = pcall(Json.decode, content)
      assert(ok and type(data) == 'table', 'expected valid projectile json for ' .. tostring(skill_id))
      return data
    end
  end

  error('projectile json missing for ' .. tostring(skill_id))
end

local function load_sound_json(sound_key)
  local path_patterns = {
    'maps/EntryMap/editor_table/soundall/%s.json',
    'editor_table/soundall/%s.json',
    '../editor_table/soundall/%s.json',
  }

  for _, pattern in ipairs(path_patterns) do
    local content = read_text_file(string.format(pattern, tostring(sound_key)))
    if content and content ~= '' then
      local ok, data = pcall(Json.decode, content)
      assert(ok and type(data) == 'table', 'expected valid sound json for ' .. tostring(sound_key))
      return data
    end
  end

  error('sound json missing for ' .. tostring(sound_key))
end

for _, skill_id in ipairs(unique_skill_ids) do
  local ability_data = load_ability_json(skill_id)
  local projectile_data = load_projectile_json(skill_id)

  local impact_particle = tonumber(
    ability_data.hit_sfx_list
      and ability_data.hit_sfx_list.items
      and ability_data.hit_sfx_list.items[1]
      and ability_data.hit_sfx_list.items[1][1]
  ) or tonumber(
    projectile_data.effect_foes
      and projectile_data.effect_foes.items
      and projectile_data.effect_foes.items[1]
  )
  assert(impact_particle ~= nil and impact_particle > 0, 'expected impact_particle for ' .. tostring(skill_id))
  assert(seen_impact_particles[impact_particle] == nil,
    string.format('expected unique impact_particle, but %s reused %s from %s', tostring(skill_id), tostring(impact_particle), tostring(seen_impact_particles[impact_particle])))
  seen_impact_particles[impact_particle] = skill_id

  local object_audio_items = ability_data.hit_sound_effect and ability_data.hit_sound_effect.items or nil
  assert(type(object_audio_items) == 'table' and object_audio_items[1] ~= nil, 'expected object hit_sound_effect for ' .. tostring(skill_id))
  local object_cast_audio_items = ability_data.cst_sound_effect and ability_data.cst_sound_effect.items or nil
  assert(type(object_cast_audio_items) == 'table' and object_cast_audio_items[1] ~= nil, 'expected object cst_sound_effect for ' .. tostring(skill_id))
  local object_end_audio_items = ability_data.end_sound_effect and ability_data.end_sound_effect.items or nil
  assert(type(object_end_audio_items) == 'table' and object_end_audio_items[1] ~= nil, 'expected object end_sound_effect for ' .. tostring(skill_id))
  assert(load_sound_json(object_cast_audio_items[1]).key == object_cast_audio_items[1], 'expected cast sound object for ' .. tostring(skill_id))
  assert(load_sound_json(object_audio_items[1]).key == object_audio_items[1], 'expected impact sound object for ' .. tostring(skill_id))
  assert(load_sound_json(object_end_audio_items[1]).key == object_end_audio_items[1], 'expected burst sound object for ' .. tostring(skill_id))

  local _, impact_config = runtime_audio.debug_get_attack_skill_stage_config(skill_id, 'impact')
  assert(type(impact_config) == 'table', 'expected impact audio config for ' .. tostring(skill_id))
  assert(type(impact_config.ids) == 'table' and impact_config.ids[1] ~= nil, 'expected impact audio ids for ' .. tostring(skill_id))
  local first_audio_id = tostring(impact_config.ids[1])
  assert(first_audio_id == tostring(object_audio_items[1]),
    string.format('expected runtime impact audio to use object data for %s, got %s vs %s', tostring(skill_id), tostring(first_audio_id), tostring(object_audio_items[1])))
  assert(seen_impact_audio_ids[first_audio_id] == nil,
    string.format('expected unique impact audio first id, but %s reused %s from %s', tostring(skill_id), first_audio_id, tostring(seen_impact_audio_ids[first_audio_id])))
  seen_impact_audio_ids[first_audio_id] = skill_id

  local _, cast_config = runtime_audio.debug_get_attack_skill_stage_config(skill_id, 'cast')
  assert(type(cast_config) == 'table', 'expected cast audio config for ' .. tostring(skill_id))
  assert(type(cast_config.ids) == 'table' and cast_config.ids[1] ~= nil, 'expected cast audio ids for ' .. tostring(skill_id))
  assert(tostring(cast_config.ids[1]) == tostring(object_cast_audio_items[1]),
    string.format('expected runtime cast audio to use object data for %s, got %s vs %s', tostring(skill_id), tostring(cast_config.ids[1]), tostring(object_cast_audio_items[1])))

  local _, burst_config = runtime_audio.debug_get_attack_skill_stage_config(skill_id, 'burst')
  assert(type(burst_config) == 'table', 'expected burst audio config for ' .. tostring(skill_id))
  assert(type(burst_config.ids) == 'table' and burst_config.ids[1] ~= nil, 'expected burst audio ids for ' .. tostring(skill_id))
  assert(tostring(burst_config.ids[1]) == tostring(object_end_audio_items[1]),
    string.format('expected runtime burst audio to use object data for %s, got %s vs %s', tostring(skill_id), tostring(burst_config.ids[1]), tostring(object_end_audio_items[1])))
end

print('[OK] attack skill uniqueness smoke passed')

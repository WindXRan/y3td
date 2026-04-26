package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local waves = require 'data.object_tables.waves'
local challenges = require 'data.object_tables.challenges'

local wave_ids = {}
for _, wave in ipairs(waves.list or {}) do
  assert(wave.id ~= nil and wave.id ~= '', 'expected wave id')
  assert(wave.index ~= nil and wave.index > 0, 'expected positive wave index: ' .. tostring(wave.id))
  assert(wave_ids[wave.id] == nil, 'expected unique wave id: ' .. tostring(wave.id))
  assert(type(wave.spawn_segments) == 'table' and #wave.spawn_segments > 0, 'expected wave segments: ' .. tostring(wave.id))
  wave_ids[wave.id] = wave
end

local challenge_ids = {}
for _, challenge in ipairs(challenges.list or {}) do
  assert(challenge.id ~= nil and challenge.id ~= '', 'expected challenge id')
  assert(challenge.order_index ~= nil and challenge.order_index > 0, 'expected positive challenge order_index: ' .. tostring(challenge.id))
  assert(challenge.duration_sec ~= nil and challenge.duration_sec > 0, 'expected positive challenge duration: ' .. tostring(challenge.id))
  assert(type(challenge.batches) == 'table' and #challenge.batches > 0, 'expected challenge batches: ' .. tostring(challenge.id))
  assert(challenge_ids[challenge.id] == nil, 'expected unique challenge id: ' .. tostring(challenge.id))
  challenge_ids[challenge.id] = challenge
end

for wave_id, wave in pairs(wave_ids) do
  local previous_start_sec = -1
  for _, segment in ipairs(wave.spawn_segments or {}) do
    assert(segment.start_sec >= previous_start_sec, 'expected nondecreasing segment start_sec: ' .. tostring(wave_id))
    assert(segment.interval_sec > 0, 'expected positive segment interval_sec: ' .. tostring(wave_id))
    previous_start_sec = segment.start_sec
  end
end

for challenge_id, challenge in pairs(challenge_ids) do
  for _, batch in ipairs(challenge.batches or {}) do
    assert(batch.time_sec ~= nil and batch.time_sec >= 0, 'expected nonnegative batch time_sec: ' .. tostring(challenge_id))
    assert(batch.count ~= nil and batch.count > 0, 'expected positive batch count: ' .. tostring(challenge_id))
  end
end

print('[OK] waves challenges catalog consistency smoke passed')

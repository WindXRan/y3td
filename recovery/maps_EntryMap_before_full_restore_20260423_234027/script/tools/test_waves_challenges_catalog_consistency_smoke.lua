package.path = 'script/?.lua;script/?/init.lua;script/?/?.lua;maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local CsvLoader = require 'data.csv_loader'
local waves = require 'data.object_tables.waves'
local challenges = require 'data.object_tables.challenges'

local wave_segment_rows = CsvLoader.read_rows('data_csv/wave_spawn_segments.csv')
local wave_attr_rows = CsvLoader.read_rows('data_csv/wave_main_attr_overrides.csv')
local challenge_batch_rows = CsvLoader.read_rows('data_csv/challenge_batches.csv')

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

local segment_groups = {}
for _, row in ipairs(wave_segment_rows) do
  assert(wave_ids[row.wave_id] ~= nil, 'expected segment wave to exist: ' .. tostring(row.wave_id))
  segment_groups[row.wave_id] = segment_groups[row.wave_id] or {}
  segment_groups[row.wave_id][#segment_groups[row.wave_id] + 1] = {
    segment_index = tonumber(row.segment_index) or 0,
    start_sec = tonumber(row.start_sec) or 0,
  }
end

for wave_id, rows in pairs(segment_groups) do
  table.sort(rows, function(a, b)
    return a.segment_index < b.segment_index
  end)

  local seen_indices = {}
  local previous_start_sec = -1
  for _, row in ipairs(rows) do
    assert(row.segment_index > 0, 'expected positive segment_index: ' .. tostring(wave_id))
    assert(seen_indices[row.segment_index] == nil, 'expected unique segment_index: ' .. tostring(wave_id))
    assert(row.start_sec >= previous_start_sec, 'expected nondecreasing segment start_sec: ' .. tostring(wave_id))
    seen_indices[row.segment_index] = true
    previous_start_sec = row.start_sec
  end
end

for _, row in ipairs(wave_attr_rows) do
  assert(wave_ids[row.wave_id] ~= nil, 'expected attr override wave to exist: ' .. tostring(row.wave_id))
  assert(row.attr_name ~= nil and row.attr_name ~= '', 'expected attr override attr_name: ' .. tostring(row.wave_id))
  assert(row.value ~= nil and row.value ~= '', 'expected attr override value: ' .. tostring(row.wave_id))
end

local batch_groups = {}
for _, row in ipairs(challenge_batch_rows) do
  assert(challenge_ids[row.challenge_id] ~= nil, 'expected batch challenge to exist: ' .. tostring(row.challenge_id))
  batch_groups[row.challenge_id] = batch_groups[row.challenge_id] or {}
  batch_groups[row.challenge_id][#batch_groups[row.challenge_id] + 1] = {
    batch_index = tonumber(row.batch_index) or 0,
    time_sec = tonumber(row.time_sec) or 0,
  }
end

for challenge_id, rows in pairs(batch_groups) do
  table.sort(rows, function(a, b)
    return a.batch_index < b.batch_index
  end)

  local seen_indices = {}
  local previous_time_sec = -1
  for _, row in ipairs(rows) do
    assert(row.batch_index > 0, 'expected positive batch_index: ' .. tostring(challenge_id))
    assert(seen_indices[row.batch_index] == nil, 'expected unique batch_index: ' .. tostring(challenge_id))
    assert(row.time_sec >= previous_time_sec, 'expected nondecreasing batch time_sec: ' .. tostring(challenge_id))
    seen_indices[row.batch_index] = true
    previous_time_sec = row.time_sec
  end
end

print('[OK] waves challenges catalog consistency smoke passed')

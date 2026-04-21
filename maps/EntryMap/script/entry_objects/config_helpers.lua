local battle_base = require 'data.object_tables.battle_base_config'
local global_rules = battle_base.global_rules or {}

local function resolve_debug_time_scale()
  local raw
  if y3.game.is_debug_mode() then
    raw = tonumber(global_rules.debug_time_scale_debug)
  else
    raw = tonumber(global_rules.debug_time_scale_release)
  end
  if raw == nil or raw <= 0 then
    return 1.0
  end
  return raw
end

local DEBUG_TIME_SCALE = resolve_debug_time_scale()

local M = {
  debug_time_scale = DEBUG_TIME_SCALE,
}

function M.scale(seconds)
  return seconds * DEBUG_TIME_SCALE
end

function M.segment(start_sec, interval_sec)
  return {
    start_sec = M.scale(start_sec),
    interval_sec = M.scale(interval_sec),
  }
end

function M.challenge_batch(time_sec, count)
  return {
    time_sec = M.scale(time_sec),
    count = count,
  }
end

return M

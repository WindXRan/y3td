local DEBUG_TIME_SCALE = y3.game.is_debug_mode() and 0.2 or 1.0

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
